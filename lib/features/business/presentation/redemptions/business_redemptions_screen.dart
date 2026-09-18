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
import '../../../../shared/widgets/load_more_indicator.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../purchases/presentation/load_more_threshold.dart';
import '../../../redemptions/data/models/redemption.dart';
import '../../../redemptions/presentation/redemption_status.dart';
import '../../application/business_branches_controller.dart';
import '../../application/business_redemptions_controller.dart';
import '../business_routes.dart';
import '../widgets/business_dialogs.dart';
import '../widgets/business_list_filters.dart';
import '../widgets/business_page_header.dart';
import '../widgets/business_stat_strip.dart';
import 'verify_redemption_sheet.dart';

/// Town Coin redemptions raised at this business. Opens on the
/// verification queue; each pending row can be verified (scan, type a
/// code, or one tap when the customer scanned the counter QR) or
/// cancelled without leaving the list.
class BusinessRedemptionsScreen extends ConsumerStatefulWidget {
  const BusinessRedemptionsScreen({super.key});

  @override
  ConsumerState<BusinessRedemptionsScreen> createState() => _BusinessRedemptionsScreenState();
}

class _BusinessRedemptionsScreenState extends ConsumerState<BusinessRedemptionsScreen> {
  final _scroll = ScrollController();
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - kLoadMoreThreshold) {
        ref.read(businessRedemptionsControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _verify(Redemption r) async {
    final verified = await showVerifyRedemptionSheet(context, ref, redemption: r);
    if (verified && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Redemption verified.')));
    }
  }

  Future<void> _cancel(Redemption r) async {
    final reason = await showBusinessReasonDialog(
      context,
      title: 'Cancel redemption',
      message: 'This cannot be undone. Coins already debited will be reversed.',
      confirmLabel: 'Cancel redemption',
      placeholder: 'Why is this redemption being cancelled?',
    );
    if (reason == null || !mounted) return;
    setState(() => _busyId = r.id);
    try {
      await ref.read(businessRedemptionsControllerProvider.notifier).cancel(r.id, reason: reason);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Redemption cancelled.')));
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(redemptionListFiltersProvider);
    final state = ref.watch(businessRedemptionsControllerProvider);
    final branches = ref.watch(businessBranchesControllerProvider).value ?? const [];
    final totals = state.value?.totals;

    return Scaffold(
      body: Column(
        children: [
          BusinessPageHeader(
            title: 'Redemptions',
            subtitle: 'Verify when a customer shows their code at the counter',
            leading: BusinessHeaderIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onTap: () => context.canPop() ? context.pop() : context.go(BusinessRoutes.root)),
            child: BusinessStatStrip(
              isLoading: totals == null && state.isLoading,
              stats: [
                BusinessStat(label: 'Pending verification', value: '${totals?.pending ?? 0}', hint: 'AWAITING YOUR ACTION'),
                BusinessStat(label: 'Verified', value: '${totals?.verified ?? 0}', hint: 'SUCCESSFULLY REDEEMED'),
                BusinessStat(label: 'Cancelled', value: '${totals?.cancelled ?? 0}', hint: 'NOT COMPLETED'),
                BusinessStat(label: 'Coins redeemed', value: '${totals?.coinsRedeemed ?? 0}', hint: filters.range.label.toUpperCase()),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          BusinessListFilters(
            statusOptions: RedemptionListFilters.statusOptions,
            status: filters.status,
            onStatusChanged: ref.read(redemptionListFiltersProvider.notifier).setStatus,
            range: filters.range,
            onRangeChanged: ref.read(redemptionListFiltersProvider.notifier).setRange,
            searchHint: 'Name, mobile or code…',
            onSearchChanged: ref.read(redemptionListFiltersProvider.notifier).setSearch,
            extra: branches.length > 1
                ? PopupMenuButton<int?>(
                    tooltip: 'Branch',
                    initialValue: filters.branchId,
                    onSelected: ref.read(redemptionListFiltersProvider.notifier).setBranch,
                    itemBuilder: (context) => [
                      const PopupMenuItem<int?>(value: null, child: Text('All branches')),
                      for (final b in branches) PopupMenuItem<int?>(value: b.id, child: Text(b.name)),
                    ],
                    child: Container(
                      height: AppSize.field,
                      width: AppSize.field,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                        border: Border.all(color: filters.branchId == null ? AppColors.border : AppColors.businessInk),
                      ),
                      child: const Icon(Icons.location_on_outlined, color: AppColors.textSecondary),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: state.when(
              loading: () => const LoadingSkeletonList(),
              error: (e, _) => ErrorState(
                error: e is AppException ? e : const UnknownAppException(),
                title: 'Could not load redemptions.',
                onRetry: () => ref.read(businessRedemptionsControllerProvider.notifier).refresh(),
              ),
              data: (data) {
                if (data.items.isEmpty) {
                  final initiated = filters.status == 'initiated';
                  return EmptyState(
                    icon: Icons.qr_code_2_rounded,
                    title: initiated ? 'Nothing awaiting verification' : 'No redemptions yet',
                    message: initiated
                        ? "You're all caught up. New redemption requests will appear here as customers make them."
                        : 'Redemptions will appear here once a customer requests one at your business.',
                    action: AppButton(label: 'Process a redemption', icon: Icons.point_of_sale_rounded, expand: false, onPressed: () => context.push(BusinessRoutes.counter)),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(businessRedemptionsControllerProvider.notifier).refresh(),
                  child: ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xxl),
                    itemCount: data.items.length + (data.hasMore ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      if (index >= data.items.length) {
                        return const LoadMoreIndicator();
                      }
                      final r = data.items[index];
                      return _RedemptionRow(
                        redemption: r,
                        busy: _busyId == r.id,
                        onTap: () => context.push('${BusinessRoutes.redemptions}/${r.id}', extra: r),
                        onVerify: () => _verify(r),
                        onCancel: () => _cancel(r),
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

class _RedemptionRow extends StatelessWidget {
  const _RedemptionRow({required this.redemption, required this.busy, required this.onTap, required this.onVerify, required this.onCancel});

  final Redemption redemption;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onVerify;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final r = redemption;
    final label = redemptionStatusLabel(r.status);
    final title = r.customer?.name ?? 'Redemption #${r.id}';

    return Semantics(
      button: true,
      label: '$title, ${formatMoney(r.billAmount)}, ${r.coinsRequested} coins, $label',
      child: AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (r.customer?.mobileNumber != null) Text(r.customer!.mobileNumber!, style: AppTypography.caption),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        [
                          'Bill ${formatMoney(r.billAmount)}',
                          '${r.coinsRequested} coins',
                          if (r.discountAmount != null) '−${formatMoney(r.discountAmount!)}',
                          if (r.branch != null) r.branch!.name,
                          if (r.createdAt != null) relativeTime(r.createdAt!),
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
                    StatusBadge(label: label, tone: redemptionStatusTone(r.status)),
                    if (r.isInitiated && r.counterPresenceVerified) ...[
                      const SizedBox(height: AppSpacing.xs),
                      const StatusBadge(label: 'At your counter', tone: AppTone.success, icon: Icons.storefront_rounded),
                    ],
                  ],
                ),
              ],
            ),
            if (r.isInitiated) ...[
              const SizedBox(height: AppSpacing.smd),
              Row(
                children: [
                  Expanded(child: AppButton(label: 'Cancel', variant: AppButtonVariant.secondary, size: AppButtonSize.sm, icon: Icons.block_rounded, onPressed: busy ? null : onCancel)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: AppButton(label: 'Verify', size: AppButtonSize.sm, icon: Icons.verified_rounded, isLoading: busy, onPressed: onVerify)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
