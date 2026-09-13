import 'package:customer/features/business/data/models/management_totals.dart';
import 'package:customer/features/business/data/models/merchant_branch.dart';
import 'package:customer/features/redemptions/data/models/redemption.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Redemption (management view)', () {
    test('parses the customer, counter-presence flag and discount figures', () {
      final r = Redemption.fromJson({
        'id': 9,
        'customer': {'id': 3, 'name': 'Asha', 'mobile_number': '+919876543210'},
        'branch': {'id': 1, 'name': 'Main'},
        'bill_amount': 500,
        'merchant_discount_rate': 10,
        'max_discount_amount': 50,
        'coins_requested': 500,
        'coins_debited': null,
        'discount_amount': null,
        'remaining_bill_amount': null,
        'status': 'initiated',
        'counter_presence_verified': true,
        'verification_method': null,
        'verified_at': null,
        'qr_expires_at': '2026-09-13T10:00:00+05:30',
        'created_at': '2026-09-13T09:50:00+05:30',
      });
      expect(r.customer?.name, 'Asha');
      expect(r.customer?.mobileNumber, '+919876543210');
      expect(r.counterPresenceVerified, isTrue);
      expect(r.maxDiscountAmount, 50);
      expect(r.isInitiated, isTrue);
    });

    test('the detail endpoint shape (no customer key) still parses', () {
      final r = Redemption.fromJson({'id': 9, 'bill_amount': 500, 'coins_requested': 500, 'status': 'settled'});
      expect(r.customer, isNull);
      expect(r.counterPresenceVerified, isFalse);
    });
  });

  group('MerchantBranch', () {
    test('tolerates the omitted-null address keys and joins what exists', () {
      final b = MerchantBranch.fromJson({
        'id': 4,
        'name': 'Annex',
        'is_primary': false,
        'address_line': '12 Market Rd',
        'city': 'Kochi',
        'country': 'IN',
        'latitude': 9.93,
        'longitude': 76.26,
        'merchant_id': 5,
        'cover_image_url': null,
        'status': 'inactive',
        'created_at': '2026-09-01T00:00:00Z',
      });
      expect(b.formattedAddress, '12 Market Rd, Kochi');
      expect(b.isActive, isFalse);
      expect(b.locality, isNull);
    });

    test('BranchInput nulls empty optionals and never sends country', () {
      final json = const BranchInput(name: ' Main ', addressLine: 'A', latitude: 1, longitude: 2, city: '', postalCode: ' 682001 ').toJson();
      expect(json['name'], 'Main');
      expect(json['city'], isNull);
      expect(json['postal_code'], '682001');
      expect(json.containsKey('country'), isFalse);
      expect(json['is_primary'], isFalse);
    });
  });

  test('totals default to zero when meta.totals is absent', () {
    expect(PurchaseTotals.fromJson(null).pending, 0);
    expect(RedemptionTotals.fromJson({'pending': 4, 'verified': 12, 'cancelled': 2, 'coins_redeemed': 3400}).coinsRedeemed, 3400);
  });
}
