import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../application/business_context.dart';
import 'business_routes.dart';
import 'widgets/business_page_header.dart';

/// Wraps every package-gated Business screen. Until the shop is on a
/// package the child never builds -- the [PackageGateScreen] takes its
/// place, exactly like the web app's `<RequirePackage feature="…">`
/// layouts. The backend enforces the same rule with a 402, so this is
/// presentation, not security.
class RequirePackage extends ConsumerWidget {
  const RequirePackage({super.key, required this.feature, required this.child});

  /// Human label for what is locked ("Purchases", "Your merchant wallet").
  final String feature;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(merchantEntitlementProvider);
    return entitlement.when(
      loading: () => const Scaffold(body: LoadingSkeletonList(count: 5)),
      // merchantEntitlementProvider already fails open; an error here is
      // unreachable in practice, but a blank screen is never acceptable.
      error: (_, _) => child,
      data: (value) => value.hasPackage ? child : PackageGateScreen(feature: feature),
    );
  }
}

/// "Please select a package" -- copy and structure mirror the web gate.
class PackageGateScreen extends ConsumerWidget {
  const PackageGateScreen({super.key, required this.feature});

  final String feature;

  static const _benefits = [
    'Record purchases and issue coupons',
    'Run Direct POS at your counter',
    'Publish offers to your town',
    'Manage branches and counter QR',
    'See your customer directory',
    'Verify Town Coin redemptions',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(isBusinessOwnerProvider);
    final textTheme = Theme.of(context).textTheme;

    return BusinessScaffold(
      title: feature,
      padded: false,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.businessInk, AppColors.businessInkDeep]),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: AppSize.avatarLg,
                  height: AppSize.avatarLg,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: const Icon(Icons.lock_rounded, color: AppColors.yellow, size: AppIconSize.xl),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('LOCKED', style: AppTypography.overline.copyWith(color: AppColors.yellow)),
                const SizedBox(height: AppSpacing.xs),
                Text('Please select a package', style: textTheme.headlineMedium?.copyWith(color: AppColors.onBusinessInk)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '$feature unlocks as soon as your shop is on a Town Shoppy plan. Until then you can still use your dashboard and update your shop profile.',
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.onBusinessInkMuted),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (isOwner)
                  AppButton(
                    label: 'Choose a package',
                    trailingIcon: Icons.arrow_forward_rounded,
                    onPressed: () => context.push(BusinessRoutes.subscriptions),
                  )
                else
                  Text(
                    'Ask the shop owner to choose a package.',
                    style: textTheme.bodyMedium?.copyWith(color: AppColors.yellow, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What a package gives you', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.smd),
                for (final benefit in _benefits)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.verified_rounded, color: AppColors.success, size: AppIconSize.md),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text(benefit, style: textTheme.bodyMedium)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Back to dashboard',
            variant: AppButtonVariant.text,
            onPressed: () => context.go(BusinessRoutes.root),
          ),
        ],
      ),
    );
  }
}
