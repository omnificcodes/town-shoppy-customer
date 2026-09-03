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

/// Password sign-in — the primary entry point to the app (mirrors the
/// Association Admin/Merchant web app's own mobile-number + password login,
/// rather than the OTP-only flow this screen used to be). Client-side
/// validation here is UX-only (section 63): the backend's
/// `PhoneNumberNormalizer`/`ValidMobileNumber` rule remains authoritative
/// and accepts a much broader set of formats than this simple check.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _touched = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Never show a stray error left over from the Register screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(authControllerProvider.notifier).clearError());
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? get _mobileError {
    final digits = _mobileController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10) return 'Enter a valid mobile number.';
    return null;
  }

  String? get _passwordError {
    if (_passwordController.text.isEmpty) return 'Enter your password.';
    return null;
  }

  void _submit() {
    setState(() => _touched = true);
    if (_mobileError != null || _passwordError != null) return;
    ref.read(authControllerProvider.notifier).login(_mobileController.text.trim(), _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final isSubmitting = state is AuthUnauthenticated && state.isSubmitting;
    final serverError = state is AuthUnauthenticated ? state.error : null;
    final wasSessionExpired = state is AuthSessionExpired;

    return Scaffold(
      body: SafeArea(
        // Center, not a bare Padding+Column: this content is meant to sit
        // vertically centered on a normal screen, but a short viewport, a
        // large system text scale, or the extra error/session-expired text
        // below can make it taller than that -- Center lets
        // SingleChildScrollView take over scrolling in exactly that case
        // instead of overflowing.
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset('assets/images/townshoppy_logo.png', height: 64, semanticLabel: 'Town Shoppy'),
                const SizedBox(height: AppSpacing.lg),
                Text('Welcome back to Town Shoppy', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.xs),
                Text('Enter your mobile number and password to sign in.', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.lg),
                if (wasSessionExpired)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      'Your session expired. Please sign in again.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error),
                    ),
                  ),
                AppTextField(
                  label: 'Mobile number',
                  controller: _mobileController,
                  prefixText: '+91 ',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  errorText: _touched ? _mobileError : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Password',
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  errorText: _touched ? _passwordError : null,
                  onSubmitted: (_) => _submit(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                if (serverError != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(serverError.message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error)),
                ],
                const SizedBox(height: AppSpacing.lg),
                AppButton(label: 'Sign in', onPressed: _submit, isLoading: isSubmitting),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: AppButton(
                    label: "New to Town Shoppy? Create an account",
                    variant: AppButtonVariant.text,
                    onPressed: isSubmitting ? null : () => context.push('/register'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
