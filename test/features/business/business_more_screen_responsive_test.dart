import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/auth/application/auth_controller.dart';
import 'package:customer/features/auth/application/auth_state.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:customer/features/auth/data/models/merchant_profile_ref.dart';
import 'package:customer/features/business/application/business_context.dart';
import 'package:customer/features/business/data/models/business_merchant.dart';
import 'package:customer/features/business/data/models/merchant_entitlement.dart';
import 'package:customer/features/business/presentation/business_more_screen.dart';
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

Widget _wrap({bool isOwner = true, bool hasPackage = true}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(_AuthenticatedController.new),
      isBusinessOwnerProvider.overrideWithValue(isOwner),
      myMerchantProvider.overrideWith(
        (ref) async => BusinessMerchant.fromJson({
          'id': 5,
          'name': 'Sunrise Grocers and Provisions of Ernakulam',
          'status': 'active',
        }),
      ),
      merchantEntitlementProvider.overrideWith(
        (ref) async => MerchantEntitlement(
          hasPackage: hasPackage,
          status: hasPackage ? 'active' : null,
          planName: hasPackage ? 'VIP' : null,
          inGracePeriod: false,
        ),
      ),
      dashboardPendingPurchasesCountProvider.overrideWith((ref) async => 2),
      unreadNotificationCountProvider.overrideWith((ref) async => 3),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const BusinessMoreScreen()),
  );
}

void main() {
  testWidgets('More renders the header, the signed-in card and every owner group without overflow', (tester) async {
    await forEachViewport(
      tester,
      _wrap,
      verify: (tester, size) async {
        expect(find.text('More'), findsOneWidget);
        expect(find.textContaining('Sunrise Grocers'), findsOneWidget);
        expect(find.text('SIGNED IN AS'), findsOneWidget);
        expect(find.text('+91 99900 03001'), findsOneWidget);
        expect(find.text('Switch'), findsOneWidget);
        // Branches, Customers, Purchases, Direct POS, Offers, Products and
        // Offer redemptions -- no separate Redemptions any more.
        expect(find.text('7 services'), findsOneWidget);
        expect(find.text('2 pending'), findsOneWidget);

        final page = find.byType(CustomScrollView);
        await tester.dragUntilVisible(find.text('Sign out'), page, const Offset(0, -300));
        expect(find.text('Sponsored prizes'), findsOneWidget);
        expect(find.text('Security'), findsOneWidget);
        expect(find.text('Help & merchant support'), findsOneWidget);
        expect(find.text('Sign out'), findsOneWidget);
      },
    );
  });

  testWidgets('staff without a package see locked entries, no owner-only rows and no pending badge', (tester) async {
    await forEachViewport(
      tester,
      () => _wrap(isOwner: false, hasPackage: false),
      verify: (tester, size) async {
        expect(find.text('Branches'), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline_rounded), findsWidgets);
        expect(find.text('2 pending'), findsNothing);
        expect(find.textContaining('Staff'), findsOneWidget);

        final page = find.byType(CustomScrollView);
        await tester.dragUntilVisible(find.text('Sign out'), page, const Offset(0, -300));
        expect(find.text('Sponsored prizes'), findsNothing);
        expect(find.text('Payments'), findsNothing);
      },
    );
  });

  testWidgets('Purchases is listed and Redemptions is not, for owners and staff alike', (tester) async {
    for (final isOwner in [true, false]) {
      // Tall enough to build every group, so "not found" means "not there".
      tester.view.physicalSize = const Size(420, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrap(isOwner: isOwner));
      await tester.pumpAndSettle();

      expect(find.text('Purchases'), findsOneWidget, reason: 'isOwner: $isOwner');
      expect(find.text('Redemptions'), findsNothing, reason: 'isOwner: $isOwner');
      // A different thing -- customers claiming offers -- and it stays.
      expect(find.text('Offer redemptions'), findsOneWidget, reason: 'isOwner: $isOwner');
    }
  });
}
