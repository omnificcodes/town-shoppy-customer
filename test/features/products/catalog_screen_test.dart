import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/products/data/models/product.dart';
import 'package:customer/features/products/data/products_repository.dart';
import 'package:customer/features/products/presentation/products_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Product _product({
  int id = 1,
  String name = 'Butter Cookies',
  double price = 149,
  double? mrp = 200,
  double? percentage = 25.5,
}) => Product.fromJson({
  'id': id,
  'merchant': {'id': 3, 'name': 'Kairaly Bakers', 'contact_mobile_number': '9876543210'},
  'name': name,
  'price': price,
  'mrp': ?mrp,
  'discount_amount': ?(mrp == null ? null : mrp - price),
  'discount_percentage': ?percentage,
  'status': 'active',
});

/// Remembers what the screen asked the API for, so a test can assert on
/// the request the pills and the search box actually produce.
class _RecordingProductsRepository implements ProductsRepository {
  _RecordingProductsRepository(this.products);

  final List<Product> products;
  final List<Map<String, dynamic>> calls = [];

  @override
  Future<OffsetPage<Product>> list({
    int? merchantId,
    int page = 1,
    int perPage = 20,
    Map<String, dynamic> filters = const {},
  }) async {
    calls.add({'merchant_id': merchantId, 'page': page, ...filters});
    final matching = filters.containsKey('max_price')
        ? products.where((p) => p.price <= (filters['max_price'] as num)).toList()
        : products;
    return OffsetPage(items: matching, currentPage: 1, lastPage: 1, total: matching.length);
  }

  @override
  Future<Product> show(int id) async => products.firstWhere((product) => product.id == id);
}

// ignore: library_private_types_in_public_api -- a test helper, not an API.
Future<_RecordingProductsRepository> pumpCatalog(WidgetTester tester, {List<Product>? products}) async {
  final repository = _RecordingProductsRepository(
    products ??
        [
          _product(),
          _product(id: 2, name: 'Banana Chips', price: 90, mrp: 100, percentage: 10),
          _product(id: 3, name: 'Ghee Cake', price: 180, mrp: null, percentage: null),
        ],
  );

  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [productsRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(theme: AppTheme.light, home: const ProductsListScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  testWidgets('features the biggest saving, and says what is on offer', (tester) async {
    await pumpCatalog(tester);

    expect(find.text('BIGGEST SAVING'), findsOneWidget);
    expect(find.text('Up to 25.5% OFF today'), findsOneWidget);
    expect(find.text('2 products are on offer'), findsOneWidget);
    // The featured product is not repeated in the grid below it.
    expect(find.text('Butter Cookies'), findsOneWidget);
    expect(find.text('3 items'), findsOneWidget);
  });

  testWidgets('a filter pill refetches with that filter, and drops the featured card', (tester) async {
    final repository = await pumpCatalog(tester);

    // The pill row scrolls; the last pill starts off the right edge.
    await tester.ensureVisible(find.text('Under ₹100'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Under ₹100'));
    await tester.pumpAndSettle();

    expect(repository.calls.last['max_price'], 100);
    expect(find.text('BIGGEST SAVING'), findsNothing);
    expect(find.text('All products'), findsOneWidget);
    expect(find.text('Banana Chips'), findsOneWidget);
  });

  testWidgets('typing searches once the typing stops, not once per letter', (tester) async {
    final repository = await pumpCatalog(tester);

    await tester.enterText(find.byType(TextField), 'cake');
    await tester.pump(const Duration(milliseconds: 100));
    expect(repository.calls, hasLength(1), reason: 'still typing');

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(repository.calls.last['search'], 'cake');
  });

  testWidgets('says so when a search matches nothing, quoting what was searched for', (tester) async {
    await pumpCatalog(tester, products: []);

    await tester.enterText(find.byType(TextField), 'samosa');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Nothing matched'), findsOneWidget);
    expect(find.textContaining('"samosa"'), findsOneWidget);
  });

  group('the bag', () {
    testWidgets('appears only once something is added, and totals what is in it', (tester) async {
      await pumpCatalog(tester);

      expect(find.text('Order via WhatsApp'), findsNothing);

      await tester.tap(find.text('Add').first);
      await tester.pumpAndSettle();

      expect(find.text('1 item in bag'), findsOneWidget);
      expect(find.text('₹149'), findsWidgets);
      expect(find.text('Saved ₹51'), findsOneWidget);
      expect(find.text('Order via WhatsApp'), findsOneWidget);
    });

    testWidgets('the tile turns into a stepper that counts up and empties again', (tester) async {
      await pumpCatalog(tester);

      await tester.tap(find.text('Add').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('One more'));
      await tester.pumpAndSettle();

      expect(find.text('2 items in bag'), findsOneWidget);

      await tester.tap(find.byTooltip('One fewer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove from bag'));
      await tester.pumpAndSettle();

      expect(find.text('Order via WhatsApp'), findsNothing);
      expect(find.text('Add'), findsWidgets);
    });
  });
}
