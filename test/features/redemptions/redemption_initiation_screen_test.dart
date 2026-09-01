import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/networking/cursor_page.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/merchants/application/merchant_branches_provider.dart';
import 'package:customer/features/merchants/application/merchant_detail_provider.dart';
import 'package:customer/features/merchants/data/models/association_ref.dart';
import 'package:customer/features/merchants/data/models/merchant.dart';
import 'package:customer/features/merchants/data/models/merchant_branch_ref.dart';
import 'package:customer/features/redemptions/presentation/redemption_initiation_screen.dart';
import 'package:customer/features/wallet/data/models/silver_wallet_balance.dart';
import 'package:customer/features/wallet/data/models/wallet_ledger_entry.dart';
import 'package:customer/features/wallet/data/wallet_repository.dart';

import '../../helpers/responsive_test_helper.dart';

class _FakeWalletRepository implements WalletRepository {
  @override
  Future<SilverWalletBalance> balance() async =>
      const SilverWalletBalance(balance: 800, balanceInrEquivalent: 8, updatedAt: null);

  @override
  Future<CursorPage<WalletLedgerEntry>> transactions({String? cursor}) async => throw UnimplementedError();
}

Merchant _merchant({required bool eligible}) {
  return Merchant(
    id: 1,
    name: 'Corner Cafe',
    description: null,
    logoUrl: null,
    websiteUrl: null,
    socialLinks: null,
    discountRate: eligible ? 5 : null,
    acceptsTownCoin: eligible,
    category: null,
    association: const AssociationRef(id: 1, name: 'Downtown Association', slug: 'downtown', town: null),
    branch: null,
  );
}

const _singleBranch = [
  MerchantBranchRef(
    id: 7,
    name: 'Main Branch',
    isPrimary: true,
    addressLine: 'MG Road',
    locality: null,
    city: 'Springfield',
    state: null,
    postalCode: null,
    country: null,
    latitude: 1.0,
    longitude: 2.0,
    distanceKm: null,
  ),
];

const _twoBranches = [
  MerchantBranchRef(
    id: 7,
    name: 'Main Street',
    isPrimary: true,
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
  MerchantBranchRef(
    id: 8,
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

Widget _wrap(Merchant merchant, List<MerchantBranchRef> branches) {
  return ProviderScope(
    overrides: [
      merchantDetailProvider(merchant.id).overrideWith((ref) async => merchant),
      merchantBranchesProvider(merchant.id).overrideWith((ref) async => branches),
      walletRepositoryProvider.overrideWithValue(_FakeWalletRepository()),
    ],
    child: MaterialApp(theme: AppTheme.light, home: RedemptionInitiationScreen(merchantId: merchant.id)),
  );
}

void main() {
  group('RedemptionInitiationScreen', () {
    testWidgets('a merchant that does not accept Town Coin shows the not-available empty state', (tester) async {
      await tester.pumpWidget(_wrap(_merchant(eligible: false), _singleBranch));
      await tester.pumpAndSettle();

      expect(find.text('Redemption not available'), findsOneWidget);
      expect(find.text('Submit'), findsNothing);
    });

    testWidgets('a merchant with exactly one branch auto-selects it and enables submit once an amount is entered', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_merchant(eligible: true), _singleBranch));
      await tester.pumpAndSettle();

      expect(find.text('Branch'), findsOneWidget);
      expect(find.text('Main Branch'), findsOneWidget);

      final submitButtonFinder = find.widgetWithText(ElevatedButton, 'Submit');
      expect(tester.widget<ElevatedButton>(submitButtonFinder).onPressed, isNull);

      await tester.enterText(find.widgetWithText(TextField, 'Bill amount'), '500');
      await tester.pumpAndSettle();

      expect(tester.widget<ElevatedButton>(submitButtonFinder).onPressed, isNotNull);
      expect(find.text('Review'), findsOneWidget);
      expect(find.text('₹500.00'), findsOneWidget);
    });

    testWidgets('a merchant with multiple branches requires an explicit tap before Review appears', (tester) async {
      await tester.pumpWidget(_wrap(_merchant(eligible: true), _twoBranches));
      await tester.pumpAndSettle();

      expect(find.text('Select a branch'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Bill amount'), '500');
      await tester.pumpAndSettle();

      // No branch tapped yet — Review must not appear.
      expect(find.text('Review'), findsNothing);

      await tester.tap(find.text('City Centre'));
      await tester.pumpAndSettle();

      expect(find.text('Review'), findsOneWidget);
      expect(find.text('City Centre'), findsWidgets);
    });

    testWidgets('renders a long merchant name and full review row without overflow at every mandated viewport', (
      tester,
    ) async {
      final merchant = Merchant(
        id: 1,
        name: 'The Grand Downtown Corner Cafe, Bakery, and Artisanal Coffee Roastery Emporium',
        description: null,
        logoUrl: null,
        websiteUrl: null,
        socialLinks: null,
        discountRate: 12.5,
        acceptsTownCoin: true,
        category: null,
        association: const AssociationRef(id: 1, name: 'Downtown Association', slug: 'downtown', town: null),
        branch: null,
      );

      await forEachViewport(
        tester,
        () => _wrap(merchant, _singleBranch),
        verify: (tester, size) async {
          expect(find.textContaining('The Grand Downtown'), findsWidgets);
          expect(find.text('Main Branch'), findsOneWidget);

          await tester.enterText(find.widgetWithText(TextField, 'Bill amount'), '999999.99');
          await tester.pumpAndSettle();

          expect(find.text('Review'), findsOneWidget);
          expect(find.text('₹999999.99'), findsWidgets);
          expect(tester.takeException(), isNull);
        },
      );
    });
  });
}
