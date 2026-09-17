import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/relative_time.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/notification_badge.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../merchants/presentation/category_visual.dart';
import '../../merchants/presentation/merchant_logo.dart';
import '../../notifications/application/unread_count_provider.dart';
import '../../purchases/presentation/purchase_status.dart';
import '../../redemptions/presentation/redemption_status.dart';
import '../application/business_context.dart';
import '../data/models/business_merchant.dart';
import '../data/models/purchase_stats.dart';
import 'business_routes.dart';
import 'business_status.dart';
import 'widgets/business_page_header.dart';
import 'widgets/purchase_trend_chart.dart';

/// Business mode's landing screen, following the Google Stitch redesign: a
/// light header, the shop's identity card with its approval status, four
/// KPI tiles, quick actions, the purchase trend, a pointer to everything
/// else, and one recent-activity feed.
///
/// Every figure is live: `myMerchantProvider`, the entitlement and
/// subscription, the pending-purchase count, the redemptions awaiting
/// verification, unread notifications and purchase stats. Stitch's script
/// slogan and bakery illustration are replaced by the brand tagline and the
/// shop's own category icon, so the card suits any kind of shop.
class BusinessDashboardScreen extends ConsumerStatefulWidget {
  const BusinessDashboardScreen({super.key});

  @override
  ConsumerState<BusinessDashboardScreen> createState() => _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends ConsumerState<BusinessDashboardScreen> {
  String _range = '30d';

  Future<void> _refresh() async {
    ref
      ..invalidate(myMerchantProvider)
      ..invalidate(merchantEntitlementProvider)
      ..invalidate(dashboardPendingPurchasesCountProvider)
      ..invalidate(dashboardAwaitingRedemptionsProvider)
      ..invalidate(dashboardRecentPurchasesProvider)
      ..invalidate(unreadNotificationCountProvider)
      ..invalidate(mySubscriptionProvider)
      ..invalidate(purchaseStatsProvider(_range));
    try {
      await ref.read(myMerchantProvider.future);
    } on AppException {
      // The dashboard's own error surfaces show the failure.
    }
  }

  @override
  Widget build(BuildContext context) {
    final merchant = ref.watch(myMerchantProvider);
    final entitlement = ref.watch(merchantEntitlementProvider);
    final isOwner = ref.watch(isBusinessOwnerProvider);
    final hasPackage = entitlement.value?.hasPackage ?? true;

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: _Header()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.xs,
                  AppSpacing.page,
                  AppSpacing.xxl + AppSize.fab,
                ),
                sliver: SliverList.list(
                  children: [
                    merchant.when(
                      loading: () =>
                          LoadingSkeleton(height: 250, borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
                      error: (e, _) => AppCard(
                        child: ErrorState(
                          compact: true,
                          error: e is AppException ? e : const UnknownAppException(),
                          onRetry: () => ref.invalidate(myMerchantProvider),
                        ),
                      ),
                      data: (m) => _IdentityCard(merchant: m),
                    ),
                    if (entitlement.value != null && !hasPackage) ...[
                      const SizedBox(height: AppSpacing.md),
                      _SelectPackageBanner(isOwner: isOwner),
                    ],
                    if (merchant.value?.isRejected == true && merchant.value?.rejectionReason != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _RejectionBanner(reason: merchant.value!.rejectionReason!),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    _KpiGrid(isOwner: isOwner),
                    const SizedBox(height: AppSpacing.md),
                    _QuickActions(isOwner: isOwner, hasPackage: hasPackage),
                    const SizedBox(height: AppSpacing.md),
                    _AnalyticsCard(range: _range, onRangeChanged: (r) => setState(() => _range = r)),
                    const SizedBox(height: AppSpacing.md),
                    const _GrowBanner(),
                    const SizedBox(height: AppSpacing.md),
                    const _RecentActivity(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Light header row: the More hub, the Town Shoppy logo, and notifications.
class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider).value ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.smd),
      child: Row(
        children: [
          _HeaderButton(icon: Icons.menu_rounded, tooltip: 'More', onTap: () => context.go(BusinessRoutes.more)),
          Expanded(
            child: Center(
              child: Semantics(
                label: 'Town Shoppy',
                image: true,
                child: Image.asset('assets/images/townshoppy_logo.png', height: AppSize.controlMd, fit: BoxFit.contain),
              ),
            ),
          ),
          _HeaderButton(
            icon: Icons.notifications_outlined,
            tooltip: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
            onTap: () => context.push(BusinessRoutes.notifications),
            badgeCount: unread,
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.tooltip, required this.onTap, this.badgeCount = 0});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  /// Unread count shown on the icon's top-right; nothing when zero.
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusMd);

    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: AppElevation.card),
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: const BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: SizedBox.square(
              dimension: AppSpacing.touchTarget,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, color: AppColors.textPrimary, size: AppIconSize.lg),
                  // Tucked into the button's top-right corner, fully inside
                  // it: clear of the screen edge, and only grazing the bell.
                  if (badgeCount > 0) Positioned(top: 2, right: 2, child: _CountBadge(count: badgeCount)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The unread count on a header button -- the same crimson pill as
/// [NotificationBadge], sized to sit inside a 48dp button.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.crimson,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: AppColors.surface, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 9 ? '9+' : '$count',
        style: AppTypography.overline.copyWith(color: AppColors.onCrimson, letterSpacing: 0, height: 1.1),
      ),
    );
  }
}

/// The shop's identity on a deep maroon card -- the business mode's own
/// ground -- with where it stands on Town Shoppy.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.merchant});

