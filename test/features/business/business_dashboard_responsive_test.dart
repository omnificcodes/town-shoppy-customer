import 'package:customer/core/networking/offset_page.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/auth/application/auth_controller.dart';
import 'package:customer/features/auth/application/auth_state.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:customer/features/auth/data/models/merchant_profile_ref.dart';
import 'package:customer/features/business/application/business_context.dart';
import 'package:customer/features/business/data/models/business_merchant.dart';
import 'package:customer/features/business/data/models/merchant_entitlement.dart';
import 'package:customer/features/business/data/models/purchase_stats.dart';
import 'package:customer/features/business/presentation/business_dashboard_screen.dart';
import 'package:customer/features/notifications/application/unread_count_provider.dart';
import 'package:customer/features/purchases/data/models/purchase.dart';
import 'package:customer/features/redemptions/data/models/redemption.dart';
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

BusinessMerchant _merchant({String status = 'active'}) => BusinessMerchant.fromJson({
  'id': 5,
  'name': 'Sunrise Grocers and Provisions of Ernakulam',
  'status': status,
  'accepts_town_coin': true,
  'is_featured': false,
  'category': {'id': 1, 'name': 'Grocery & Kirana', 'slug': 'grocery-kirana'},
  'association': {
    'id': 2,
    'name': 'Ernakulam Traders',
    'slug': 'ernakulam-traders',
    'town': {'id': 3, 'name': 'Kochi', 'slug': 'kochi'},
  },
});

final _purchase = Purchase.fromJson({
  'id': 10,
  'merchant_id': 5,
  'bill_amount': 1234.5,
  'currency': 'INR',
  'status': 'recorded',
  'created_at': DateTime.now().toIso8601String(),
});

final _redemption = Redemption.fromJson({
  'id': 11,
  'bill_amount': 500,
  'coins_requested': 50,
  'status': 'initiated',
  'created_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
});

Widget _wrap({required bool hasPackage, String status = 'active', bool empty = false}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(_AuthenticatedController.new),
      myMerchantProvider.overrideWith((ref) async => _merchant(status: status)),
      merchantEntitlementProvider.overrideWith(
        (ref) async => MerchantEntitlement(
          hasPackage: hasPackage,
          status: hasPackage ? 'active' : null,
          planName: hasPackage ? 'VIP' : null,
          inGracePeriod: false,
        ),
      ),
      mySubscriptionProvider.overrideWith((ref) async => null),
      unreadNotificationCountProvider.overrideWith((ref) async => 3),
      dashboardPendingPurchasesCountProvider.overrideWith((ref) async => 2),
      dashboardAwaitingRedemptionsProvider.overrideWith(
        (ref) async => empty
            ? const OffsetPage<Redemption>(items: [], currentPage: 1, lastPage: 1, total: 0)
            : OffsetPage(items: [_redemption], currentPage: 1, lastPage: 1, total: 1),
      ),
      dashboardRecentPurchasesProvider.overrideWith((ref) async => empty ? const <Purchase>[] : [_purchase]),
      purchaseStatsProvider.overrideWith(
        (ref, range) async => PurchaseStats.fromJson({
          'range': range,
          'from': '2026-08-15',
          'total': 42,
          'trend': [
            for (var i = 0; i < 30; i++) {'date': '2026-08-${(i + 1).toString().padLeft(2, '0')}', 'count': i % 5},
          ],
          'breakdown_by_branch': [
            {'branch_id': 1, 'branch_name': 'Main', 'count': 30},
            {'branch_id': 2, 'branch_name': 'Annex', 'count': 12},
          ],
        }),
      ),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const BusinessDashboardScreen()),
  );
}

void main() {
  testWidgets('dashboard renders every section without overflow at each viewport', (tester) async {
    await forEachViewport(
      tester,
      () => _wrap(hasPackage: true),
      verify: (tester, size) async {
        expect(find.textContaining('Sunrise Grocers'), findsOneWidget);
        expect(find.text('BUSINESS'), findsOneWidget);
        expect(find.text('View profile'), findsOneWidget);
        expect(find.text('Please select a package'), findsNothing);

        // Below the fold on phone viewports -- the sliver list builds lazily.
        final page = find.byType(CustomScrollView);
        for (final text in ['Pending purchases', 'Quick Actions', '42', 'Recent Activity']) {
          await tester.dragUntilVisible(find.text(text), page, const Offset(0, -300));
          expect(find.text(text), findsOneWidget, reason: '$text should be reachable at $size');
        }
        await tester.dragUntilVisible(find.textContaining('1234.50'), page, const Offset(0, -300));
        expect(find.textContaining('1234.50'), findsOneWidget);
        expect(find.textContaining('500.00'), findsOneWidget);
      },
    );
  });

  testWidgets('shows the select-a-package banner when the shop has no package', (tester) async {
    await tester.pumpWidget(_wrap(hasPackage: false));
    await tester.pumpAndSettle();

    expect(find.text('Please select a package'), findsOneWidget);
    expect(find.text('Choose a package'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a shop under review says so, and an empty feed shows its empty state', (tester) async {
    await tester.pumpWidget(_wrap(hasPackage: true, status: 'pending', empty: true));
    await tester.pumpAndSettle();

    expect(find.text('Pending approval'), findsOneWidget);
    expect(find.textContaining('under review'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('No recent activity'),
      find.byType(CustomScrollView),
      const Offset(0, -300),
    );
    expect(find.text('No recent activity'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
