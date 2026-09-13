import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_mode/app_mode.dart';
import '../../../core/app_mode/app_mode_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/nav_link_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../merchants/presentation/merchant_logo.dart';
import '../application/business_context.dart';
import 'business_routes.dart';
import 'widgets/business_page_header.dart';

/// The full merchant menu -- every destination the web sidebar has, in the
/// same groups, with the same Owner/Staff visibility and the same lock
/// icon on package-gated entries. Also where an owner switches back to the
/// Customer app and signs out.
class BusinessMoreScreen extends ConsumerWidget {
  const BusinessMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final account = auth is AuthAuthenticated ? auth.account : null;
    final isLoggingOut = auth is AuthAuthenticated && auth.isLoggingOut;
    final isOwner = ref.watch(isBusinessOwnerProvider);
    final merchant = ref.watch(myMerchantProvider).value;
    final hasPackage = ref.watch(merchantEntitlementProvider).value?.hasPackage ?? true;
    final textTheme = Theme.of(context).textTheme;

    final visible = BusinessDestination.all.where((d) => d.path != BusinessRoutes.root && (isOwner || !d.ownerOnly));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: BusinessPageHeader(
              title: 'More',
              subtitle: merchant == null ? null : '${merchant.name} · ${isOwner ? 'Owner' : 'Staff'}',
              child: merchant == null
                  ? null
                  : Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.xxs),
                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                          child: MerchantLogo(url: merchant.logoUrl, merchantName: merchant.name, size: AppSize.avatarMd),
                        ),
                        const SizedBox(width: AppSpacing.smd),
                        Expanded(
                          child: Text(
                            account == null ? '' : 'Signed in as ${account.mobileNumber}',
                            style: textTheme.bodySmall?.copyWith(color: AppColors.onBusinessInkMuted),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.xxl + AppSize.fab),
            sliver: SliverList.list(
              children: [
                for (final group in BusinessDestination.groupOrder) ...[
                  if (visible.any((d) => d.group == group)) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
                      child: Text(group.toUpperCase(), style: AppTypography.overline),
                    ),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (final (i, d) in visible.where((d) => d.group == group).indexed) ...[
                            if (i > 0) const Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md),
                            NavLinkRow(
                              icon: d.icon,
                              iconColor: d.gated && !hasPackage ? AppColors.textSecondary : AppColors.businessInk,
                              title: d.label,
                              subtitle: d.subtitle,
                              trailing: d.gated && !hasPackage
                                  ? const Tooltip(
                                      message: 'Select a package',
                                      child: Icon(Icons.lock_outline_rounded, color: AppColors.textSecondary, size: AppIconSize.md),
                                    )
                                  : null,
                              onTap: () => BusinessRoutes.tabs.contains(d.path) ? context.go(d.path) : context.push(d.path),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.section),
                  ],
                ],
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
                  child: Text('APP', style: AppTypography.overline),
                ),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      NavLinkRow(
                        icon: Icons.shopping_bag_rounded,
                        iconColor: AppColors.orange,
                        title: 'Switch to Customer app',
                        subtitle: 'Shop, earn Town Coin and enter the Lucky Draw',
                        onTap: () async {
                          await ref.read(appModeControllerProvider.notifier).select(AppMode.customer);
                          if (context.mounted) context.go('/home');
                        },
                      ),
                      const Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md),
                      NavLinkRow(
                        icon: Icons.support_agent_rounded,
                        iconColor: AppColors.info,
                        title: 'Need help?',
                        subtitle: 'Get support any time from our team',
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Support contact is coming soon.'))),
                      ),
                      const Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md),
                      NavLinkRow(
                        icon: isLoggingOut ? Icons.hourglass_top_rounded : Icons.logout_rounded,
                        iconColor: AppColors.error,
                        title: isLoggingOut ? 'Signing out…' : 'Sign out',
                        // Always tappable so the row keeps its InkWell padding;
                        // the guard is inside AuthController.logout anyway.
                        onTap: () {
                          if (!isLoggingOut) ref.read(authControllerProvider.notifier).logout();
                        },
                        trailing: const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
