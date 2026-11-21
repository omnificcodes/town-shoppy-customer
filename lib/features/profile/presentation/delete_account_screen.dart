import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/info_box.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../auth/data/models/account.dart';

/// Profile > Delete account. The app stores require that an account made
/// in the app can be deleted in the app, so this is a complete flow, not a
/// link to a web page: it says plainly what goes and what stays, asks for
/// the word DELETE (and the password, when the account has one), and then
/// deletes on the spot.
///
/// An account that runs a business or holds an admin role is not deleted
/// here -- that would orphan a live shop -- so it is shown how to reach
/// support instead (`Account.canDeleteAccount`).
///
/// On success the auth state becomes signed-out and the router takes the
/// customer to the login screen; this screen does nothing more.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirmController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _submitting = false;
  String? _passwordError;
  String? _error;

  @override
  void dispose() {
    _confirmController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _typedDelete => _confirmController.text.trim().toUpperCase() == 'DELETE';

  Future<void> _submit(Account account) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
      _passwordError = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .deleteAccount(password: account.hasPassword ? _passwordController.text : null);
      // Signed out now: the router replaces this screen with Login.
    } on ValidationAppException catch (e) {
      if (!mounted) return;
      final passwordError = e.firstErrorFor('password');
      setState(() {
        _passwordError = passwordError;
        _error = passwordError == null ? (e.firstErrorFor('account') ?? e.message) : null;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    if (authState is! AuthAuthenticated) {
      // The frame between a successful deletion and the router's redirect.
      return const Scaffold(body: LoadingSkeletonList(count: 4));
    }

    final account = authState.account;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          Text('Delete your Town Shoppy account', style: textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'This is permanent. Once deleted, your account cannot be brought back.',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.section),
          const _FactCard(
            icon: Icons.delete_outline_rounded,
            tint: AppColors.error,
            title: 'Deleted immediately',
            facts: [
              'Your mobile number, name, email and password',
              'Your birthday, anniversary, social links and photos',
              'Your notifications and this phone\'s registration',
            ],
          ),
          const SizedBox(height: AppSpacing.smd),
          const _FactCard(
            icon: Icons.redeem_outlined,
            tint: AppColors.pending,
            title: 'You will lose',
            facts: [
              'Any unused Town Coins',
              'Your Lucky Draw coupons, including entries in upcoming draws',
              'Scratch cards, stamp cards and prizes you have not claimed',
            ],
          ),
          const SizedBox(height: AppSpacing.smd),
          const _FactCard(
            icon: Icons.receipt_long_outlined,
            tint: AppColors.silverDark,
            title: 'Kept without your name',
            facts: [
              'Bills, coin and draw records that shops must keep. They are no longer linked to you.',
            ],
          ),
          const SizedBox(height: AppSpacing.section),
          if (!account.canDeleteAccount)
            _BusinessAccountNotice(mobileNumber: account.mobileNumber)
          else ...[
            if (account.hasPassword) ...[
              AppTextField(
                label: 'Your password',
                controller: _passwordController,
                obscureText: _obscurePassword,
                errorText: _passwordError,
                enabled: !_submitting,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() => _passwordError = null),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            AppTextField(
              label: 'Type DELETE to confirm',
              controller: _confirmController,
              hintText: 'DELETE',
              enabled: !_submitting,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_error != null) ...[
              InfoBox(tone: AppTone.error, icon: Icons.error_outline_rounded, message: _error!),
              const SizedBox(height: AppSpacing.md),
            ],
            AppButton(
              label: 'Delete my account',
              variant: AppButtonVariant.destructive,
              icon: Icons.delete_forever_rounded,
              isLoading: _submitting,
              onPressed: _typedDelete && (!account.hasPassword || _passwordController.text.isNotEmpty)
                  ? () => _submit(account)
                  : null,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Center(
            child: TextButton(
              onPressed: () => launchUrl(Uri.parse(AppConstants.privacyPolicyUrl), mode: LaunchMode.externalApplication),
              child: const Text('Read our privacy policy'),
            ),
          ),
        ],
      ),
    );
  }
}

/// One titled group of plain facts -- what goes, what is lost, what stays.
class _FactCard extends StatelessWidget {
  const _FactCard({required this.icon, required this.tint, required this.title, required this.facts});

  final IconData icon;
  final Color tint;
  final String title;
  final List<String> facts;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: tint, size: AppIconSize.md),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
            ],
          ),
          for (final fact in facts) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7, left: AppSpacing.xs, right: AppSpacing.smd),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                  ),
                ),
                Expanded(child: Text(fact, style: AppTypography.caption.copyWith(color: AppColors.textPrimary))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown instead of the delete form to a shop owner, staff member or admin.
class _BusinessAccountNotice extends StatelessWidget {
  const _BusinessAccountNotice({required this.mobileNumber});

  final String mobileNumber;

  @override
  Widget build(BuildContext context) {
    return InfoBox(
      tone: AppTone.pending,
      icon: Icons.storefront_outlined,
      title: 'This account runs a business',
      message:
          'Deleting it here would leave the shop, its customers\' coins and its plan without an owner. '
          'Email our support team and we will close the business and delete the account for you.',
      action: AppButton(
        label: 'Email ${AppConstants.supportEmail}',
        variant: AppButtonVariant.secondary,
        size: AppButtonSize.sm,
        icon: Icons.mail_outline_rounded,
        onPressed: () => launchUrl(
          // `query:` with encodeComponent, not `queryParameters:` -- the
          // latter writes spaces as "+", which mail apps show literally.
          Uri(
            scheme: 'mailto',
            path: AppConstants.supportEmail,
            query: 'subject=${Uri.encodeComponent('Delete my Town Shoppy account')}'
                '&body=${Uri.encodeComponent('Please close my business and delete my Town Shoppy account.\nRegistered mobile number: $mobileNumber')}',
          ),
        ),
      ),
    );
  }
}
