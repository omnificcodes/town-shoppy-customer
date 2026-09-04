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

/// Password-first registration — no OTP, no proof of phone ownership
/// (`AuthService::registerWithPassword()`'s own docblock). A referral code
/// can only ever be applied here, at the moment of a genuinely new account
/// being created; the backend silently ignores an unknown code rather than
/// blocking signup or revealing whether it exists (referral-code
/// enumeration protection).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _mobileController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _referralController = TextEditingController();
  bool _touched = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    // Never show a stray error left over from the Login screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(authControllerProvider.notifier).clearError());
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  String? get _mobileError {
    final digits = _mobileController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10) return 'Enter a valid mobile number.';
    return null;
  }

  String? get _nameError {
    if (_nameController.text.trim().isEmpty) return 'Enter your name.';
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

  void _submit() {
    setState(() => _touched = true);
    if (_mobileError != null || _nameError != null || _passwordError != null || _confirmPasswordError != null) return;

    final referral = _referralController.text.trim();
    ref
        .read(authControllerProvider.notifier)
        .register(
          _mobileController.text.trim(),
          _nameController.text.trim(),
          _passwordController.text,
          referralCode: referral.isEmpty ? null : referral,
        );
  }

  void _goToLogin() => context.canPop() ? context.pop() : context.go('/login');

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final isSubmitting = state is AuthUnauthenticated && state.isSubmitting;
    final serverError = state is AuthUnauthenticated ? state.error : null;

    return Scaffold(
      backgroundColor: AuthPalette.cream,
      body: Stack(
        children: [
          const AuthBackdrop(cornerBlobs: false),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.md, top: AppSpacing.xs),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 10,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.arrow_back_rounded, color: AuthPalette.brown, size: 28),
                                      tooltip: 'Back',
                                      onPressed: _goToLogin,
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.only(left: AppSpacing.sm),
                                      child: AuthBrandBlock(logoHeight: 66),
                                    ),
                                    const SizedBox(height: 30),
                                    Padding(
                                      padding: const EdgeInsets.only(left: AppSpacing.sm),
                                      child: Text(
                                        'Create your\naccount',
                                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                              color: AuthPalette.brown,
                                              fontWeight: FontWeight.w800,
                                              height: 1.15,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    Padding(
                                      padding: const EdgeInsets.only(left: AppSpacing.sm),
                                      child: Text(
                                        'Join Town Shoppy to start earning rewards at local businesses.',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: const Color(0xFF6F5F57),
                                              fontSize: 15,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                flex: 11,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: const [
                                    Padding(
                                      padding: EdgeInsets.only(right: AppSpacing.lg, top: 14),
                                      child: AuthScriptText(
                                        'Shop Local\nEarn Rewards\nBe Part of a\nStronger Community',
                                        size: 19,
                                        angle: -0.09,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Padding(
                                      padding: EdgeInsets.only(right: AppSpacing.md),
                                      child: AuthHeroIllustration(variant: AuthHeroVariant.register),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                          // The form sits in a white card in the reference,
                          // unlike Login where the fields sit on the cream.
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: AuthPalette.fieldBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8A5A2B).withValues(alpha: 0.08),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
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
                                const SizedBox(height: 12),
                                AuthTextField(
                                  label: 'Your name',
                                  icon: Icons.person_outline_rounded,
                                  controller: _nameController,
                                  textInputAction: TextInputAction.next,
                                  errorText: _touched ? _nameError : null,
                                ),
                                const SizedBox(height: 12),
                                AuthTextField(
                                  label: 'Password',
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
                                const SizedBox(height: 12),
                                AuthTextField(
                                  label: 'Confirm password',
                                  icon: Icons.lock_outline_rounded,
                                  controller: _confirmPasswordController,
                                  obscureText: _obscureConfirmPassword,
                                  textInputAction: TextInputAction.next,
                                  errorText: _touched ? _confirmPasswordError : null,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    ),
                                    tooltip: _obscureConfirmPassword ? 'Show password' : 'Hide password',
                                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                AuthTextField(
                                  label: 'Referral code (optional)',
                                  icon: Icons.card_giftcard_rounded,
                                  hintText: "Have a friend's code?",
                                  controller: _referralController,
                                  maxLength: 32,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _submit(),
                                ),
                                if (serverError != null) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    serverError.message,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error),
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.lg),
                                AuthGradientButton(label: 'Create account', onPressed: _submit, isLoading: isSubmitting),
                                const SizedBox(height: AppSpacing.md),
                                const AuthOrDivider(label: 'OR'),
                                const SizedBox(height: AppSpacing.md),
                                AuthTintedPillButton(
                                  leading: 'Already have an account?',
                                  trailing: 'Sign in',
                                  onPressed: isSubmitting ? null : _goToLogin,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const Spacer(),
                        const AuthRegisterFooter(),
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
