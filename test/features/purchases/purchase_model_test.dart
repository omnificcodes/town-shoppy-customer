import 'package:flutter_test/flutter_test.dart';
import 'package:customer/features/purchases/data/models/purchase.dart';

void main() {
  group('Purchase.fromJson', () {
    test('parses a purchase with merchant and branch names', () {
      final purchase = Purchase.fromJson({
        'id': 1,
        'merchant_id': 5,
        'merchant': {'id': 5, 'name': 'Corner Cafe'},
        'branch': {'id': 9, 'name': 'Main Street'},
        'bill_amount': 250.5,
        'currency': 'INR',
        'bill_reference': 'INV-1',
        'coins_awarded': 25,
        'coupons_issued': 1,
        'status': 'recorded',
        'created_at': '2026-01-01T10:00:00Z',
      });

      expect(purchase.merchantName, 'Corner Cafe');
      expect(purchase.branch?.name, 'Main Street');
      expect(purchase.billAmount, 250.5);
      expect(purchase.coinsAwarded, 25);
      expect(purchase.status, 'recorded');
    });

    test('falls back to a placeholder merchant name when the relation is not present', () {
      final purchase = Purchase.fromJson({
        'id': 2,
        'merchant_id': 7,
        'bill_amount': 100,
        'currency': 'INR',
        'coins_awarded': 0,
        'status': 'recorded',
      });

      expect(purchase.merchant, isNull);
      expect(purchase.merchantName, 'Merchant #7');
    });
  });
}
