import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/auth/application/auth_controller.dart';
import 'package:customer/features/auth/application/auth_state.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:customer/features/auth/data/models/customer_profile.dart';
import 'package:customer/features/home/presentation/home_screen.dart';
import 'package:customer/features/purchases/application/recent_purchases_provider.dart';
import 'package:customer/features/purchases/data/models/purchase.dart';
import 'package:customer/features/wallet/data/models/silver_wallet_balance.dart';
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
    referralCode: 'ABC123',
    status: 'active',
  ),
);

class _AuthenticatedController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(_account);
}

class _FakeWalletRepository implements WalletRepository {
  @override
  Future<SilverWalletBalance> balance() async =>
      const SilverWalletBalance(balance: 1234567, balanceInrEquivalent: 12345.67, updatedAt: null);
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
        expect(find.text('Recent purchases'), findsOneWidget);
        expect(find.text('1234567 coins'), findsOneWidget);

        // "Redemptions" is further down than a short viewport's initial
        // render -- confirm it's actually reachable by scrolling, not just
        // present somewhere off in the cache extent.
        await tester.dragUntilVisible(find.text('Redemptions'), find.byType(ListView), const Offset(0, -200));
        expect(find.text('Redemptions'), findsOneWidget);
      },
    );
  });
}
