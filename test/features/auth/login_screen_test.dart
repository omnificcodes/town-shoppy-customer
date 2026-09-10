import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/storage/secure_storage_service.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/auth/application/auth_controller.dart';
import 'package:customer/features/auth/application/auth_state.dart';
import 'package:customer/features/auth/data/auth_repository.dart';
import 'package:customer/features/auth/data/models/account.dart';
import 'package:customer/features/auth/data/models/otp_request_result.dart';
import 'package:customer/features/auth/presentation/login_screen.dart';
import 'package:customer/features/auth/presentation/widgets/auth_widgets.dart';

/// Minimal fake — this screen only ever calls `me()` once during
/// `AuthController.build()`'s session restore, and there is no stored
/// token in [_FakeEmptySecureStorage] so `me()` is never actually reached.
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

/// Fixed to the exact state that produced Phase 9's real overflow: a
/// short-enough viewport plus the "session expired" banner text this
/// screen renders above the form -- the extra height is what pushed the
/// original `Column` past the available space.
class _SessionExpiredAuthController extends AuthController {
  @override
  AuthState build() => const AuthSessionExpired();
}

// 320x568 is the narrowest phone still in circulation (iPhone SE 1st gen
// / small Androids) and is where the two-column hero collapses to one.
const _viewportSizes = [Size(320, 568), Size(375, 812), Size(390, 844), Size(430, 932), Size(768, 1024)];

/// Regression coverage for two Phase 9 findings, both real overflow bugs
/// found via a genuine authenticated browser session (see
/// docs/phase-9-report.md), not something invented for testing:
///
/// 1. (Phase 8) whether the primary CTA and mobile-number field actually
///    span the available width at a real phone size.
/// 2. (Phase 9) this screen overflowed at a short viewport once the "Your
///    session expired" text pushed it past the available height -- fixed
///    by replacing the `Spacer`-based centering with `Center` +
///    `SingleChildScrollView`.
void main() {
  testWidgets('the mobile-number field and Sign in button span the available width at a 375px phone size', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
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
        child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
      ),
    );
    await tester.pump();

    final buttonSize = tester.getSize(find.byType(AuthGradientButton).first);
    final fieldSize = tester.getSize(find.byType(AuthTextField).first);

    // 375 logical width minus AppSpacing.lg (24) padding on each side = 327.
    // Both should be within a few pixels of that, not a fraction of it.
    expect(buttonSize.width, greaterThan(300));
    expect(fieldSize.width, greaterThan(300));
  });

  for (final size in _viewportSizes) {
    testWidgets('does not overflow at ${size.width.toInt()}x${size.height.toInt()} with the session-expired banner shown', (tester) async {
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
            authControllerProvider.overrideWith(_SessionExpiredAuthController.new),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Your session expired. Please sign in again.'), findsOneWidget);
    });
  }
}
