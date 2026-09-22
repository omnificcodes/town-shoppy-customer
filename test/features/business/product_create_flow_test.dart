import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/business/application/business_context.dart';
import 'package:customer/features/business/data/business_products_repository.dart';
import 'package:customer/features/business/presentation/business_routes.dart';
import 'package:customer/features/business/presentation/products/business_products_screen.dart';
import 'package:customer/features/business/presentation/products/product_form_screen.dart';
import 'package:customer/features/products/data/models/product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Stands in for the API: keeps what was created, and lists it back the
/// way a refreshed catalog would.
class _FakeBusinessProductsRepository implements BusinessProductsRepository {
  final List<Product> saved = [];
  int creates = 0;

  @override
  Future<OffsetPage<Product>> list({required int merchantId, int page = 1, int perPage = 20}) async =>
      OffsetPage(items: [...saved], currentPage: 1, lastPage: 1, total: saved.length);

  @override
  Future<Product> create({required int merchantId, required ProductInput input}) async {
    creates++;
    final json = input.toJson()..addAll({'id': 41 + creates});
    final product = Product.fromJson(json);
    saved.add(product);
    return product;
  }

  @override
  Future<Product> update(int id, ProductInput input) async => throw UnimplementedError();

  @override
  Future<void> delete(int id) async => throw UnimplementedError();
}

// ignore: library_private_types_in_public_api -- a test helper, not an API.
Future<_FakeBusinessProductsRepository> pumpCatalog(WidgetTester tester) async {
  final repository = _FakeBusinessProductsRepository();

  // Tall enough that the form's lazy ListView builds in full.
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final router = GoRouter(
    initialLocation: BusinessRoutes.products,
    routes: [
      GoRoute(path: BusinessRoutes.products, builder: (context, state) => const BusinessProductsScreen()),
      GoRoute(path: BusinessRoutes.productNew, builder: (context, state) => const ProductFormScreen()),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        businessProductsRepositoryProvider.overrideWithValue(repository),
        myMerchantIdProvider.overrideWithValue(3),
        isBusinessOwnerProvider.overrideWithValue(true),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  testWidgets('saving a new product lands back on the catalog, with the product already in it', (tester) async {
    final repository = await pumpCatalog(tester);
    expect(find.text('No products yet'), findsOneWidget);

    await tester.tap(find.text('New product'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Cardamom Rusks');
    await tester.enterText(find.widgetWithText(TextField, 'Offer price (₹)'), '99');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add product'));
    await tester.pumpAndSettle();

    // Saved before anything moved.
    expect(repository.creates, 1);
    expect(repository.saved.single.name, 'Cardamom Rusks');

    // On the catalog, not on the form, and told what happened.
    expect(find.text('Product added successfully.'), findsOneWidget);
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Add product'), findsNothing);

    // Already listed -- no pull-to-refresh needed.
    expect(find.text('Cardamom Rusks'), findsOneWidget);
    expect(find.text('No products yet'), findsNothing);
  });

  testWidgets('a rejected save keeps the merchant on the form with what they typed', (tester) async {
    await pumpCatalog(tester);

    await tester.tap(find.text('New product'));
    await tester.pumpAndSettle();

    // No name, so the form refuses before it ever calls the API.
    await tester.enterText(find.widgetWithText(TextField, 'Offer price (₹)'), '99');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add product'));
    await tester.pumpAndSettle();

    expect(find.text('Add product'), findsOneWidget, reason: 'still on the form');
    expect(find.text('Product added successfully.'), findsNothing);
  });
}
