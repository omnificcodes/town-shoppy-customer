import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/networking/cursor_page.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/auth/application/auth_controller.dart';
import 'package:customer/features/auth/application/auth_state.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:customer/features/auth/data/models/customer_profile.dart';
import 'package:customer/features/home/application/home_location_controller.dart';
import 'package:customer/features/home/presentation/home_screen.dart';
import 'package:customer/features/merchants/application/featured_merchants_provider.dart';
import 'package:customer/features/merchants/application/merchant_categories_provider.dart';
import 'package:customer/features/notifications/application/unread_count_provider.dart';
import 'package:customer/features/offers/application/trending_offers_provider.dart';
import 'package:customer/features/purchases/application/recent_purchases_provider.dart';
import 'package:customer/features/purchases/data/models/purchase.dart';
import 'package:customer/features/wallet/data/models/silver_wallet_balance.dart';
import 'package:customer/features/wallet/data/models/wallet_ledger_entry.dart';
import 'package:customer/features/wallet/data/wallet_repository.dart';

import '../../helpers/responsive_test_helper.dart';

/// A long display name is the realistic worst case Home's greeting has to
/// survive -- the backend enforces no length cap on `CustomerProfile.name`.
const _account = Account(
  id: 1,
  mobileNumber: '9990003001',
  status: 'active',
  isSuperAdmin: false,
  roles: ['customer'],
  customerProfile: CustomerProfile(
    id: 1,
    name: 'Venkataramanujachandrasekaran Padmanabhaswamy Iyengar',
    dateOfBirth: null,
    anniversaryDate: null,
    socialLinks: null,
    referralCode: 'ABC123',
    status: 'active',
  ),
);

class _AuthenticatedController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(_account);
}

class _FakeHomeLocationController extends HomeLocationController {
  @override
  Future<HomeLocationState> build() async => const HomeLocationUnavailable();
}

class _FakeWalletRepository implements WalletRepository {
  @override
  Future<SilverWalletBalance> balance() async =>
      const SilverWalletBalance(
        balance: 1234567,
        universalBalance: 1234567,
        shopExclusiveBalance: 0,
        shopExclusiveBreakdown: [],
        balanceInrEquivalent: 12345.67,
        updatedAt: null,
      );

  @override
  Future<CursorPage<WalletLedgerEntry>> transactions({String? cursor}) async => throw UnimplementedError();
}

Purchase _purchase({required String merchantName}) {
  return Purchase(
    id: 1,
    merchantId: 1,
    merchant: PurchaseMerchantRef(id: 1, name: merchantName),
    branch: null,
    billAmount: 999999.99,
    currency: 'INR',
    billReference: null,
    coinsAwarded: 5000,
    couponsIssued: null,
    status: 'recorded',
    reviewedAt: null,
    rejectionReason: null,
    createdAt: DateTime(2026, 1, 1),
  );
}

Widget _wrap() {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(_AuthenticatedController.new),
      walletRepositoryProvider.overrideWithValue(_FakeWalletRepository()),
      recentPurchasesProvider.overrideWith(
        (ref) async => [_purchase(merchantName: 'The Grand Downtown Corner Cafe and Bakery Emporium')],
      ),
      homeLocationControllerProvider.overrideWith(_FakeHomeLocationController.new),
      merchantCategoriesProvider.overrideWith((ref) async => []),
      featuredMerchantsProvider.overrideWith((ref) async => []),
      trendingOffersProvider.overrideWith((ref) async => []),
      unreadNotificationCountProvider.overrideWith((ref) async => 0),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
  );
}

void main() {
  testWidgets('HomeScreen renders without overflow at every mandated viewport, even with a long name/merchant/amount', (
    tester,
  ) async {
    await forEachViewport(
      tester,
      _wrap,
      verify: (tester, size) async {
        expect(find.textContaining('Hi,'), findsOneWidget);
        expect(find.text('Discover merchants'), findsOneWidget);
        expect(find.text('Browse by category'), findsOneWidget);
        expect(find.text('1234567 coins'), findsOneWidget);

        // Featured businesses/trending offers/recent purchases/Redemptions
        // all sit further down than a short viewport's initial render --
        // confirm each is actually reachable by scrolling, not just present
        // somewhere off in the cache extent.
        await tester.dragUntilVisible(find.text('Recent purchases'), find.byType(ListView), const Offset(0, -200));
        expect(find.text('Recent purchases'), findsOneWidget);

        await tester.dragUntilVisible(find.text('Redemption history'), find.byType(ListView), const Offset(0, -200));
        expect(find.text('Redemption history'), findsOneWidget);
      },
    );
  });
}
