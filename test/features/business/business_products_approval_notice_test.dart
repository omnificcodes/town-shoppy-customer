import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/business/application/business_context.dart';
import 'package:customer/features/business/data/business_products_repository.dart';
import 'package:customer/features/business/data/models/business_merchant.dart';
import 'package:customer/features/business/presentation/business_routes.dart';
import 'package:customer/features/business/presentation/products/business_products_screen.dart';
import 'package:customer/features/products/data/models/product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeBusinessProductsRepository implements BusinessProductsRepository {
  _FakeBusinessProductsRepository(this.items);

  final List<Product> items;

  @override
  Future<OffsetPage<Product>> list({required int merchantId, int page = 1, int perPage = 20}) async =>
      OffsetPage(items: items, currentPage: 1, lastPage: 1, total: items.length);

  @override
  Future<Product> create({required int merchantId, required ProductInput input}) async => throw UnimplementedError();

  @override
  Future<Product> update(int id, ProductInput input) async => throw UnimplementedError();

  @override
  Future<void> delete(int id) async => throw UnimplementedError();
}

BusinessMerchant _merchant(String status) => BusinessMerchant.fromJson({
  'id': 3,
  'name': 'Kairaly Bakers',
  'status': status,
  'accepts_town_coin': true,
  'is_featured': false,
});

final _product = Product.fromJson({
  'id': 7,
  'merchant_id': 3,
  'name': 'Chocolate Cake',
  'price': 450.0,
  'status': 'active',
  'image_urls': <String>[],
});

Future<void> _pump(WidgetTester tester, {required String status, List<Product> products = const []}) async {
  final router = GoRouter(
    initialLocation: BusinessRoutes.products,
    routes: [GoRoute(path: BusinessRoutes.products, builder: (context, state) => const BusinessProductsScreen())],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        businessProductsRepositoryProvider.overrideWithValue(_FakeBusinessProductsRepository(products)),
        myMerchantIdProvider.overrideWithValue(3),
        isBusinessOwnerProvider.overrideWithValue(true),
        myMerchantProvider.overrideWith((ref) async => _merchant(status)),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a pending shop is told its products are not in Shopping yet', (tester) async {
    await _pump(tester, status: 'pending', products: [_product]);

    expect(find.text('Awaiting approval'), findsOneWidget);
    expect(find.textContaining('once an admin approves your shop'), findsOneWidget);
    // The catalog itself still lists, so the merchant can keep building it.
    expect(find.text('Chocolate Cake'), findsOneWidget);
  });

  testWidgets('the notice shows even before the first product exists', (tester) async {
    await _pump(tester, status: 'pending');

    expect(find.text('Awaiting approval'), findsOneWidget);
    expect(find.text('No products yet'), findsOneWidget);
  });

  testWidgets('a suspended shop gets the hidden-from-customers notice instead', (tester) async {
    await _pump(tester, status: 'suspended', products: [_product]);

    expect(find.text('Suspended'), findsOneWidget);
    expect(find.textContaining('hidden from Shopping'), findsOneWidget);
    expect(find.text('Awaiting approval'), findsNothing);
  });

  testWidgets('an active shop sees no notice at all', (tester) async {
    await _pump(tester, status: 'active', products: [_product]);

    expect(find.text('Awaiting approval'), findsNothing);
    expect(find.textContaining('hidden from Shopping'), findsNothing);
    expect(find.text('Chocolate Cake'), findsOneWidget);
  });
}
