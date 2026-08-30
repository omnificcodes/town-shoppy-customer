import 'package:flutter_test/flutter_test.dart';
import 'package:customer/features/redemptions/data/models/redemption.dart';

void main() {
  group('Redemption.fromJson', () {
    test('parses a settled redemption with merchant/branch and discount fields', () {
      final redemption = Redemption.fromJson({
        'id': 1,
        'merchant': {'id': 3, 'name': 'Sunrise Store'},
        'branch': {'id': 4, 'name': 'Downtown'},
        'bill_amount': 500,
        'merchant_discount_rate': 10,
        'max_discount_amount': 100,
        'coins_requested': 200,
        'coins_debited': 200,
        'discount_amount': 50,
        'remaining_bill_amount': 450,
        'status': 'settled',
        'verification_method': 'qr',
        'verified_at': '2026-01-02T09:00:00Z',
        'qr_expires_at': null,
        'created_at': '2026-01-02T08:55:00Z',
      });

      expect(redemption.merchantName, 'Sunrise Store');
      expect(redemption.branch?.name, 'Downtown');
      expect(redemption.coinsRequested, 200);
      expect(redemption.discountAmount, 50);
      expect(redemption.remainingBillAmount, 450);
      expect(redemption.status, 'settled');
      expect(redemption.verificationMethod, 'qr');
    });

    test('handles a pending redemption with no discount/verification data yet', () {
      final redemption = Redemption.fromJson({
        'id': 2,
        'bill_amount': 300,
        'merchant_discount_rate': 10,
        'max_discount_amount': 60,
        'coins_requested': 100,
        'status': 'initiated',
      });

      expect(redemption.merchant, isNull);
      expect(redemption.merchantName, 'Merchant');
      expect(redemption.discountAmount, isNull);
      expect(redemption.coinsDebited, isNull);
      expect(redemption.verificationMethod, isNull);
    });
  });
}
