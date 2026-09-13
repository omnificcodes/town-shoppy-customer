import 'package:customer/features/business/data/models/business_offer.dart';
import 'package:customer/features/business/data/models/business_prize.dart';
import 'package:customer/features/business/data/models/merchant_customer.dart';
import 'package:customer/features/business/data/models/merchant_wallet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BusinessOffer', () {
    test('parses the management resource and derives "live now"', () {
      final now = DateTime.now();
      final o = BusinessOffer.fromJson({
        'id': 3,
        'merchant': {'id': 1, 'name': 'Shop'},
        'branch': null,
        'title': 'Weekend deal',
        'description': null,
        'image_url': null,
        'offer_type': 'announcement',
        'discount_value': null,
        'coin_discount_rate': 10,
        'applicable_item': 'Any pizza',
        'is_coin_redeemable': true,
        'terms': null,
        'starts_at': now.subtract(const Duration(days: 1)).toIso8601String(),
        'ends_at': now.add(const Duration(days: 1)).toIso8601String(),
        'status': 'active',
        'created_by': 'owner',
      });
      expect(o.isLiveNow, isTrue);
      expect(o.branchName, isNull);
      expect(o.coinDiscountRate, 10);
    });

    test('OfferInput sends UTC ISO dates, nulls empty optionals, and null rate when not redeemable', () {
      final json = OfferInput(title: ' Deal ', startsAt: DateTime(2026, 9, 20, 10), endsAt: DateTime(2026, 9, 21, 10), description: '', terms: '  ').toJson();
      expect(json['title'], 'Deal');
      expect(json['description'], isNull);
      expect(json['terms'], isNull);
      expect(json['coin_discount_rate'], isNull);
      expect((json['starts_at'] as String).endsWith('Z'), isTrue);
    });

    test('status counts default to zero and total sums', () {
      final c = OfferStatusCounts.fromJson({'draft': 2, 'active': 3, 'expired': 4});
      expect(c.total, 9);
      expect(OfferStatusCounts.fromJson(null).total, 0);
    });
  });

  test('MerchantCustomerDetail parses the hand-built payload', () {
    final d = MerchantCustomerDetail.fromJson({
      'customer': {'id': 7, 'name': 'Asha', 'mobile_number': '+919876543210', 'referral_code': 'ASHA1', 'member_since': '2026-01-01T00:00:00Z'},
      'stats': {'purchase_count': 3, 'total_spent': 1200.5, 'coupons_earned': 3, 'redemption_count': 1, 'total_discount_redeemed': 25, 'first_visit_at': null, 'last_visit_at': '2026-09-01T10:00:00Z'},
      'purchases': [
        {'id': 1, 'merchant_id': 1, 'bill_amount': 400, 'status': 'recorded'},
      ],
      'redemptions': [
        {'id': 9, 'bill_amount': 500, 'coins_requested': 50, 'status': 'settled'},
      ],
    });
    expect(d.name, 'Asha');
    expect(d.totalSpent, 1200.5);
    expect(d.purchases.single.billAmount, 400);
    expect(d.redemptions.single.status, 'settled');
  });

  test('MerchantWallet and the string-money blue redemption parse', () {
    final w = MerchantWallet.fromJson({'blue_balance': 250, 'red_balance': 400, 'updated_at': null});
    expect(w.blueInr, 25);
    final r = MerchantBlueRedemption.fromJson({'id': 1, 'spending_merchant_id': 1, 'redeeming_merchant_id': 2, 'redeeming_merchant_name': 'Cafe', 'bill_amount': '100.00', 'discount_amount': '10.00', 'coins_debited': 100, 'status': 'settled'});
    expect(r.discountAmount, 10);
    expect(r.redeemingMerchantName, 'Cafe');
  });

  test('BusinessPrize: winners only when present, withdraw allowed from draft/available', () {
    final p = BusinessPrize.fromJson({
      'id': 4,
      'sponsor_merchant': {'id': 1},
      'association_id': 2,
      'name': 'Smart Watch',
      'quantity_total': 2,
      'quantity_remaining': 1,
      'status': 'awarded',
      'winners': [
        {'voucher_id': 11, 'winner_label': 'Asha K.', 'claim_status': 'claimed', 'claimed_at': '2026-09-01T00:00:00Z'},
      ],
    });
    expect(p.winners?.single.winnerLabel, 'Asha K.');
    expect(p.canWithdraw, isFalse);
    expect(BusinessPrize.fromJson({'id': 5, 'name': 'X', 'status': 'draft'}).canWithdraw, isTrue);
    final input = const PrizeInput(name: ' TV ', quantityTotal: 1, value: null, description: '').toJson(merchantId: 1, associationId: 2);
    expect(input['name'], 'TV');
    expect(input['description'], isNull);
    expect(input['association_id'], 2);
  });
}
