/// Mirrors `App\Domain\Auth\Http\Resources\OtpRequestResource`.
///
/// [debugCode] is only ever present when the backend has
/// `OTP_EXPOSE_CODE_IN_RESPONSE=true` in local/testing environments — never
/// in production regardless of configuration (enforced server-side by
/// `OtpService`, not by this client). When present, the login screen may
/// show it as a development convenience; production builds will simply
/// never receive it.
class OtpRequestResult {
  const OtpRequestResult({
    required this.otpRequestId,
    required this.expiresInSeconds,
    required this.channelUsed,
    this.debugCode,
  });

  factory OtpRequestResult.fromJson(Map<String, dynamic> json) {
    return OtpRequestResult(
      otpRequestId: json['otp_request_id'] as int,
      expiresInSeconds: json['expires_in_seconds'] as int? ?? 0,
      channelUsed: json['channel_used'] as String? ?? 'sms',
      debugCode: json['debug_code'] as String?,
    );
  }

  final int otpRequestId;
  final int expiresInSeconds;
  final String channelUsed;
  final String? debugCode;
}
