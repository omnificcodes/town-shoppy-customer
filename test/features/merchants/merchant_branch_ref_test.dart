import 'package:flutter_test/flutter_test.dart';
import 'package:customer/features/merchants/data/models/merchant_branch_ref.dart';

void main() {
  group('MerchantBranchRef', () {
    test('formattedAddress joins only the parts the backend actually returned', () {
      final branch = MerchantBranchRef.fromJson({
        'id': 1,
        'name': 'Main Branch',
        'address_line': '123 Main St',
        'city': 'Springfield',
        'latitude': 1.0,
        'longitude': 2.0,
        // locality, state, postal_code deliberately absent — the resource's
        // array_filter() omits null fields rather than sending them as null.
      });

      expect(branch.formattedAddress, '123 Main St, Springfield');
    });

    test('formattedAddress is empty when no address fields are present', () {
      final branch = MerchantBranchRef.fromJson({'id': 1, 'latitude': 1.0, 'longitude': 2.0});

      expect(branch.formattedAddress, isEmpty);
    });

    test('distance_km is null when the backend did not compute one (non-nearby fetch)', () {
      final branch = MerchantBranchRef.fromJson({'id': 1, 'latitude': 1.0, 'longitude': 2.0});

      expect(branch.distanceKm, isNull);
    });

    test('isPrimary parses true/false from is_primary', () {
      final primary = MerchantBranchRef.fromJson({'id': 1, 'is_primary': true, 'latitude': 1.0, 'longitude': 2.0});
      final secondary = MerchantBranchRef.fromJson({'id': 2, 'is_primary': false, 'latitude': 1.0, 'longitude': 2.0});

      expect(primary.isPrimary, isTrue);
      expect(secondary.isPrimary, isFalse);
    });

    test('isPrimary defaults to false when absent', () {
      final branch = MerchantBranchRef.fromJson({'id': 1, 'latitude': 1.0, 'longitude': 2.0});

      expect(branch.isPrimary, isFalse);
    });
  });
}
