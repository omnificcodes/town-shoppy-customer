import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/auth/data/auth_repository.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:customer/features/auth/data/models/otp_request_result.dart';
import 'package:customer/features/auth/presentation/mobile_number_screen.dart';

/// Never touches the network — every call resolves immediately with a
/// canned response, so widget tests exercise real UI/state wiring without
/// depending on a live backend (see the phase brief's testing section: use
/// mocked APIs for widget tests, the real backend for integration tests).
class FakeAuthRepository implements AuthRepository {
  int requestOtpCallCount = 0;
  String? lastRequestedMobileNumber;

  @override
  Future<OtpRequestResult> requestOtp({required String mobileNumber, String? channel}) async {
    requestOtpCallCount++;
    lastRequestedMobileNumber = mobileNumber;
    return const OtpRequestResult(otpRequestId: 1, expiresInSeconds: 300, channelUsed: 'sms', debugCode: '123456');
  }

  @override
  Future<VerifyOtpResult> verifyOtp({required int otpRequestId, required String code, String? name, String? referralCode}) {
    throw UnimplementedError();
  }

  @override
  Future<Account> me() => throw UnimplementedError();

  @override
  Future<void> logout() async {}
}

void main() {
  late FakeAuthRepository fakeRepository;

  Widget buildApp() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const MobileNumberScreen()),
        GoRoute(path: '/otp', builder: (context, state) => const Scaffold(body: Text('OTP screen'))),
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

  testWidgets('renders the Town Shoppy brand and mobile number entry', (tester) async {
    await tester.pumpWidget(buildApp());

    expect(find.text('Welcome to Town Shoppy'), findsOneWidget);
    expect(find.text('Send code'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('shows a validation error for a number shorter than 10 digits', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('Send code'));
    await tester.pump();

    expect(find.text('Enter a valid mobile number.'), findsOneWidget);
    expect(fakeRepository.requestOtpCallCount, 0);
  });

  testWidgets('requests an OTP for a valid 10-digit number', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.enterText(find.byType(TextField), '9999900002');
    await tester.tap(find.text('Send code'));
    await tester.pump();

    expect(fakeRepository.requestOtpCallCount, 1);
    expect(fakeRepository.lastRequestedMobileNumber, '9999900002');
  });
}