  final BusinessMerchant merchant;

  static String _statusCopy(String status) => switch (status) {
    'pending' => "Your profile is under review. We'll notify you once it's approved.",
    'active' => 'Your shop is live for customers on Town Shoppy.',
    'rejected' => 'Your application was not approved. The reason is shown below.',
    'subscription_expired' => 'Your plan has ended, so customer features are paused.',
    'suspended' => 'Your shop is suspended, so customer features are paused.',
    _ => 'Your shop is not visible to customers right now.',
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final category = merchant.category;
    final visual = category == null
        ? CategoryVisual.fallback
        : CategoryVisual.forCategory(name: category.name, slug: category.slug);
    final meta = [category?.name, merchant.townName].whereType<String>().where((p) => p.isNotEmpty).join(' · ');
    final (statusBg, statusFg) = merchantStatusTone(merchant.status).colors;
    final radius = BorderRadius.circular(AppSpacing.radiusLg);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.businessInkDeep, AppColors.businessInk],
        ),
        boxShadow: AppElevation.floating,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(
              right: -AppSpacing.xl,
              top: -AppSpacing.xl,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.16), shape: BoxShape.circle),
              ),
            ),
            Positioned(
              right: AppSpacing.md,
              top: AppSpacing.xxl,
              child: ExcludeSemantics(
                child: Icon(visual.icon, size: 96, color: AppColors.yellow.withValues(alpha: 0.16)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BusinessModeChip(),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Shop Local.\nWin Local.',
                          textAlign: TextAlign.right,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.goldLight,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    merchant.name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.headlineSmall?.copyWith(
                      color: AppColors.onBusinessInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: AppIconSize.sm, color: AppColors.yellow),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(color: AppColors.onBusinessInkMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                          child: MerchantLogo(
                            url: merchant.logoUrl,
                            merchantName: merchant.name,
                            size: AppSize.avatarLg - AppSpacing.xs,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.smd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xxs,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      merchant.isActive ? Icons.verified_rounded : Icons.schedule_rounded,
                                      size: AppIconSize.xs,
                                      color: statusFg,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Flexible(
                                      child: Text(
                                        merchantStatusLabel(merchant.status),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.badgeLabel.copyWith(color: statusFg),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _statusCopy(merchant.status),
                              style: AppTypography.caption.copyWith(color: AppColors.onBusinessInkMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Material(
                    color: AppColors.onBusinessInk.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                      side: BorderSide(color: AppColors.onBusinessInk.withValues(alpha: 0.25)),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                      onTap: () => context.push(BusinessRoutes.profile),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: AppSize.controlSm),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View profile',
                                style: textTheme.labelLarge?.copyWith(
                                  color: AppColors.onBusinessInk,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: AppIconSize.sm,
                                color: AppColors.onBusinessInk,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectPackageBanner extends StatelessWidget {
  const _SelectPackageBanner({required this.isOwner});

  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.pendingBg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.pending.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_rounded, color: AppColors.pending, size: AppIconSize.md),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Please select a package', style: textTheme.titleSmall?.copyWith(color: AppColors.pending)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isOwner
                ? 'Purchases, offers, branches, customers and redemptions stay locked until your shop is on a plan.'
                : 'Your shop is not on a plan yet, so most features are locked. Ask the shop owner to choose a package.',
            style: textTheme.bodySmall,
          ),
          if (isOwner) ...[
            const SizedBox(height: AppSpacing.smd),
            AppButton(
              label: 'Choose a package',
              size: AppButtonSize.sm,
              expand: false,
              trailingIcon: Icons.arrow_forward_rounded,
              onPressed: () => context.push(BusinessRoutes.subscriptions),
            ),
          ],
        ],
      ),
    );
  }
}

class _RejectionBanner extends StatelessWidget {
  const _RejectionBanner({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: AppIconSize.md),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: textTheme.bodySmall,
                children: [
                  TextSpan(
                    text: 'Rejected: ',
                    style: textTheme.titleSmall?.copyWith(color: AppColors.error),
                  ),
                  TextSpan(text: reason),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends ConsumerWidget {
  const _KpiGrid({required this.isOwner});

  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingPurchases = ref.watch(dashboardPendingPurchasesCountProvider);
    final awaiting = ref.watch(dashboardAwaitingRedemptionsProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    final subscription = ref.watch(mySubscriptionProvider);

    final pendingCount = pendingPurchases.value ?? 0;
    final awaitingCount = awaiting.value?.total ?? 0;
    final unreadCount = unread.value ?? 0;

    final tiles = <Widget>[
      _KpiTile(
        title: 'Pending purchases',
        value: pendingPurchases.hasError ? '—' : '$pendingCount',
        isLoading: pendingPurchases.isLoading,
        icon: Icons.shopping_bag_rounded,
        color: AppColors.orangeDeep,
        background: AppColors.orangeTint,
        description: pendingPurchases.hasError
            ? 'Could not load'
            : pendingCount == 1
            ? 'purchase needs your approval'
            : 'purchases need your approval',
        onTap: () => context.go(BusinessRoutes.purchases),
      ),
      _KpiTile(
        title: 'Awaiting verification',
        value: awaiting.hasError ? '—' : '$awaitingCount',
        isLoading: awaiting.isLoading,
        icon: Icons.qr_code_2_rounded,
        color: AppColors.success,
        background: AppColors.successBg,
        description: awaiting.hasError
            ? 'Could not load'
            : awaitingCount == 1
            ? 'redemption needs your attention'
            : 'redemptions need your attention',
        onTap: () => context.push(BusinessRoutes.redemptions),
      ),
      _KpiTile(
        title: 'Notifications',
        value: '$unreadCount',
        isLoading: unread.isLoading,
        icon: Icons.notifications_rounded,
        color: AppColors.info,
        background: AppColors.infoBg,
        description: unreadCount == 1 ? 'unread notification' : 'unread notifications',
        onTap: () => context.push(BusinessRoutes.notifications),
      ),
      if (isOwner)
        subscription.when(
          loading: () => const _KpiTile(
            title: 'Subscription',
            value: '',
            isLoading: true,
            icon: Icons.workspace_premium_rounded,
            color: AppColors.crimson,
            background: AppColors.errorBg,
          ),
          error: (_, _) => _KpiTile(
            title: 'Subscription',
            value: '—',
            icon: Icons.workspace_premium_rounded,
            color: AppColors.crimson,
            background: AppColors.errorBg,
            description: 'Could not load',
            onTap: () => context.push(BusinessRoutes.subscriptions),
          ),
          data: (sub) {
            if (sub == null) {
              return _KpiTile(
                title: 'Subscription',
                value: 'No plan',
                compactValue: true,
                icon: Icons.workspace_premium_rounded,
                color: AppColors.crimson,
                background: AppColors.errorBg,
                description: 'Choose a plan to unlock everything',
                onTap: () => context.push(BusinessRoutes.subscriptions),
              );
            }
            final (_, statusFg) = subscriptionStatusTone(sub.status).colors;
            return _KpiTile(
              title: 'Subscription',
              value: sub.plan?.name ?? 'Plan',
              compactValue: true,
              icon: Icons.workspace_premium_rounded,
              color: AppColors.crimson,
              background: AppColors.errorBg,
              footer: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: statusFg, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      subscriptionStatusLabel(sub.status),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.badgeLabel.copyWith(color: statusFg),
                    ),
                  ),
                ],
              ),
              onTap: () => context.push(BusinessRoutes.subscriptions),
            );
          },
        )
      else
        const _KpiTile(
          title: 'Your access',
          value: 'Staff',
          compactValue: true,
          icon: Icons.badge_rounded,
          color: AppColors.silverDark,
          background: AppColors.silverLight,
          description: 'Day-to-day operations access',
        ),
    ];

    return _TwoColumnGrid(children: tiles);
  }
}

/// One soft-tinted KPI: icon and chevron on top, then the label, the value
/// and what it means.
class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.background,
    this.description,
    this.footer,
    this.onTap,
    this.isLoading = false,
    this.compactValue = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color background;
  final String? description;
  final Widget? footer;
  final VoidCallback? onTap;
  final bool isLoading;

  /// A word (a plan name) rather than a count, set smaller but kept in the
  /// same band a count occupies.
  final bool compactValue;

  /// The height one line of the large count takes at the current text size.
  static double _valueBandHeight(BuildContext context) {
    const style = AppTypography.numericFinancialLarge;
    final lines = MediaQuery.textScalerOf(context).scale(style.fontSize ?? 28);
    return lines * (style.height ?? 1.2);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusMd);
    final shownDescription = description;
    final shownFooter = footer;

    return Semantics(
      button: onTap != null,
      label: [title, if (!isLoading) value, ?shownDescription].join(', '),
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: color.withValues(alpha: 0.2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: AppSize.controlSm,
                      height: AppSize.controlSm,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                      ),
                      child: Icon(icon, color: color, size: AppIconSize.md),
                    ),
                    const Spacer(),
                    if (onTap != null)
                      Container(
                        width: AppIconSize.lg,
                        height: AppIconSize.lg,
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
                        child: Icon(Icons.chevron_right_rounded, color: color, size: AppIconSize.sm),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xxs),
                if (isLoading)
                  const LoadingSkeleton(width: 56, height: 26)
                else
                  compactValue
                      // A word sits in the same band as a big count, so the
                      // caption or status under it lines up with the tile
                      // beside it.
                      ? SizedBox(
                          height: _valueBandHeight(context),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            value,
                            style: AppTypography.numericFinancialLarge.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                if (shownDescription != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(shownDescription, style: AppTypography.caption),
                ],
                if (shownFooter != null) ...[const SizedBox(height: AppSpacing.xs), shownFooter],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A white panel with an icon, a title and an optional trailing widget --
/// the frame for Quick Actions, the trend and Recent Activity.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: AppIconSize.xl,
                  height: AppIconSize.xl,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(icon, color: iconColor, size: AppIconSize.sm),
                ),
                const SizedBox(width: AppSpacing.sm),
                // The title claims most of the row; a flexible trailing
                // caption shares what is left and ellipsizes first.
                Flexible(
                  flex: 3,
                  fit: FlexFit.tight,
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: AppSpacing.sm), trailing!],
              ],
            ),
            const SizedBox(height: AppSpacing.smd),
            child,
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.isOwner, required this.hasPackage});

  final bool isOwner;
  final bool hasPackage;

  @override
  Widget build(BuildContext context) {
    final locked = !hasPackage;

    final actions = <Widget>[
      _ActionTile(
        label: 'Record purchase',
        icon: Icons.point_of_sale_rounded,
        color: AppColors.orangeDeep,
        locked: locked,
        onTap: () => context.push(BusinessRoutes.counter),
      ),
      _ActionTile(
        label: 'Manage customers',
        icon: Icons.people_alt_rounded,
        color: AppColors.success,
        locked: locked,
        onTap: () => context.push(BusinessRoutes.customers),
      ),
      if (isOwner)
        _ActionTile(
          label: 'Manage prizes',
          icon: Icons.emoji_events_rounded,
          color: AppColors.info,
          locked: locked,
          onTap: () => context.push(BusinessRoutes.prizes),
        )
      else
        _ActionTile(
          label: 'Verify redemptions',
          icon: Icons.qr_code_2_rounded,
          color: AppColors.info,
          locked: locked,
          onTap: () => context.push(BusinessRoutes.redemptions),
        ),
      // Staff can see offers but never create them, same split the backend
      // policy enforces.
      if (isOwner)
        _ActionTile(
          label: 'Create offers',
          icon: Icons.campaign_rounded,
          color: AppColors.crimson,
          locked: locked,
          onTap: () => context.push(BusinessRoutes.offerNew),
        )
      else
        _ActionTile(
          label: 'View offers',
          icon: Icons.campaign_rounded,
          color: AppColors.crimson,
          locked: locked,
          onTap: () => context.go(BusinessRoutes.offers),
        ),
    ];

    return _Panel(
      icon: Icons.bolt_rounded,
      iconColor: AppColors.goldDark,
      iconBackground: AppColors.goldLight,
      title: 'Quick Actions',
      trailing: Flexible(
        flex: 2,
        child: Text(
          'Manage your business easily',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: AppTypography.caption,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 300 ? 2 : 4;
          final width = (constraints.maxWidth - AppSpacing.sm * (columns - 1)) / columns;
          return Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [for (final action in actions) SizedBox(width: width, child: action)],
          );
        },
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.locked,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusMd);

    return Semantics(
      button: true,
      label: locked ? '$label, needs a package' : label,
      excludeSemantics: true,
      child: Material(
        color: color.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: color.withValues(alpha: 0.16)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.smd),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: AppSize.controlLg,
                      height: AppSize.controlLg,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: Icon(icon, color: color, size: AppIconSize.lg),
                    ),
                    if (locked)
                      Positioned(
                        right: -AppSpacing.xs,
                        top: -AppSpacing.xs,
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.xxs),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(Icons.lock_rounded, size: AppIconSize.xs, color: AppColors.pending),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyticsCard extends ConsumerWidget {
  const _AnalyticsCard({required this.range, required this.onRangeChanged});

  final String range;
  final ValueChanged<String> onRangeChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(purchaseStatsProvider(range));
    final textTheme = Theme.of(context).textTheme;

    return _Panel(
      icon: Icons.insights_rounded,
      iconColor: AppColors.businessInk,
      iconBackground: AppColors.businessTint,
      title: 'Purchases',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final r in PurchaseStats.ranges) ...[
                  ChoiceChip(
                    label: Text(PurchaseStats.rangeLabel(r)),
                    selected: r == range,
                    selectedColor: AppColors.businessTintStrong,
                    labelStyle: textTheme.labelMedium?.copyWith(
                      color: r == range ? AppColors.businessInk : AppColors.textSecondary,
                    ),
                    side: BorderSide(color: r == range ? AppColors.businessInk : AppColors.border),
                    showCheckmark: false,
                    onSelected: (_) => onRangeChanged(r),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          stats.when(
            loading: () => const Column(
              children: [
                LoadingSkeleton(width: 80, height: 32),
                SizedBox(height: AppSpacing.md),
                LoadingSkeleton(height: 140),
              ],
            ),
            error: (e, _) => ErrorState(
              compact: true,
              error: e is AppException ? e : const UnknownAppException(),
              onRetry: () => ref.invalidate(purchaseStatsProvider(range)),
            ),
            data: (s) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${s.total}', style: AppTypography.numericFinancialLarge),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(
                          'recorded in the last ${PurchaseStats.rangeLabel(s.range)}',
                          style: textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                PurchaseTrendChart(points: s.trend),
                if (s.byBranch.length > 1) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Divider(),
                  const SizedBox(height: AppSpacing.sm),
                  Text('By branch', style: textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  for (final b in s.byBranch)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              b.branchName,
                              style: textTheme.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text('${b.count}', style: AppTypography.numericFinancialSmall),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A pointer to everything the dashboard doesn't show -- the More hub.
class _GrowBanner extends StatelessWidget {
  const _GrowBanner();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGradients.warmWash,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.orangeBorder),
        boxShadow: AppElevation.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: AppSize.controlLg + AppSpacing.xs,
                  height: AppSize.controlLg + AppSpacing.xs,
                  decoration: BoxDecoration(
                    gradient: AppGradients.promoHero,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    boxShadow: AppElevation.floating,
                  ),
                  child: const Icon(Icons.card_giftcard_rounded, color: AppColors.onCrimson, size: AppIconSize.xl),
                ),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Grow your business with Town Shoppy',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Run offers · Put your brand on a Lucky Draw · Build a loyal local following',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.smd),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                label: 'Explore features',
                size: AppButtonSize.sm,
                expand: false,
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: () => context.go(BusinessRoutes.more),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One feed of the latest purchases and the redemptions waiting on this
/// shop, newest first.
class _RecentActivity extends ConsumerWidget {
  const _RecentActivity();

  static const _limit = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchases = ref.watch(dashboardRecentPurchasesProvider);
    final redemptions = ref.watch(dashboardAwaitingRedemptionsProvider);

    final Widget body;
    if (purchases.isLoading || redemptions.isLoading) {
      body = const Column(
        children: [
          LoadingSkeletonCard(),
          SizedBox(height: AppSpacing.sm),
          LoadingSkeletonCard(),
        ],
      );
    } else if (purchases.hasError && redemptions.hasError) {
      final error = purchases.error;
      body = ErrorState(
        compact: true,
        error: error is AppException ? error : const UnknownAppException(),
        onRetry: () => ref
          ..invalidate(dashboardRecentPurchasesProvider)
          ..invalidate(dashboardAwaitingRedemptionsProvider),
      );
    } else {
      final entries = <_ActivityEntry>[
        for (final p in purchases.value ?? const [])
          _ActivityEntry(
            icon: Icons.receipt_long_rounded,
            color: AppColors.orangeDeep,
            title: 'Purchase ₹${p.billAmount.toStringAsFixed(2)}',
            createdAt: p.createdAt,
            badge: StatusBadge(label: purchaseStatusLabel(p.status), tone: purchaseStatusTone(p.status)),
            path: '${BusinessRoutes.purchases}/${p.id}',
          ),
        for (final r in redemptions.value?.items ?? const [])
          _ActivityEntry(
            icon: Icons.qr_code_2_rounded,
            color: AppColors.success,
            title: 'Redemption ₹${r.billAmount.toStringAsFixed(2)}',
            createdAt: r.createdAt,
            badge: StatusBadge(label: redemptionStatusLabel(r.status), tone: redemptionStatusTone(r.status)),
            path: '${BusinessRoutes.redemptions}/${r.id}',
          ),
      ]..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

      body = entries.isEmpty
          ? const _EmptyActivity()
          : Column(
              children: [
                for (var i = 0; i < entries.length && i < _limit; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.border),
                  _ActivityRow(entry: entries[i]),
                ],
              ],
            );
    }

    return _Panel(
      icon: Icons.schedule_rounded,
      iconColor: AppColors.orangeDeep,
      iconBackground: AppColors.orangeTint,
      title: 'Recent Activity',
      trailing: TextButton(
        onPressed: () => context.go(BusinessRoutes.purchases),
        style: TextButton.styleFrom(foregroundColor: AppColors.orangeDeep, visualDensity: VisualDensity.compact),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('View all'),
            Icon(Icons.chevron_right_rounded, size: AppIconSize.sm),
          ],
        ),
      ),
      child: body,
    );
  }
}

