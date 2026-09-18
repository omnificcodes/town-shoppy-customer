import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/favorites/data/favorites_repository.dart';
import 'package:customer/features/merchants/data/models/association_ref.dart';
import 'package:customer/features/merchants/data/models/merchant.dart';
import 'package:customer/features/merchants/data/models/merchant_category.dart';
import 'package:customer/features/merchants/data/models/town_ref.dart';
import 'package:customer/features/merchants/presentation/merchant_card.dart';

import '../../helpers/fake_favorites_repository.dart';

// MerchantCard renders a FavoriteButton, which reads the saved-id set.
Widget _wrap(Widget child, {FakeFavoritesRepository? favorites}) => ProviderScope(
  overrides: [favoritesRepositoryProvider.overrideWithValue(favorites ?? FakeFavoritesRepository())],
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

  test('dialableIndianMobile accepts the common Indian formats and rejects anything else', () {
    expect(dialableIndianMobile('9876543210'), '9876543210');
    expect(dialableIndianMobile('+91 98765 43210'), '9876543210');
    expect(dialableIndianMobile('09876543210'), '9876543210');
    expect(dialableIndianMobile('+91 98765 43210 extension 00000'), isNull);
    expect(dialableIndianMobile('1234567890'), isNull);
    expect(dialableIndianMobile(null), isNull);
  });
}
