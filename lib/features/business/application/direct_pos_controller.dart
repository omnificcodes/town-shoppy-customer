import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/idempotency_key.dart';
import '../../notifications/application/unread_count_provider.dart';
import '../data/direct_pos_repository.dart';
import '../data/models/direct_pos.dart';
import 'business_context.dart';
import 'business_purchases_controller.dart';

enum DirectPosMethod { mobile, qr }

/// Everything the counter form holds, in one immutable value. Mirrors the
/// web `DirectPosForm`'s state one-to-one (including its idempotency-key
/// rotation rule) so the two behave identically against the same API.
class DirectPosState {
  const DirectPosState({
    this.method = DirectPosMethod.mobile,
    this.mobile = '',
    this.customerName = '',
    this.qrToken,
    this.lookedUp,
    this.needsRegistration = false,
    this.branchId,
    this.billAmount = '',
    this.billReference = '',
    this.redeem = true,
    this.preview,
    this.isLookingUp = false,
    this.isPreviewing = false,
    this.isSubmitting = false,
    this.error,
    this.subscriptionReason,
    this.result,
    required this.idempotencyKey,
  });

  final DirectPosMethod method;
  final String mobile;
  final String customerName;
  final String? qrToken;
  final CustomerLookupResult? lookedUp;

  /// Set when a preview 422'd for an unknown number and no lookup has
  /// contradicted it -- the form then asks for the customer's name so the
  /// submit can register them inline.
  final bool needsRegistration;
  final int? branchId;
  final String billAmount;
  final String billReference;
  final bool redeem;
  final DirectPosPreview? preview;
  final bool isLookingUp;
  final bool isPreviewing;
  final bool isSubmitting;
  final AppException? error;

  /// `no_subscription` / `quota_exhausted` from a 402 -- shown as its own
  /// banner pointing at Subscriptions, not as a generic error.
  final String? subscriptionReason;
  final DirectPosResult? result;
  final String idempotencyKey;

  double? get amountValue => double.tryParse(billAmount.trim());

  bool get isAmountValid {
    final v = amountValue;
    return v != null && v >= 0.01 && v <= 1000000;
  }

  bool get hasIdentity => method == DirectPosMethod.mobile ? mobile.trim().isNotEmpty : qrToken != null;

  bool get canSearch => method == DirectPosMethod.mobile && mobile.replaceAll(RegExp(r'\D'), '').length >= 10;

  /// A lookup that said "not registered" is authoritative; a preview's 422
  /// is the fallback for a number never searched.
  bool get mustRegister => (lookedUp != null && !lookedUp!.registered) || needsRegistration;

  bool get canSubmit => hasIdentity && isAmountValid && !isSubmitting;

  DirectPosIdentity get identity => method == DirectPosMethod.qr
      ? DirectPosIdentity.qr(qrToken)
      : DirectPosIdentity.mobile(mobile.trim(), customerName: mustRegister ? customerName : null);

  /// What the idempotency key protects: a change here means a genuinely
  /// different purchase and gets a fresh key.
  String get signature => '${method == DirectPosMethod.qr ? 'qr:${qrToken ?? ''}' : 'mobile:$mobile'}|$branchId|$billAmount|$redeem';

  DirectPosState copyWith({
    DirectPosMethod? method,
    String? mobile,
    String? customerName,
    String? qrToken,
    bool clearQrToken = false,
    CustomerLookupResult? lookedUp,
    bool clearLookedUp = false,
    bool? needsRegistration,
    int? branchId,
    bool clearBranch = false,
    String? billAmount,
    String? billReference,
    bool? redeem,
    DirectPosPreview? preview,
    bool clearPreview = false,
    bool? isLookingUp,
    bool? isPreviewing,
    bool? isSubmitting,
    AppException? error,
    bool clearError = false,
    String? subscriptionReason,
    bool clearSubscriptionReason = false,
    DirectPosResult? result,
    String? idempotencyKey,
  }) {
    return DirectPosState(
      method: method ?? this.method,
      mobile: mobile ?? this.mobile,
      customerName: customerName ?? this.customerName,
      qrToken: clearQrToken ? null : (qrToken ?? this.qrToken),
      lookedUp: clearLookedUp ? null : (lookedUp ?? this.lookedUp),
      needsRegistration: needsRegistration ?? this.needsRegistration,
      branchId: clearBranch ? null : (branchId ?? this.branchId),
      billAmount: billAmount ?? this.billAmount,
      billReference: billReference ?? this.billReference,
      redeem: redeem ?? this.redeem,
      preview: clearPreview ? null : (preview ?? this.preview),
      isLookingUp: isLookingUp ?? this.isLookingUp,
      isPreviewing: isPreviewing ?? this.isPreviewing,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      subscriptionReason: clearSubscriptionReason ? null : (subscriptionReason ?? this.subscriptionReason),
      result: result ?? this.result,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }
}

class DirectPosController extends Notifier<DirectPosState> {
  @override
  DirectPosState build() => DirectPosState(idempotencyKey: generateIdempotencyKey());

