import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/business/presentation/products/product_form_screen.dart';
import 'package:customer/features/products/data/models/product.dart';
import 'package:customer/features/products/presentation/product_card.dart';
import 'package:customer/features/products/presentation/product_price.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Product _product({double price = 799, double? mrp, double? discount, double? percentage}) => Product.fromJson({
  'id': 4,
  'name': 'Assorted Cupcakes',
  'price': price,
  'mrp': ?mrp,
  'discount_amount': ?discount,
  'discount_percentage': ?percentage,
  'status': 'active',
});

Widget _wrap(Widget child) => ProviderScope(
  child: MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  ),
);

void main() {
  group('the saving a product shows', () {
    test('comes from the server when it sends one', () {
      final product = _product(price: 799, mrp: 1000, discount: 201, percentage: 20.1);

      expect(product.saving, 201);
      expect(product.savingPercentage, 20.1);
      expect(product.hasDiscount, isTrue);
    });

    test('is worked out from the two prices when an older API omits it', () {
      final product = _product(price: 799, mrp: 1000);

      expect(product.saving, 201);
      expect(product.savingPercentage, 20.1);
    });

    test('is nothing when the prices match, or when there is no MRP', () {
      expect(_product(price: 799, mrp: 799).saving, isNull);
      expect(_product(price: 799, mrp: 799).hasDiscount, isFalse);
      expect(_product(price: 799).saving, isNull);
      expect(_product(price: 799).savingPercentage, isNull);
    });

    test('sends the MRP with the product, and null clears it', () {
      expect(const ProductInput(name: 'A', price: 799, mrp: 1000).toJson()['mrp'], 1000);
      expect(const ProductInput(name: 'A', price: 799).toJson()['mrp'], isNull);
    });
  });

  group('what a customer sees', () {
    testWidgets('a discounted product card shows the offer price, the old price and the saving', (tester) async {
      await tester.pumpWidget(_wrap(SizedBox(width: 200, child: ProductCard(product: _product(mrp: 1000)))));
      await tester.pumpAndSettle();

      expect(find.text('20.1% OFF'), findsOneWidget);
      expect(find.text('₹1000'), findsOneWidget);
      expect(find.text('₹799'), findsOneWidget);
      expect(find.text('You save ₹201'), findsOneWidget);

      final old = tester.widget<Text>(find.text('₹1000'));
      expect(old.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('a product with no MRP shows its price alone', (tester) async {
      await tester.pumpWidget(_wrap(SizedBox(width: 200, child: ProductCard(product: _product()))));
      await tester.pumpAndSettle();

      expect(find.text('₹799'), findsOneWidget);
      expect(find.textContaining('OFF'), findsNothing);
      expect(find.textContaining('You save'), findsNothing);
    });

    testWidgets('the detail treatment lays the same prices along one row', (tester) async {
      await tester.pumpWidget(_wrap(ProductPrice(product: _product(price: 22, mrp: 30), large: true)));
      await tester.pumpAndSettle();

      expect(find.text('₹22'), findsOneWidget);
      expect(find.text('₹30'), findsOneWidget);
      expect(find.text('You Save ₹8'), findsOneWidget);
      // The percentage belongs to the detail page's discount tag, over the
      // image -- repeating it beside the prices would say it twice.
      expect(find.textContaining('% OFF'), findsNothing);
    });
  });

  group('the merchant form', () {
    // Tall enough that the whole form is built: its ListView is lazy, and a
    // phone-sized window leaves the discount box and its errors unbuilt.
    Future<void> openForm(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(_wrap(const ProductFormScreen()));
      await tester.pumpAndSettle();
    }

    testWidgets('works the discount out from the two prices as they are typed', (tester) async {
      await openForm(tester);

      expect(find.text('No discount'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Actual price / MRP (₹)'), '1000');
      await tester.enterText(find.widgetWithText(TextField, 'Offer price (₹)'), '799');
      await tester.pumpAndSettle();

      expect(find.text('₹201 OFF · 20.1% OFF'), findsOneWidget);
      expect(find.text('Customers pay ₹799 instead of ₹1000.'), findsOneWidget);
    });

    testWidgets('an offer price above the actual price is refused, and equal prices are simply no discount', (
      tester,
    ) async {
      await openForm(tester);

      await tester.enterText(find.widgetWithText(TextField, 'Actual price / MRP (₹)'), '500');
      await tester.enterText(find.widgetWithText(TextField, 'Offer price (₹)'), '799');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add product'));
      await tester.pumpAndSettle();

      expect(find.text('The actual price cannot be less than the offer price.'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Actual price / MRP (₹)'), '799');
      await tester.pumpAndSettle();

      expect(find.text('The actual price cannot be less than the offer price.'), findsNothing);
      expect(find.text('No discount'), findsOneWidget);
      expect(find.text('Customers pay ₹799.'), findsOneWidget);
    });
  });
}
