import 'package:customer/core/routing/app_router.dart';
import 'package:customer/core/storage/secure_storage_service.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/auth/application/auth_controller.dart';
import 'package:customer/features/auth/application/auth_state.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bug this guards against (reported 2026-09-27): "Register as a
/// merchant" used to PUSH the registration page on top of Login. Creating
/// the applicant's account mid-registration flips auth to signed-in, which
/// makes the router re-judge the current page -- and on that pass it only
/// sees the page UNDER a push. Judged as "/login", a signed-in customer
/// belongs on Home, so the router threw the registration page away with
/// the application still in flight: no success screen, no choice of app,
/// straight to the customer dashboard. Opening registration as its own
/// page (`go`) keeps it exempt from that redirect.
class _FakeStorage implements SecureStorageService {
  final Map<String, String> store = {};

  @override
  Future<void> write(String key, String value) async => store[key] = value;

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> delete(String key) async => store.remove(key);
}

Account _customerAccount() => Account.fromJson({
  'id': 1,
  'mobile_number': '+919812345600',
  'status': 'active',
  'is_super_admin': false,
  'roles': ['customer'],
  'customer_profile': {'id': 1, 'name': 'New Applicant', 'referral_code': 'NEW00001', 'status': 'active'},
});

/// Starts signed out; the test flips it to signed in, exactly as
/// `MerchantRegistrationController.submit()` does after `register()`.
class _ScriptedAuthController extends AuthController {
  @override
  AuthState build() => const AuthUnauthenticated();

  void signIn() => state = AuthAuthenticated(_customerAccount());
}

void main() {
  testWidgets('signing in mid-registration keeps the applicant on the registration page, not Home', (tester) async {
    final auth = _ScriptedAuthController();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(() => auth),
        secureStorageServiceProvider.overrideWithValue(_FakeStorage()),
      ],
    );
    addTearDown(container.dispose);

    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Signed out: the splash sends the visitor to Login, whose
    // "Register as a merchant" link is the way in.
    expect(router.state.matchedLocation, '/login');
    final link = find.text('Register as a merchant');
    await tester.ensureVisible(link);
    await tester.pump();
    await tester.tap(link, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(router.state.matchedLocation, '/register-merchant');

    // The applicant's account is created mid-registration.
    auth.signIn();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(router.state.matchedLocation, '/register-merchant');
    expect(find.text('Join Town Shoppy'), findsOneWidget);

    // The real screens fire real (failing) requests in this harness; let
    // their retry/timeout timers run out before the tree is torn down.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 2));
  });
}
