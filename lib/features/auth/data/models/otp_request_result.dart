/// Mirrors `OtpRequestResource` — returned identically by both
/// `POST /auth/otp/request` and `POST /auth/password/forgot`.
/// `debug_code` only ever appears in local/testing environments
/// (`otp.expose_code_in_response`), and `delivery_debug` only while the
/// API's temporary `OTP_EXPOSE_DELIVERY_ERRORS` is on; both are shown in a
/// debug panel and never relied on for anything else.
class OtpRequestResult {
  const OtpRequestResult({
    required this.otpRequestId,
    required this.expiresInSeconds,
    required this.channelUsed,
    this.deliveries = const [],
    this.debugCode,
  });

  factory OtpRequestResult.fromJson(Map<String, dynamic> json) {
    final deliveries = json['delivery_debug'];
    return OtpRequestResult(
      otpRequestId: json['otp_request_id'] as int,
      expiresInSeconds: json['expires_in_seconds'] as int,
      channelUsed: json['channel_used'] as String,
      deliveries: deliveries is List
          ? [
              for (final item in deliveries)
                if (item is Map<String, dynamic>) OtpDelivery.fromJson(item),
            ]
          : const [],
      debugCode: json['debug_code'] as String?,
    );
  }

  final int otpRequestId;
  final int expiresInSeconds;
  final String channelUsed;

  /// How each channel (SMS, WhatsApp) went — empty unless the API is in
  /// OTP delivery debugging mode.
  final List<OtpDelivery> deliveries;
  final String? debugCode;
}

/// One entry of `delivery_debug`: a channel, the provider that handled it,
/// whether the provider accepted the message, and its error if not.
class OtpDelivery {
  const OtpDelivery({required this.channel, required this.provider, required this.sent, this.error});

  factory OtpDelivery.fromJson(Map<String, dynamic> json) {
    return OtpDelivery(
      channel: json['channel'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      sent: json['sent'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }

  final String channel;
  final String provider;
  final bool sent;
  final String? error;

  String get channelLabel => switch (channel) {
    'sms' => 'SMS',
    'whatsapp' => 'WhatsApp',
    _ => channel,
  };
}
