import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/core/utils/indian_mobile.dart';
import 'package:customer/features/favorites/data/favorites_repository.dart';
import 'package:customer/features/merchants/data/models/association_ref.dart';
import 'package:customer/features/merchants/data/models/merchant.dart';
import 'package:customer/features/merchants/data/models/merchant_category.dart';
import 'package:customer/features/merchants/data/models/town_ref.dart';
import 'package:customer/features/merchants/presentation/merchant_card.dart';
import 'package:customer/features/wallet/application/wallet_controller.dart';
import 'package:customer/features/wallet/data/models/silver_wallet_balance.dart';

import '../../helpers/fake_favorites_repository.dart';

/// A wallet that resolves straight to [_balance] -- the card reads the
/// customer's Shop-Exclusive coins for its shop from it.
class _FixedWallet extends WalletController {
  _FixedWallet(this._balance);

  final SilverWalletBalance _balance;

  @override
  Future<SilverWalletBalance> build() async => _balance;
}

SilverWalletBalance _wallet({List<ShopExclusiveBreakdownEntry> breakdown = const []}) => SilverWalletBalance(
  balance: 500,
  universalBalance: 500,
  shopExclusiveBalance: breakdown.fold(0, (sum, row) => sum + row.balance),
  shopExclusiveBreakdown: breakdown,
  balanceInrEquivalent: 500,
  updatedAt: null,
);

// MerchantCard renders a FavoriteButton, which reads the saved-id set, and
// the customer's coins for the shop, which come from the wallet.
Widget _wrap(Widget child, {FakeFavoritesRepository? favorites, SilverWalletBalance? wallet}) => ProviderScope(
  overrides: [
    favoritesRepositoryProvider.overrideWithValue(favorites ?? FakeFavoritesRepository()),
    walletControllerProvider.overrideWith(() => _FixedWallet(wallet ?? _wallet())),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('shows the merchant name, category, and town', (tester) async {
    const merchant = Merchant(
      id: 1,
      name: 'Corner Cafe',
      description: null,
      logoUrl: null,
      websiteUrl: null,
      contactMobileNumber: null,
      socialLinks: null,
      discountRate: null,
      acceptsTownCoin: false,
      category: MerchantCategory(id: 1, name: 'Restaurant', slug: 'restaurant'),
      association: AssociationRef(
        id: 1,
        name: 'Downtown Association',
        slug: 'downtown',
        town: TownRef(id: 1, name: 'Springfield', slug: 'springfield', stateRegion: 'Illinois'),
      ),
      branch: null,
    );

    await tester.pumpWidget(_wrap(const MerchantCard(merchant: merchant)));

    expect(find.text('Corner Cafe'), findsOneWidget);
    expect(find.text('Restaurant · Springfield'), findsOneWidget);
  });

  testWidgets('shows a discount badge only when discount_rate is present and positive', (tester) async {
    const withDiscount = Merchant(
      id: 1,
      name: 'Corner Cafe',
      description: null,
      logoUrl: null,
      websiteUrl: null,
      contactMobileNumber: null,
      socialLinks: null,
      discountRate: 10,
      acceptsTownCoin: true,
      category: null,
      association: null,
      branch: null,
    );

    await tester.pumpWidget(_wrap(const MerchantCard(merchant: withDiscount)));
    expect(find.textContaining('% off'), findsOneWidget);
  });

  testWidgets('does not show a discount badge when discount_rate is null', (tester) async {
    const noDiscount = Merchant(
      id: 1,
      name: 'Corner Cafe',
      description: null,
      logoUrl: null,
      websiteUrl: null,
      contactMobileNumber: null,
      socialLinks: null,
      discountRate: null,
      acceptsTownCoin: false,
      category: null,
      association: null,
      branch: null,
    );

    await tester.pumpWidget(_wrap(const MerchantCard(merchant: noDiscount)));
    expect(find.textContaining('% off'), findsNothing);
  });

  testWidgets('invokes onTap when the card is tapped', (tester) async {
    const merchant = Merchant(
      id: 1,
      name: 'Corner Cafe',
      description: null,
      logoUrl: null,
      websiteUrl: null,
      contactMobileNumber: null,
      socialLinks: null,
      discountRate: null,
      acceptsTownCoin: false,
      category: null,
      association: null,
      branch: null,
    );
    var tapped = false;

    await tester.pumpWidget(_wrap(MerchantCard(merchant: merchant, onTap: () => tapped = true)));
    await tester.tap(find.byType(MerchantCard));

    expect(tapped, isTrue);
  });

  Merchant withContact(String? number) => Merchant(
    id: 1,
    name: 'Corner Cafe',
    description: null,
    logoUrl: null,
    websiteUrl: null,
    contactMobileNumber: number,
    socialLinks: null,
    discountRate: null,
    acceptsTownCoin: false,
    category: null,
    association: null,
    branch: null,
  );

  testWidgets('offers Call now and WhatsApp for a dialable mobile, and View shop otherwise', (tester) async {
    await tester.pumpWidget(
      _wrap(SingleChildScrollView(child: MerchantCard(merchant: withContact('+91 98765 43210')))),
    );
    expect(find.text('Call now'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('View shop'), findsNothing);

    await tester.pumpWidget(_wrap(SingleChildScrollView(child: MerchantCard(merchant: withContact('not a phone')))));
    expect(find.text('Call now'), findsNothing);
    expect(find.text('View shop'), findsOneWidget);
  });

  testWidgets("shows the customer's coins for this shop only, and nothing when there are none", (tester) async {
    final shop = withContact(null);
    final wallet = _wallet(
      breakdown: [
        ShopExclusiveBreakdownEntry(merchantId: 1, merchantName: 'Corner Cafe', balance: 120, balanceInrEquivalent: 120, expiresAt: null),
        ShopExclusiveBreakdownEntry(merchantId: 2, merchantName: 'Other Shop', balance: 75, balanceInrEquivalent: 75, expiresAt: null),
      ],
    );

    await tester.pumpWidget(_wrap(SingleChildScrollView(child: MerchantCard(merchant: shop)), wallet: wallet));
    await tester.pump();
    // Universal coins (500) are the same everywhere, so they never show here.
    expect(find.text('120'), findsOneWidget);
    expect(find.text('75'), findsNothing);
    expect(find.text('coins'), findsOneWidget);

    // A fresh ProviderScope, so the empty wallet override takes effect.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_wrap(SingleChildScrollView(child: MerchantCard(merchant: shop))));
    await tester.pump();
    expect(find.text('coins'), findsNothing);
  });

  test('dialableIndianMobile accepts the common Indian formats and rejects anything else', () {
    expect(dialableIndianMobile('9876543210'), '9876543210');
    expect(dialableIndianMobile('+91 98765 43210'), '9876543210');
    expect(dialableIndianMobile('09876543210'), '9876543210');
    expect(dialableIndianMobile('+91 98765 43210 extension 00000'), isNull);
    expect(dialableIndianMobile('1234567890'), isNull);
    expect(dialableIndianMobile(null), isNull);
  });
}
