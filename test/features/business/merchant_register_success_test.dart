import 'package:customer/features/auth/application/auth_controller.dart';
import 'package:customer/features/auth/application/auth_state.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:customer/features/business/application/merchant_registration_controller.dart';
import 'package:customer/features/business/data/models/business_merchant.dart';
import 'package:customer/features/business/presentation/business_routes.dart';
import 'package:customer/features/business/presentation/merchant_register_screen.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The bug this whole file guards against: `MerchantRegistrationController
/// .submit()` refreshes `/auth/me` once, right after the merchant is
/// created, so the account in memory picks up the new merchant profile
/// before "Go to dashboard" appears. If that ONE refresh loses a flaky
/// mobile connection, the account stays stale -- `hasMerchantAccess` reads
/// false -- and the router, which has no way to know better, sends "Go to
/// dashboard" straight to the Customer Home it shows any other non-merchant
/// account. No error, no explanation, just the wrong screen. `_SuccessView`
/// must retry the refresh itself before trusting the stale account.
Account _account({required bool hasMerchantAccess}) => Account.fromJson({
  'id': 1,
  'mobile_number': '+919812345600',
  'status': 'active',
  'is_super_admin': false,
  'roles': ['customer', if (hasMerchantAccess) 'merchant_owner'],
  'customer_profile': {'id': 1, 'name': 'Claude Owner', 'referral_code': 'OWNER001', 'status': 'active'},
  if (hasMerchantAccess)
    'merchant_owner_profiles': [
      {'id': 1, 'merchant_id': 9, 'status': 'active'},
    ],
});

final _registered = BusinessMerchant.fromJson({
  'id': 9,
  'name': 'Claude Test Bakery',
  'status': 'pending',
  'accepts_town_coin': false,
  'is_featured': false,
});

/// Starts without merchant access (mirrors a `refreshAccount()` in
/// `submit()` that already silently lost the race) and scripts what each
/// subsequent [refreshAccount] call returns -- exactly what `_SuccessView`
/// retries against.
class _ScriptedAuthController extends AuthController {
  _ScriptedAuthController(this._responses, {this.startsWithMerchantAccess = false});

  final List<bool> _responses;
  final bool startsWithMerchantAccess;
  int refreshCallCount = 0;

  @override
  AuthState build() => AuthAuthenticated(_account(hasMerchantAccess: startsWithMerchantAccess));

  @override
  Future<bool> refreshAccount() async {
    refreshCallCount++;
    final ok = _responses.isNotEmpty ? _responses.removeAt(0) : false;
    if (ok) state = AuthAuthenticated(_account(hasMerchantAccess: true));
    return ok;
  }
}

/// `build()` returns the post-submit state directly -- the form itself is
/// not what this file is testing.
class _AlreadyRegisteredController extends MerchantRegistrationController {
  @override
  MerchantRegistrationState build() => MerchantRegistrationState(registered: _registered);
}

Future<void> _pump(WidgetTester tester, {required List<bool> refreshResponses}) async {
  final authController = _ScriptedAuthController(refreshResponses);
  final router = GoRouter(
    initialLocation: '/register-merchant',
    routes: [
      GoRoute(path: '/register-merchant', builder: (context, state) => const MerchantRegisterScreen()),
      GoRoute(
        path: BusinessRoutes.root,
        builder: (context, state) => const Scaffold(body: Text('Business dashboard')),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('Customer home')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => authController),
        merchantRegistrationControllerProvider.overrideWith(_AlreadyRegisteredController.new),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a lost first refresh is retried, and "Go to dashboard" still lands on Business', (tester) async {
    // The submit()-time refresh already failed (build() starts without
    // merchant access); the tap-time retry succeeds on its first try.
    await _pump(tester, refreshResponses: [true]);

    expect(find.text('Application submitted'), findsOneWidget);

    await tester.tap(find.text('Go to dashboard'));
    await tester.pump(); // enter the loading state
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Business dashboard'), findsOneWidget);
    expect(find.text('Customer home'), findsNothing);
  });

  testWidgets('an already-fresh account navigates straight through with no retry needed', (tester) async {
    // build() starts WITH merchant access this time -- the ordinary case,
    // where submit()'s own refresh already succeeded.
    final authController = _ScriptedAuthController([], startsWithMerchantAccess: true);
    final router = GoRouter(
      initialLocation: '/register-merchant',
      routes: [
        GoRoute(path: '/register-merchant', builder: (context, state) => const MerchantRegisterScreen()),
        GoRoute(
          path: BusinessRoutes.root,
          builder: (context, state) => const Scaffold(body: Text('Business dashboard')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => authController),
          merchantRegistrationControllerProvider.overrideWith(_AlreadyRegisteredController.new),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Go to dashboard'));
    await tester.pumpAndSettle();

    expect(find.text('Business dashboard'), findsOneWidget);
    // The fast path: already-fresh access skips the network call entirely.
    expect(authController.refreshCallCount, 0);
  });

  testWidgets('every retry failing shows a clear, recoverable error instead of navigating anywhere', (tester) async {
    await _pump(tester, refreshResponses: [false, false, false]);

    await tester.tap(find.text('Go to dashboard'));
    await tester.pumpAndSettle();

    expect(find.textContaining("couldn't confirm your dashboard access"), findsOneWidget);
    expect(find.text('Business dashboard'), findsNothing);
    expect(find.text('Customer home'), findsNothing);
    // Still on the success screen, and still offered the same action.
    expect(find.text('Go to dashboard'), findsOneWidget);
  });

  testWidgets('tapping again after a failure can still recover', (tester) async {
    await _pump(tester, refreshResponses: [false, false, false, true]);

    await tester.tap(find.text('Go to dashboard'));
    await tester.pumpAndSettle();
    expect(find.textContaining("couldn't confirm your dashboard access"), findsOneWidget);

    await tester.tap(find.text('Go to dashboard'));
    await tester.pumpAndSettle();

    expect(find.text('Business dashboard'), findsOneWidget);
  });
}
