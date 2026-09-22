import 'package:customer/features/cart/application/cart_controller.dart';
import 'package:customer/features/products/data/models/product.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Product _product({
  int id = 1,
  int merchantId = 3,
  String merchantName = 'Kairaly Bakers',
  String name = 'Butter Cookies',
  double price = 149,
  double? mrp = 200,
  String? contact = '9876543210',
}) => Product.fromJson({
  'id': id,
  'merchant': {'id': merchantId, 'name': merchantName, 'contact_mobile_number': ?contact},
  'name': name,
  'price': price,
  'mrp': ?mrp,
  'discount_amount': ?(mrp == null ? null : mrp - price),
  'status': 'active',
});

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  CartController controller() => container.read(cartControllerProvider.notifier);
  CartState cart() => container.read(cartControllerProvider);

  group('adding to the bag', () {
    test('adds one, then raises the same line rather than repeating it', () {
      final cookies = _product();

      expect(controller().add(cookies), isTrue);
      expect(controller().add(cookies), isTrue);

      expect(cart().lines, hasLength(1));
      expect(cart().quantityOf(cookies.id), 2);
      expect(cart().itemCount, 2);
    });

    test('refuses a product from another shop, and leaves the bag exactly as it was', () {
      controller().add(_product());

      final otherShop = _product(id: 9, merchantId: 4, merchantName: 'Tea Time Crunch', price: 99, mrp: null);
      expect(controller().add(otherShop), isFalse);

      expect(cart().lines, hasLength(1));
      expect(cart().merchantName, 'Kairaly Bakers');
    });

    test('starting a new bag empties the old shop out of it', () {
      controller().add(_product());
      final otherShop = _product(id: 9, merchantId: 4, merchantName: 'Tea Time Crunch', price: 99, mrp: null);

      controller().startNewBagWith(otherShop);

      expect(cart().lines, hasLength(1));
      expect(cart().merchantId, 4);
      expect(cart().quantityOf(otherShop.id), 1);
    });
  });

  group('changing the bag', () {
    test('a quantity of zero removes the line, and the last one empties the bag', () {
      final cookies = _product();
      final chips = _product(id: 2, name: 'Banana Chips', price: 120, mrp: 150);
      controller()
        ..add(cookies)
        ..add(chips);

      controller().setQuantity(chips, 0);
      expect(cart().lines, hasLength(1));

      controller().setQuantity(cookies, 0);
      expect(cart().isEmpty, isTrue);
      expect(cart().merchantId, isNull);
    });

    test('a quantity never climbs past the per-line cap', () {
      final cookies = _product();

      controller().setQuantity(cookies, 500);

      expect(cart().quantityOf(cookies.id), CartController.maxQuantityPerLine);
    });
  });

  group('what the bag comes to', () {
    test('totals what is in it, and what the offers took off', () {
      controller()
        ..add(_product()) // 149, saving 51
        ..add(_product())
        ..add(_product(id: 2, name: 'Banana Chips', price: 120, mrp: 150)); // saving 30

      expect(cart().total, 418); // 149*2 + 120
      expect(cart().saved, 132); // 51*2 + 30
      expect(cart().itemCount, 3);
    });

    test('is not orderable when the shop has published no number', () {
      controller().add(_product(contact: null));

      expect(cart().contactMobileNumber, isNull);
    });
  });

  test('the order message lists every line and what the bag comes to', () {
    controller()
      ..add(_product())
      ..add(_product())
      ..add(_product(id: 2, name: 'Banana Chips', price: 120, mrp: 150));

    final message = buildCartOrderMessage(cart());

    expect(message, contains("I'd like to order from Kairaly Bakers"));
    expect(message, contains('2 x Butter Cookies — ₹298'));
    expect(message, contains('1 x Banana Chips — ₹120'));
    expect(message, contains('Total: ₹418'));
    expect(message, contains('You save: ₹132'));
  });
}
