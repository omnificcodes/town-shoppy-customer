import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/networking/cursor_page.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/auth/application/auth_controller.dart';
import 'package:customer/features/auth/application/auth_state.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:customer/features/auth/data/models/customer_profile.dart';
import 'package:customer/features/merchants/application/merchant_categories_provider.dart';
import 'package:customer/features/merchants/data/models/merchant_category.dart';
import 'package:customer/features/notifications/application/unread_count_provider.dart';
import 'package:customer/features/wallet/data/models/silver_wallet_balance.dart';
import 'package:customer/features/wallet/data/models/wallet_ledger_entry.dart';
import 'package:customer/features/wallet/data/wallet_repository.dart';
import 'package:customer/features/wallet/presentation/wallet_screen.dart';

import '../../helpers/responsive_test_helper.dart';

const _longMerchant = 'The Grand Downtown Corner Cafe and Bakery Emporium';

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

/// Worst-case figures: a seven-digit balance, long shop names, and one lot
/// three days from expiry so the warning banner renders too.
class _FakeWalletRepository implements WalletRepository {
  @override
  Future<SilverWalletBalance> balance() async => SilverWalletBalance(
    balance: 1234567,
    universalBalance: 1000000,
    shopExclusiveBalance: 234567,
    shopExclusiveBreakdown: [
      ShopExclusiveBreakdownEntry(
        merchantId: 7,
        merchantName: _longMerchant,
        balance: 234000,
        balanceInrEquivalent: 23400,
        expiresAt: DateTime.now().add(const Duration(days: 3)),
      ),
      ShopExclusiveBreakdownEntry(
        merchantId: 8,
        merchantName: 'Alathur Silks',
        balance: 567,
        balanceInrEquivalent: 56.7,
        expiresAt: DateTime.now().add(const Duration(days: 90)),
      ),
    ],
    balanceInrEquivalent: 123456.7,
    updatedAt: null,
  );

  @override
  Future<CursorPage<WalletLedgerEntry>> transactions({String? cursor}) async => CursorPage(
    items: [
      WalletLedgerEntry(
        id: 1,
        direction: 'credit',
        amount: 250,
        source: 'purchase_reward',
        coinType: null,
        merchantName: null,
        balanceAfter: 1234567,
        lotExpiresAt: null,
        createdAt: DateTime(2026, 9, 1),
      ),
    ],
    nextCursor: null,
  );
}

Widget _wrap() {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(_AuthenticatedController.new),
      walletRepositoryProvider.overrideWithValue(_FakeWalletRepository()),
      unreadNotificationCountProvider.overrideWith((ref) async => 3),
      merchantCategoriesProvider.overrideWith(
        (ref) async => [
          for (var i = 1; i <= 6; i++)
            MerchantCategory(id: i, name: 'Category number $i with a long name', slug: 'c$i'),
        ],
      ),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const WalletScreen()),
  );
}

void main() {
  testWidgets('Wallet renders every section with worst-case figures without overflow at every viewport', (
    tester,
  ) async {
    await forEachViewport(
      tester,
      _wrap,
      verify: (tester, size) async {
        expect(find.text('Wallet'), findsOneWidget);
        expect(find.text('Hello, Venkataramanujachandrasekaran!'), findsOneWidget);
        expect(find.text('1234567'), findsOneWidget);
        expect(find.text('≈ ₹123456.70'), findsOneWidget);

        final page = find.byType(CustomScrollView);
        for (final text in [
          'STORE-LOCKED',
          'Store-locked coins expiring soon',
          'WHERE TO SPEND',
          'MY STORE-LOCKED COINS',
          'Alathur Silks',
          'SCAN QR TO REDEEM COINS',
          'Transaction history',
          'Bal. 1234567',
        ]) {
          await tester.dragUntilVisible(find.text(text), page, const Offset(0, -250));
          expect(find.text(text), findsOneWidget, reason: '$text should be reachable at $size');
        }
      },
    );
  });
}
