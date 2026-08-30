import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';

/// Shown exactly once, only for a genuinely new account, right after a
/// correct OTP — the backend needs a name to finish creating the
/// `CustomerProfile`, and this is the only moment it will ever accept a
/// referral code (`AuthProfileRequired`'s docblock). Submitting here is a
/// single resubmission of the same OTP verification, so there is nothing
/// to "apply twice" — the referral field simply never appears again once
/// this screen is behind the user.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _nameController = TextEditingController();
  final _referralController = TextEditingController();
  bool _touched = false;

  @override
  void dispose() {
    _nameController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  String? get _nameError {
    if (_nameController.text.trim().isEmpty) return 'Enter your name to continue.';
    return null;
  }

  void _submit() {
    setState(() => _touched = true);
    if (_nameError != null) return;

    final referral = _referralController.text.trim();
    ref.read(authControllerProvider.notifier).completeRegistration(
          name: _nameController.text.trim(),
          referralCode: referral.isEmpty ? null : referral,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    if (state is! AuthProfileRequired) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final isSubmitting = state.isSubmitting;

    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to Town Shoppy')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Let's finish setting up your account", style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'This is your first time signing in with +91 ${state.mobileNumber}.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Your name',
                controller: _nameController,
                autofocus: true,
                enabled: !isSubmitting,
                errorText: _touched ? _nameError : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Referral code (optional)',
                hintText: 'Have a friend\'s code?',
                controller: _referralController,
                enabled: !isSubmitting,
                maxLength: 32,
              ),
              if (state.error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(state.error!.message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error)),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(label: 'Continue', isLoading: isSubmitting, onPressed: isSubmitting ? null : _submit),
            ],
          ),
        ),
      ),
    );
  }
}
