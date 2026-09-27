import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/idempotency_key.dart';
import '../../auth/application/auth_controller.dart';
import '../../merchants/data/merchants_repository.dart';
import '../../merchants/data/models/merchant.dart';
import '../data/merchant_wallet_repository.dart';
import '../data/models/merchant_wallet.dart';
import 'business_context.dart';

final merchantWalletProvider = FutureProvider<MerchantWallet>((ref) {
  ref.watch(sessionEpochProvider);
  return ref.watch(merchantWalletRepositoryProvider).wallet();
});

/// Merchants this shop could spend Blue Coin at: active, not itself, and
/// (pre-validated client-side, because the backend answers 500 for these)
/// accepting Town Coin with a positive discount rate. Searched by name.
final spendTargetMerchantsProvider = FutureProvider.autoDispose.family<List<Merchant>, String>((ref, query) async {
  final myId = ref.watch(myMerchantIdProvider);
  final page = await ref.watch(merchantsRepositoryProvider).list(perPage: 20, acceptsTownCoin: true, search: query);
  return page.items.where((m) => m.id != myId && (m.discountRate ?? 0) > 0).toList();
});

class SpendBlueCoinState {
  const SpendBlueCoinState({this.target, this.billAmount = '', this.isSubmitting = false, this.error, this.result, required this.idempotencyKey});

  final Merchant? target;
  final String billAmount;
  final bool isSubmitting;
  final AppException? error;
  final MerchantBlueRedemption? result;
  final String idempotencyKey;

  double? get amountValue => double.tryParse(billAmount.trim());
  bool get isAmountValid => (amountValue ?? 0) > 0;
  bool get canSubmit => target != null && isAmountValid && !isSubmitting;

  /// Estimate shown before confirming: min(bill × rate, bill, balance in
  /// rupees). [coinToInrRate] comes from the wallet the server returned --
  /// the same figure MerchantCoinLedgerService uses -- so this never
  /// drifts from what the server will actually charge.
  double estimatedDiscount(int blueBalance, int coinToInrRate) {
    final bill = amountValue ?? 0;
    final rate = target?.discountRate ?? 0;
    final capped = (bill * rate / 100).clamp(0, bill).toDouble();
    final coins = (capped * coinToInrRate).floor().clamp(0, blueBalance);
    return coins / coinToInrRate;
  }

  SpendBlueCoinState copyWith({Merchant? target, bool clearTarget = false, String? billAmount, bool? isSubmitting, AppException? error, bool clearError = false, MerchantBlueRedemption? result, String? idempotencyKey}) {
    return SpendBlueCoinState(
      target: clearTarget ? null : (target ?? this.target),
      billAmount: billAmount ?? this.billAmount,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      result: result ?? this.result,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }
}

/// "Spend Blue Coin at another merchant". One idempotency key per opened
/// sheet, kept across a failed retry (same as the web dialog).
class SpendBlueCoinController extends Notifier<SpendBlueCoinState> {
  @override
  SpendBlueCoinState build() => SpendBlueCoinState(idempotencyKey: generateIdempotencyKey());

  void setTarget(Merchant? m) => state = state.copyWith(target: m, clearTarget: m == null, clearError: true);
  void setBillAmount(String v) => state = state.copyWith(billAmount: v, clearError: true);

  Future<void> submit() async {
    if (!state.canSubmit) return;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final result = await ref.read(merchantWalletRepositoryProvider).redeemBlueCoin(
            redeemingMerchantId: state.target!.id,
            billAmount: state.amountValue!,
            idempotencyKey: state.idempotencyKey,
          );
      ref.invalidate(merchantWalletProvider);
      state = state.copyWith(isSubmitting: false, result: result);
    } on ServerException {
      state = state.copyWith(
        isSubmitting: false,
        error: const UnknownAppException('That merchant cannot take Blue Coin for this bill right now — check they accept Town Coin and that you have a Blue Coin balance.'),
      );
    } on AppException catch (e) {
      state = state.copyWith(isSubmitting: false, error: e);
    }
  }
}

final spendBlueCoinControllerProvider = NotifierProvider.autoDispose<SpendBlueCoinController, SpendBlueCoinState>(SpendBlueCoinController.new);
