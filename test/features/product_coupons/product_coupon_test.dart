import 'package:customer/core/networking/cursor_page.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/business/application/business_context.dart';
import 'package:customer/features/business/data/business_products_repository.dart';
import 'package:customer/features/business/data/models/merchant_entitlement.dart';
import 'package:customer/features/business/presentation/business_routes.dart';
import 'package:customer/features/business/presentation/products/product_coupon_requests_screen.dart';
import 'package:customer/features/business/presentation/products/product_form_screen.dart';
import 'package:customer/features/product_coupons/data/models/product_coupon_request.dart';
import 'package:customer/features/product_coupons/data/product_coupons_repository.dart';
import 'package:customer/features/product_coupons/presentation/product_coupon_button.dart';
import 'package:customer/features/products/data/models/product.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Product _product({int couponsPerClaim = 3, String? mine}) => Product.fromJson({
  'id': 7,
  'merchant': {'id': 3, 'name': 'Kairaly Bakers'},
  'name': 'Butter Cookies',
  'price': 149,
  'status': 'active',
  'coupon_count': couponsPerClaim,
  'coupons_per_claim': couponsPerClaim,
  'my_coupon_request': ?mine,
});

ProductCouponRequest _request({String status = 'pending'}) => ProductCouponRequest.fromJson({
  'id': 21,
  'product_id': 7,
  'product_name': 'Butter Cookies',
  'merchant_id': 3,
  'customer': {'id': 9, 'name': 'Asha', 'mobile_number': '+919990001111'},
  'coupons_requested': 3,
  'coupons_issued': status == 'approved' ? 3 : null,
  'status': status,
  'created_at': '2026-10-07T10:00:00+05:30',
});

/// Records what was asked of the API instead of sending it.
class _FakeProductCouponsRepository extends ProductCouponsRepository {
  _FakeProductCouponsRepository() : super(Dio());

  final List<int> requestedProducts = [];
  final List<int> approved = [];
  List<ProductCouponRequest> queue = [_request()];

  @override
  Future<ProductCouponRequest> request(int productId, {required String idempotencyKey}) async {
    requestedProducts.add(productId);
    return _request();
  }

  @override
  Future<CursorPage<ProductCouponRequest>> merchantRequests({String? status, String? cursor, int perPage = 20}) async =>
      CursorPage(items: queue.where((r) => status == null || r.status == status).toList(), nextCursor: null);

  @override
  Future<ProductCouponRequest> approve(int id) async {
    approved.add(id);
    queue = [_request(status: 'approved')];
    return queue.single;
  }
}

Widget _wrap(Widget child, {required _FakeProductCouponsRepository repository, List overrides = const []}) =>
    ProviderScope(
      overrides: [productCouponsRepositoryProvider.overrideWithValue(repository), ...overrides],
      child: MaterialApp(theme: AppTheme.light, home: Scaffold(body: child)),
    );

class _FakeBusinessProductsRepository implements BusinessProductsRepository {
  ProductInput? created;

  @override
  Future<OffsetPage<Product>> list({required int merchantId, int page = 1, int perPage = 20}) async =>
      const OffsetPage(items: [], currentPage: 1, lastPage: 1, total: 0);

  @override
  Future<Product> create({required int merchantId, required ProductInput input}) async {
    created = input;
    return Product.fromJson(input.toJson()..addAll({'id': 50}));
  }

  @override
  Future<Product> update(int id, ProductInput input) async => throw UnimplementedError();

  @override
  Future<void> delete(int id) async => throw UnimplementedError();
}

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  group('the customer\'s Get coupons button', () {
    testWidgets('asks the shop after a confirmation and then shows the request as waiting', (tester) async {
      final repository = _FakeProductCouponsRepository();
      await tester.pumpWidget(_wrap(Center(child: ProductCouponButton(product: _product(), compact: true)), repository: repository));

      expect(find.text('Get 3 coupons'), findsOneWidget);

      await tester.tap(find.text('Get 3 coupons'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ask Kairaly Bakers for 3 coupons'), findsOneWidget);

      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();

      expect(repository.requestedProducts, [7]);
      expect(find.text('Requested'), findsOneWidget);
      expect(find.text('Request sent to Kairaly Bakers.'), findsOneWidget);
    });

    testWidgets('shows nothing when the product carries no coupons, and Received once accepted', (tester) async {
      final repository = _FakeProductCouponsRepository();
      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              ProductCouponButton(product: _product(couponsPerClaim: 0), compact: true),
              ProductCouponButton(product: _product(mine: 'approved'), compact: true),
              ProductCouponButton(product: _product(mine: 'pending')),
            ],
          ),
          repository: repository,
        ),
      );

      expect(find.textContaining('Get'), findsNothing);
      expect(find.text('Received'), findsOneWidget);
      expect(find.text('Requested — waiting for the shop to accept'), findsOneWidget);
    });
  });

  testWidgets('the shop accepts a request from its queue', (tester) async {
    final repository = _FakeProductCouponsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [productCouponsRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(theme: AppTheme.light, home: const ProductCouponRequestsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Butter Cookies'), findsOneWidget);
    expect(find.textContaining('Asha'), findsOneWidget);
    expect(find.text('3 Lucky Draw coupons'), findsOneWidget);

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    // The confirmation names what is given.
    expect(find.text('Give 3 coupons?'), findsOneWidget);
    await tester.tap(find.text('Accept').last);
    await tester.pumpAndSettle();

    expect(repository.approved, [21]);
    expect(find.text('Nothing awaiting review'), findsOneWidget);
  });

  group('the Business product form', () {
    Future<_FakeBusinessProductsRepository> pumpForm(WidgetTester tester, MerchantEntitlement entitlement) async {
      final products = _FakeBusinessProductsRepository();
      tester.view.physicalSize = const Size(420, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessProductsRepositoryProvider.overrideWithValue(products),
            myMerchantIdProvider.overrideWithValue(3),
            merchantEntitlementProvider.overrideWith((ref) async => entitlement),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: GoRouter(
              initialLocation: BusinessRoutes.productNew,
              routes: [
                GoRoute(path: BusinessRoutes.products, builder: (context, state) => const Scaffold(body: Text('Catalog'))),
                GoRoute(path: BusinessRoutes.productNew, builder: (context, state) => const ProductFormScreen()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return products;
    }

    testWidgets('offers Lucky Draw coupons only when the plan includes them', (tester) async {
      await pumpForm(
        tester,
        const MerchantEntitlement(hasPackage: true, status: 'active', planName: 'Standard', inGracePeriod: false),
      );
      expect(find.text('Lucky Draw coupons'), findsNothing);
    });

    testWidgets('holds the count to the plan maximum', (tester) async {
      final products = await pumpForm(
        tester,
        const MerchantEntitlement(
          hasPackage: true,
          status: 'active',
          planName: 'VIP',
          inGracePeriod: false,
          productCoupons: true,
          maxCouponsPerProduct: 5,
        ),
      );
      expect(find.text('Lucky Draw coupons'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Cake');
      await tester.enterText(find.widgetWithText(TextField, 'Offer price (₹)'), '500');
      await tester.enterText(find.widgetWithText(TextField, 'Coupons per customer'), '6');
      await tester.tap(find.text('Add product'));
      await tester.pumpAndSettle();

      expect(find.text('Your plan allows at most 5 coupons per product.'), findsOneWidget);
      expect(products.created, isNull);

      await tester.enterText(find.widgetWithText(TextField, 'Coupons per customer'), '5');
      await tester.tap(find.text('Add product'));
      await tester.pumpAndSettle();
      expect(products.created?.couponCount, 5);
    });
  });
}
