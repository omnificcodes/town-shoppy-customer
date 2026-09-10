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

/// Below this logical width the two-column hero (copy on the left, art on
/// the right) can no longer fit the heading, so it collapses to one column.
const double _heroTwoColumnMinWidth = 340;

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
                          child: constraints.maxWidth < _heroTwoColumnMinWidth
                              ? const _LoginHeroStacked()
                              : const _LoginHeroSideBySide(),
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
                              const SizedBox(height: AppSpacing.md),
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
                              const SizedBox(height: AppSpacing.xs),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: isSubmitting ? null : () => context.push('/forgot-password'),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(AppSpacing.touchTarget, AppSpacing.touchTarget),
                                    textStyle: Theme.of(context).textTheme.labelLarge,
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

class _LoginHeading extends StatelessWidget {
  const _LoginHeading();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome back to Town Shoppy', style: textTheme.headlineMedium?.copyWith(color: AuthPalette.brown)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Enter your mobile number and password to sign in.',
          style: textTheme.bodyMedium?.copyWith(color: AuthPalette.mutedText),
        ),
      ],
    );
  }
}

class _LoginTagline extends StatelessWidget {
  const _LoginTagline();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(right: AppSpacing.lg, top: AppSpacing.sm),
      child: AuthScriptText('Shop Local\nSupport Local\nGrow Together', angle: -0.09),
    );
  }
}

/// The reference layout: brand + heading on the left, tagline + storefront
/// art on the right.
class _LoginHeroSideBySide extends StatelessWidget {
  const _LoginHeroSideBySide();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 11,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: AppSpacing.xxl),
              AuthBrandBlock(logoHeight: 78),
              SizedBox(height: AppSpacing.xl),
              _LoginHeading(),
            ],
          ),
        ),
        SizedBox(width: AppSpacing.xs),
        Expanded(
          flex: 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _LoginTagline(),
              SizedBox(height: AppSpacing.xs),
              // Bleeds to the screen's right edge on purpose -- the
              // storefront is cropped by the edge in the reference art too.
              AuthHeroIllustration(variant: AuthHeroVariant.login),
            ],
          ),
        ),
      ],
    );
  }
}

/// Narrow-screen fallback (under [_heroTwoColumnMinWidth]): one column with
/// the art full-width under the brand block and the tagline kept
/// right-aligned above it.
class _LoginHeroStacked extends StatelessWidget {
  const _LoginHeroStacked();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: AppSpacing.xl),
        AuthBrandBlock(logoHeight: 64),
        SizedBox(height: AppSpacing.sm),
        Align(alignment: Alignment.centerRight, child: _LoginTagline()),
        SizedBox(height: AppSpacing.xs),
        AuthHeroIllustration(variant: AuthHeroVariant.login),
        SizedBox(height: AppSpacing.lg),
        Padding(padding: EdgeInsets.only(right: AppSpacing.lg), child: _LoginHeading()),
      ],
    );
  }
}