  /// Every field edit funnels through here so the key-rotation rule is
  /// applied in exactly one place: a changed signature invalidates both
  /// the key and any preview computed for the old inputs.
  void _set(DirectPosState next) {
    if (next.signature != state.signature) {
      state = next.copyWith(idempotencyKey: generateIdempotencyKey(), clearPreview: true, clearError: true);
    } else {
      state = next;
    }
  }

  void setMethod(DirectPosMethod method) {
    if (method == state.method) return;
    // Switching identity method discards whatever the other one had.
    _set(state.copyWith(method: method, mobile: '', customerName: '', clearQrToken: true, clearLookedUp: true, needsRegistration: false, clearPreview: true, clearError: true));
  }

  void setMobile(String value) => _set(state.copyWith(mobile: value, needsRegistration: false, clearLookedUp: true));

  void setCustomerName(String value) => state = state.copyWith(customerName: value);

  void setQrToken(String? token) => _set(state.copyWith(qrToken: token, clearQrToken: token == null, clearError: true));

  void setBranch(int? branchId) => _set(state.copyWith(branchId: branchId, clearBranch: branchId == null));

  void setBillAmount(String value) => _set(state.copyWith(billAmount: value));

  void setBillReference(String value) => state = state.copyWith(billReference: value);

  void setRedeem(bool value) => _set(state.copyWith(redeem: value));

  void reset() => state = DirectPosState(idempotencyKey: generateIdempotencyKey());

  Future<void> lookup() async {
    if (!state.canSearch || state.isLookingUp) return;
    final merchantId = ref.read(myMerchantIdProvider);
    if (merchantId == null) return;

    state = state.copyWith(isLookingUp: true, clearError: true);
    try {
      final result = await ref.read(directPosRepositoryProvider).lookupCustomer(merchantId: merchantId, mobileNumber: state.mobile);
      state = state.copyWith(isLookingUp: false, lookedUp: result, needsRegistration: false);
    } on AppException catch (e) {
      state = state.copyWith(isLookingUp: false, clearLookedUp: true, error: e);
    }
  }

  Future<void> previewDiscount() async {
    if (!state.hasIdentity || !state.isAmountValid || state.isPreviewing) return;
    final merchantId = ref.read(myMerchantIdProvider);
    if (merchantId == null) return;

    state = state.copyWith(isPreviewing: true, needsRegistration: false, clearError: true);
    try {
      final preview = await ref.read(directPosRepositoryProvider).preview(
            merchantId: merchantId,
            identity: state.identity,
            billAmount: state.amountValue!,
            branchId: state.branchId,
          );
      state = state.copyWith(isPreviewing: false, preview: preview);
    } on ValidationAppException catch (e) {
      // Unknown mobile number -- offer inline registration, not a dead end.
      if (state.method == DirectPosMethod.mobile) {
        state = state.copyWith(isPreviewing: false, needsRegistration: true);
      } else {
        state = state.copyWith(isPreviewing: false, error: e);
      }
    } on ServerException {
      // The backend throws a 500 (not a 422) when the merchant does not
      // accept Town Coin or has no discount rate -- say so plainly.
      state = state.copyWith(
        isPreviewing: false,
        error: const UnknownAppException('No Town Coin discount applies at this business yet — check the discount rate and "Accepts Town Coin" in your profile.'),
      );
    } on AppException catch (e) {
      state = state.copyWith(isPreviewing: false, error: e);
    }
  }

  Future<void> submit() async {
    if (!state.canSubmit) return;
    final merchantId = ref.read(myMerchantIdProvider);
    if (merchantId == null) return;
    if (state.mustRegister && state.customerName.trim().isEmpty) {
      state = state.copyWith(error: const UnknownAppException("Enter the customer's name to register them."));
      return;
    }

    state = state.copyWith(isSubmitting: true, clearError: true, clearSubscriptionReason: true);
    try {
      final result = await ref.read(directPosRepositoryProvider).submit(
            merchantId: merchantId,
            identity: state.identity,
            billAmount: state.amountValue!,
            redeem: state.redeem,
            idempotencyKey: state.idempotencyKey,
            branchId: state.branchId,
            billReference: state.billReference,
          );
      state = state.copyWith(isSubmitting: false, result: result);
      ref
        ..invalidate(businessPurchasesControllerProvider)
        ..invalidate(dashboardRecentPurchasesProvider)
        ..invalidate(dashboardAwaitingRedemptionsProvider)
        ..invalidate(unreadNotificationCountProvider);
    } on UnknownAppException catch (e) {
      // 402 arrives as UnknownAppException(statusCode: 402); the reason is
      // in the message text already, but the banner needs the flag.
      if (e.statusCode == 402) {
        state = state.copyWith(
          isSubmitting: false,
          subscriptionReason: e.message.contains('coupons') ? 'quota_exhausted' : 'no_subscription',
          error: e,
        );
      } else {
        state = state.copyWith(isSubmitting: false, error: e);
      }
    } on AppException catch (e) {
      state = state.copyWith(isSubmitting: false, error: e);
    }
  }
}

final directPosControllerProvider = NotifierProvider.autoDispose<DirectPosController, DirectPosState>(DirectPosController.new);
