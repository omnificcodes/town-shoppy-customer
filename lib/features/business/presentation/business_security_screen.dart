import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/info_box.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../application/password_controller.dart';
import 'business_routes.dart';
import 'widgets/business_page_header.dart';

/// Mirrors the merchant web app's Security page: password management only
/// (the API has no sessions/devices/2FA surface). "Set" when the account
/// has no password yet, "Change" otherwise.
class BusinessSecurityScreen extends ConsumerWidget {
  const BusinessSecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final hasPassword = auth is AuthAuthenticated && auth.account.hasPassword;
    final mobile = auth is AuthAuthenticated ? auth.account.mobileNumber : '';
    final textTheme = Theme.of(context).textTheme;

    return BusinessScaffold(
      title: 'Security',
      padded: false,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          Text('Manage how you sign in to Town Shoppy.', style: textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(
            title: 'Password',
            subtitle: 'Sign in with your mobile number and a password, as an alternative to OTP. OTP sign-in always stays available.',
            icon: Icons.key_rounded,
          ),
          const SizedBox(height: AppSpacing.smd),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: AppSize.avatarMd,
                      height: AppSize.avatarMd,
                      decoration: BoxDecoration(color: AppColors.businessTint, borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                      child: const Icon(Icons.password_rounded, color: AppColors.businessInk, size: AppIconSize.md),
                    ),
                    const SizedBox(width: AppSpacing.smd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Password', style: textTheme.titleMedium),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(mobile, style: textTheme.bodySmall),
                        ],
                      ),
                    ),
                    StatusBadge(
                      label: hasPassword ? 'Configured' : 'Not configured',
                      tone: hasPassword ? AppTone.success : AppTone.neutral,
                      icon: hasPassword ? Icons.check_rounded : null,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: hasPassword ? 'Change password' : 'Set password',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => context.push(BusinessRoutes.securityPassword),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The set/change form, pushed from [BusinessSecurityScreen].
class BusinessPasswordScreen extends ConsumerStatefulWidget {
  const BusinessPasswordScreen({super.key});

  @override
  ConsumerState<BusinessPasswordScreen> createState() => _BusinessPasswordScreenState();
}

class _BusinessPasswordScreenState extends ConsumerState<BusinessPasswordScreen> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _touched = false;
  bool _obscure = true;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? get _passwordError => _password.text.length < 8 ? 'Use at least 8 characters.' : null;
  String? get _confirmError => _confirm.text != _password.text ? "Passwords don't match." : null;
  String? _currentError(bool hasPassword) => hasPassword && _current.text.isEmpty ? 'Enter your current password.' : null;

  void _submit(bool hasPassword) {
    setState(() => _touched = true);
    if (_passwordError != null || _confirmError != null || _currentError(hasPassword) != null) return;
    final controller = ref.read(passwordControllerProvider.notifier);
    if (hasPassword) {
      controller.changePassword(currentPassword: _current.text, password: _password.text);
    } else {
      controller.setPassword(_password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final hasPassword = auth is AuthAuthenticated && auth.account.hasPassword;
    final state = ref.watch(passwordControllerProvider);

    ref.listen(passwordControllerProvider, (prev, next) {
      if (next.success && prev?.success != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(hasPassword ? 'Password changed.' : 'Password set. You can now sign in with it.')),
        );
        context.pop();
      }
    });

    String? serverError(String field) => state.fieldErrors[field]?.firstOrNull;
    final toggle = IconButton(
      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
      tooltip: _obscure ? 'Show password' : 'Hide password',
      onPressed: () => setState(() => _obscure = !_obscure),
    );

    return BusinessScaffold(
      title: hasPassword ? 'Change password' : 'Set a password',
      padded: false,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          Text(
            hasPassword ? 'Enter your current password, then choose a new one.' : 'Add a password so you can sign in without waiting for an OTP.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.section),
          if (hasPassword) ...[
            AppTextField(
              label: 'Current password',
              controller: _current,
              obscureText: _obscure,
              errorText: serverError('current_password') ?? (_touched ? _currentError(hasPassword) : null),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.smd),
          ],
          AppTextField(
            label: hasPassword ? 'New password' : 'New password',
            controller: _password,
            obscureText: _obscure,
            helperText: 'At least 8 characters.',
            errorText: serverError('password') ?? (_touched ? _passwordError : null),
            suffixIcon: toggle,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(
            label: hasPassword ? 'Confirm new password' : 'Confirm password',
            controller: _confirm,
            obscureText: _obscure,
            errorText: _touched ? _confirmError : null,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(hasPassword),
          ),
          const SizedBox(height: AppSpacing.section),
          if (state.error != null && state.fieldErrors.isEmpty) ...[
            InfoBox(icon: Icons.error_outline_rounded, tone: AppTone.error, message: state.error!.message),
            const SizedBox(height: AppSpacing.md),
          ],
          AppButton(label: hasPassword ? 'Change password' : 'Set password', isLoading: state.isSubmitting, onPressed: () => _submit(hasPassword)),
        ],
      ),
    );
  }
}
