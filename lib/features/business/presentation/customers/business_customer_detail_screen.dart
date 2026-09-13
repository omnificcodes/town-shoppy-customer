import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/detail_row.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/state_panel.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../purchases/presentation/purchase_status.dart';
import '../../../redemptions/presentation/redemption_status.dart';
import '../../application/merchant_customers_controller.dart';
import '../business_routes.dart';
import '../widgets/business_page_header.dart';
import 'business_customers_screen.dart';

/// One customer as this business knows them: stats at this shop only,
/// then their purchase and redemption history here.
class BusinessCustomerDetailScreen extends ConsumerWidget {
  const BusinessCustomerDetailScreen({super.key, required this.customerId});

  final int customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(merchantCustomerDetailProvider(customerId));
    final textTheme = Theme.of(context).textTheme;

    return BusinessScaffold(
      title: 'Customer',
      padded: false,
      body: async.when(
        loading: () => const LoadingSkeletonList(count: 4),
        error: (e, _) => e is NotFoundException
            ? const StatePanel(icon: Icons.person_off_outlined, iconColor: AppColors.textDisabled, title: "This isn't your customer", message: 'This customer has no purchase or redemption history at your business.')
            : ErrorState(error: e is AppException ? e : const UnknownAppException(), title: 'Could not load this customer', onRetry: () => ref.invalidate(merchantCustomerDetailProvider(customerId))),
        data: (c) => RefreshIndicator(
          onRefresh: () => ref.refresh(merchantCustomerDetailProvider(customerId).future),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.businessInk, AppColors.businessInkDeep]), borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
                child: Row(
                  children: [
                    CustomerAvatar(name: c.name, size: AppSize.avatarLg, onDark: true),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name, style: textTheme.headlineSmall?.copyWith(color: AppColors.onBusinessInk), maxLines: 2, overflow: TextOverflow.ellipsis),
                          if (c.mobileNumber != null) Text(c.mobileNumber!, style: textTheme.bodyMedium?.copyWith(color: AppColors.onBusinessInkMuted)),
                          if (c.memberSince != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text('Customer since ${formatDate(c.memberSince!)}', style: AppTypography.caption.copyWith(color: AppColors.yellow)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'At your business', subtitle: 'Scoped to your business only — never a platform-wide total.', icon: Icons.storefront_rounded),
              const SizedBox(height: AppSpacing.smd),
              AppCard(
                child: Column(
                  children: [
                    DetailRow(label: 'Purchases', value: '${c.purchaseCount}'),
                    DetailRow(label: 'Total spent', value: formatMoney(c.totalSpent), emphasize: true),
                    DetailRow(label: 'Coupons earned', value: '${c.couponsEarned}'),
                    DetailRow(label: 'Redemptions', value: '${c.redemptionCount}'),
                    DetailRow(label: 'Total discount redeemed', value: formatMoney(c.totalDiscountRedeemed)),
                    DetailRow(label: 'First visit', value: c.firstVisitAt != null ? formatDateTime(c.firstVisitAt!) : '—'),
                    DetailRow(label: 'Last visit', value: c.lastVisitAt != null ? formatDateTime(c.lastVisitAt!) : '—'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              SectionHeader(title: 'Purchase history', subtitle: '${c.purchases.length} at your business', icon: Icons.receipt_long_rounded),
              const SizedBox(height: AppSpacing.smd),
              if (c.purchases.isEmpty)
                AppCard(child: Text('Nothing recorded yet.', style: textTheme.bodySmall))
              else
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final (i, p) in c.purchases.indexed) ...[
                        if (i > 0) const Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md),
                        InkWell(
                          onTap: () => context.push('${BusinessRoutes.purchases}/${p.id}'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.smd),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(formatMoney(p.billAmount), style: AppTypography.numericFinancialSmall),
                                      Text('${p.branch?.name ?? '—'}${p.createdAt != null ? ' · ${formatDate(p.createdAt!)}' : ''}${p.coinsAwarded > 0 ? ' · +${p.coinsAwarded} coins' : ''}', style: AppTypography.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Flexible(child: StatusBadge(label: purchaseStatusLabel(p.status), tone: purchaseStatusTone(p.status))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.section),
              SectionHeader(title: 'Redemption history', subtitle: '${c.redemptions.length} at your business', icon: Icons.qr_code_2_rounded),
              const SizedBox(height: AppSpacing.smd),
              if (c.redemptions.isEmpty)
                AppCard(child: Text('Nothing redeemed yet.', style: textTheme.bodySmall))
              else
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final (i, r) in c.redemptions.indexed) ...[
                        if (i > 0) const Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md),
                        InkWell(
                          onTap: () => context.push('${BusinessRoutes.redemptions}/${r.id}'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.smd),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${formatMoney(r.billAmount)} bill${r.discountAmount != null ? ' · −${formatMoney(r.discountAmount!)}' : ''}', style: AppTypography.numericFinancialSmall),
                                      Text('${r.coinsDebited ?? r.coinsRequested} coins${r.createdAt != null ? ' · ${formatDate(r.createdAt!)}' : ''}', style: AppTypography.caption),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Flexible(child: StatusBadge(label: redemptionStatusLabel(r.status), tone: redemptionStatusTone(r.status))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
