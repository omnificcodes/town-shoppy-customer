import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/merchants/application/merchant_branches_provider.dart';
import 'package:customer/features/merchants/application/merchant_detail_provider.dart';
import 'package:customer/features/merchants/data/models/association_ref.dart';
import 'package:customer/features/merchants/data/models/merchant.dart';
import 'package:customer/features/merchants/data/models/merchant_branch_ref.dart';
import 'package:customer/features/merchants/data/models/merchant_category.dart';
import 'package:customer/features/merchants/data/models/town_ref.dart';
import 'package:customer/features/merchants/presentation/merchant_detail_screen.dart';

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
    distanceKm: null,
  ),
];

Widget _wrap() {
  return ProviderScope(
    overrides: [
      merchantDetailProvider(1).overrideWith((ref) async => _merchant),
      merchantBranchesProvider(1).overrideWith((ref) async => _branches),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const MerchantDetailScreen(merchantId: 1)),
  );
}

void main() {
  testWidgets(
    'MerchantDetailScreen renders a long name/description/website/branch-address without overflow at every viewport',
    (tester) async {
      await forEachViewport(
        tester,
        _wrap,
        verify: (tester, size) async {
          expect(find.textContaining('The Grand Downtown'), findsWidgets);
          expect(find.text('Redeem Town Coin'), findsOneWidget);

          // "Branches"/"Website" sit further down the ListView than a short
          // viewport's initial render -- confirm they're actually reachable
          // by scrolling, not just present somewhere off in the cache extent.
          await tester.dragUntilVisible(find.text('Website'), find.byType(ListView), const Offset(0, -300));

          expect(find.text('About'), findsOneWidget);
          expect(find.text('Branches'), findsOneWidget);
          expect(find.text('Main Street Flagship Location'), findsOneWidget);
          expect(find.text('Primary'), findsOneWidget);
          expect(find.text('Website'), findsOneWidget);
        },
      );
    },
  );
}
