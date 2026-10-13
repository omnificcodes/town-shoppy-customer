import 'package:customer/features/lucky_draw/data/models/draw.dart';
import 'package:customer/features/lucky_draw/data/models/draw_entry.dart';
import 'package:customer/features/lucky_draw/data/models/draw_winner.dart';
import 'package:flutter_test/flutter_test.dart';

/// `DrawResource` / `DrawWinnerResource` / `DrawEntryResource` as the API
/// sends them since BR-44 -- the public story of a completed draw, and the
/// hand-over details only some callers receive.
void main() {
  group('Draw.fromJson', () {
    test('reads the BR-44 story: association, units, sponsor shops, entries per shop, conductors', () {
      final draw = Draw.fromJson({
        'id': 7,
        'association_id': 2,
        'association': {'id': 2, 'name': 'Kochi Traders'},
        'cadence': 'weekly',
        'scope': 'all',
        'status': 'complete',
        'pool_locked_at': '2026-10-11T10:00:00+05:30',
        'executed_at': '2026-10-11T10:01:00+05:30',
        'prizes': [
          {
            'id': 1,
            'sponsor_merchant': {'id': 9, 'name': 'Sponsor Mart'},
            'association_id': 2,
            'name': 'Mixer Grinder',
            'description': null,
            'image_url': null,
            'value': 2500,
            'quantity_total': 5,
            'quantity_remaining': 3,
            'status': 'available',
            'units_allocated': 2,
            'units_awarded': 2,
          },
        ],
        'sponsor_shops': [
          {'id': 9, 'name': 'Sponsor Mart', 'logo_url': null, 'prize_names': ['Mixer Grinder'], 'units_awarded': 2},
        ],
        'pool_size': 40,
        'winner_count': 2,
        'entries_by_shop': [
          {'id': 9, 'name': 'Sponsor Mart', 'entries': 30},
          {'id': 11, 'name': 'Corner Books', 'entries': 10},
        ],
        'coordinator_name': 'Jordan Lee',
        'witnesses': [
          {'id': 1, 'name': 'Alex Kim', 'phone_number': null},
        ],
        'created_at': '2026-10-11T09:00:00+05:30',
      });

      expect(draw.associationName, 'Kochi Traders');
      expect(draw.poolSize, 40);
      expect(draw.prizes.single.unitsAllocated, 2);
      expect(draw.prizes.single.unitsAwarded, 2);
      expect(draw.prizes.single.unitsInDraw, 2);
      expect(draw.prizes.single.value, 2500);
      expect(draw.unitsAwarded, 2);
      expect(draw.sponsorShops.single.name, 'Sponsor Mart');
      expect(draw.sponsorShops.single.unitsAwarded, 2);
      expect(draw.entriesByShop.map((e) => e.entries), [30, 10]);
      expect(draw.coordinatorName, 'Jordan Lee');
      expect(draw.witnessNames, ['Alex Kim']);
    });

    test('a prize with no allocation counts every unit it had as in the draw', () {
      final draw = Draw.fromJson({
        'id': 1,
        'association_id': 1,
        'cadence': 'weekly',
        'scope': 'all',
        'status': 'complete',
        'pool_locked_at': null,
        'executed_at': null,
        'prizes': [
          {
            'id': 1,
            'sponsor_merchant': {'id': 9},
            'association_id': 1,
            'name': 'Voucher',
            'description': null,
            'image_url': null,
            'value': null,
            'quantity_total': 5,
            'quantity_remaining': 3,
            'status': 'available',
            'units_allocated': null,
            'units_awarded': 2,
          },
        ],
        'created_at': null,
      });

      // 2 won here + 3 still left = the 5 that were up for grabs.
      expect(draw.prizes.single.unitsInDraw, 5);
      expect(draw.sponsorShops, isEmpty);
      expect(draw.witnessNames, isEmpty);
    });
  });

  group('DrawWinner.fromJson', () {
    test('shows the real name when the API sent it, the masked label otherwise', () {
      final full = DrawWinner.fromJson({
        'id': 1,
        'draw_id': 7,
        'prize': null,
        'winner_label': 'Ravi M.',
        'winner_name': 'Ravi Menon',
        'winner_mobile_number': '+919876543210',
        'coupon_code': 'LUDHVYO7VJCZ',
        'earned_at_shop': {'id': 9, 'name': 'Sponsor Mart'},
        'claim_status': 'active',
        'claimed_at': null,
        'status': 'selected',
        'selected_at': null,
      });
      expect(full.displayName, 'Ravi Menon');
      expect(full.hasFullDetails, isTrue);
      expect(full.earnedAtShopName, 'Sponsor Mart');
      expect(full.claimStatus, 'active');

      final masked = DrawWinner.fromJson({
        'id': 2,
        'draw_id': 7,
        'prize': null,
        'winner_label': 'Asha K.',
        'coupon_code': '****7G2K',
        'earned_at_shop': null,
        'claim_status': 'active',
        'claimed_at': null,
        'status': 'selected',
        'selected_at': null,
      });
      expect(masked.displayName, 'Asha K.');
      expect(masked.hasFullDetails, isFalse);
      expect(masked.couponCode, '****7G2K');
    });
  });

  test('DrawEntry.fromJson reads the masked entry and its winner flag', () {
    final entry = DrawEntry.fromJson({
      'id': 5,
      'coupon_id': 50,
      'entrant_label': 'Asha K.',
      'coupon_code': '****7G2K',
      'shop': {'id': 9, 'name': 'Sponsor Mart'},
      'is_winner': true,
      'snapshotted_at': null,
    });
    expect(entry.displayName, 'Asha K.');
    expect(entry.shopName, 'Sponsor Mart');
    expect(entry.isWinner, isTrue);
  });
}
