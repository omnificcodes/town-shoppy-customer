import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/networking/cursor_page.dart';
import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/favorites/data/favorites_repository.dart';
import 'package:customer/features/merchants/application/merchant_branches_provider.dart';
import 'package:customer/features/merchants/application/merchant_detail_provider.dart';
import 'package:customer/features/merchants/data/models/association_ref.dart';
import 'package:customer/features/merchants/data/models/merchant.dart';
import 'package:customer/features/merchants/data/models/merchant_branch_ref.dart';
import 'package:customer/features/merchants/data/models/merchant_category.dart';
import 'package:customer/features/merchants/data/models/town_ref.dart';
import 'package:customer/features/merchants/presentation/merchant_detail_screen.dart';
import 'package:customer/features/offers/application/merchant_offers_provider.dart';
import 'package:customer/features/offers/data/models/offer.dart';
import 'package:customer/features/products/data/models/product.dart';
import 'package:customer/features/products/data/products_repository.dart';
import 'package:customer/features/wallet/data/models/silver_wallet_balance.dart';
import 'package:customer/features/wallet/data/models/wallet_ledger_entry.dart';
import 'package:customer/features/wallet/data/wallet_repository.dart';

import '../../helpers/fake_favorites_repository.dart';
import '../../helpers/responsive_test_helper.dart';

const _merchant = Merchant(
  id: 1,
  name: 'The Grand Downtown Corner Cafe, Bakery, and Artisanal Coffee Roastery Emporium',
  description:
      'A long-standing neighbourhood institution serving locally roasted coffee, fresh-baked pastries, and '
      'a full breakfast and lunch menu every day of the week, rain or shine, since well before Town Shoppy '
      'ever existed as an idea.',
  logoUrl: null,
  websiteUrl: 'https://www.the-grand-downtown-corner-cafe-and-artisanal-coffee-roastery-emporium.example.com/menu',
  contactMobileNumber: '9876543210',
  socialLinks: null,
  discountRate: 12.5,
  acceptsTownCoin: true,
  category: MerchantCategory(id: 1, name: 'Food & Beverage', slug: 'food-beverage'),
  association: AssociationRef(
    id: 1,
    name: 'Downtown Traders and Merchants Welfare Association',
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

const _branches = [
  MerchantBranchRef(
    id: 1,
    name: 'Main Street Flagship Location',
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
  MerchantBranchRef(
    id: 2,
    name: 'City Centre',
    isPrimary: false,
    addressLine: null,
    locality: null,
    city: null,
    state: null,
    postalCode: null,
    country: null,
    latitude: 1.0,
    longitude: 2.0,
    distanceKm: 7.4,
  ),
];

final _offer = Offer(
  id: 9,
  merchantId: 1,
  merchantName: _merchant.name,
  merchantLogoUrl: null,
  title: 'Weekend feast: flat 25% off across every cafe and bakery counter in the whole town',
  description: 'Valid on dine-in and takeaway orders above five hundred rupees',
  imageUrl: null,
  offerType: 'percentage_discount',
  discountValue: 25,
  terms: null,
  startsAt: null,
  endsAt: DateTime.now().add(const Duration(days: 21)),
  distanceKm: null,
  coinDiscountRate: 5,
  applicableItem: null,
  isCoinRedeemable: true,
);

/// The products section loads through the real controller; an empty
/// catalog keeps it quiet without reaching for the network.
class _EmptyProductsRepository implements ProductsRepository {
  @override
  Future<OffsetPage<Product>> list({int? merchantId, int page = 1, int perPage = 20}) async =>
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

Widget _wrap() {
  return ProviderScope(
    overrides: [
      merchantDetailProvider(1).overrideWith((ref) async => _merchant),
      merchantBranchesProvider(1).overrideWith((ref) async => _branches),
      merchantOffersProvider(1).overrideWith((ref) async => [_offer]),
      productsRepositoryProvider.overrideWithValue(_EmptyProductsRepository()),
      walletRepositoryProvider.overrideWithValue(_FakeWalletRepository()),
      favoritesRepositoryProvider.overrideWithValue(FakeFavoritesRepository()),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const MerchantDetailScreen(merchantId: 1)),
  );
}

const _singleBranchMerchant = Merchant(
  id: 2,
  name: 'The Grand Downtown Corner Cafe, Bakery, and Artisanal Coffee Roastery Emporium',
  description: 'A long-standing neighbourhood institution.',
  logoUrl: null,
  websiteUrl: null,
  // Not a dialable mobile number, so Call and WhatsApp must stay disabled.
  contactMobileNumber: '+91 98765 43210 extension 00000',
  socialLinks: null,
  discountRate: null,
  acceptsTownCoin: false,
  category: MerchantCategory(id: 1, name: 'Food & Beverage', slug: 'food-beverage'),
  association: AssociationRef(id: 1, name: 'Downtown', slug: 'downtown', town: null),
  branch: null,
);

const _singleBranch = [
  MerchantBranchRef(
    id: 1,
    name: 'Main Street Flagship Location, Ground and Mezzanine Floor',
    isPrimary: true,
    addressLine: '1200 West Boulevard Avenue, Suite 450B, Uptown Financial District Complex',
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

Widget _wrapSingleBranch() {
  return ProviderScope(
    overrides: [
      merchantDetailProvider(2).overrideWith((ref) async => _singleBranchMerchant),
      merchantBranchesProvider(2).overrideWith((ref) async => _singleBranch),
      merchantOffersProvider(2).overrideWith((ref) async => const <Offer>[]),
      productsRepositoryProvider.overrideWithValue(_EmptyProductsRepository()),
      walletRepositoryProvider.overrideWithValue(_FakeWalletRepository()),
      favoritesRepositoryProvider.overrideWithValue(FakeFavoritesRepository()),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const MerchantDetailScreen(merchantId: 2)),
  );
}

void main() {
  testWidgets('MerchantDetailScreen renders every section with worst-case content without overflow at every viewport', (
    tester,
  ) async {
    await forEachViewport(
      tester,
      _wrap,
      verify: (tester, size) async {
        expect(find.text('Merchant Details'), findsOneWidget);
        expect(find.textContaining('The Grand Downtown'), findsWidgets);
        expect(find.text('Accepts Town Coin'), findsOneWidget);
        expect(find.text('Pay bill with coins'), findsOneWidget);

        final page = find.byType(ListView);
        for (final text in [
          'Redeem Town Coin',
          'Call store',
          'ABOUT',
          'OFFERS',
          'Claim',
          'BRANCH LOCATIONS',
          'Main Street Flagship Location',
          'Primary',
          '7.4 km away',
        ]) {
          await tester.dragUntilVisible(find.text(text), page, const Offset(0, -250));
          expect(find.text(text), findsOneWidget, reason: '$text should be reachable at $size');
        }
      },
    );
  });

  testWidgets('a merchant without coin redemption or a dialable number shows only what is real', (tester) async {
    await forEachViewport(
      tester,
      _wrapSingleBranch,
      verify: (tester, size) async {
        expect(find.text('Redeem Town Coin'), findsNothing);
        expect(find.text('Scan QR to pay'), findsOneWidget);

        final page = find.byType(ListView);
        await tester.dragUntilVisible(find.text('Directions'), page, const Offset(0, -250));
        expect(find.text('No number listed'), findsNWidgets(2));
        expect(find.text('Open in Maps'), findsOneWidget);

        await tester.dragUntilVisible(find.text('BRANCH LOCATION'), page, const Offset(0, -250));
        expect(find.textContaining('Main Street Flagship'), findsOneWidget);
        expect(find.text('Primary'), findsNothing);
      },
    );
  });
}
