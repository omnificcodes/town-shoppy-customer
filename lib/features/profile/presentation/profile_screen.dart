import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/info_box.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';

/// Read-only by design — section 22: "support editing only where backend
/// permits it." `CustomerProfile` has no update endpoint today (see the
/// backend contract doc), so this screen shows exactly what `/auth/me`
/// returns and nothing more.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final account = authState is AuthAuthenticated ? authState.account : null;
    final isLoggingOut = authState is AuthAuthenticated && authState.isLoggingOut;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: account == null
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  AppCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.orange.withValues(alpha: 0.12),
                          child: Text(
                            _initials(account.customerProfile?.name, account.mobileNumber),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.orange),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(account.displayName, style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 2),
                              Text(account.mobileNumber, style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Activity', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  _NavRow(icon: Icons.receipt_long_rounded, label: 'Purchases', onTap: () => context.push('/purchases')),
                  const SizedBox(height: AppSpacing.sm),
                  _NavRow(icon: Icons.qr_code_2_rounded, label: 'Redemptions', onTap: () => context.push('/redemptions')),
                  if (account.customerProfile?.referralCode != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _NavRow(icon: Icons.card_giftcard_rounded, label: 'Referrals', onTap: () => context.push('/referrals')),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  InfoBox(
                    icon: Icons.verified_user_rounded,
                    title: 'Account status',
                    message: account.customerProfile?.status ?? account.status,
                    tone: (account.customerProfile?.status ?? account.status) == 'active' ? InfoBoxTone.success : InfoBoxTone.pending,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'Sign out',
                    variant: AppButtonVariant.secondary,
                    isLoading: isLoggingOut,
                    onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                    icon: Icons.logout_rounded,
                  ),
                ],
              ),
      ),
    );
  }

  String _initials(String? name, String mobile) {
    if (name != null && name.trim().isNotEmpty) {
      final parts = name.trim().split(RegExp(r'\s+'));
      return parts.take(2).map((p) => p[0].toUpperCase()).join();
    }
    return mobile.isNotEmpty ? mobile.substring(mobile.length - 2) : '?';
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.orange),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.titleSmall)),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
