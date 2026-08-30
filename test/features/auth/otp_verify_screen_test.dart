import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/core/theme/app_theme.dart';
import 'package:customer/features/auth/application/auth_controller.dart';
import 'package:customer/features/auth/application/auth_state.dart';
import 'package:customer/features/auth/presentation/otp_verify_screen.dart';

/// Fixed to an `AuthOtpSent` state with a debug code shown -- the exact
/// combination (heading + subtext + code field + debug-code line + Verify
/// button + resend timer + "use a different number" link) that produced two
/// real, genuine bugs found on an authenticated browser session this phase
/// (see docs/phase-9-report.md): a vertical overflow from this screen's
/// body being a bare `Column` instead of a `ListView`, and -- once that was
/// fixed and this test swept every required width -- a second, narrower
/// horizontal overflow from `AppButton`'s "Use a different number" label
/// (330px of natural text width) not fitting a ~304px-wide button at
/// 375/390px. Both are fixed; this file covers both regressions at once.
class _OtpSentAuthController extends AuthController {
  @override
  AuthState build() => AuthOtpSent(
    otpRequestId: 1,
    mobileNumber: '9990003001',
    expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    channelUsed: 'sms',
    debugCode: '123456',
  );
}

const _viewportSizes = [
  Size(375, 812),
  Size(390, 844),
  Size(430, 932),
  Size(768, 1024),
];

void main() {
  for (final size in _viewportSizes) {
    testWidgets(
      'does not overflow at ${size.width.toInt()}x${size.height.toInt()} with the debug code shown',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith(_OtpSentAuthController.new),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              home: const OtpVerifyScreen(),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Debug code: 123456'), findsOneWidget);

        // Unmounts the screen so its resend-cooldown Timer.periodic is
        // cancelled in dispose() before the test ends -- otherwise it's
        // still pending when flutter_test checks for leaked timers.
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
