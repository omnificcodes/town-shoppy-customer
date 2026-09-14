import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/networking/cursor_page.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/auth/application/auth_controller.dart';
import 'package:customer/features/auth/application/auth_state.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:customer/features/auth/data/models/customer_profile.dart';
import 'package:customer/features/coupons/application/coupons_list_controller.dart';
import 'package:customer/features/profile/presentation/profile_screen.dart';
import 'package:customer/features/wallet/data/models/silver_wallet_balance.dart';
import 'package:customer/features/wallet/data/models/wallet_ledger_entry.dart';
import 'package:customer/features/wallet/data/wallet_repository.dart';

import '../../helpers/responsive_test_helper.dart';

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
      authControllerProvider.overrideWith(_AuthenticatedController.new),
      walletRepositoryProvider.overrideWithValue(_FakeWalletRepository()),
      couponCountsProvider.overrideWith((ref) async => const CouponCounts(active: 98765, won: 3, expired: 12)),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const ProfileScreen()),
  );
}

void main() {
  testWidgets('ProfileScreen renders a long name and large balances without overflow at every mandated viewport', (
    tester,
  ) async {
    await forEachViewport(
      tester,
      _wrap,
      verify: (tester, size) async {
        expect(find.text('My Profile'), findsOneWidget);
        expect(find.textContaining('Venkataramanujachandrasekaran'), findsOneWidget);
        expect(find.text('+91 99900 03001'), findsOneWidget);
        expect(find.text('1234567'), findsOneWidget);
        expect(find.text('98765'), findsOneWidget);

        // ListView builds lazily, so every lower section is scrolled into view.
        final page = find.byType(ListView).first;
        for (final label in ['Purchases', 'Redemptions', 'Referrals', 'Register your business', 'Account status', 'Sign out']) {
          await tester.dragUntilVisible(find.text(label), page, const Offset(0, -200));
          expect(find.text(label), findsOneWidget, reason: '$label should be reachable at $size');
        }
      },
    );
  });
}
