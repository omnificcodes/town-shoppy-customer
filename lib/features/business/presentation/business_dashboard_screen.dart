import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/relative_time.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/notification_badge.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';
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
import 'widgets/dashboard_tiles.dart';
import 'widgets/purchase_trend_chart.dart';

/// Business mode's landing screen -- the merchant web dashboard, laid out
/// for one hand: identity band, package banner, four KPIs, purchase trend,
/// quick actions, then the two work queues (recent purchases, redemptions
/// awaiting verification).
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
    final unread = ref.watch(unreadNotificationCountProvider).value ?? 0;
    final hasPackage = entitlement.value?.hasPackage ?? true;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        edgeOffset: 120,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: BusinessPageHeader(
                title: merchant.value?.name ?? 'Your business',
                subtitle: 'Welcome back!',
                actions: [
                  BusinessHeaderIconButton(
                    icon: Icons.notifications_outlined,
                    tooltip: 'Notifications',
                    onTap: () => context.push(BusinessRoutes.notifications),
                    badge: unread > 0 ? NotificationBadge(count: unread, child: const SizedBox.shrink()) : null,
                  ),
                ],
                child: merchant.when(
                  loading: () => const _IdentitySkeleton(),
                  error: (e, _) => Text(
                    e is AppException ? e.message : 'Could not load your business.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.yellow),
                  ),
                  data: (m) => _IdentityBlock(merchant: m),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.xxl + AppSize.fab),
              sliver: SliverList.list(
                children: [
                  if (entitlement.value != null && !hasPackage) ...[
                    _SelectPackageBanner(isOwner: isOwner),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (merchant.value?.isRejected == true && merchant.value?.rejectionReason != null) ...[
                    _RejectionBanner(reason: merchant.value!.rejectionReason!),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _KpiGrid(isOwner: isOwner),
                  const SizedBox(height: AppSpacing.section),
                  _AnalyticsCard(range: _range, onRangeChanged: (r) => setState(() => _range = r)),
                  const SizedBox(height: AppSpacing.section),
                  const SectionHeader(title: 'Quick actions', subtitle: 'Manage your business with ease', icon: Icons.bolt_rounded),
                  const SizedBox(height: AppSpacing.smd),
                  _QuickActions(isOwner: isOwner, hasPackage: hasPackage),
                  const SizedBox(height: AppSpacing.section),
                  SectionHeader(title: 'Recent purchases', actionLabel: 'View all', onAction: () => context.go(BusinessRoutes.purchases)),
                  const SizedBox(height: AppSpacing.smd),
                  const _RecentPurchases(),
                  const SizedBox(height: AppSpacing.section),
                  SectionHeader(title: 'Awaiting verification', actionLabel: 'View all', onAction: () => context.push(BusinessRoutes.redemptions)),
                  const SizedBox(height: AppSpacing.smd),
                  const _AwaitingRedemptions(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityBlock extends StatelessWidget {
  const _IdentityBlock({required this.merchant});

  final BusinessMerchant merchant;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final meta = [merchant.category?.name, merchant.townName].whereType<String>().join(' · ');

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xxs),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
          child: MerchantLogo(url: merchant.logoUrl, merchantName: merchant.name, size: AppSize.avatarLg),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (meta.isNotEmpty)
                Text(meta, style: textTheme.bodySmall?.copyWith(color: AppColors.onBusinessInkMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusBadge(label: merchantStatusLabel(merchant.status), tone: merchantStatusTone(merchant.status)),
                  InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    onTap: () => context.push(BusinessRoutes.profile),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                        border: Border.all(color: AppColors.onBusinessInk.withValues(alpha: 0.4)),
                      ),
                      child: Text('View profile', style: AppTypography.badgeLabel.copyWith(color: AppColors.onBusinessInk)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IdentitySkeleton extends StatelessWidget {
  const _IdentitySkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: AppSize.avatarLg,
          height: AppSize.avatarLg,
          decoration: BoxDecoration(
            color: AppColors.onBusinessInk.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 12, width: 140, color: AppColors.onBusinessInk.withValues(alpha: 0.15)),
              const SizedBox(height: AppSpacing.sm),
              Container(height: 22, width: 96, color: AppColors.onBusinessInk.withValues(alpha: 0.15)),
            ],
          ),
        ),
      ],
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
              Expanded(child: Text('Please select a package', style: textTheme.titleSmall?.copyWith(color: AppColors.pending))),
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
                  TextSpan(text: 'Rejected: ', style: textTheme.titleSmall?.copyWith(color: AppColors.error)),
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

    final tiles = <Widget>[
      DashboardStatTile(
        title: 'Pending purchases',
        value: pendingPurchases.hasError ? '—' : '$pendingCount',
        isLoading: pendingPurchases.isLoading,
        icon: Icons.shopping_bag_rounded,
        tone: pendingCount > 0 ? AppTone.pending : AppTone.success,
        description: pendingPurchases.hasError
            ? 'Could not load'
            : pendingCount == 1
                ? 'purchase needs your approval'
                : 'purchases need your approval',
        onTap: () => context.go(BusinessRoutes.purchases),
      ),
      DashboardStatTile(
        title: 'Awaiting verification',
        value: awaiting.hasError ? '—' : '$awaitingCount',
        isLoading: awaiting.isLoading,
        icon: Icons.qr_code_2_rounded,
        tone: awaitingCount > 0 ? AppTone.pending : AppTone.success,
        description: awaiting.hasError
            ? 'Could not load'
            : awaitingCount == 1
                ? 'redemption needs your attention'
                : 'redemptions need your attention',
        onTap: () => context.push(BusinessRoutes.redemptions),
      ),
      DashboardStatTile(
        title: 'Notifications',
        value: '${unread.value ?? 0}',
        isLoading: unread.isLoading,
        icon: Icons.notifications_rounded,
        tone: AppTone.info,
        description: (unread.value ?? 0) == 1 ? 'unread notification' : 'unread notifications',
        onTap: () => context.push(BusinessRoutes.notifications),
      ),
      if (isOwner)
        subscription.when(
          loading: () => const DashboardStatTile(title: 'Subscription', value: '', isLoading: true, icon: Icons.workspace_premium_rounded, tone: AppTone.neutral),
          error: (_, _) => DashboardStatTile(
            title: 'Subscription',
            value: '—',
            icon: Icons.workspace_premium_rounded,
            tone: AppTone.neutral,
            description: 'Could not load',
            onTap: () => context.push(BusinessRoutes.subscriptions),
          ),
          data: (sub) => sub == null
              ? DashboardStatTile(
                  title: 'Subscription',
                  value: 'No plan',
                  icon: Icons.workspace_premium_rounded,
                  tone: AppTone.pending,
                  description: 'Choose a plan to unlock everything',
                  onTap: () => context.push(BusinessRoutes.subscriptions),
                )
              : DashboardStatTile(
                  title: 'Subscription',
                  value: sub.plan?.name ?? 'Plan',
                  icon: Icons.workspace_premium_rounded,
                  tone: subscriptionStatusTone(sub.status),
                  descriptionWidget: StatusBadge(label: subscriptionStatusLabel(sub.status), tone: subscriptionStatusTone(sub.status)),
                  onTap: () => context.push(BusinessRoutes.subscriptions),
                ),
        )
      else
        const DashboardStatTile(
          title: 'Your access',
          value: 'Staff',
          icon: Icons.badge_rounded,
          tone: AppTone.neutral,
          description: 'Day-to-day operations access',
        ),
    ];

    return _TwoColumnGrid(children: tiles);
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

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Purchases', style: textTheme.titleMedium)),
              const Icon(Icons.insights_rounded, color: AppColors.businessInk, size: AppIconSize.md),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final r in PurchaseStats.ranges) ...[
                  ChoiceChip(
                    label: Text(PurchaseStats.rangeLabel(r)),
                    selected: r == range,
                    selectedColor: AppColors.businessTintStrong,
                    labelStyle: textTheme.labelMedium?.copyWith(color: r == range ? AppColors.businessInk : AppColors.textSecondary),
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
              children: [LoadingSkeleton(width: 80, height: 32), SizedBox(height: AppSpacing.md), LoadingSkeleton(height: 140)],
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
                        child: Text('recorded in the last ${PurchaseStats.rangeLabel(s.range)}', style: textTheme.bodySmall),
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
                          Expanded(child: Text(b.branchName, style: textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
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

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.isOwner, required this.hasPackage});

  final bool isOwner;
  final bool hasPackage;

  @override
  Widget build(BuildContext context) {
    return _TwoColumnGrid(
      children: [
        QuickActionTile(
          title: 'Record a bill',
          description: 'Direct POS at the counter',
          icon: Icons.point_of_sale_rounded,
          tone: AppTone.pending,
          locked: !hasPackage,
          onTap: () => context.push(BusinessRoutes.counter),
        ),
        QuickActionTile(
          title: 'Manage redemptions',
          description: 'Verify and cancel',
          icon: Icons.qr_code_2_rounded,
          tone: AppTone.info,
          locked: !hasPackage,
          onTap: () => context.push(BusinessRoutes.redemptions),
        ),
        QuickActionTile(
          title: 'Create offer',
          description: 'Attract more customers',
          icon: Icons.campaign_rounded,
          tone: AppTone.neutral,
          locked: !hasPackage,
          onTap: () => context.go(BusinessRoutes.offers),
        ),
        if (isOwner)
          QuickActionTile(
            title: 'Sponsor a prize',
            description: 'Support the Lucky Draw',
            icon: Icons.emoji_events_rounded,
            tone: AppTone.success,
            locked: !hasPackage,
            onTap: () => context.push(BusinessRoutes.prizes),
          )
        else
          QuickActionTile(
            title: 'Notifications',
            description: 'Your recent activity',
            icon: Icons.notifications_rounded,
            tone: AppTone.success,
            onTap: () => context.push(BusinessRoutes.notifications),
          ),
      ],
    );
  }
}

class _RecentPurchases extends ConsumerWidget {
  const _RecentPurchases();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchases = ref.watch(dashboardRecentPurchasesProvider);
    final textTheme = Theme.of(context).textTheme;

    return purchases.when(
      loading: () => const Column(children: [LoadingSkeletonCard(), SizedBox(height: AppSpacing.sm), LoadingSkeletonCard()]),
      error: (e, _) => AppCard(
        child: ErrorState(compact: true, error: e is AppException ? e : const UnknownAppException(), onRetry: () => ref.invalidate(dashboardRecentPurchasesProvider)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return AppCard(
            child: Text('No purchases recorded yet.', style: textTheme.bodySmall),
          );
        }
        return AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.smd),
                  child: _QueueRow(
                    amount: items[i].billAmount,
                    createdAt: items[i].createdAt,
                    badge: StatusBadge(label: purchaseStatusLabel(items[i].status), tone: purchaseStatusTone(items[i].status)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AwaitingRedemptions extends ConsumerWidget {
  const _AwaitingRedemptions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(dashboardAwaitingRedemptionsProvider);
    final textTheme = Theme.of(context).textTheme;

    return page.when(
      loading: () => const LoadingSkeletonCard(),
      error: (e, _) => AppCard(
        child: ErrorState(compact: true, error: e is AppException ? e : const UnknownAppException(), onRetry: () => ref.invalidate(dashboardAwaitingRedemptionsProvider)),
      ),
      data: (p) {
        if (p.items.isEmpty) {
          return AppCard(
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: AppIconSize.md),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text("You're all caught up — nothing is waiting on verification.", style: textTheme.bodySmall)),
              ],
            ),
          );
        }
        return AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < p.items.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md),
                InkWell(
                  onTap: () => context.push('${BusinessRoutes.redemptions}/${p.items[i].id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.smd),
                    child: _QueueRow(
                      amount: p.items[i].billAmount,
                      createdAt: p.items[i].createdAt,
                      badge: StatusBadge(label: redemptionStatusLabel(p.items[i].status), tone: redemptionStatusTone(p.items[i].status)),
                      chevron: true,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Two equal columns that fall back to one on a very narrow width -- a
/// dashboard's tiles must never squeeze their numbers.
class _TwoColumnGrid extends StatelessWidget {
  const _TwoColumnGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 300 ? 1 : 2;
        final width = (constraints.maxWidth - AppSpacing.smd * (columns - 1)) / columns;
        return Wrap(
          spacing: AppSpacing.smd,
          runSpacing: AppSpacing.smd,
          children: [for (final child in children) SizedBox(width: width, child: child)],
        );
      },
    );
  }
}

/// One line of a work queue (recent purchases, awaiting verification):
/// amount + time on the left, status badge (and chevron) on the right. The
/// badge is Flexible so a long label ("Awaiting verification") ellipsizes
/// on a narrow phone instead of overflowing the row.
class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.amount, required this.createdAt, required this.badge, this.chevron = false});

  final double amount;
  final DateTime? createdAt;
  final Widget badge;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('₹${amount.toStringAsFixed(2)}', style: AppTypography.numericFinancialSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (createdAt != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(relativeTime(createdAt!), style: AppTypography.caption),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(child: badge),
        if (chevron) ...[
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.chevron_right_rounded, size: AppIconSize.md, color: AppColors.textSecondary),
        ],
      ],
    );
  }
}
