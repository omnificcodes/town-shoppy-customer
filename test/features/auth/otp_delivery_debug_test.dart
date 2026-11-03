import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/features/auth/data/models/otp_request_result.dart';
import 'package:customer/features/auth/presentation/widgets/otp_delivery_debug_panel.dart';

/// The temporary OTP delivery debugging block (`delivery_debug`, sent by the
/// API only while `OTP_EXPOSE_DELIVERY_ERRORS` is on).
void main() {
  test('parses delivery_debug and debug_code when the API sends them', () {
    final result = OtpRequestResult.fromJson({
      'otp_request_id': 7,
      'expires_in_seconds': 300,
      'channel_used': 'sms',
      'debug_code': '123456',
      'delivery_debug': [
        {'channel': 'sms', 'provider': 'Msg91SmsProvider', 'sent': true, 'error': null},
        {'channel': 'whatsapp', 'provider': 'WhatsAppCloudApiProvider', 'sent': false, 'error': '(#132001) Template name does not exist'},
      ],
    });

    expect(result.debugCode, '123456');
    expect(result.deliveries, hasLength(2));
    expect(result.deliveries[0].channelLabel, 'SMS');
    expect(result.deliveries[0].sent, isTrue);
    expect(result.deliveries[1].channelLabel, 'WhatsApp');
    expect(result.deliveries[1].error, '(#132001) Template name does not exist');
  });

  test('has no deliveries when the API leaves delivery_debug out', () {
    final result = OtpRequestResult.fromJson({'otp_request_id': 7, 'expires_in_seconds': 300, 'channel_used': 'sms'});

    expect(result.deliveries, isEmpty);
    expect(result.debugCode, isNull);
  });

  testWidgets('shows each channel and the provider error', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OtpDeliveryDebugPanel(
            deliveries: [
              OtpDelivery(channel: 'sms', provider: 'Msg91SmsProvider', sent: true),
              OtpDelivery(channel: 'whatsapp', provider: 'WhatsAppCloudApiProvider', sent: false, error: 'Recipient not in allowed list'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('OTP delivery (debug)'), findsOneWidget);
    expect(find.text('SMS via Msg91SmsProvider: accepted'), findsOneWidget);
    expect(find.text('WhatsApp via WhatsAppCloudApiProvider: failed'), findsOneWidget);
    expect(find.text('Recipient not in allowed list'), findsOneWidget);
  });

  testWidgets('renders nothing without deliveries', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: OtpDeliveryDebugPanel(deliveries: []))));

    expect(find.text('OTP delivery (debug)'), findsNothing);
  });
}
