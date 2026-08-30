import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/idempotency_key.dart';
import '../data/models/redemption_initiation_result.dart';
import '../data/redemptions_repository.dart';
import 'pending_otp_codes_provider.dart';
import 'redemptions_list_controller.dart';

/// Client-side wizard state only — branch selection and bill-amount entry
/// have no backend representation of their own (the only real backend
/// states are "not yet created" / `initiated` / `settled` / `expired` /
/// `cancelled`, per `RedemptionStatus`). Once [result] is set, the caller
/// hands off to the existing `redemptionDetailProvider` to watch the real
/// backend lifecycle rather than this controller inventing one.
class RedemptionInitiationState {
  const RedemptionInitiationState({
    this.selectedBranchId,
    this.billAmountText = '',
    this.isSubmitting = false,
    this.error,
    this.result,
    required this.idempotencyKey,
  });

  final int? selectedBranchId;
  final String billAmountText;
  final bool isSubmitting;
  final AppException? error;
  final RedemptionInitiationResult? result;
  final String idempotencyKey;

  /// Matches `InitiateRedemptionRequest`'s own `min:0.01`/`max:1000000`
  /// bounds — mirrored here for responsive UI feedback only; the backend
  /// remains the authoritative check.
  double? get billAmount {
    final parsed = double.tryParse(billAmountText.trim());
    if (parsed == null || parsed < 0.01 || parsed > 1000000) return null;
    return parsed;
  }

  bool get canSubmit => selectedBranchId != null && billAmount != null && !isSubmitting;

  RedemptionInitiationState copyWith({
    int? selectedBranchId,
    String? billAmountText,
    bool? isSubmitting,
    AppException? error,
    bool clearError = false,
    RedemptionInitiationResult? result,
    String? idempotencyKey,
  }) {
    return RedemptionInitiationState(
      selectedBranchId: selectedBranchId ?? this.selectedBranchId,
      billAmountText: billAmountText ?? this.billAmountText,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      result: result ?? this.result,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }
}

/// One redemption-initiation attempt for one merchant. A fresh instance is
/// created every time a customer opens the flow (the provider is
/// `autoDispose`d once the screen is popped), so nothing carries over
/// between separate redemption attempts, including at different merchants.
///
/// Riverpod 3.x's family notifiers take the family argument through the
/// constructor (not through `build(arg)` — `Notifier.build()` stays
/// argument-less); see `NotifierProviderFamilyBuilder`'s
/// `NotifierT Function(ArgT arg) create` signature.
class RedemptionInitiationController extends Notifier<RedemptionInitiationState> {
  RedemptionInitiationController(this.merchantId);

  final int merchantId;

  @override
  RedemptionInitiationState build() {
    return RedemptionInitiationState(idempotencyKey: generateIdempotencyKey());
  }

  /// Auto-selects when a merchant has exactly one branch (section 6: "avoid
  /// unnecessary friction"); a multi-branch merchant requires an explicit
  /// tap via the interactive `BranchSelector`.
  void selectBranch(int branchId) {
    if (state.selectedBranchId == branchId) return;

    // Editing the request after any point changes what the backend would
    // consider "the same request" for the Idempotency-Key it was given —
    // RedemptionService.assertSameRequestContext() rejects a reused key
    // whose merchant/amount changed, so a genuinely different selection
    // needs a fresh key. A retry of the *same* selection (this early
    // return, above) correctly keeps replaying with the same key.
    state = state.copyWith(selectedBranchId: branchId, idempotencyKey: generateIdempotencyKey(), clearError: true);
  }

  void setBillAmount(String text) {
    if (state.billAmountText == text) return;
    state = state.copyWith(billAmountText: text, idempotencyKey: generateIdempotencyKey(), clearError: true);
  }

  Future<void> submit() async {
    final branchId = state.selectedBranchId;
    final amount = state.billAmount;
    if (state.isSubmitting || branchId == null || amount == null) return;

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final result = await ref.read(redemptionsRepositoryProvider).initiate(
            merchantId: merchantId,
            branchId: branchId,
            billAmount: amount,
            idempotencyKey: state.idempotencyKey,
          );

      if (result.otpCode != null) {
        ref.read(pendingOtpCodesProvider.notifier).stash(result.redemption.id, result.otpCode!);
      }

      // The new redemption should appear in the customer's history without
      // a hard refresh.
      ref.invalidate(redemptionsListControllerProvider);

      state = state.copyWith(isSubmitting: false, result: result);
    } on AppException catch (e) {
      // Preserve the selected branch and typed amount — only the in-flight
      // flag and error change, so a network-failure retry re-sends the same
      // (merchant, branch, amount, Idempotency-Key) tuple safely.
      state = state.copyWith(isSubmitting: false, error: e);
    }
  }
}

final redemptionInitiationControllerProvider =
    NotifierProvider.family.autoDispose<RedemptionInitiationController, RedemptionInitiationState, int>(
  RedemptionInitiationController.new,
);
