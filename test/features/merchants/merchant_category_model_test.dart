import 'package:flutter_test/flutter_test.dart';
import 'package:customer/features/merchants/data/models/merchant_category.dart';

void main() {
  test('MerchantCategory.fromJson parses id/name/slug', () {
    final category = MerchantCategory.fromJson({'id': 1, 'name': 'Bakery', 'slug': 'bakery-1234'});

    expect(category.id, 1);
    expect(category.name, 'Bakery');
    expect(category.slug, 'bakery-1234');
  });
}
