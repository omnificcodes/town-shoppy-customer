import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/networking/cursor_page.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/favorites/data/favorites_repository.dart';
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
import 'package:customer/features/merchants/presentation/favorite_button.dart';
import 'package:customer/features/merchants/presentation/merchant_detail_screen.dart';
import 'package:customer/features/merchants/presentation/merchants_list_screen.dart';
import 'package:customer/features/offers/application/merchant_offers_provider.dart';
import 'package:customer/features/offers/data/models/offer.dart';
import 'package:customer/features/products/data/models/product.dart';
import 'package:customer/features/products/data/products_repository.dart';
import 'package:customer/features/wallet/data/models/silver_wallet_balance.dart';
import 'package:customer/features/wallet/data/models/wallet_ledger_entry.dart';
import 'package:customer/features/wallet/data/wallet_repository.dart';

import '../../helpers/fake_favorites_repository.dart';
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
  contactMobileNumber: '+91 98765 43210',
  socialLinks: null,
  discountRate: 12.5,
  acceptsTownCoin: true,
  category: MerchantCategory(id: 1, name: 'Food & Beverage', slug: 'food-beverage'),
  association: AssociationRef(
    id: 1,
    name: 'Downtown',
    slug: 'downtown',
    town: TownRef(
      id: 1,
      name: 'Springfield-on-the-Hudson Metropolitan Area',
      slug: 'springfield',
      stateRegion: 'New Amsterdam',
    ),
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
    int? associationId,
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
    double? radiusKm,
    int page = 1,
    int perPage = 50,
  }) async => throw UnimplementedError();
}

class _EmptyProductsRepository implements ProductsRepository {
  @override
  Future<OffsetPage<Product>> list({int? merchantId, int page = 1, int perPage = 20, Map<String, dynamic> filters = const {}}) async =>
      const OffsetPage(items: [], currentPage: 1, lastPage: 1, total: 0);

  @override
  Future<Product> show(int id) async => throw UnimplementedError();
}

class _FakeWalletRepository implements WalletRepository {
  @override
  Future<SilverWalletBalance> balance() async => const SilverWalletBalance(
    balance: 1234567,
    universalBalance: 1234567,
    shopExclusiveBalance: 0,
    shopExclusiveBreakdown: [],
    balanceInrEquivalent: 123456.7,
    updatedAt: null,
  );

  @override
  Future<CursorPage<WalletLedgerEntry>> transactions({String? cursor}) async => throw UnimplementedError();
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
          merchantOffersProvider(1).overrideWith((ref) async => const <Offer>[]),
          productsRepositoryProvider.overrideWithValue(_EmptyProductsRepository()),
          walletRepositoryProvider.overrideWithValue(_FakeWalletRepository()),
          favoritesRepositoryProvider.overrideWithValue(FakeFavoritesRepository()),
        ],
        child: _app(const MerchantDetailScreen(merchantId: 1)),
      ),
      verify: (tester, size) async {
        // At 2x the cover and profile card alone can fill a 568px viewport,
        // so everything below them is legitimately below the fold --
        // reachable, not missing.
        final page = find.byType(ListView);
        for (final text in ['Accepts Town Coin', 'Pay bill with coins', 'Directions', 'BRANCH LOCATION']) {
          // The sticky pay bar repeats 'Pay bill with coins' outside the
          // list, so only look for the copy that scrolls with the page.
          final inPage = find.descendant(of: page, matching: find.text(text));
          await tester.dragUntilVisible(inPage, page, const Offset(0, -200));
          expect(inPage, findsOneWidget, reason: '$text should be reachable at $size');
        }
      },
    );
  });

  testWidgets('MerchantsListScreen renders its header, search, strip and cards at 320px and 2x text', (tester) async {
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
          favoritesRepositoryProvider.overrideWithValue(FakeFavoritesRepository()),
          homeLocationControllerProvider.overrideWith(_FakeHomeLocationController.new),
        ],
        child: _app(const MerchantsListScreen()),
      ),
      verify: (tester, size) async {
        expect(find.text('Discover Merchants'), findsOneWidget);
        expect(find.text('Bakery'), findsOneWidget);
        // The heart's tooltip now names the shop, so match the control itself.
        expect(find.byType(FavoriteButton, skipOffstage: false), findsWidgets);
      },
    );
  });
}
