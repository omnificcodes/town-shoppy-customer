/// Mirrors `OtpRequestResource` — returned identically by both
/// `POST /auth/otp/request` and `POST /auth/password/forgot`.
/// `debug_code` only ever appears in local/testing environments
/// (`otp.expose_code_in_response`) and is never relied on here.
class OtpRequestResult {
  const OtpRequestResult({required this.otpRequestId, required this.expiresInSeconds, required this.channelUsed});

  factory OtpRequestResult.fromJson(Map<String, dynamic> json) {
    return OtpRequestResult(
      otpRequestId: json['otp_request_id'] as int,
      expiresInSeconds: json['expires_in_seconds'] as int,
      channelUsed: json['channel_used'] as String,
    );
  }

  final int otpRequestId;
  final int expiresInSeconds;
  final String channelUsed;
}
