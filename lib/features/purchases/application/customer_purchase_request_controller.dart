import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/idempotency_key.dart';
import '../data/models/merchant_purchase_qr_resolution.dart';
import '../data/models/purchase.dart';
import '../data/purchases_repository.dart';
import 'purchases_list_controller.dart';

/// Method 1 (3-way purchase architecture): customer scans a merchant/
/// branch's Purchase QR, confirms the resolved merchant/branch, enters a
/// bill amount, and submits. Same shape as RedemptionInitiationController
/// (scan replaces branch-selection as the first step) -- see that class's
/// own docblock for the family-provider/idempotency-key reasoning this
/// mirrors.
class CustomerPurchaseRequestState {
  const CustomerPurchaseRequestState({
    this.isResolving = false,
    this.resolution,
    this.resolveError,
    this.billAmountText = '',
    this.isSubmitting = false,
    this.submitError,
    this.result,
    required this.idempotencyKey,
  });

  final bool isResolving;
  final MerchantPurchaseQrResolution? resolution;
  final AppException? resolveError;
  final String billAmountText;
  final bool isSubmitting;
  final AppException? submitError;
  final Purchase? result;
  final String idempotencyKey;

  /// Matches RequestPurchaseRequest's `min:0.01`/`max:1000000` bounds --
  /// mirrored here for responsive UI feedback only, the backend remains
  /// authoritative.
  double? get billAmount {
    final parsed = double.tryParse(billAmountText.trim());
    if (parsed == null || parsed < 0.01 || parsed > 1000000) return null;
    return parsed;
  }

  bool get canSubmit => resolution != null && billAmount != null && !isSubmitting;

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
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }
}

/// One scan-and-request attempt. A fresh instance per screen open
/// (`autoDispose`) -- nothing carries over between separate attempts,
/// including a re-scan of a different QR.
class CustomerPurchaseRequestController extends Notifier<CustomerPurchaseRequestState> {
  String? _token;

  @override
  CustomerPurchaseRequestState build() {
    return CustomerPurchaseRequestState(idempotencyKey: generateIdempotencyKey());
  }

  Future<void> resolveScannedToken(String token) async {
    if (state.isResolving) return;

    _token = token;
    state = state.copyWith(isResolving: true, clearResolveError: true);
    try {
      final resolution = await ref.read(purchasesRepositoryProvider).resolveMerchantQr(token);
      state = state.copyWith(isResolving: false, resolution: resolution);
    } on AppException catch (e) {
      state = state.copyWith(isResolving: false, resolveError: e);
    }
  }

  void setBillAmount(String text) {
    if (state.billAmountText == text) return;
    // A different amount against the same scanned token is still "a fresh
    // request" from the backend's point of view (RequestPurchaseRequest's
    // idempotency semantics match RecordPurchaseRequest's) -- new key.
    state = state.copyWith(billAmountText: text, idempotencyKey: generateIdempotencyKey(), clearSubmitError: true);
  }

  Future<void> submit() async {
    final token = _token;
    final amount = state.billAmount;
    if (state.isSubmitting || token == null || amount == null) return;

    state = state.copyWith(isSubmitting: true, clearSubmitError: true);
    try {
      final purchase = await ref.read(purchasesRepositoryProvider).requestPurchase(
            token: token,
            billAmount: amount,
            idempotencyKey: state.idempotencyKey,
          );

      // The new pending request should appear in "my purchases" without a
      // hard refresh.
      ref.invalidate(purchasesListControllerProvider);

      state = state.copyWith(isSubmitting: false, result: purchase);
    } on AppException catch (e) {
      // Preserve the resolved merchant/branch and typed amount -- only the
      // in-flight flag and error change, so a network-failure retry
      // re-sends the same (token, amount, Idempotency-Key) tuple safely.
      state = state.copyWith(isSubmitting: false, submitError: e);
    }
  }
}

final customerPurchaseRequestControllerProvider =
    NotifierProvider.autoDispose<CustomerPurchaseRequestController, CustomerPurchaseRequestState>(
  CustomerPurchaseRequestController.new,
);
