import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../purchases/data/models/purchase.dart';
import '../../../purchases/presentation/load_more_threshold.dart';
import '../../../purchases/presentation/purchase_status.dart';
import '../../application/business_purchases_controller.dart';
import '../business_routes.dart';
import '../widgets/business_dialogs.dart';
import '../widgets/business_list_filters.dart';
import '../widgets/business_page_header.dart';
import '../widgets/business_stat_strip.dart';

/// The "Sales" tab: every purchase made at this business, however it was
/// submitted. Opens on the approval queue (`pending`), the way the web
/// does, with Approve/Reject right on the row.
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
      message: "Approving this purchase will record the transaction and issue the customer's applicable Town Coins and Lucky Draw coupons.",
      confirmLabel: 'Approve',
    );
    if (!ok || !mounted) return;
    setState(() => _busyId = purchase.id);
    try {
      final updated = await ref.read(businessPurchasesControllerProvider.notifier).approve(purchase.id);
      if (!mounted) return;
      await showPurchaseCelebration(context, title: 'Purchase approved!', coinsAwarded: updated.coinsAwarded);
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.statusCode == 402 ? '${e.message} Visit Subscriptions to choose a plan.' : e.message)));
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
    final state = ref.watch(businessPurchasesControllerProvider);
    final totals = state.value?.totals;

    return Scaffold(
      body: Column(
        children: [
          BusinessPageHeader(
            title: 'Purchases',
            subtitle: 'Every bill recorded at your business',
            child: BusinessStatStrip(
              isLoading: totals == null && state.isLoading,
              stats: [
                BusinessStat(label: 'Total purchases', value: '${totals?.purchases ?? 0}', hint: filters.range.label.toUpperCase()),
                BusinessStat(label: 'Bill amount', value: formatMoney(totals?.billAmount ?? 0), hint: 'RECORDED SALES'),
                BusinessStat(label: 'Coins awarded', value: '${totals?.coinsAwarded ?? 0}'),
                BusinessStat(label: 'Pending approval', value: '${totals?.pending ?? 0}', hint: 'AWAITING REVIEW'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          BusinessListFilters(
            statusOptions: PurchaseListFilters.statusOptions,
            status: filters.status,
            onStatusChanged: ref.read(purchaseListFiltersProvider.notifier).setStatus,
            range: filters.range,
            onRangeChanged: ref.read(purchaseListFiltersProvider.notifier).setRange,
            searchHint: 'Reference or amount…',
            onSearchChanged: ref.read(purchaseListFiltersProvider.notifier).setSearch,
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: state.when(
              loading: () => const LoadingSkeletonList(),
              error: (e, _) => ErrorState(
                error: e is AppException ? e : const UnknownAppException(),
                title: 'Could not load purchases.',
                onRetry: () => ref.read(businessPurchasesControllerProvider.notifier).refresh(),
              ),
              data: (data) {
                if (data.items.isEmpty) {
                  final pending = filters.status == 'pending';
                  return EmptyState(
                    icon: Icons.shopping_bag_outlined,
                    title: pending ? 'Nothing awaiting approval' : 'No purchases yet',
                    message: pending
                        ? "You're all caught up. New scan-and-submit requests will appear here."
                        : 'Purchases will appear here once a customer buys from your business.',
                    action: AppButton(
                      label: 'Record a purchase (Direct POS)',
                      icon: Icons.point_of_sale_rounded,
                      expand: false,
                      onPressed: () => context.push(BusinessRoutes.counter),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(businessPurchasesControllerProvider.notifier).refresh(),
                  child: ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xxl + AppSize.fab),
                    itemCount: data.items.length + (data.hasMore ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      if (index >= data.items.length) {
                        return const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.md), child: Center(child: CircularProgressIndicator()));
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseRow extends StatelessWidget {
  const _PurchaseRow({required this.purchase, required this.busy, required this.onTap, required this.onApprove, required this.onReject});

  final Purchase purchase;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = purchaseStatusLabel(purchase.status);

    return Semantics(
      button: true,
      label: 'Purchase #${purchase.id}, ${formatMoney(purchase.billAmount)}, $label',
      child: AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(formatMoney(purchase.billAmount), style: AppTypography.numericFinancialMedium),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        [
                          '#${purchase.id}',
                          if (purchase.billReference != null && purchase.billReference!.isNotEmpty) 'Ref. ${purchase.billReference}',
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusBadge(label: label, tone: purchaseStatusTone(purchase.status)),
                    if (purchase.coinsAwarded > 0) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text('+${purchase.coinsAwarded} coins', style: AppTypography.numericFinancialInline.copyWith(color: AppColors.success)),
                    ],
                  ],
                ),
              ],
            ),
            if (purchase.isPending) ...[
              const SizedBox(height: AppSpacing.smd),
              Row(
                children: [
                  Expanded(
                    child: AppButton(label: 'Reject', variant: AppButtonVariant.secondary, size: AppButtonSize.sm, icon: Icons.block_rounded, onPressed: busy ? null : onReject),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(label: 'Approve', size: AppButtonSize.sm, icon: Icons.verified_rounded, isLoading: busy, onPressed: onApprove),
                  ),
                ],
              ),
            ] else if (purchase.isRejected && purchase.rejectionReason != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Reason: ${purchase.rejectionReason}', style: textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}
