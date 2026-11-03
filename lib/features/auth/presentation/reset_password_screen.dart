import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/password_reset_controller.dart';
import '../application/password_reset_state.dart';
import 'widgets/auth_background.dart';
import '../data/models/otp_request_result.dart';
import 'widgets/auth_widgets.dart';
import 'widgets/otp_delivery_debug_panel.dart';

/// Passed from [ForgotPasswordScreen] as `extra` — [otpRequestId] is
/// reassigned locally on a resend (a new OTP request each time), so it's
/// held as screen state below rather than re-read from this immutable args
/// object after the first request.
class ResetPasswordArgs {
  const ResetPasswordArgs({
    required this.mobileNumber,
    required this.otpRequestId,
    required this.channelUsed,
    this.deliveries = const [],
    this.debugCode,
  });

  final String mobileNumber;
  final int otpRequestId;
  final String channelUsed;

  /// OTP delivery debugging details, empty unless the API has
  /// `OTP_EXPOSE_DELIVERY_ERRORS` on — see [OtpDeliveryDebugPanel].
  final List<OtpDelivery> deliveries;
  final String? debugCode;
}

/// Step 2 -- `POST /auth/password/reset`. A wrong/expired/wrong-purpose code
/// and an unknown `mobile_number` both surface as ordinary 422 field errors
/// from the backend (see the reset controller's docblock); this screen
/// doesn't try to distinguish them beyond showing whatever message comes
/// back.
///
/// Same cream backdrop, brand block and gradient CTA as the rest of the
/// auth flow; no hero art so the three fields stay above the fold.
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
  late List<OtpDelivery> _deliveries;
  String? _debugCode;

  @override
  void initState() {
    super.initState();
    _otpRequestId = widget.args.otpRequestId;
    _deliveries = widget.args.deliveries;
    _debugCode = widget.args.debugCode;
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
    setState(() {
      _otpRequestId = result.otpRequestId;
      _deliveries = result.deliveries;
      _debugCode = result.debugCode;
    });
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
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AuthPalette.cream,
      body: Stack(
        children: [
          const AuthBackdrop(cornerBlobs: false),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthHeader(onBack: () => context.pop()),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AuthBrandBlock(logoHeight: 56),
                        const SizedBox(height: AppSpacing.lg),
                        Text('Reset password', style: textTheme.headlineMedium?.copyWith(color: AuthPalette.brown)),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Enter the 6-digit code sent to +91 ${widget.args.mobileNumber} and choose a new password.',
                          style: textTheme.bodyMedium?.copyWith(color: AuthPalette.mutedText),
                        ),
                        if (_deliveries.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          OtpDeliveryDebugPanel(deliveries: _deliveries, debugCode: _debugCode),
                        ],
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
                        // "Resend code" is its own row under the code field
                        // rather than the sole spacer between two fields, so
                        // the field-to-field rhythm stays at AppSpacing.md.
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Flexible bounds the button to the row's width
                            // so its label wraps at a large text scale
                            // instead of overflowing the row.
                            Flexible(
                              child: TextButton(
                                onPressed: isSubmitting ? null : _resend,
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(AppSpacing.touchTarget, AppSpacing.touchTarget),
                                  textStyle: textTheme.labelLarge,
                                ),
                                child: const Text('Resend code'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
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
                          Text(serverError.message, style: textTheme.bodySmall?.copyWith(color: AppColors.error)),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        AuthGradientButton(label: 'Reset password', onPressed: _submit, isLoading: isSubmitting),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
