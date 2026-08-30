import 'package:flutter_test/flutter_test.dart';
import 'package:customer/features/redemptions/data/models/redemption_initiation_result.dart';

void main() {
  group('RedemptionInitiationResult.fromJson', () {
    test('parses the redemption and otp_code from a fresh initiation', () {
      final result = RedemptionInitiationResult.fromJson({
        'id': 8,
        'merchant': {'id': 42, 'name': 'Suspended Redemption Test'},
        'branch': {'id': 42, 'name': 'Main Branch'},
        'bill_amount': 500,
        'merchant_discount_rate': 5,
        'max_discount_amount': 25,
        'coins_requested': 250,
        'status': 'initiated',
        'qr_secret': 'v0TVCb6p3uKMR1B7KP6A5ZrG4G5DUDnP5RLdK8zQ',
        'otp_code': '585937',
      });

      expect(result.redemption.id, 8);
      expect(result.redemption.merchantName, 'Suspended Redemption Test');
      expect(result.otpCode, '585937');
    });

    test('otp_code is null on an idempotent replay response', () {
      final result = RedemptionInitiationResult.fromJson({
        'id': 8,
        'bill_amount': 500,
        'merchant_discount_rate': 5,
        'max_discount_amount': 25,
        'coins_requested': 250,
        'status': 'initiated',
      });

      expect(result.otpCode, isNull);
    });
  });
}
