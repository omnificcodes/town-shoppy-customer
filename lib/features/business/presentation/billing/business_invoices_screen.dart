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
import '../../../../shared/widgets/load_more_indicator.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/state_panel.dart';
import '../../../purchases/presentation/load_more_threshold.dart';
import '../../application/billing_controller.dart';
import '../../application/business_context.dart';
import '../../data/models/billing.dart';
import '../business_routes.dart';
import '../widgets/business_list_filters.dart';
import '../widgets/business_page_header.dart';
import '../widgets/business_stat_strip.dart';

/// The GST invoices Town Shoppy issued to this business -- one per
/// successful payment, immutable. Owner only.
class BusinessInvoicesScreen extends ConsumerStatefulWidget {
  const BusinessInvoicesScreen({super.key});

  @override
  ConsumerState<BusinessInvoicesScreen> createState() => _BusinessInvoicesScreenState();
}

class _BusinessInvoicesScreenState extends ConsumerState<BusinessInvoicesScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - kLoadMoreThreshold) {
        ref.read(businessInvoicesControllerProvider.notifier).loadMore();
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
    final filters = ref.watch(invoiceListFiltersProvider);
    final state = ref.watch(businessInvoicesControllerProvider);
    final notifier = ref.read(invoiceListFiltersProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final data = state.value;
    final taxTotal = data?.items.fold<double>(0, (sum, i) => sum + i.taxAmount) ?? 0;
    final loadedAll = data != null && !data.hasMore;

    return Scaffold(
      body: Column(
        children: [
          BusinessPageHeader(
            title: 'Invoices',
            subtitle: 'Tax invoices for every successful payment',
            leading: BusinessHeaderIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onTap: () => context.canPop() ? context.pop() : context.go(BusinessRoutes.more)),
            child: BusinessStatStrip(
              isLoading: data == null && state.isLoading,
              stats: [
                BusinessStat(label: 'Invoices', value: '${data?.total ?? 0}', hint: filters.dates.isActive ? filters.dates.label.toUpperCase() : 'ALL TIME'),
                BusinessStat(label: 'Tax on these', value: formatMoney(taxTotal), hint: loadedAll ? 'GST INCLUDED' : 'LOADED SO FAR'),
              ],
            ),
          ),
          if (!isOwner)
            const Expanded(
              child: StatePanel(
                icon: Icons.lock_outline_rounded,
                iconColor: AppColors.textDisabled,
                title: 'Owner only',
                message: 'Invoices are visible to the shop owner. Ask them if you need a copy.',
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      filters.isFiltered ? 'Issued ${filters.dates.label.toLowerCase()}' : 'Newest first',
                      style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (filters.isFiltered) ...[
                    TextButton(onPressed: notifier.clear, child: const Text('Clear')),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  BusinessRangeMenu(
                    range: filters.dates.range,
                    onRangeChanged: notifier.setRange,
                    customLabel: filters.dates.isCustom ? filters.dates.label : null,
                    onCustomRange: notifier.setCustomRange,
                  ),
                ],
              ),
            ),
            Expanded(
              child: state.when(
                loading: () => const LoadingSkeletonList(),
                error: (e, _) => ErrorState(
                  error: e is AppException ? e : const UnknownAppException(),
                  title: 'Could not load invoices.',
                  onRetry: () => ref.read(businessInvoicesControllerProvider.notifier).refresh(),
                ),
                data: (data) {
                  if (data.items.isEmpty) {
                    return EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: filters.isFiltered ? 'No invoices in this range' : 'No invoices yet',
                      message: filters.isFiltered ? 'Try a different date range.' : 'An invoice is generated automatically for every successful payment.',
                      action: filters.isFiltered
                          ? AppButton(label: 'Clear filter', variant: AppButtonVariant.secondary, icon: Icons.filter_alt_off_rounded, expand: false, onPressed: notifier.clear)
                          : AppButton(label: 'See payments', variant: AppButtonVariant.secondary, icon: Icons.credit_card_rounded, expand: false, onPressed: () => context.push(BusinessRoutes.payments)),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () => ref.read(businessInvoicesControllerProvider.notifier).refresh(),
                    child: ListView.separated(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xxl),
                      itemCount: data.items.length + (data.hasMore ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        if (index >= data.items.length) {
                          return const LoadMoreIndicator();
                        }
                        final i = data.items[index];
                        return InvoiceRow(invoice: i, onTap: () => context.push('${BusinessRoutes.invoices}/${i.id}'));
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

/// One invoice: number, issued date and tax on the left, the total on the
/// right.
class InvoiceRow extends StatelessWidget {
  const InvoiceRow({super.key, required this.invoice, required this.onTap});

  final MerchantInvoice invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final i = invoice;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Invoice ${i.invoiceNumber}, ${formatCurrency(i.totalAmount, i.currency)}',
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: AppSize.avatarMd,
              height: AppSize.avatarMd,
              decoration: BoxDecoration(color: AppColors.businessTint, borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
              child: const Icon(Icons.receipt_long_rounded, color: AppColors.businessInk, size: AppIconSize.md),
            ),
            const SizedBox(width: AppSpacing.smd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(i.invoiceNumber, style: textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    [
                      if (i.issuedAt != null) 'Issued ${formatDate(i.issuedAt!)}',
                      'Tax ${formatCurrency(i.taxAmount, i.currency)}',
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
                Text(formatCurrency(i.totalAmount, i.currency), style: AppTypography.numericFinancialSmall),
                Text('incl. tax', style: AppTypography.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
