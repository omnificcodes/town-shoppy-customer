import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/merchants/data/models/association_ref.dart';
import 'package:customer/features/merchants/data/models/merchant.dart';
import 'package:customer/features/merchants/data/models/merchant_category.dart';
import 'package:customer/features/merchants/data/models/town_ref.dart';
import 'package:customer/features/merchants/presentation/merchant_card.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));

void main() {
  testWidgets('shows the merchant name, category, and town', (tester) async {
    const merchant = Merchant(
      id: 1,
      name: 'Corner Cafe',
      description: null,
      logoUrl: null,
      websiteUrl: null,
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
}
