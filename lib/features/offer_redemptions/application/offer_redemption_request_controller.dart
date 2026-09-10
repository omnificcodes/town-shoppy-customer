import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/idempotency_key.dart';
import '../data/models/offer_redemption.dart';
import '../data/offer_redemptions_repository.dart';
import 'offer_redemptions_list_controller.dart';

/// Client-side form state only, same shape as `RedemptionInitiationState`:
/// a bill-amount entry has no backend representation of its own (the only
/// real states are "not yet requested" / `pending` / `approved` /
/// `rejected`, per `OfferRedemptionStatus`). Once [result] is set, the
/// caller hands off to `offerRedemptionDetailProvider` to watch the real
/// backend lifecycle.
class OfferRedemptionRequestState {
  const OfferRedemptionRequestState({
    this.billAmountText = '',
    this.isSubmitting = false,
    this.error,
    this.result,
    required this.idempotencyKey,
  });

  final String billAmountText;
  final bool isSubmitting;
  final AppException? error;
  final OfferRedemption? result;
  final String idempotencyKey;

  /// Matches `RequestOfferRedemptionRequest`'s own `min:0.01`/`max:1000000`
  /// bounds -- mirrored here for responsive UI feedback only; the backend
  /// remains the authoritative check.
  double? get billAmount {
    final parsed = double.tryParse(billAmountText.trim());
    if (parsed == null || parsed < 0.01 || parsed > 1000000) return null;
    return parsed;
  }

  bool get canSubmit => billAmount != null && !isSubmitting;

  OfferRedemptionRequestState copyWith({
    String? billAmountText,
    bool? isSubmitting,
    AppException? error,
    bool clearError = false,
    OfferRedemption? result,
    String? idempotencyKey,
  }) {
    return OfferRedemptionRequestState(
      billAmountText: billAmountText ?? this.billAmountText,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      result: result ?? this.result,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }
}

/// One redemption-request attempt for one offer. A fresh instance every
/// time a customer opens the flow (`autoDispose`), same lifecycle as
/// `RedemptionInitiationController`.
class OfferRedemptionRequestController extends Notifier<OfferRedemptionRequestState> {
  OfferRedemptionRequestController(this.offerId);

  final int offerId;

  @override
  OfferRedemptionRequestState build() {
    return OfferRedemptionRequestState(idempotencyKey: generateIdempotencyKey());
  }

  void setBillAmount(String text) {
    if (state.billAmountText == text) return;
    // A genuinely different amount changes what the backend considers "the
    // same request" for the Idempotency-Key it was given -- same reasoning
    // as `RedemptionInitiationController.setBillAmount()`.
    state = state.copyWith(billAmountText: text, idempotencyKey: generateIdempotencyKey(), clearError: true);
  }

  Future<void> submit() async {
    final amount = state.billAmount;
    if (state.isSubmitting || amount == null) return;

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final result = await ref.read(offerRedemptionsRepositoryProvider).request(
            offerId: offerId,
            billAmount: amount,
            idempotencyKey: state.idempotencyKey,
          );

      ref.invalidate(offerRedemptionsListControllerProvider);

      state = state.copyWith(isSubmitting: false, result: result);
    } on AppException catch (e) {
      state = state.copyWith(isSubmitting: false, error: e);
    }
  }
}

final offerRedemptionRequestControllerProvider =
    NotifierProvider.family.autoDispose<OfferRedemptionRequestController, OfferRedemptionRequestState, int>(
  OfferRedemptionRequestController.new,
);
