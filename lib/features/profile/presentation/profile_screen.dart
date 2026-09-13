import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_mode/app_mode.dart';
import '../../../core/app_mode/app_mode_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../business/presentation/business_routes.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/info_box.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/nav_link_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';

/// Name, date of birth, anniversary, and social links are all editable via
/// `/profile/edit` (section 22's "support editing only where backend
/// permits it" now applies to that screen's field set, not this one --
/// `PATCH /customer-profile` is the backend contract behind it).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final account = authState is AuthAuthenticated ? authState.account : null;
    final isLoggingOut = authState is AuthAuthenticated && authState.isLoggingOut;

    if (account == null) {
      // Only reachable for the frame(s) while the session is still resolving
      // (the router redirects away otherwise) -- a skeleton, never a blank
      // screen.
      return const AppScaffold(title: 'Profile', padded: false, body: LoadingSkeletonList(count: 4));
    }

    final status = account.customerProfile?.status ?? account.status;

    return AppScaffold(
      title: 'Profile',
      padded: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Edit profile',
          onPressed: () => context.push('/profile/edit'),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          AppCard(
            child: Row(
              children: [
                Container(
                  width: AppSize.avatarLg,
                  height: AppSize.avatarLg,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AppColors.orangeTintStrong, shape: BoxShape.circle),
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
                      const SizedBox(height: AppSpacing.xxs),
                      Text(account.mobileNumber, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'Activity'),
          const SizedBox(height: AppSpacing.smd),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                NavLinkRow(
                  icon: Icons.receipt_long_rounded,
                  title: 'Purchases',
                  subtitle: 'Bills recorded at participating merchants',
                  onTap: () => context.push('/purchases'),
                ),
                const Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md),
                NavLinkRow(
                  icon: Icons.qr_code_2_rounded,
                  iconColor: AppColors.goldDark,
                  title: 'Redemptions',
                  subtitle: 'Town Coin you have spent',
                  onTap: () => context.push('/redemptions'),
                ),
                if (account.customerProfile?.referralCode != null) ...[
                  const Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md),
                  NavLinkRow(
                    icon: Icons.card_giftcard_rounded,
                    title: 'Referrals',
                    subtitle: 'Invite friends with your code',
                    onTap: () => context.push('/referrals'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'Business'),
          const SizedBox(height: AppSpacing.smd),
          AppCard(
            padding: EdgeInsets.zero,
            child: account.hasMerchantAccess
                ? NavLinkRow(
                    icon: Icons.storefront_rounded,
                    iconColor: AppColors.businessInk,
                    title: 'Switch to Business app',
                    subtitle: 'Counter, offers, redemptions and your shop profile',
                    onTap: () async {
                      await ref.read(appModeControllerProvider.notifier).select(AppMode.business);
                      if (context.mounted) context.go(BusinessRoutes.root);
                    },
                  )
                : NavLinkRow(
                    icon: Icons.storefront_outlined,
                    title: 'Register your business',
                    subtitle: 'Join Town Shoppy as a merchant',
                    onTap: () => context.push('/register-merchant'),
                  ),
          ),
          const SizedBox(height: AppSpacing.section),
          InfoBox(
            icon: status == 'active' ? Icons.verified_user_rounded : Icons.hourglass_top_rounded,
            title: 'Account status',
            message: status == 'active' ? 'Active — you can earn and redeem Town Coin.' : _humanize(status),
            tone: status == 'active' ? AppTone.success : AppTone.pending,
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
    );
  }

  String _humanize(String status) {
    final words = status.replaceAll('_', ' ');
    return words.isEmpty ? words : words[0].toUpperCase() + words.substring(1);
  }

  String _initials(String? name, String mobile) {
    if (name != null && name.trim().isNotEmpty) {
      final parts = name.trim().split(RegExp(r'\s+'));
      return parts.take(2).map((p) => p[0].toUpperCase()).join();
    }
    return mobile.isNotEmpty ? mobile.substring(mobile.length - 2) : '?';
  }
}
