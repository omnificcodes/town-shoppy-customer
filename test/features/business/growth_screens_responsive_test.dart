import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/auth/application/auth_controller.dart';
import 'package:customer/features/auth/application/auth_state.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:customer/features/auth/data/models/merchant_profile_ref.dart';
import 'package:customer/features/business/application/business_offers_controller.dart';
import 'package:customer/features/business/application/merchant_wallet_controller.dart';
import 'package:customer/features/business/data/models/business_offer.dart';
import 'package:customer/features/business/data/models/merchant_wallet.dart';
import 'package:customer/features/business/presentation/offers/business_offers_screen.dart';
import 'package:customer/features/business/presentation/wallet/merchant_wallet_screen.dart';
import 'package:customer/features/notifications/application/unread_count_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/responsive_test_helper.dart';

const _account = Account(
  id: 1,
  mobileNumber: '+919990003001',
  status: 'active',
  isSuperAdmin: false,
  roles: ['merchant_owner'],
  customerProfile: null,
  merchantOwnerProfiles: [MerchantProfileRef(id: 1, merchantId: 5, status: 'active')],
);

class _AuthenticatedController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(_account);
}

class _FakeOffersController extends BusinessOffersController {
  @override
  Future<BusinessOffersState> build() async => BusinessOffersState(
        items: [
          BusinessOffer.fromJson({
            'id': 1,
            'title': 'A very long offer title that should wrap onto a second line without overflowing the card',
            'offer_type': 'announcement',
            'coin_discount_rate': 12.5,
            'is_coin_redeemable': true,
            'applicable_item': 'Any large pizza with extra toppings',
            'starts_at': '2026-09-01T00:00:00Z',
            'ends_at': '2026-12-31T00:00:00Z',
            'status': 'active',
            'branch': {'id': 2, 'name': 'Edappally Branch'},
          }),
          BusinessOffer.fromJson({'id': 2, 'title': 'Draft', 'offer_type': 'announcement', 'is_coin_redeemable': false, 'status': 'draft'}),
        ],
        currentPage: 1,
        lastPage: 1,
        counts: const OfferStatusCounts(draft: 1, active: 1, expired: 0),
      );
}

class _EmptyOffersController extends BusinessOffersController {
  @override
  Future<BusinessOffersState> build() async =>
      const BusinessOffersState(items: [], currentPage: 1, lastPage: 1, counts: OfferStatusCounts.empty);
}

Widget _offers({bool empty = false}) => ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_AuthenticatedController.new),
        businessOffersControllerProvider.overrideWith(empty ? _EmptyOffersController.new : _FakeOffersController.new),
        unreadNotificationCountProvider.overrideWith((ref) async => 3),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const BusinessOffersScreen()),
    );

Widget _wallet() => ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_AuthenticatedController.new),
        merchantWalletProvider.overrideWith((ref) async => MerchantWallet.fromJson({'blue_balance': 1234567, 'red_balance': 89, 'updated_at': '2026-09-13T00:00:00Z'})),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const MerchantWalletScreen()),
    );

void main() {
  testWidgets('offers list renders cards and counts without overflow at every viewport', (tester) async {
    await forEachViewport(
      tester,
      _offers,
      verify: (tester, size) async {
        expect(find.textContaining('A very long offer title'), findsOneWidget);
        expect(find.text('12.5% Town Coin'), findsOneWidget);
        expect(find.text('New offer'), findsOneWidget);
        expect(find.text('Offers'), findsOneWidget);
        expect(find.text('LIVE NOW'), findsOneWidget);
        expect(find.text('NOT PUBLISHED'), findsOneWidget);
        expect(find.text('Scheduled'), findsWidgets);
      },
    );
  });

  testWidgets('an empty offers list shows the empty state with New offer for owners', (tester) async {
    await forEachViewport(
      tester,
      () => _offers(empty: true),
      verify: (tester, size) async {
        expect(find.text('No offers yet'), findsOneWidget);
        expect(find.text('ALL CREATED'), findsOneWidget);
        // Only the empty-state button; the floating one steps aside.
        expect(find.text('New offer'), findsOneWidget);
      },
    );
  });

  testWidgets('wallet renders both balances and the spend button without overflow', (tester) async {
    await forEachViewport(
      tester,
      _wallet,
      verify: (tester, size) async {
        expect(find.text('1234567'), findsOneWidget);
        expect(find.text('89'), findsOneWidget);
        expect(find.text('Spend Blue Coin at another merchant'), findsOneWidget);
      },
    );
  });
}