class _ActivityEntry {
  const _ActivityEntry({
    required this.icon,
    required this.color,
    required this.title,
    required this.createdAt,
    required this.badge,
    required this.path,
  });

  final IconData icon;
  final Color color;
  final String title;
  final DateTime? createdAt;
  final Widget badge;
  final String path;
}

/// One line of the feed: what happened and when on the left, its status
/// on the right. The badge is Flexible so a long label ("Awaiting
/// verification") ellipsizes on a narrow phone instead of overflowing.
class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry});

  final _ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final createdAt = entry.createdAt;

    return InkWell(
      onTap: () => context.push(entry.path),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.smd),
        child: Row(
          children: [
            Container(
              width: AppSize.controlSm,
              height: AppSize.controlSm,
              decoration: BoxDecoration(
                color: entry.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
              ),
              child: Icon(entry.icon, color: entry.color, size: AppIconSize.md),
            ),
            const SizedBox(width: AppSpacing.smd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.numericFinancialSmall,
                  ),
                  if (createdAt != null) Text(relativeTime(createdAt), style: AppTypography.caption),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(child: entry.badge),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.chevron_right_rounded, size: AppIconSize.md, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.lg),
        child: Column(
          children: [
            Container(
              width: AppSize.controlLg,
              height: AppSize.controlLg,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.find_in_page_outlined, color: AppColors.textSecondary, size: AppIconSize.lg),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No recent activity',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'New purchases and redemptions will appear here.',
              textAlign: TextAlign.center,
              style: AppTypography.caption,
            ),
          ],
        ),
      ),
    );
  }
}

/// Two equal columns that fall back to one on a very narrow width -- a
/// dashboard's tiles must never squeeze their numbers. Tiles sharing a row
/// are stretched to the same height, so their edges and contents line up.
class _TwoColumnGrid extends StatelessWidget {
  const _TwoColumnGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 300 ? 1 : 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var start = 0; start < children.length; start += columns) ...[
              if (start > 0) const SizedBox(height: AppSpacing.smd),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < columns; i++) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.smd),
                      Expanded(
                        child: start + i < children.length ? children[start + i] : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
