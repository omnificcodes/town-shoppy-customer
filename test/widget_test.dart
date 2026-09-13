import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/auth/data/auth_repository.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:customer/features/auth/data/models/otp_request_result.dart';
import 'package:customer/features/auth/presentation/login_screen.dart';

/// Never touches the network — every call resolves immediately with a
/// canned response, so widget tests exercise real UI/state wiring without
/// depending on a live backend (see the phase brief's testing section: use
/// mocked APIs for widget tests, the real backend for integration tests).
class FakeAuthRepository implements AuthRepository {
  int loginCallCount = 0;
  String? lastMobileNumber;
  String? lastPassword;

  @override
  Future<AuthResult> login({required String mobileNumber, required String password}) async {
    loginCallCount++;
    lastMobileNumber = mobileNumber;
    lastPassword = password;
    // Never resolves — these tests only assert the call was made with the
    // right arguments, not what happens once the request completes.
    return Completer<AuthResult>().future;
  }

  @override
  Future<AuthResult> register({required String mobileNumber, required String name, required String password, String? referralCode}) {
    throw UnimplementedError();
  }

  @override
  Future<Account> me() => throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<void> setPassword({required String password}) async {}

  @override
  Future<void> changePassword({required String currentPassword, required String password}) async {}

  @override
  Future<OtpRequestResult> forgotPassword({required String mobileNumber, String? channel}) async =>
      throw UnimplementedError();

  @override
  Future<void> resetPassword({
    required String mobileNumber,
    required int otpRequestId,
    required String code,
    required String password,
  }) async => throw UnimplementedError();
}

void main() {
  late FakeAuthRepository fakeRepository;

  Widget buildApp() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const LoginScreen()),
        GoRoute(path: '/register', builder: (context, state) => const Scaffold(body: Text('Register screen'))),
      ],
    );

    return ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(fakeRepository)],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
  }

  setUp(() {
    fakeRepository = FakeAuthRepository();
  });

  testWidgets('renders the Town Shoppy brand and the sign-in form', (tester) async {
    await tester.pumpWidget(buildApp());

    // The heading wraps naturally now (no hard line break), so match on its
    // prefix rather than an exact string.
    expect(find.textContaining('Welcome back to'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('shows a validation error for a number shorter than 10 digits', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.enterText(find.byType(TextField).first, '123');
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Enter a valid mobile number.'), findsOneWidget);
    expect(fakeRepository.loginCallCount, 0);
  });

  testWidgets('shows a validation error for an empty password', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.enterText(find.byType(TextField).first, '9999900002');
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Enter your password.'), findsOneWidget);
    expect(fakeRepository.loginCallCount, 0);
  });

  testWidgets('submits mobile number and password for a valid form', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.enterText(find.byType(TextField).first, '9999900002');
    await tester.enterText(find.byType(TextField).last, 'a-real-password');
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(fakeRepository.loginCallCount, 1);
    expect(fakeRepository.lastMobileNumber, '9999900002');
    expect(fakeRepository.lastPassword, 'a-real-password');
  });
}
