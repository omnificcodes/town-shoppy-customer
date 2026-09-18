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
import '../../../purchases/presentation/load_more_threshold.dart';
import '../../application/business_branches_controller.dart';
import '../../application/list_range.dart';
import '../../application/merchant_customers_controller.dart';
import '../../data/models/merchant_customer.dart';
import '../business_routes.dart';
import '../widgets/business_page_header.dart';
import '../widgets/business_stat_strip.dart';

/// Everyone who has bought from or redeemed Town Coin at this business,
/// most recent visit first. Read-only for Owner and Staff alike.
class BusinessCustomersScreen extends ConsumerStatefulWidget {
  const BusinessCustomersScreen({super.key});

  @override
  ConsumerState<BusinessCustomersScreen> createState() => _BusinessCustomersScreenState();
}

class _BusinessCustomersScreenState extends ConsumerState<BusinessCustomersScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - kLoadMoreThreshold) {
        ref.read(merchantCustomersControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _openFilters() async {
    final branches = ref.read(businessBranchesControllerProvider).value ?? const [];
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final f = ref.watch(customerListFiltersProvider);
          final n = ref.read(customerListFiltersProvider.notifier);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filter customers', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.md),
                  Text('Visited in', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [for (final r in ListRange.values) ChoiceChip(label: Text(r.label), selected: f.range == r, onSelected: (_) => n.setRange(r))],
                  ),
                  if (branches.length > 1) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text('Branch', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        ChoiceChip(label: const Text('All branches'), selected: f.branchId == null, onSelected: (_) => n.setBranch(null)),
                        for (final b in branches) ChoiceChip(label: Text(b.name), selected: f.branchId == b.id, onSelected: (_) => n.setBranch(b.id)),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(label: 'Done', onPressed: () => Navigator.of(sheetContext).pop()),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(customerListFiltersProvider);
    final state = ref.watch(merchantCustomersControllerProvider);
    final totals = state.value?.totals;
    final filterActive = filters.branchId != null || filters.range != ListRange.all;

    return Scaffold(
      body: Column(
        children: [
          BusinessPageHeader(
            title: 'Customers',
            subtitle: 'Everyone who has shopped or redeemed at your business',
            leading: BusinessHeaderIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onTap: () => context.canPop() ? context.pop() : context.go(BusinessRoutes.root)),
            child: BusinessStatStrip(
              isLoading: totals == null && state.isLoading,
              stats: [
                BusinessStat(label: 'Customers', value: '${totals?.customers ?? 0}', hint: 'UNIQUE'),
                BusinessStat(label: 'Purchases', value: '${totals?.purchases ?? 0}'),
                BusinessStat(label: 'Total spent', value: formatMoney(totals?.spent ?? 0)),
                BusinessStat(label: 'Coupons earned', value: '${totals?.coupons ?? 0}', hint: 'LUCKY DRAW'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(labelText: 'Search', hintText: 'Name or mobile number', prefixIcon: Icon(Icons.search_rounded)),
                    textInputAction: TextInputAction.search,
                    onSubmitted: ref.read(customerListFiltersProvider.notifier).setSearch,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Material(
                  color: filterActive ? AppColors.businessTintStrong : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                    onTap: _openFilters,
                    child: Container(
                      width: AppSize.field,
                      height: AppSize.field,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppSpacing.radiusControl), border: Border.all(color: filterActive ? AppColors.businessInk : AppColors.border)),
                      child: Icon(Icons.tune_rounded, color: filterActive ? AppColors.businessInk : AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: state.when(
              loading: () => const LoadingSkeletonList(),
              error: (e, _) => ErrorState(error: e is AppException ? e : const UnknownAppException(), title: 'Could not load customers.', onRetry: () => ref.read(merchantCustomersControllerProvider.notifier).refresh()),
              data: (data) {
                if (data.items.isEmpty) {
                  return EmptyState(
                    icon: Icons.people_alt_outlined,
                    title: filters.isDefault ? 'No customers yet' : 'No customers match these filters',
                    message: filters.isDefault ? 'Everyone who buys from or redeems Town Coin at your business will show up here.' : 'Try a different name, branch, or date range.',
                    action: filters.isDefault
                        ? AppButton(label: 'Record a purchase', icon: Icons.point_of_sale_rounded, expand: false, onPressed: () => context.push(BusinessRoutes.counter))
                        : AppButton(
                            label: 'Clear filters',
                            variant: AppButtonVariant.secondary,
                            expand: false,
                            onPressed: () {
                              _search.clear();
                              ref.read(customerListFiltersProvider.notifier).clear();
                            },
                          ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(merchantCustomersControllerProvider.notifier).refresh(),
                  child: ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xxl),
                    itemCount: data.items.length + (data.hasMore ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      if (i >= data.items.length) {
                        return const LoadMoreIndicator();
                      }
                      final c = data.items[i];
                      return _CustomerRow(customer: c, onTap: () => context.push('${BusinessRoutes.customers}/${c.id}'));
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

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.customer, required this.onTap});

  final MerchantCustomer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = customer;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '${c.name}, ${c.purchaseCount} purchases, ${formatMoney(c.totalSpent)} spent',
      child: AppCard(
        onTap: onTap,
        compact: true,
        child: Row(
          children: [
            CustomerAvatar(name: c.name),
            const SizedBox(width: AppSpacing.smd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name, style: textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    [
                      if (c.mobileNumber != null) c.mobileNumber!,
                      '${c.purchaseCount} ${c.purchaseCount == 1 ? 'visit' : 'visits'}',
                      if (c.lastPurchaseAt != null) 'last ${relativeTime(c.lastPurchaseAt!)}',
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
                Text(formatMoney(c.totalSpent), style: AppTypography.numericFinancialSmall),
                if (c.couponsEarned > 0) Text('${c.couponsEarned} coupons', style: AppTypography.caption),
              ],
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: AppIconSize.lg),
          ],
        ),
      ),
    );
  }
}

/// Initials in a tinted circle -- shared by the directory and the detail
/// hero.
class CustomerAvatar extends StatelessWidget {
  const CustomerAvatar({super.key, required this.name, this.size = AppSize.avatarMd, this.onDark = false});

  final String name;
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2);
    final initials = parts.map((p) => p[0].toUpperCase()).join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: onDark ? AppColors.onBusinessInk.withValues(alpha: 0.15) : AppColors.businessTint, shape: BoxShape.circle),
      child: Text(initials.isEmpty ? '?' : initials, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: onDark ? AppColors.onBusinessInk : AppColors.businessInk, fontSize: size * 0.36)),
    );
  }
}
