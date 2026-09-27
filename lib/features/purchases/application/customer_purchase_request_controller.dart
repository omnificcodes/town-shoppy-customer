import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/idempotency_key.dart';
import '../../merchants/data/merchants_repository.dart';
import '../../merchants/data/models/merchant.dart';
import '../../wallet/application/wallet_controller.dart';
import '../../wallet/data/models/silver_wallet_balance.dart';
import '../data/models/counter_redemption.dart';
import '../data/models/merchant_purchase_qr_resolution.dart';
import '../data/models/purchase.dart';
import '../data/models/purchase_request_target.dart';
import '../data/purchases_repository.dart';
import 'purchases_list_controller.dart';

/// Where the customer is in the counter flow. These are client-side steps
/// only: nothing exists on the backend until [CounterStep.waiting], when a
/// real Purchase (and usually a Redemption) row has been created.
enum CounterStep { amount, review, waiting }

/// Method 1 (3-way purchase architecture): customer scans a merchant/
/// branch's Purchase QR, enters the bill, sees what their Town Coins take
/// off it, confirms, and then waits at the counter while the merchant
/// settles it.
class CustomerPurchaseRequestState {
  const CustomerPurchaseRequestState({
    this.isResolving = false,
    this.resolution,
    this.resolveError,
    this.billAmountText = '',
    this.isSubmitting = false,
    this.submitError,
    this.result,
    this.redemption,
    this.step = CounterStep.amount,
    this.redeem = true,
    this.walletBalance,
    required this.idempotencyKey,
  });

  final bool isResolving;
  final MerchantPurchaseQrResolution? resolution;
  final AppException? resolveError;
  final String billAmountText;
  final bool isSubmitting;
  final AppException? submitError;
  final Purchase? result;
  final CounterRedemption? redemption;
  final CounterStep step;

  /// Spend coins on this bill. On by default -- the customer opened this
  /// flow to pay less; they can still turn it off before confirming.
  final bool redeem;

  /// Needed for the estimate only. Null while it is still loading, or when
  /// it could not be read, in which case the estimate falls back to the
  /// merchant's rate alone.
  final SilverWalletBalance? walletBalance;

  final String idempotencyKey;

  /// Matches RequestPurchaseRequest's `min:0.01`/`max:1000000` bounds --
  /// mirrored here for responsive UI feedback only, the backend remains
  /// authoritative.
  double? get billAmount {
    final parsed = double.tryParse(billAmountText.trim());
    if (parsed == null || parsed < 0.01 || parsed > 1000000) return null;
    return parsed;
  }

  /// What the coins are expected to take off this bill, by the same two
  /// caps `RedemptionCalculator` applies server-side: the merchant's own
  /// percentage of the bill, and the rupee value of the wallet. An
  /// ESTIMATE -- the server recomputes it, and its figure is the one that
  /// reaches [redemption].
  double get estimatedDiscount {
    final amount = billAmount;
    final merchant = resolution;
    if (amount == null || merchant == null || !merchant.canDiscount || !redeem) return 0;

    final merchantCap = math.min(amount * merchant.discountRate! / 100, amount);
    final walletCap = walletBalance?.balanceInrEquivalent;
    final capped = walletCap != null ? math.min(merchantCap, walletCap) : merchantCap;

    return (capped * 100).round() / 100;
  }

  /// The number the whole screen is built around: what the customer hands
  /// over at the counter.
  double get estimatedPayable => math.max((billAmount ?? 0) - estimatedDiscount, 0);

  /// The customer's Town Coins, when the wallet has loaded.
  int? get availableCoins => walletBalance?.balance;

  /// The coins [estimatedDiscount] would use, at the rate the server
  /// published with the wallet (never a rate hardcoded here, and no longer
  /// back-derived from balance ÷ rupees, which was undefined for an empty
  /// wallet). An estimate, like the discount: the server's figure replaces
  /// it once the request exists.
  int get estimatedCoins {
    final wallet = walletBalance;
    final discount = estimatedDiscount;
    if (wallet == null || discount <= 0) return 0;
    return math.min((discount * wallet.coinToInrRate).round(), wallet.balance);
  }

  bool get canContinue => resolution != null && billAmount != null && !isSubmitting;

  bool get canSubmit => canContinue && step == CounterStep.review;

  CustomerPurchaseRequestState copyWith({
    bool? isResolving,
    MerchantPurchaseQrResolution? resolution,
    AppException? resolveError,
    bool clearResolveError = false,
    String? billAmountText,
    bool? isSubmitting,
    AppException? submitError,
    bool clearSubmitError = false,
    Purchase? result,
    CounterRedemption? redemption,
    CounterStep? step,
    bool? redeem,
    SilverWalletBalance? walletBalance,
    String? idempotencyKey,
  }) {
    return CustomerPurchaseRequestState(
      isResolving: isResolving ?? this.isResolving,
      resolution: resolution ?? this.resolution,
      resolveError: clearResolveError ? null : (resolveError ?? this.resolveError),
      billAmountText: billAmountText ?? this.billAmountText,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
      result: result ?? this.result,
      redemption: redemption ?? this.redemption,
      step: step ?? this.step,
      redeem: redeem ?? this.redeem,
      walletBalance: walletBalance ?? this.walletBalance,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }
}

/// One scan-and-pay attempt. A fresh instance per screen open
/// (`autoDispose`) -- nothing carries over between separate attempts,
/// including a re-scan of a different QR.
class CustomerPurchaseRequestController extends Notifier<CustomerPurchaseRequestState> {
  PurchaseRequestTarget? _target;

