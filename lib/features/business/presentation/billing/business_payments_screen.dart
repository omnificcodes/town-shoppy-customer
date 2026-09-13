import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/state_panel.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../purchases/presentation/load_more_threshold.dart';
import '../../application/billing_controller.dart';
import '../../application/business_context.dart';
import '../../data/models/billing.dart';
import '../billing_status.dart';
import '../business_routes.dart';
import '../widgets/business_list_filters.dart';
import '../widgets/business_page_header.dart';
import '../widgets/business_stat_strip.dart';

/// Every subscription payment this business made to Town Shoppy. Owner
/// only, read only -- refunds are a Town Shoppy staff action, so the only
/// things to do here are filter, search and open a receipt.
class BusinessPaymentsScreen extends ConsumerStatefulWidget {
  const BusinessPaymentsScreen({super.key});

  @override
  ConsumerState<BusinessPaymentsScreen> createState() => _BusinessPaymentsScreenState();
}

class _BusinessPaymentsScreenState extends ConsumerState<BusinessPaymentsScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - kLoadMoreThreshold) {
        ref.read(businessPaymentsControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(isBusinessOwnerProvider);
    final filters = ref.watch(paymentListFiltersProvider);
    final state = ref.watch(businessPaymentsControllerProvider);
    final totals = state.value?.totals;
    final notifier = ref.read(paymentListFiltersProvider.notifier);

    return Scaffold(
      body: Column(
        children: [
          BusinessPageHeader(
            title: 'Payments',
            subtitle: 'What you have paid Town Shoppy for your package',
            leading: BusinessHeaderIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onTap: () => context.canPop() ? context.pop() : context.go(BusinessRoutes.more)),
            child: BusinessStatStrip(
              isLoading: totals == null && state.isLoading,
              stats: [
                BusinessStat(label: 'Total payments', value: '${totals?.payments ?? 0}', hint: filters.dates.isActive ? filters.dates.label.toUpperCase() : 'ALL TIME'),
                BusinessStat(label: 'Successful', value: '${totals?.successful ?? 0}', hint: 'COMPLETED'),
                BusinessStat(label: 'Failed', value: '${totals?.failed ?? 0}', hint: 'NOT CHARGED'),
                BusinessStat(label: 'Refunded', value: '${totals?.refunded ?? 0}', hint: 'PROCESSED'),
              ],
            ),
          ),
          if (!isOwner)
            const Expanded(
              child: StatePanel(
                icon: Icons.lock_outline_rounded,
                iconColor: AppColors.textDisabled,
                title: 'Owner only',
                message: 'Payments are visible to the shop owner. Ask them if you need a receipt.',
              ),
            )
          else ...[
            const SizedBox(height: AppSpacing.md),
            BusinessListFilters(
              statusOptions: PaymentListFilters.statusOptions,
              status: filters.status,
              onStatusChanged: notifier.setStatus,
              range: filters.dates.range,
              onRangeChanged: notifier.setRange,
              customRangeLabel: filters.dates.isCustom ? filters.dates.label : null,
              onCustomRange: notifier.setCustomRange,
              searchHint: 'Payment ID, amount or reference…',
              onSearchChanged: notifier.setSearch,
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: state.when(
                loading: () => const LoadingSkeletonList(),
                error: (e, _) => ErrorState(
                  error: e is AppException ? e : const UnknownAppException(),
                  title: 'Could not load payments.',
                  onRetry: () => ref.read(businessPaymentsControllerProvider.notifier).refresh(),
                ),
                data: (data) {
                  if (data.items.isEmpty) {
                    return EmptyState(
                      icon: Icons.credit_card_outlined,
                      title: filters.isFiltered ? 'No payments match this filter' : 'No payments yet',
                      message: filters.isFiltered ? 'Try a different status, date range or search.' : 'Your subscription payments will appear here once you choose a package.',
                      action: filters.isFiltered
                          ? AppButton(label: 'Clear filters', variant: AppButtonVariant.secondary, icon: Icons.filter_alt_off_rounded, expand: false, onPressed: notifier.clear)
                          : AppButton(label: 'View packages', icon: Icons.workspace_premium_rounded, expand: false, onPressed: () => context.push(BusinessRoutes.subscriptions)),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () => ref.read(businessPaymentsControllerProvider.notifier).refresh(),
                    child: ListView.separated(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xxl),
                      itemCount: data.items.length + (data.hasMore ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        if (index >= data.items.length) {
                          return const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.md), child: Center(child: CircularProgressIndicator()));
                        }
                        final p = data.items[index];
                        return PaymentRow(payment: p, onTap: () => context.push('${BusinessRoutes.payments}/${p.id}'));
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One payment: amount, status, when, and whether a receipt exists.
class PaymentRow extends StatelessWidget {
  const PaymentRow({super.key, required this.payment, required this.onTap});

  final MerchantPayment payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final label = paymentStatusLabel(p.status);
    final tone = paymentStatusTone(p.status);
    final (bg, fg) = tone.colors;

    return Semantics(
      button: true,
      label: 'Payment #${p.id}, ${formatCurrency(p.amount, p.currency)}, $label',
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: AppSize.avatarMd,
              height: AppSize.avatarMd,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
              child: Icon(_iconFor(p.status), color: fg, size: AppIconSize.md),
            ),
            const SizedBox(width: AppSpacing.smd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formatCurrency(p.amount, p.currency), style: AppTypography.numericFinancialMedium),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    [
                      '#${p.id}',
                      paymentProviderLabel(p.provider).split(' ').first,
                      if (p.createdAt != null) formatDateTime(p.createdAt!),
                    ].join(' · '),
                    style: AppTypography.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (p.isRefunded && p.refundedAmount != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text('${formatCurrency(p.refundedAmount!, p.currency)} refunded', style: AppTypography.caption.copyWith(color: AppColors.info)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(label: label, tone: tone),
                if (p.invoiceId != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_rounded, size: AppIconSize.xs, color: AppColors.textSecondary),
                      const SizedBox(width: AppSpacing.xxs),
                      Text('Invoice', style: AppTypography.caption),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(String status) => switch (status) {
        'paid' => Icons.check_rounded,
        'refunded' => Icons.replay_rounded,
        'failed' => Icons.close_rounded,
        'cancelled' => Icons.block_rounded,
        'pending' => Icons.hourglass_top_rounded,
        _ => Icons.credit_card_rounded,
      };
}
