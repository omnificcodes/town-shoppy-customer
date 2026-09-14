import 'package:flutter_test/flutter_test.dart';
import 'package:customer/features/offers/data/models/offer.dart';
import 'package:customer/features/offers/presentation/offer_labels.dart';

Offer _offer({required String type, double? value}) => Offer(
      id: 1,
      merchantId: 1,
      merchantName: 'Corner Cafe',
      merchantLogoUrl: null,
      title: 'Test offer',
      description: null,
      imageUrl: null,
      offerType: type,
      discountValue: value,
      terms: null,
      startsAt: null,
      endsAt: null,
      distanceKm: null,
      coinDiscountRate: null,
      applicableItem: null,
      isCoinRedeemable: false,
    );

void main() {
  group('offerDiscountLabel', () {
    test('formats a percentage, keeping one decimal only when there is one', () {
      expect(offerDiscountLabel(_offer(type: 'percentage_discount', value: 20)), '20% OFF');
      expect(offerDiscountLabel(_offer(type: 'percentage_discount', value: 12.5)), '12.5% OFF');
    });

    test('groups a flat rupee discount the Indian way', () {
      expect(offerDiscountLabel(_offer(type: 'fixed_discount', value: 50)), '₹50 OFF');
      expect(offerDiscountLabel(_offer(type: 'fixed_discount', value: 1500)), '₹1,500 OFF');
      expect(offerDiscountLabel(_offer(type: 'fixed_discount', value: 150000)), '₹1,50,000 OFF');
      expect(offerDiscountLabel(_offer(type: 'fixed_discount', value: 1234567.5)), '₹12,34,567.5 OFF');
    });

    test('is null for an offer with no discount value', () {
      expect(offerDiscountLabel(_offer(type: 'announcement')), isNull);
    });
  });

  group('offerEndsInLabel', () {
    final now = DateTime(2026, 9, 14, 12);

    test('counts whole days, says today inside 24 hours, and handles missing or past dates', () {
      expect(offerEndsInLabel(now.add(const Duration(days: 14, hours: 3)), now: now), 'Ends in 14d');
      expect(offerEndsInLabel(now.add(const Duration(hours: 5)), now: now), 'Ends today');
      expect(offerEndsInLabel(now.subtract(const Duration(minutes: 1)), now: now), 'Ending soon');
      expect(offerEndsInLabel(null, now: now), 'Limited time');
    });
  });

  test('offerTypeLabel names every API offer type, with a fallback', () {
    expect(offerTypeLabel(_offer(type: 'percentage_discount')), 'Percentage off');
    expect(offerTypeLabel(_offer(type: 'fixed_discount')), 'Flat discount');
    expect(offerTypeLabel(_offer(type: 'announcement')), 'Announcement');
    expect(offerTypeLabel(_offer(type: 'something_new')), 'Offer');
  });

  test('offerValidTillLabel shows day and short month, or null without an end date', () {
    expect(offerValidTillLabel(DateTime(2026, 10, 2, 18)), 'Till 2 Oct');
    expect(offerValidTillLabel(null), isNull);
  });
}
