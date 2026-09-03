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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final isSubmitting = state is AuthUnauthenticated && state.isSubmitting;
    final serverError = state is AuthUnauthenticated ? state.error : null;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        // A ListView, not a Column: a short viewport, a large system text
        // scale, or the on-screen keyboard can make this form's five fields
        // taller than the available height.
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Create your account', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text('Join Town Shoppy to start earning rewards at local businesses.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
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
              label: 'Your name',
              controller: _nameController,
              textInputAction: TextInputAction.next,
              errorText: _touched ? _nameError : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Password',
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
            AppTextField(
              label: 'Confirm password',
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.next,
              errorText: _touched ? _confirmPasswordError : null,
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                tooltip: _obscureConfirmPassword ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Referral code (optional)',
              hintText: "Have a friend's code?",
              controller: _referralController,
              maxLength: 32,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            if (serverError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(serverError.message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(label: 'Create account', onPressed: _submit, isLoading: isSubmitting),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: AppButton(
                label: 'Already have an account? Sign in',
                variant: AppButtonVariant.text,
                onPressed: isSubmitting ? null : () => context.canPop() ? context.pop() : context.go('/login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
