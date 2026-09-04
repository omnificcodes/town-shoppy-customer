import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/password_reset_controller.dart';
import '../application/password_reset_state.dart';
import 'widgets/auth_widgets.dart';

/// Passed from [ForgotPasswordScreen] as `extra` — [otpRequestId] is
/// reassigned locally on a resend (a new OTP request each time), so it's
/// held as screen state below rather than re-read from this immutable args
/// object after the first request.
class ResetPasswordArgs {
  const ResetPasswordArgs({required this.mobileNumber, required this.otpRequestId, required this.channelUsed});

  final String mobileNumber;
  final int otpRequestId;
  final String channelUsed;
}

/// Step 2 -- `POST /auth/password/reset`. A wrong/expired/wrong-purpose code
/// and an unknown `mobile_number` both surface as ordinary 422 field errors
/// from the backend (see the reset controller's docblock); this screen
/// doesn't try to distinguish them beyond showing whatever message comes
/// back.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.args});

  final ResetPasswordArgs args;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _touched = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  late int _otpRequestId;

  @override
  void initState() {
    super.initState();
    _otpRequestId = widget.args.otpRequestId;
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(passwordResetControllerProvider.notifier).clearError());
  }

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? get _codeError {
    if (_codeController.text.length != 6) return 'Enter the 6-digit code.';
    return null;
  }

  String? get _passwordError {
    if (_passwordController.text.length < 8) return 'Use at least 8 characters.';
    return null;
  }

  String? get _confirmPasswordError {
    if (_confirmPasswordController.text != _passwordController.text) return 'Passwords do not match.';
    return null;
  }

  Future<void> _resend() async {
    final result = await ref.read(passwordResetControllerProvider.notifier).requestOtp(widget.args.mobileNumber);
    if (result == null || !mounted) return;
    setState(() => _otpRequestId = result.otpRequestId);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A new code has been sent.')));
  }

  Future<void> _submit() async {
    setState(() => _touched = true);
    if (_codeError != null || _passwordError != null || _confirmPasswordError != null) return;

    final success = await ref.read(passwordResetControllerProvider.notifier).reset(
          mobileNumber: widget.args.mobileNumber,
          otpRequestId: _otpRequestId,
          code: _codeController.text.trim(),
          password: _passwordController.text,
        );
    if (!success || !mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Password reset. Please sign in with your new password.')));
    while (context.canPop()) {
      context.pop();
    }
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
                Text('Reset Password', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Enter the 6-digit code sent to +91 ${widget.args.mobileNumber} and choose a new password.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                AuthTextField(
                  label: '6-digit code',
                  icon: Icons.password_rounded,
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  errorText: _touched ? _codeError : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isSubmitting ? null : _resend,
                    child: const Text('Resend code'),
                  ),
                ),
                AuthTextField(
                  label: 'New password',
                  icon: Icons.lock_outline_rounded,
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  errorText: _touched ? _passwordError : null,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AuthTextField(
                  label: 'Confirm new password',
                  icon: Icons.lock_outline_rounded,
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  errorText: _touched ? _confirmPasswordError : null,
                  onSubmitted: (_) => _submit(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    tooltip: _obscureConfirmPassword ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                if (serverError != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(serverError.message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error)),
                ],
                const SizedBox(height: AppSpacing.lg),
                AuthGradientButton(label: 'Reset password', onPressed: _submit, isLoading: isSubmitting),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
