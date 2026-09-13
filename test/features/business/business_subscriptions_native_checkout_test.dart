import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/auth/application/auth_controller.dart';
import 'package:customer/features/auth/application/auth_state.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:customer/features/auth/data/models/merchant_profile_ref.dart';
import 'package:customer/features/business/application/business_context.dart';
import 'package:customer/features/business/application/subscription_checkout_controller.dart';
import 'package:customer/features/business/data/models/merchant_entitlement.dart';
import 'package:customer/features/business/data/models/merchant_subscription.dart';
import 'package:customer/features/business/data/models/subscription_plan.dart';
import 'package:customer/features/business/presentation/business_subscriptions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _owner = Account(
  id: 1,
  mobileNumber: '+919990003001',
  status: 'active',
  isSuperAdmin: false,
  roles: ['merchant_owner'],
  customerProfile: null,
  merchantOwnerProfiles: [MerchantProfileRef(id: 1, merchantId: 5, status: 'active')],
);

class _OwnerAuth extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(_owner);
}

SubscriptionPlan _plan(int id, String name, double price) => SubscriptionPlan(
      id: id,
      code: name.toLowerCase(),
      name: name,
      price: price,
      currency: 'INR',
      billingCycle: 'monthly',
      couponQuotaMonthly: 100,
      features: const {},
      status: 'active',
    );

final _starter = _plan(1, 'Starter Pack', 200);
final _growth = _plan(2, 'Growth Pack', 300);
final _mega = _plan(3, 'Mega Pack', 500);

MerchantSubscription _subscriptionFor(SubscriptionPlan plan, {String status = 'active'}) => MerchantSubscription(
      id: 10,
      plan: plan,
      status: status,
      currentPeriodStart: DateTime(2026, 9, 10),
      currentPeriodEnd: DateTime(2026, 10, 10),
      couponQuotaUsed: 1,
      couponQuotaRemaining: 99,
      pendingPlan: null,
      pendingPlanChangeAt: null,
      cancelledAt: null,
    );

Widget _app({required MerchantSubscription? subscription, bool nativeCheckout = true}) => ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_OwnerAuth.new),
        nativeCheckoutAvailableProvider.overrideWithValue(nativeCheckout),
        subscriptionPlansProvider.overrideWith((ref) async => [_starter, _growth, _mega]),
        mySubscriptionProvider.overrideWith((ref) async => subscription),
        merchantEntitlementProvider.overrideWith(
          (ref) async => MerchantEntitlement(hasPackage: subscription?.grantsFullService ?? false, status: subscription?.status, planName: subscription?.plan?.name, inGracePeriod: false),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const BusinessSubscriptionsScreen()),
    );

void main() {
  group('BusinessSubscriptionsScreen native checkout (Android)', () {
    testWidgets('a merchant with no subscription sees a Subscribe button on every plan, no web hand-off', (tester) async {
      await tester.pumpWidget(_app(subscription: null));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(find.text('Mega Pack'), find.byType(ListView), const Offset(0, -300));

      expect(find.text('Subscribe'), findsNWidgets(3));
      expect(find.text('Subscribe on the web'), findsNothing);
      expect(find.text('Change plan on the web'), findsNothing);

      await tester.dragUntilVisible(find.textContaining('processed securely by Razorpay'), find.byType(ListView), const Offset(0, -300));
      expect(find.textContaining('processed securely by Razorpay'), findsOneWidget);
    });

    testWidgets('the active plan shows Current with no button; a pricier plan shows Upgrade-style Subscribe', (tester) async {
      await tester.pumpWidget(_app(subscription: _subscriptionFor(_growth)));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(find.text('Mega Pack'), find.byType(ListView), const Offset(0, -300));

      expect(find.text('Current'), findsOneWidget);
      // Growth Pack (current) has no action button of its own; only Mega
      // Pack (pricier) gets a Subscribe button on this screen.
      expect(find.text('Subscribe'), findsOneWidget);
      expect(find.textContaining('Downgrade from the Subscriptions page on the web.'), findsOneWidget); // Starter Pack
    });

    testWidgets('a stalled (pending) subscription shows Payment pending and Retry payment, not Current', (tester) async {
      await tester.pumpWidget(_app(subscription: _subscriptionFor(_growth, status: 'pending')));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(find.text('Mega Pack'), find.byType(ListView), const Offset(0, -300));

      expect(find.text('Current'), findsNothing);
      expect(find.text('Payment pending'), findsOneWidget);
      expect(find.text('Retry payment'), findsOneWidget);
      // Starter and Mega are unaffected by another plan's stalled payment.
      expect(find.text('Subscribe'), findsNWidgets(2));
    });

    testWidgets('on iOS/web (native checkout unavailable) the plain web hand-off button is used instead', (tester) async {
      await tester.pumpWidget(_app(subscription: null, nativeCheckout: false));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(find.textContaining('Subscribe on the web'), find.byType(ListView), const Offset(0, -300));

      expect(find.text('Subscribe'), findsNothing);
      // Env.merchantWebUrl is empty in tests, so the info box appears rather
      // than a dead link -- either way, no native per-plan button renders.
      expect(find.textContaining('Subscribe on the web'), findsWidgets);
    });
  });
}
