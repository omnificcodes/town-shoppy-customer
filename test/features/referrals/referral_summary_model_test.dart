import 'package:flutter_test/flutter_test.dart';
import 'package:customer/features/referrals/data/models/referral_summary.dart';

void main() {
  group('ReferralSummary.fromJson', () {
    test('parses referral code, stats, history, and a referred_by slot', () {
      final summary = ReferralSummary.fromJson({
        'referral_code': 'ABC123',
        'referral_link': 'https://townshoppy.example/r/ABC123',
        'qualified_count': 2,
        'pending_count': 1,
        'bonus_coupons_earned': 1,
        'milestone_referral_count': 5,
        'next_milestone_referrals_remaining': 3,
        'referrals': [
          {
            'id': 10,
            'referrer_name': null,
            'referred_name': 'Priya',
            'status': 'qualified',
            'qualified_at': '2026-01-05T00:00:00Z',
            'reward_coins_referrer': 50,
            'reward_coins_referred': 25,
            'bonus_coupon_issued': false,
            'created_at': '2026-01-01T00:00:00Z',
          },
        ],
        'referred_by': {
          'id': 11,
          'referrer_name': 'Amit',
          'referred_name': null,
          'status': 'qualified',
          'qualified_at': '2025-12-01T00:00:00Z',
          'reward_coins_referrer': null,
          'reward_coins_referred': 25,
          'bonus_coupon_issued': false,
          'created_at': '2025-11-01T00:00:00Z',
        },
      });

      expect(summary.referralCode, 'ABC123');
      expect(summary.qualifiedCount, 2);
      expect(summary.pendingCount, 1);
      expect(summary.referrals, hasLength(1));
      expect(summary.referrals.first.referredName, 'Priya');
      expect(summary.referredBy?.referrerName, 'Amit');
    });

    test('handles a non-customer account (no referral code, empty history)', () {
      final summary = ReferralSummary.fromJson({
        'referral_code': null,
        'referral_link': null,
        'qualified_count': 0,
        'pending_count': 0,
        'bonus_coupons_earned': 0,
        'milestone_referral_count': 5,
        'next_milestone_referrals_remaining': null,
        'referrals': [],
        'referred_by': null,
      });

      expect(summary.referralCode, isNull);
      expect(summary.referrals, isEmpty);
      expect(summary.referredBy, isNull);
    });
  });
}