  @override
  CustomerPurchaseRequestState build() {
    // Listened to, not watched: watching would re-run build() when the
    // balance arrives and throw away the amount the customer has already
    // typed. The balance only feeds the estimate, so a failure to read it
    // is never surfaced -- the estimate falls back to the merchant's rate,
    // and the server's own figure replaces it on submit either way.
    ref.listen(walletControllerProvider, (previous, next) {
      final balance = next.value;
      if (balance != null) state = state.copyWith(walletBalance: balance);
    });

    return CustomerPurchaseRequestState(
      idempotencyKey: generateIdempotencyKey(),
      // Already loaded by the time this flow opens, in the common case --
      // the listener above only covers a balance that arrives later.
      walletBalance: ref.read(walletControllerProvider).value,
    );
  }

  /// Where this request is going. A scanned token has to be resolved to
  /// find out who it belongs to; a merchant chosen from its profile is
  /// already known, so the form is ready at once with no round trip.
  Future<void> start(PurchaseRequestTarget target) async {
    if (state.isResolving) return;

    _target = target;
    switch (target) {
      case ScannedPurchaseTarget(:final token):
        state = state.copyWith(isResolving: true, clearResolveError: true);
        try {
          final resolution = await ref.read(purchasesRepositoryProvider).resolveMerchantQr(token);
          state = state.copyWith(isResolving: false, resolution: resolution);
        } on AppException catch (e) {
          state = state.copyWith(isResolving: false, resolveError: e);
        }
      case MerchantPurchaseTarget(merchant: final Merchant merchant):
        state = state.copyWith(
          isResolving: false,
          clearResolveError: true,
          resolution: MerchantPurchaseQrResolution.fromMerchant(merchant),
        );
      case MerchantPurchaseTarget(:final merchantId):
        // Only the ids made it here (a browser round trip drops the
        // profile snapshot -- see PurchaseRequestTarget), so fetch what
        // the form shows. Still no scan: the customer picked this shop.
        state = state.copyWith(isResolving: true, clearResolveError: true);
        try {
          final merchant = await ref.read(merchantsRepositoryProvider).show(merchantId);
          state = state.copyWith(isResolving: false, resolution: MerchantPurchaseQrResolution.fromMerchant(merchant));
        } on AppException catch (e) {
          state = state.copyWith(isResolving: false, resolveError: e);
        }
    }
  }

  Future<void> resolveScannedToken(String token) => start(PurchaseRequestTarget.scanned(token));

  void setBillAmount(String text) {
    if (state.billAmountText == text) return;
    // A different amount against the same scanned token is still "a fresh
    // request" from the backend's point of view (RequestPurchaseRequest's
    // idempotency semantics match RecordPurchaseRequest's) -- new key.
    state = state.copyWith(billAmountText: text, idempotencyKey: generateIdempotencyKey(), clearSubmitError: true);
  }

  void setRedeem(bool redeem) {
    if (state.redeem == redeem) return;
    // Redeeming or not is part of what the request IS, so it needs its own
    // key for the same reason a changed amount does.
    state = state.copyWith(redeem: redeem, idempotencyKey: generateIdempotencyKey(), clearSubmitError: true);
  }

  void review() {
    if (!state.canContinue) return;
    state = state.copyWith(step: CounterStep.review, clearSubmitError: true);
  }

  void backToAmount() {
    if (state.step != CounterStep.review) return;
    state = state.copyWith(step: CounterStep.amount, clearSubmitError: true);
  }

  Future<void> submit() async {
    final target = _target;
    final amount = state.billAmount;
    if (state.isSubmitting || target == null || amount == null) return;

    state = state.copyWith(isSubmitting: true, clearSubmitError: true);
    try {
      final result = await ref.read(purchasesRepositoryProvider).requestPurchase(
            target: target,
            billAmount: amount,
            idempotencyKey: state.idempotencyKey,
            redeem: state.redeem,
          );

      // The new pending request should appear in "my purchases" without a
      // hard refresh.
      ref.invalidate(purchasesListControllerProvider);

      state = state.copyWith(
        isSubmitting: false,
        result: result.purchase,
        redemption: result.redemption,
        step: CounterStep.waiting,
      );
    } on AppException catch (e) {
      // Preserve the resolved merchant/branch and typed amount -- only the
      // in-flight flag and error change, so a network-failure retry
      // re-sends the same (target, amount, Idempotency-Key) tuple safely.
      state = state.copyWith(isSubmitting: false, submitError: e);
    }
  }
}

final customerPurchaseRequestControllerProvider =
    NotifierProvider.autoDispose<CustomerPurchaseRequestController, CustomerPurchaseRequestState>(
  CustomerPurchaseRequestController.new,
);
