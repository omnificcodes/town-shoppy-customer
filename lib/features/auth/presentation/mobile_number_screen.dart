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

/// Mobile-number entry — the first screen of the OTP login flow (section 5).
/// Client-side validation here is UX-only (section 63): the backend's
/// `PhoneNumberNormalizer`/`ValidMobileNumber` rule remains authoritative
/// and accepts a much broader set of formats than this simple check.
class MobileNumberScreen extends ConsumerStatefulWidget {
  const MobileNumberScreen({super.key});

  @override
  ConsumerState<MobileNumberScreen> createState() => _MobileNumberScreenState();
}

class _MobileNumberScreenState extends ConsumerState<MobileNumberScreen> {
  final _controller = TextEditingController();
  bool _touched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? get _validationError {
    final digits = _controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10) return 'Enter a valid mobile number.';
    return null;
  }

  void _submit() {
    setState(() => _touched = true);
    if (_validationError != null) return;
    ref
        .read(authControllerProvider.notifier)
        .requestOtp(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      if (next is AuthOtpSent &&
          (previous is! AuthOtpSent ||
              previous.otpRequestId != next.otpRequestId)) {
        context.push('/otp');
      }
    });

    final state = ref.watch(authControllerProvider);
    final isSubmitting = state is AuthUnauthenticated && state.isRequestingOtp;
    final serverError = state is AuthUnauthenticated ? state.error : null;
    final wasSessionExpired = state is AuthSessionExpired;

    return Scaffold(
      body: SafeArea(
        // Center, not a bare Padding+Column: this content is meant to sit
        // vertically centered on a normal screen, but a short viewport, a
        // large system text scale, or the extra error/session-expired text
        // below can make it taller than that -- Center lets
        // SingleChildScrollView take over scrolling in exactly that case
        // instead of overflowing (the Spacer-based centering this replaced
        // can't coexist with a scrollable parent).
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/images/townshoppy_logo.png',
                  height: 64,
                  semanticLabel: 'Town Shoppy',
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Welcome to Town Shoppy',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Enter your mobile number to sign in or create an account.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (wasSessionExpired)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      'Your session expired. Please sign in again.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.error),
                    ),
                  ),
                AppTextField(
                  label: 'Mobile number',
                  controller: _controller,
                  prefixText: '+91 ',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  autofocus: true,
                  errorText: _touched ? _validationError : null,
                  onSubmitted: (_) => _submit(),
                ),
                if (serverError != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    serverError.message,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.error),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Send code',
                  onPressed: _submit,
                  isLoading: isSubmitting,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
