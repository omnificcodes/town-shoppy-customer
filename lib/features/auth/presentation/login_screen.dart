import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';
import 'widgets/auth_background.dart';
import 'widgets/auth_hero_illustration.dart';
import 'widgets/auth_widgets.dart';

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
      backgroundColor: AuthPalette.cream,
      body: Stack(
        children: [
          const AuthBackdrop(),
          SafeArea(
            // ConstrainedBox(minHeight) + IntrinsicHeight + Spacer: the
            // skyline footer sits at the very bottom on a tall screen, and
            // simply follows the content (scrolling) on a short one or with
            // the keyboard up -- never overlapping the form.
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.lg, top: AppSpacing.sm),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 11,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 44),
                                    const AuthBrandBlock(logoHeight: 78),
                                    const SizedBox(height: 34),
                                    Text(
                                      'Welcome back to\nTown Shoppy',
                                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                            color: AuthPalette.brown,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 21,
                                            height: 1.15,
                                          ),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    Text(
                                      'Enter your mobile number and password to sign in.',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: const Color(0xFF6F5F57),
                                            height: 1.4,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                flex: 10,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(right: AppSpacing.lg, top: 6),
                                      child: AuthScriptText('Shop Local\nSupport Local\nGrow Together', angle: -0.09),
                                    ),
                                    const SizedBox(height: 4),
                                    // Bleeds to the screen's right edge on
                                    // purpose -- the storefront is cropped by
                                    // the edge in the reference art too.
                                    const AuthHeroIllustration(variant: AuthHeroVariant.login),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: AppSpacing.lg),
                              if (wasSessionExpired)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                  child: Text(
                                    'Your session expired. Please sign in again.',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error),
                                  ),
                                ),
                              AuthTextField(
                                label: 'Mobile number',
                                icon: Icons.smartphone_rounded,
                                controller: _mobileController,
                                prefixText: '+91 ',
                                keyboardType: TextInputType.phone,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                                autofocus: true,
                                textInputAction: TextInputAction.next,
                                errorText: _touched ? _mobileError : null,
                              ),
                              const SizedBox(height: 14),
                              AuthTextField(
                                label: 'Password',
                                icon: Icons.lock_outline_rounded,
                                hintText: 'Enter your password',
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
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: isSubmitting ? null : () => context.push('/forgot-password'),
                                  style: TextButton.styleFrom(
                                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                  ),
                                  child: const Text('Forgot password?'),
                                ),
                              ),
                              if (serverError != null) ...[
                                Text(serverError.message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error)),
                                const SizedBox(height: AppSpacing.sm),
                              ],
                              const SizedBox(height: AppSpacing.xs),
                              AuthGradientButton(label: 'Sign in', onPressed: _submit, isLoading: isSubmitting),
                              const SizedBox(height: AppSpacing.lg),
                              const AuthOrDivider(label: 'New to Town Shoppy?'),
                              const SizedBox(height: AppSpacing.lg),
                              AuthOutlinedPillButton(
                                label: 'Create an account',
                                onPressed: isSubmitting ? null : () => context.push('/register'),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                            ],
                          ),
                        ),
                        const Spacer(),
                        const AuthLoginFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
