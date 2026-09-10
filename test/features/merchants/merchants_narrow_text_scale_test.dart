import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/home/application/home_location_controller.dart';
import 'package:customer/features/merchants/application/merchant_branches_provider.dart';
import 'package:customer/features/merchants/application/merchant_categories_provider.dart';
import 'package:customer/features/merchants/application/merchant_detail_provider.dart';
import 'package:customer/features/merchants/data/merchants_repository.dart';
import 'package:customer/features/merchants/data/models/association_ref.dart';
import 'package:customer/features/merchants/data/models/merchant.dart';
import 'package:customer/features/merchants/data/models/merchant_branch_ref.dart';
import 'package:customer/features/merchants/data/models/merchant_category.dart';
import 'package:customer/features/merchants/data/models/nearby_merchant.dart';
import 'package:customer/features/merchants/data/models/town_ref.dart';
import 'package:customer/features/merchants/presentation/merchant_detail_screen.dart';
import 'package:customer/features/merchants/presentation/merchants_list_screen.dart';

import '../../helpers/responsive_test_helper.dart';

/// The narrowest phone the audit mandates, on top of the standard sweep —
/// every screen here is also pumped at 2x system text scale.
const _narrow = Size(320, 568);

const _merchant = Merchant(
  id: 1,
  name: 'The Grand Downtown Corner Cafe, Bakery, and Artisanal Coffee Roastery Emporium',
  description: 'A long-standing neighbourhood institution serving locally roasted coffee and fresh-baked pastries.',
  logoUrl: null,
  websiteUrl: 'https://www.the-grand-downtown-corner-cafe.example.com/menu',
  contactMobileNumber: '+91 98765 43210 extension 00000',
  socialLinks: null,
  discountRate: 12.5,
  acceptsTownCoin: true,
  category: MerchantCategory(id: 1, name: 'Food & Beverage', slug: 'food-beverage'),
  association: AssociationRef(
    id: 1,
    name: 'Downtown',
    slug: 'downtown',
    town: TownRef(id: 1, name: 'Springfield-on-the-Hudson Metropolitan Area', slug: 'springfield', stateRegion: 'New Amsterdam'),
  ),
  branch: null,
);

const _singleBranch = [
  MerchantBranchRef(
    id: 1,
    name: 'Main Street Flagship Location, Ground and Mezzanine Floor',
    isPrimary: true,
    addressLine: '1200 West Boulevard Avenue, Suite 450B',
    locality: 'Uptown Financial District',
    city: 'Springfield-on-the-Hudson',
    state: 'New Amsterdam',
    postalCode: '400001',
    country: 'India',
    latitude: 1.0,
    longitude: 2.0,
    distanceKm: null,
  ),
];

class _FakeMerchantsRepository implements MerchantsRepository {
  @override
  Future<OffsetPage<Merchant>> list({
    int page = 1,
    int perPage = 20,
    int? categoryId,
    bool? acceptsTownCoin,
    bool? featured,
    String? search,
  }) async => const OffsetPage(items: [_merchant], currentPage: 1, lastPage: 1, total: 1);

  @override
  Future<Merchant> show(int id) async => _merchant;

  @override
  Future<List<MerchantBranchRef>> getBranches(int merchantId) async => _singleBranch;

  @override
  Future<OffsetPage<NearbyMerchant>> nearby({
    required double latitude,
    required double longitude,
    int? categoryId,
    int page = 1,
    int perPage = 50,
  }) async => throw UnimplementedError();
}

class _FakeHomeLocationController extends HomeLocationController {
  @override
  Future<HomeLocationState> build() async => const HomeLocationUnavailable();
}

Widget _app(Widget home) {
  return MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.0)),
      child: child!,
    ),
    home: home,
  );
}

void main() {
  testWidgets('MerchantDetailScreen renders at 320px and 2x text without overflow', (tester) async {
    await forEachViewport(
      tester,
      sizes: [_narrow, ...kResponsiveViewportSizes],
      () => ProviderScope(
        overrides: [
          merchantDetailProvider(1).overrideWith((ref) async => _merchant),
          merchantBranchesProvider(1).overrideWith((ref) async => _singleBranch),
        ],
        child: _app(const MerchantDetailScreen(merchantId: 1)),
      ),
      verify: (tester, size) async {
        expect(find.text('Accepts Town Coin'), findsOneWidget);
        // At 2x the hero alone can fill a 568px viewport, so the CTA is
        // legitimately below the fold -- reachable, not missing.
        await tester.dragUntilVisible(find.text('Redeem Town Coin'), find.byType(ListView), const Offset(0, -200));
        expect(find.text('Redeem Town Coin'), findsOneWidget);
        await tester.dragUntilVisible(find.text('Get Directions'), find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(find.text('Get Directions'), findsOneWidget);
        await tester.dragUntilVisible(find.text('Why pay with Town Coin'), find.byType(ListView), const Offset(0, -300));
        expect(find.text('Pay with Town Coins'), findsOneWidget);
      },
    );
  });

  testWidgets('MerchantsListScreen renders its header, search, banner, strip and cards at 320px and 2x text', (tester) async {
    await forEachViewport(
      tester,
      sizes: [_narrow, ...kResponsiveViewportSizes],
      () => ProviderScope(
        overrides: [
          merchantCategoriesProvider.overrideWith(
            (ref) async => const [
              MerchantCategory(id: 1, name: 'Agriculture & Farming Supplies', slug: 'agriculture'),
              MerchantCategory(id: 2, name: 'Bakery', slug: 'bakery'),
            ],
          ),
          merchantsRepositoryProvider.overrideWithValue(_FakeMerchantsRepository()),
          homeLocationControllerProvider.overrideWith(_FakeHomeLocationController.new),
        ],
        child: _app(const MerchantsListScreen()),
      ),
      verify: (tester, size) async {
        expect(find.text('Discover Merchants'), findsOneWidget);
        expect(find.text('Bakery'), findsOneWidget);
        expect(find.byTooltip('Save to favorites', skipOffstage: false), findsWidgets);
      },
    );
  });
}
