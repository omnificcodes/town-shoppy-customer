import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';

/// OTP verification — the second half of the login flow. The 60-second
/// resend cooldown shown here is a local UX pacing timer only (the backend
/// config also defines `otp.resend_cooldown_seconds`, but does not return
/// it in the request response — see `OtpRequestResource`); the real limit
/// enforced server-side is the `otp-request` rate limiter, so an early tap
/// is still safe to attempt and simply surfaces that limiter's error.
class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({super.key});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  static const _resendCooldown = Duration(seconds: 60);

  final _codeController = TextEditingController();
  Timer? _ticker;
  Duration _resendRemaining = _resendCooldown;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendRemaining = _resendCooldown;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _resendRemaining -= const Duration(seconds: 1);
        if (_resendRemaining <= Duration.zero) timer.cancel();
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (previous, next) {
      if (next is AuthOtpSent &&
          previous is AuthOtpSent &&
          next.otpRequestId != previous.otpRequestId) {
        // A resend succeeded — restart the local cooldown.
        _startResendTimer();
      }
      if (next is AuthUnauthenticated) {
        // Session was reset (e.g. "use a different number") — leave this screen.
        if (context.canPop()) context.pop();
      }
    });

    if (state is! AuthOtpSent) {
      // Reached without an active OTP request (e.g. deep link, hot reload
      // after a state reset) — nothing meaningful to verify.
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          // A ListView, not a Column, since a short viewport (a small
          // phone, a large system text scale, or the on-screen keyboard
          // reducing available height) can make this content taller than
          // the screen -- same pattern already used by the redemption
          // verification screen for the same reason.
          child: ListView(
            children: [
              Text(
                'Enter verification code',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'We sent a code to +91 ${state.mobileNumber}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Verification code',
                controller: _codeController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                autofocus: true,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(letterSpacing: 8),
                onSubmitted: (_) => _verify(),
              ),
              if (state.debugCode != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Debug code: ${state.debugCode}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.info),
                ),
              ],
              if (state.error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  state.error!.message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Verify and sign in',
                isLoading: state.isVerifying,
                onPressed: _verify,
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: _resendRemaining > Duration.zero
                    ? Text(
                        'Resend code in ${_resendRemaining.inSeconds}s',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    : AppButton(
                        label: 'Resend code',
                        variant: AppButtonVariant.text,
                        isLoading: state.isResending,
                        onPressed: () => ref
                            .read(authControllerProvider.notifier)
                            .resendOtp(),
                      ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: AppButton(
                  label: 'Use a different number',
                  variant: AppButtonVariant.text,
                  onPressed: () => ref
                      .read(authControllerProvider.notifier)
                      .backToMobileEntry(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _verify() {
    if (_codeController.text.length < 4) return;
    ref
        .read(authControllerProvider.notifier)
        .verifyOtp(_codeController.text.trim());
  }
}
