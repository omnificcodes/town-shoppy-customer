import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/storage/secure_storage_service.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/auth/data/auth_repository.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:customer/features/auth/data/models/otp_request_result.dart';
import 'package:customer/features/auth/presentation/forgot_password_screen.dart';
import 'package:customer/features/auth/presentation/register_screen.dart';
import 'package:customer/features/auth/presentation/reset_password_screen.dart';
import 'package:customer/features/auth/presentation/widgets/auth_widgets.dart';

/// Layout-only coverage for the three auth screens that have no other
/// widget tests: they must not overflow at the narrowest phone width still
/// in circulation (320) nor at the top of the text-scale range (2.0x), and
/// they all share the one [AuthHeader] back button at a 48dp target.
class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthResult> login({required String mobileNumber, required String password}) async => throw UnimplementedError();

  @override
  Future<AuthResult> register({required String mobileNumber, required String name, required String password, String? referralCode}) async =>
      throw UnimplementedError();

  @override
  Future<Account> me() async => throw UnimplementedError();

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

class _FakeEmptySecureStorage implements SecureStorageService {
  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> delete(String key) async {}
}

const _resetArgs = ResetPasswordArgs(mobileNumber: '9999900002', otpRequestId: 1, channelUsed: 'sms');

final _screens = <String, Widget>{
  'RegisterScreen': const RegisterScreen(),
  'ForgotPasswordScreen': const ForgotPasswordScreen(),
  'ResetPasswordScreen': const ResetPasswordScreen(args: _resetArgs),
};

Future<void> _pump(WidgetTester tester, Widget screen, {required Size size, double textScale = 1.0}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        secureStorageServiceProvider.overrideWithValue(_FakeEmptySecureStorage()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
          child: screen,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  for (final entry in _screens.entries) {
    for (final size in const [Size(320, 568), Size(375, 812)]) {
      testWidgets('${entry.key} does not overflow at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        await _pump(tester, entry.value, size: size);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('${entry.key} survives 2.0x text scaling without overflow', (tester) async {
      await _pump(tester, entry.value, size: const Size(375, 812), textScale: 2.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${entry.key} has a 48dp back button', (tester) async {
      await _pump(tester, entry.value, size: const Size(375, 812));
      final header = find.byType(AuthHeader);
      expect(header, findsOneWidget);
      final button = find.descendant(of: header, matching: find.byType(IconButton));
      expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    });
  }
}
