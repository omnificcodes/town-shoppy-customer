import 'package:flutter_test/flutter_test.dart';
import 'package:customer/features/merchants/data/models/merchant.dart';

void main() {
  group('Merchant.fromJson', () {
    test('parses a full merchant with nested category/association/town/branch', () {
      final merchant = Merchant.fromJson({
        'id': 5,
        'name': 'Corner Cafe',
        'description': 'A cozy neighborhood cafe.',
        'logo_url': 'https://example.com/logo.png',
        'website_url': 'https://cornercafe.example',
        'social_links': {'instagram': 'https://instagram.com/cornercafe'},
        'discount_rate': 7.5,
        'accepts_town_coin': true,
        'category': {'id': 1, 'name': 'Restaurant', 'slug': 'restaurant'},
        'association': {
          'id': 2,
          'name': 'Downtown Association',
          'slug': 'downtown-association',
          'short_code': 'DTA',
          'logo_url': null,
          'status': 'active',
          'town': {'id': 3, 'name': 'Springfield', 'slug': 'springfield', 'state_region': 'Illinois', 'status': 'active'},
        },
        'branch': {
          'id': 4,
          'name': 'Main Branch',
          'address_line': '123 Main St',
          'locality': 'Downtown',
          'city': 'Springfield',
          'state': 'Illinois',
          'postal_code': '62701',
          'country': 'US',
          'latitude': 39.78,
          'longitude': -89.65,
        },
      });

      expect(merchant.name, 'Corner Cafe');
      expect(merchant.discountRate, 7.5);
      expect(merchant.acceptsTownCoin, isTrue);
      expect(merchant.category?.name, 'Restaurant');
      expect(merchant.town?.name, 'Springfield');
      expect(merchant.branch?.city, 'Springfield');
      expect(merchant.socialLinks?['instagram'], 'https://instagram.com/cornercafe');
    });

    test('handles a merchant with no logo, description, category, association, or branch', () {
      final merchant = Merchant.fromJson({
        'id': 6,
        'name': 'New Merchant',
        'description': null,
        'logo_url': null,
        'website_url': null,
        'social_links': null,
        'discount_rate': null,
        'accepts_town_coin': false,
        'category': null,
        'association': null,
        'branch': null,
      });

      expect(merchant.description, isNull);
      expect(merchant.logoUrl, isNull);
      expect(merchant.category, isNull);
      expect(merchant.association, isNull);
      expect(merchant.town, isNull);
      expect(merchant.branch, isNull);
      expect(merchant.acceptsTownCoin, isFalse);
    });
  });
}
