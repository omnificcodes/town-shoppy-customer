import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/products/application/products_list_controller.dart';
import 'package:customer/features/products/data/models/product.dart';
import 'package:customer/features/products/presentation/product_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/responsive_test_helper.dart';

Product _product({
  double price = 149,
  double? mrp = 200,
  double? percentage = 25.5,
  String? contact = '9876543210',
  bool acceptsTownCoin = true,
}) => Product.fromJson({
  'id': 7,
  'merchant': {'id': 3, 'name': 'Kairaly Bakers', 'contact_mobile_number': ?contact},
  'name': 'Handcrafted Golden Butter Cookies',
  'description': 'Slow-baked to melt-in-mouth crispness with pure dairy churned butter.',
  'price': price,
  'mrp': ?mrp,
  'discount_amount': ?(mrp == null ? null : mrp - price),
  'discount_percentage': ?percentage,
  'town_coin_percentage': ?(acceptsTownCoin ? 10 : null),
  'accepts_town_coin': acceptsTownCoin,
  'status': 'active',
});

Widget _screen(Product product) => ProviderScope(
  overrides: [productDetailProvider(7).overrideWith((ref) async => product)],
  child: MaterialApp(theme: AppTheme.light, home: const ProductDetailScreen(productId: 7)),
);

/// A phone's width and a window tall enough to build the whole page: the
/// body is a lazy ListView, and the default 800x600 test window leaves
/// everything below the square gallery unbuilt.
Future<void> pumpPage(WidgetTester tester, Product product) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(_screen(product));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  testWidgets('shows the shop, the product, its prices and the discount tag', (tester) async {
    await pumpPage(tester, _product());

    expect(find.text('KAIRALY BAKERS'), findsOneWidget);
    expect(find.text('Handcrafted Golden Butter Cookies'), findsOneWidget);
    expect(find.text('₹149'), findsOneWidget);
    expect(find.text('₹200'), findsOneWidget);
    expect(find.text('You Save ₹51'), findsOneWidget);
    expect(find.text('25.5% OFF'), findsOneWidget);
    expect(find.text('Order via WhatsApp'), findsOneWidget);
  });

  testWidgets('a product with no MRP carries no discount tag', (tester) async {
    await pumpPage(tester, _product(mrp: null, percentage: null));

    expect(find.text('₹149'), findsOneWidget);
    expect(find.textContaining('% OFF'), findsNothing);
    expect(find.textContaining('You Save'), findsNothing);
  });

  testWidgets('adding to the bag turns the button into a stepper, and the order button then sends the bag', (tester) async {
    await pumpPage(tester, _product());

    expect(find.text('Add'), findsOneWidget);
    expect(find.text('Opens WhatsApp with your order details, addressed to the seller.'), findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    // Twice: the stepper, and the bag badge in the top bar.
    expect(find.text('1'), findsNWidgets(2));

    await tester.tap(find.byTooltip('One more'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('One more'));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsNWidgets(2));
    // 3 x 149, sent as one bag rather than a single product.
    expect(find.textContaining('Sends your bag (3 items, ₹447)'), findsOneWidget);

    // Back down to one; one fewer from there removes the line.
    await tester.tap(find.byTooltip('One fewer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('One fewer'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove from bag'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove from bag'));
    await tester.pumpAndSettle();
    expect(find.text('Add'), findsOneWidget);
  });

  testWidgets('a shop with no usable number cannot be ordered from, and says why', (tester) async {
    for (final contact in [null, '044 2345 6789']) {
      await pumpPage(tester, _product(contact: contact));

      expect(find.text('This shop has not published a WhatsApp number yet.'), findsOneWidget);
      final button = tester.widget<InkWell>(
        find.ancestor(of: find.text('Order via WhatsApp'), matching: find.byType(InkWell)).first,
      );
      expect(button.onTap, isNull, reason: 'contact was $contact');
    }
  });

  testWidgets('a number already stored with its country code still orders', (tester) async {
    await pumpPage(tester, _product(contact: '+91 98765 43210'));

    final button = tester.widget<InkWell>(
      find.ancestor(of: find.text('Order via WhatsApp'), matching: find.byType(InkWell)).first,
    );
    expect(button.onTap, isNotNull);
  });

  testWidgets('lays out without overflow at every supported width', (tester) async {
    await forEachViewport(tester, () => _screen(_product()));
  });

  group('the order message', () {
    test('states the price, the saving and the product link', () {
      final message = buildProductOrderMessage(_product());

      expect(message, contains('Handcrafted Golden Butter Cookies'));
      expect(message, contains('Price: ₹149 (MRP ₹200, saving ₹51)'));
      expect(message, contains('Accepts Town Coin: 10%'));
      expect(message, isNot(contains('Quantity')));
    });

    test('adds the quantity and the total only when more than one is ordered', () {
      final message = buildProductOrderMessage(_product(), quantity: 3);

      expect(message, contains('Quantity: 3'));
      expect(message, contains('Total: ₹447'));
    });
  });
}
