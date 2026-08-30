import 'redemption.dart';

/// The one-time response of `POST /redemptions` — everything
/// `RedemptionResource` normally returns, plus `otp_code`, merged in by
/// `RedemptionController::store()` only on a genuine first creation (never
/// on an idempotent replay, and never again from any later GET).
///
/// Deliberately does NOT parse `qr_secret`: the real merchant-side
/// verification UI (`town-shoppy-admin`'s redemption-verify dialog) has no
/// camera/QR-scanning capability at all — a merchant just types whatever
/// code the customer shows them into one text field, for either
/// `verification_method`. Rendering an actual scannable QR image here would
/// be UI for a capability the real system doesn't have (nothing can scan
/// it), so this app surfaces only the 6-digit OTP code, which a customer can
/// read aloud or show as text — the value the real merchant flow expects.
class RedemptionInitiationResult {
  const RedemptionInitiationResult({required this.redemption, required this.otpCode});

  factory RedemptionInitiationResult.fromJson(Map<String, dynamic> json) {
    return RedemptionInitiationResult(
      redemption: Redemption.fromJson(json),
      otpCode: json['otp_code'] as String?,
    );
  }

  final Redemption redemption;
  final String? otpCode;
}
