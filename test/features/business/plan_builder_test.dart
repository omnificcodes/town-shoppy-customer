import 'package:customer/core/networking/cursor_page.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/auth/application/auth_controller.dart';
import 'package:customer/features/auth/application/auth_state.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:customer/features/auth/data/models/merchant_profile_ref.dart';
import 'package:customer/features/business/application/business_context.dart';
import 'package:customer/features/business/data/models/business_merchant.dart';
import 'package:customer/features/business/data/models/merchant_entitlement.dart';
import 'package:customer/features/business/data/models/subscription_plan.dart';
import 'package:customer/features/business/presentation/business_more_screen.dart';
import 'package:customer/features/business/presentation/package_gate.dart';
import 'package:customer/features/home/presentation/widgets/flash_sales_strip.dart';
import 'package:customer/features/notifications/application/unread_count_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// BR-43 -- the dynamic plan: every item comes from the API's catalogue.

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

MerchantEntitlement _entitlement(Map<String, Object?> features) => MerchantEntitlement.fromJson({
  'has_package': true,
  'status': 'active',
  'plan_name': 'Free',
  'in_grace_period': false,
  'features': features,
});

void main() {
  group('entitlement', () {
    test('answers by catalogue key: switches, counts and unlimited', () {
      final e = _entitlement({'counter': false, 'products': 10, 'offers': 0, 'lucky_draw_coupons': null, 'voice_alert': true});
      expect(e.has('counter'), isFalse);
      expect(e.has('products'), isTrue);
      expect(e.limit('products'), 10);
      expect(e.has('offers'), isFalse);
      expect(e.has('lucky_draw_coupons'), isTrue); // unlimited
      expect(e.limit('lucky_draw_coupons'), isNull);
      expect(e.has('voice_alert'), isTrue);
      expect(e.has('no_such_item'), isFalse);
    });

    test('fails open with no map, and closed without a package', () {
      expect(MerchantEntitlement.failOpen.has('counter'), isTrue);
      expect(const MerchantEntitlement(hasPackage: false, status: null, planName: null, inGracePeriod: false).has('counter'), isFalse);
    });
  });

  test('a plan renders its items from the API, grouped and in order', () {
    final plan = SubscriptionPlan.fromJson({
      'id': 1,
      'code': 'plus',
      'name': 'Plus',
      'price': 299,
      'badge_label': 'Popular',
      'trial_days': 0,
      'features': {'counter_enabled': true},
      'items': [
        {'key': 'counter', 'label': 'Town Coin counter', 'group': 'counter', 'group_label': 'Counter & billing', 'type': 'toggle', 'enabled': true, 'display': 'Included'},
        {'key': 'lucky_draw_coupons', 'label': 'Lucky Draw coupons', 'group': 'counter', 'group_label': 'Counter & billing', 'type': 'count', 'enabled': true, 'value': 75, 'display': '75 / month'},
        {'key': 'flash_sale', 'label': 'Flash sale', 'group': 'marketing', 'group_label': 'Marketing', 'type': 'toggle', 'enabled': false, 'display': 'Included'},
        {'key': 'own_shop_draw', 'label': 'Own-shop draw', 'group': 'perks', 'group_label': 'Perks', 'type': 'perk', 'enabled': true, 'amount': 1500, 'display': '₹1,500.00 per draw'},
      ],
    });

    expect(plan.badgeLabel, 'Popular');
    expect(plan.includedItems.map((i) => i.key), ['counter', 'lucky_draw_coupons', 'own_shop_draw']);
    expect(plan.includedByGroup.keys, ['Counter & billing', 'Perks']);
    expect(plan.enabledFeatureLabels, ['Town Coin counter', 'Lucky Draw coupons · 75 / month', 'Own-shop draw · ₹1,500.00 per draw']);
  });

  test('the flash sale countdown reads naturally and ends', () {
    final now = DateTime(2026, 10, 10, 12);
    expect(FlashCountdown.label(now.add(const Duration(days: 1, hours: 2)), now), 'Ends in 1d 2h');
    expect(FlashCountdown.label(now.add(const Duration(hours: 2, minutes: 10)), now), 'Ends in 2h 10m');
    expect(FlashCountdown.label(now.add(const Duration(minutes: 5, seconds: 7)), now), 'Ends in 5:07');
    expect(FlashCountdown.label(now.subtract(const Duration(seconds: 1)), now), 'Ended');
    expect(FlashCountdown.label(null, now), 'Limited time');
  });

  testWidgets('a package without the counter locks the counter entries as "Not included in your plan"', (tester) async {
    tester.view.physicalSize = const Size(420, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_AuthenticatedController.new),
          isBusinessOwnerProvider.overrideWithValue(true),
          myMerchantProvider.overrideWith((ref) async => BusinessMerchant.fromJson({'id': 5, 'name': 'Kairaly Bakers', 'status': 'active'})),
          merchantEntitlementProvider.overrideWith((ref) async => _entitlement({'counter': false, 'offers': 0, 'products': 10, 'review_links': true})),
          dashboardPendingPurchasesCountProvider.overrideWith((ref) async => 0),
          dashboardPendingOfferRedemptionsProvider.overrideWith((ref) async => const CursorPage(items: [], nextCursor: null)),
          unreadNotificationCountProvider.overrideWith((ref) async => 0),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const BusinessMoreScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Direct POS, Purchases, Customers, Branches, Offers... are locked; Products and Review link are not.
    expect(find.text('Not included in your plan'), findsWidgets);
    expect(find.text('Your catalog, ordered via WhatsApp'), findsOneWidget);
    expect(find.text('QR that grows your Google reviews'), findsOneWidget);
  });

  testWidgets('the gate explains an item the plan lacks and points at plans', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isBusinessOwnerProvider.overrideWithValue(true),
          merchantEntitlementProvider.overrideWith((ref) async => _entitlement({'counter': false})),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const RequirePackage(feature: 'Direct POS', featureKey: 'counter', child: Scaffold(body: Text('Counter'))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Counter'), findsNothing);
    expect(find.text('Upgrade to unlock Direct POS'), findsOneWidget);
    expect(find.text('See plans'), findsOneWidget);
  });
}
