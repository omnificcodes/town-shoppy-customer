import 'package:flutter_test/flutter_test.dart';
import 'package:customer/features/coupons/data/models/coupon.dart';

void main() {
  group('Coupon.fromJson', () {
    test('parses a fully-populated response', () {
      final coupon = Coupon.fromJson({
        'id': 5,
        'code': 'ABCD1234EFGH',
        'status': 'active',
        'source_type': 'purchase',
        'eligibilities': [
          {'cadence': 'weekly', 'status': 'active'},
          {'cadence': 'monthly', 'status': 'closed'},
        ],
        'issued_at': '2026-01-01T00:00:00Z',
        'annual_cycle_expires_at': '2027-01-01T00:00:00Z',
      });

      expect(coupon.id, 5);
      expect(coupon.code, 'ABCD1234EFGH');
      expect(coupon.isActive, isTrue);
      expect(coupon.eligibilities, hasLength(2));
      expect(coupon.eligibilityFor('weekly')?.isActive, isTrue);
      expect(coupon.eligibilityFor('monthly')?.isActive, isFalse);
      expect(coupon.eligibilityFor('mega'), isNull);
      expect(coupon.issuedAt, isNotNull);
      expect(coupon.annualCycleExpiresAt, isNotNull);
    });

    test('treats a missing eligibilities key (whenLoaded omitted) as an empty list, not a crash', () {
      final coupon = Coupon.fromJson({
        'id': 1,
        'code': 'XXXX',
        'status': 'expired',
        'source_type': 'referral_milestone',
        'issued_at': null,
        'annual_cycle_expires_at': null,
      });

      expect(coupon.eligibilities, isEmpty);
      expect(coupon.isExpired, isTrue);
      expect(coupon.issuedAt, isNull);
    });
  });
}
