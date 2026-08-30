import 'package:flutter_test/flutter_test.dart';
import 'package:customer/features/merchants/data/models/nearby_merchant.dart';

void main() {
  group('NearbyMerchant', () {
    test('fromJson parses merchant, branch, and distance_km', () {
      final result = NearbyMerchant.fromJson({
        'merchant': {
          'id': 7,
          'name': 'Corner Store',
          'description': null,
          'logo_url': null,
          'website_url': null,
          'social_links': null,
          'discount_rate': null,
          'accepts_town_coin': true,
          'category': null,
          'association': null,
          'branch': null,
        },
        'branch': {'id': 3, 'address_line': '5 Market Rd', 'latitude': 12.9, 'longitude': 77.5, 'distance_km': 0.8},
        'distance_km': 0.8,
      });

      expect(result.merchant.id, 7);
      expect(result.merchant.name, 'Corner Store');
      expect(result.branch.id, 3);
      expect(result.branch.formattedAddress, '5 Market Rd');
      expect(result.distanceKm, 0.8);
    });
  });
}
