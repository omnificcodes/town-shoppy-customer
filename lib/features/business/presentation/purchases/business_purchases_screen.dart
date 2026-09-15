import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../notifications/application/unread_count_provider.dart';
import '../../../purchases/data/models/purchase.dart';
import '../../../purchases/presentation/load_more_threshold.dart';
import '../../../purchases/presentation/purchase_status.dart';
import '../../application/business_purchases_controller.dart';
import '../../application/list_range.dart';
import '../business_routes.dart';
import '../widgets/business_dialogs.dart';
import '../widgets/business_page_header.dart';

/// The "Sales" tab, following the Google Stitch redesign: a deep header
/// with the bill amount, purchase count and coins awarded, status pills
/// (the approval queue shows how many are waiting), one search-and-date
/// bar, then every purchase made at this business with Approve/Reject
/// right on a pending row.
///
/// Every figure is the list endpoint's own `meta.totals` for the current
/// filters, so the header always describes the list below it.
class BusinessPurchasesScreen extends ConsumerStatefulWidget {
  const BusinessPurchasesScreen({super.key});

  @override
  ConsumerState<BusinessPurchasesScreen> createState() => _BusinessPurchasesScreenState();
}

class _BusinessPurchasesScreenState extends ConsumerState<BusinessPurchasesScreen> {
  final _scroll = ScrollController();
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - kLoadMoreThreshold) {
        ref.read(businessPurchasesControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _approve(Purchase purchase) async {
    final ok = await showBusinessConfirmDialog(
      context,
      title: 'Approve this purchase?',
      message:
          "Approving this purchase will record the transaction and issue the customer's applicable Town Coins and Lucky Draw coupons.",
      confirmLabel: 'Approve',
    );
    if (!ok || !mounted) return;
    setState(() => _busyId = purchase.id);
    try {
      final updated = await ref.read(businessPurchasesControllerProvider.notifier).approve(purchase.id);
      if (!mounted) return;
      await showPurchaseCelebration(context, title: 'Purchase approved!', coinsAwarded: updated.coinsAwarded);
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.statusCode == 402 ? '${e.message} Visit Subscriptions to choose a plan.' : e.message),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _reject(Purchase purchase) async {
    final reason = await showBusinessReasonDialog(
      context,
      title: 'Reject this purchase',
      message: 'The customer will be notified. No Town Coins or coupons are issued for a rejected purchase.',
      confirmLabel: 'Reject purchase',
      placeholder: 'Why is this purchase being rejected?',
    );
    if (reason == null || !mounted) return;
    setState(() => _busyId = purchase.id);
    try {
      await ref.read(businessPurchasesControllerProvider.notifier).reject(purchase.id, reason: reason);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase rejected.')));
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(purchaseListFiltersProvider);
    final filterController = ref.read(purchaseListFiltersProvider.notifier);
    final state = ref.watch(businessPurchasesControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: RefreshIndicator(
        onRefresh: () => ref.read(businessPurchasesControllerProvider.notifier).refresh(),
        edgeOffset: 120,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _Hero(filters: filters)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: _StatusPills(
                  selected: filters.status,
                  pending: state.value?.totals.pending,
                  onSelected: filterController.setStatus,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.smd, AppSpacing.page, AppSpacing.smd),
                child: _SearchAndDateBar(
                  range: filters.range,
                  onRangeChanged: filterController.setRange,
                  onSearchChanged: filterController.setSearch,
                ),
              ),
            ),
            ...state.when(
              loading: () => [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                  sliver: SliverList.separated(
                    itemCount: 3,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, _) =>
                        LoadingSkeleton(height: 110, borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
                  ),
                ),
              ],
              error: (e, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorState(
                    error: e is AppException ? e : const UnknownAppException(),
                    title: 'Could not load purchases.',
                    onRetry: () => ref.read(businessPurchasesControllerProvider.notifier).refresh(),
                  ),
                ),
              ],
              data: (data) {
                if (data.items.isEmpty) {
                  return [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyPurchases(awaitingApproval: filters.status == 'pending'),
                    ),
                  ];
                }
                return [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      0,
                      AppSpacing.page,
                      AppSpacing.xxl + AppSize.fab,
                    ),
                    sliver: SliverList.separated(
                      itemCount: data.items.length + (data.hasMore ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        if (index >= data.items.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final p = data.items[index];
                        return _PurchaseRow(
                          purchase: p,
                          busy: _busyId == p.id,
                          onTap: () => context.push('${BusinessRoutes.purchases}/${p.id}'),
                          onApprove: () => _approve(p),
                          onReject: () => _reject(p),
                        );
                      },
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The deep maroon header: Business chip, notifications, the title, and
/// the current list's bill amount, purchase count and coins awarded.
class _Hero extends ConsumerWidget {
  const _Hero({required this.filters});

  final PurchaseListFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(businessPurchasesControllerProvider);
    final totals = state.value?.totals;
    final loading = totals == null && state.isLoading;
    final unread = ref.watch(unreadNotificationCountProvider).value ?? 0;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.businessInkDeep, AppColors.businessInk],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppSpacing.xl)),
        boxShadow: AppElevation.floating,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppSpacing.xl)),
        child: Stack(
          children: [
            Positioned(
              right: -AppSpacing.xl,
              top: -AppSpacing.xxl,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.12), shape: BoxShape.circle),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const BusinessModeChip(),
                        const Spacer(),
                        _BellButton(unread: unread),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      header: true,
                      child: Text(
                        'Purchases',
                        style: textTheme.headlineMedium?.copyWith(
                          color: AppColors.onBusinessInk,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Every bill recorded at your business',
                      style: textTheme.bodySmall?.copyWith(color: AppColors.onBusinessInkMuted),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _StatCard(
                      label: 'Bill amount',
                      value: formatMoney(totals?.billAmount ?? 0),
                      hint: 'RECORDED SALES',
                      loading: loading,
                      large: true,
                      trailing: Container(
                        width: AppSize.controlLg,
                        height: AppSize.controlLg,
                        decoration: BoxDecoration(
                          color: AppColors.yellow.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(color: AppColors.yellow.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.currency_rupee_rounded, color: AppColors.yellow, size: AppIconSize.lg),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Total purchases',
                              value: '${totals?.purchases ?? 0}',
                              hint: filters.range.label.toUpperCase(),
                              loading: loading,
                              trailing: Icon(
                                Icons.shopping_bag_outlined,
                                size: AppIconSize.sm,
                                color: AppColors.onBusinessInk.withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _StatCard(
                              label: 'Coins awarded',
                              value: '${totals?.coinsAwarded ?? 0}',
                              hint: 'TOWN COINS',
                              loading: loading,
                              trailing: const Icon(Icons.toll_rounded, size: AppIconSize.sm, color: AppColors.yellow),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
      child: Material(
        color: AppColors.onBusinessInk.withValues(alpha: 0.12),
        shape: CircleBorder(side: BorderSide(color: AppColors.onBusinessInk.withValues(alpha: 0.15))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => context.push(BusinessRoutes.notifications),
          child: SizedBox.square(
            dimension: AppSpacing.touchTarget,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.notifications_outlined, color: AppColors.onBusinessInk, size: AppIconSize.lg),
                if (unread > 0)
                  Positioned(
                    top: AppSpacing.smd,
                    right: AppSpacing.smd,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.businessInk, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A translucent stat card on the maroon header.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.hint,
    required this.loading,
    this.trailing,
    this.large = false,
  });

  final String label;
  final String value;
  final String hint;
  final bool loading;
  final Widget? trailing;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final shownTrailing = trailing;

    return Semantics(
      label: loading ? '$label, loading' : '$label: $value, $hint',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.onBusinessInk.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: large ? AppColors.yellow.withValues(alpha: 0.22) : AppColors.onBusinessInk.withValues(alpha: 0.12),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(large ? AppSpacing.md : AppSpacing.smd),
          child: Row(
            crossAxisAlignment: large ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(color: AppColors.onBusinessInkMuted),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (loading)
                      LoadingSkeleton(width: large ? 120 : 48, height: large ? 32 : 24)
                    else
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: (large ? AppTypography.numericFinancialLarge : AppTypography.numericFinancialMedium)
                              .copyWith(color: AppColors.onBusinessInk, fontWeight: FontWeight.w800),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.overline.copyWith(color: AppColors.yellow, letterSpacing: 0.8),
                    ),
                  ],
                ),
              ),
              if (shownTrailing != null) ...[const SizedBox(width: AppSpacing.sm), shownTrailing],
            ],
          ),
        ),
      ),
    );
  }
}

/// Status pills; the approval queue carries the pending count.
class _StatusPills extends StatelessWidget {
  const _StatusPills({required this.selected, required this.pending, required this.onSelected});

  final String selected;
  final int? pending;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final count = pending;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Row(
        children: [
          for (final (value, label) in PurchaseListFilters.statusOptions) ...[
            _Pill(
              label: label,
              count: value == 'pending' ? count : null,
              selected: value == selected,
              onTap: () => onSelected(value),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.count, required this.selected, required this.onTap});

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.onCrimson : AppColors.textPrimary;
    final shownCount = count;

    return Semantics(
      button: true,
      selected: selected,
      label: shownCount == null ? label : '$label, $shownCount',
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.orangeDeep : AppColors.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.orangeDeep : AppColors.border)),
        elevation: selected ? 2 : 0,
        shadowColor: AppColors.orange.withValues(alpha: 0.4),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSize.controlSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  if (shownCount != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: selected ? AppColors.onCrimson.withValues(alpha: 0.22) : AppColors.orangeTint,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm - 2, vertical: 1),
                        child: Text(
                          '$shownCount',
                          style: AppTypography.badgeLabel.copyWith(
                            color: selected ? AppColors.onCrimson : AppColors.orangeDeep,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One white bar: a debounced search field and a date-range menu.
class _SearchAndDateBar extends StatefulWidget {
  const _SearchAndDateBar({required this.range, required this.onRangeChanged, required this.onSearchChanged});

  final ListRange range;
  final ValueChanged<ListRange> onRangeChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  State<_SearchAndDateBar> createState() => _SearchAndDateBarState();
}

class _SearchAndDateBarState extends State<_SearchAndDateBar> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => widget.onSearchChanged(value.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final active = widget.range != ListRange.all;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Icon(Icons.search_rounded, size: AppIconSize.md, color: AppColors.textSecondary),
            ),
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: _onSearch,
                textInputAction: TextInputAction.search,
                style: textTheme.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'Reference or amount…',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.smd),
                ),
              ),
            ),
            Container(width: 1, height: AppSpacing.lg, color: AppColors.border),
            const SizedBox(width: AppSpacing.xs),
            PopupMenuButton<ListRange>(
              tooltip: 'Date range',
              initialValue: widget.range,
              onSelected: widget.onRangeChanged,
              itemBuilder: (context) => [
                for (final r in ListRange.values) PopupMenuItem<ListRange>(value: r, child: Text(r.label)),
              ],
              child: Container(
                constraints: const BoxConstraints(minHeight: AppSize.controlSm),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd),
                decoration: BoxDecoration(
                  color: active ? AppColors.orangeTint : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: AppIconSize.sm, color: AppColors.orangeDeep),
                    const SizedBox(width: AppSpacing.xs),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: Text(
                        widget.range == ListRange.all ? 'Any date' : widget.range.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelLarge?.copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down_rounded, size: AppIconSize.md, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPurchases extends StatelessWidget {
  const _EmptyPurchases({required this.awaitingApproval});

  final bool awaitingApproval;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.lg, AppSpacing.page, AppSpacing.xxl + AppSize.fab),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ExcludeSemantics(
            child: SizedBox.square(
              dimension: 112,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.08), shape: BoxShape.circle),
                  ),
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: AppGradients.warmWash,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      border: Border.all(color: AppColors.orangeBorder),
                      boxShadow: AppElevation.card,
                    ),
                    child: const Icon(
                      Icons.point_of_sale_rounded,
                      color: AppColors.orangeDeep,
                      size: AppIconSize.display,
                    ),
                  ),
                  if (awaitingApproval)
                    Positioned(
                      top: AppSpacing.xs,
                      right: AppSpacing.xs,
                      child: Container(
                        width: AppIconSize.lg,
                        height: AppIconSize.lg,
                        decoration: BoxDecoration(
                          color: AppColors.orangeDeep,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surface, width: 2),
                        ),
                        child: const Icon(Icons.check_rounded, color: AppColors.onCrimson, size: AppIconSize.sm),
                      ),
                    ),
                  const Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: Icon(Icons.auto_awesome_rounded, color: AppColors.gold, size: AppIconSize.sm),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            awaitingApproval ? 'Nothing awaiting approval' : 'No purchases yet',
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            awaitingApproval
                ? "You're all caught up. New scan-and-submit requests from customers will appear here."
                : 'Purchases will appear here once a customer buys from your business.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.pendingBg,
              borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
              border: Border.all(color: AppColors.pending.withValues(alpha: 0.25)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.smd),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.pending, size: AppIconSize.md),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text.rich(
                      const TextSpan(
                        children: [
                          TextSpan(
                            text: 'How purchases arrive: ',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          TextSpan(
                            text:
                                'customers scan your counter QR to send a bill for approval, or you record one yourself with Direct POS.',
                          ),
                        ],
                      ),
                      style: AppTypography.caption.copyWith(color: AppColors.pending),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _RecordButton(onTap: () => context.push(BusinessRoutes.counter)),
        ],
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusMd);

    return Semantics(
      button: true,
      label: 'Record a purchase (Direct POS)',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: AppElevation.floating),
        child: Material(
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: const BoxDecoration(gradient: AppGradients.promoHero),
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSize.controlLg + AppSpacing.xs),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.point_of_sale_rounded, color: AppColors.onCrimson),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          'Record a purchase (Direct POS)',
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(color: AppColors.onCrimson, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PurchaseRow extends StatelessWidget {
  const _PurchaseRow({
    required this.purchase,
    required this.busy,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
  });

  final Purchase purchase;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = purchaseStatusLabel(purchase.status);
    final radius = BorderRadius.circular(AppSpacing.radiusLg);

    return Semantics(
      button: true,
      label: 'Purchase #${purchase.id}, ${formatMoney(purchase.billAmount)}, $label',
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: AppElevation.card),
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: purchase.isPending ? AppColors.orangeBorder : AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: AppSize.controlSm,
                        height: AppSize.controlSm,
                        decoration: BoxDecoration(
                          color: AppColors.orangeTint,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: AppColors.orangeDeep,
                          size: AppIconSize.md,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.smd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(formatMoney(purchase.billAmount), style: AppTypography.numericFinancialMedium),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              [
                                '#${purchase.id}',
                                if (purchase.billReference != null && purchase.billReference!.isNotEmpty)
                                  'Ref. ${purchase.billReference}',
                                if (purchase.branch != null) purchase.branch!.name,
                                if (purchase.createdAt != null) relativeTime(purchase.createdAt!),
                              ].join(' · '),
                              style: AppTypography.caption,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            StatusBadge(label: label, tone: purchaseStatusTone(purchase.status)),
                            if (purchase.coinsAwarded > 0) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                '+${purchase.coinsAwarded} coins',
                                style: AppTypography.numericFinancialInline.copyWith(color: AppColors.success),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (purchase.isPending) ...[
                    const SizedBox(height: AppSpacing.smd),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Reject',
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.sm,
                            icon: Icons.block_rounded,
                            onPressed: busy ? null : onReject,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppButton(
                            label: 'Approve',
                            size: AppButtonSize.sm,
                            icon: Icons.verified_rounded,
                            isLoading: busy,
                            onPressed: onApprove,
                          ),
                        ),
                      ],
                    ),
                  ] else if (purchase.isRejected && purchase.rejectionReason != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Reason: ${purchase.rejectionReason}',
                      style: textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
