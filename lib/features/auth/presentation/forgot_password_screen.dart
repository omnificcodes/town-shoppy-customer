import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/password_reset_controller.dart';
import '../application/password_reset_state.dart';
import 'reset_password_screen.dart';
import 'widgets/auth_widgets.dart';

/// Step 1 of the forgot-password flow -- `POST /auth/password/forgot`.
/// Deliberately shows the same success path regardless of whether an
/// account exists for the entered number (the backend's own enumeration
/// protection, `AuthRepository.forgotPassword`'s docblock) -- this screen
/// never learns or reveals that either.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _mobileController = TextEditingController();
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(passwordResetControllerProvider.notifier).clearError());
  }

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  String? get _mobileError {
    final digits = _mobileController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10) return 'Enter a valid mobile number.';
    return null;
  }

  Future<void> _submit() async {
    setState(() => _touched = true);
    if (_mobileError != null) return;

    final mobileNumber = _mobileController.text.trim();
    final result = await ref.read(passwordResetControllerProvider.notifier).requestOtp(mobileNumber);
    if (result == null || !mounted) return;

    context.push(
      '/reset-password',
      extra: ResetPasswordArgs(mobileNumber: mobileNumber, otpRequestId: result.otpRequestId, channelUsed: result.channelUsed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(passwordResetControllerProvider);
    final isSubmitting = state is PasswordResetSubmitting;
    final serverError = state is PasswordResetIdle ? state.error : null;

    return Scaffold(
      backgroundColor: AuthPalette.cream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                  tooltip: 'Back',
                  onPressed: () => context.pop(),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Forgot Password?', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  "Enter your mobile number and we'll send you a code to reset it.",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                AuthTextField(
                  label: 'Mobile number',
                  icon: Icons.smartphone_rounded,
                  controller: _mobileController,
                  prefixText: '+91 ',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  errorText: _touched ? _mobileError : null,
                  onSubmitted: (_) => _submit(),
                ),
                if (serverError != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(serverError.message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error)),
                ],
                const SizedBox(height: AppSpacing.lg),
                AuthGradientButton(label: 'Send code', onPressed: _submit, isLoading: isSubmitting),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
