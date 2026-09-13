import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../../shared/widgets/info_box.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/nav_link_card.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../application/billing_controller.dart';
import '../../data/models/billing.dart';
import '../billing_status.dart';
import '../business_routes.dart';
import '../widgets/business_page_header.dart';

/// One payment as a receipt: the amount and outcome up top, the records it
/// is tied to, and the gateway references support will ask for -- each one
/// a tap away from the clipboard.
class BusinessPaymentDetailScreen extends ConsumerWidget {
  const BusinessPaymentDetailScreen({super.key, required this.paymentId});

  final int paymentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(businessPaymentProvider(paymentId));
    final payment = async.value;

    return BusinessScaffold(
      title: 'Payment #$paymentId',
      padded: false,
      actions: [
        if (payment?.reference != null)
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy payment reference',
            onPressed: () => _copy(context, payment!.reference!, 'Payment reference copied'),
          ),
      ],
      body: async.when(
        loading: () => const LoadingSkeletonList(count: 4),
        error: (e, _) => ErrorState(
          error: e is AppException ? e : const UnknownAppException(),
          title: 'Could not load this payment',
          onRetry: () => ref.invalidate(businessPaymentProvider(paymentId)),
        ),
        data: (p) => RefreshIndicator(
          onRefresh: () => ref.refresh(businessPaymentProvider(paymentId).future),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              _Hero(payment: p),
              if (p.isRefunded) ...[
                const SizedBox(height: AppSpacing.md),
                InfoBox(
                  icon: Icons.replay_rounded,
                  tone: AppTone.info,
                  title: 'Refunded',
                  message: '${p.refundedAmount != null ? '${formatCurrency(p.refundedAmount!, p.currency)} was' : 'This payment was'} returned to you'
                      '${p.refundedAt != null ? ' on ${formatDateTime(p.refundedAt!)}' : ''}. Refunds usually reach the original payment method within 5–7 working days.',
                ),
              ],
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Linked records', icon: Icons.link_rounded),
              const SizedBox(height: AppSpacing.smd),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    NavLinkRow(
                      icon: Icons.workspace_premium_rounded,
                      iconColor: AppColors.businessInk,
                      title: p.isForSubscription ? 'Subscription${p.payableId != null ? ' #${p.payableId}' : ''}' : '${p.payableType} #${p.payableId ?? '—'}',
                      subtitle: p.isForSubscription ? 'Your package and plan' : null,
                      onTap: () => context.push(BusinessRoutes.subscriptions),
                    ),
                    const Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md),
                    if (p.invoiceId != null)
                      NavLinkRow(
                        icon: Icons.receipt_long_rounded,
                        iconColor: AppColors.businessInk,
                        title: 'Invoice #${p.invoiceId}',
                        subtitle: 'GST tax invoice for this payment',
                        onTap: () => context.push('${BusinessRoutes.invoices}/${p.invoiceId}'),
                      )
                    else
                      const NavLinkRow(
                        icon: Icons.receipt_long_outlined,
                        iconColor: AppColors.textDisabled,
                        title: 'Invoice not yet issued',
                        subtitle: 'An invoice is generated as soon as a payment succeeds.',
                        trailing: SizedBox.shrink(),
                        onTap: null,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Gateway reference', subtitle: 'Quote these if you contact support about this payment.', icon: Icons.fingerprint_rounded),
              const SizedBox(height: AppSpacing.smd),
              AppCard(
                child: Column(
                  children: [
                    DetailRow(label: 'Provider', value: paymentProviderLabel(p.provider)),
                    _CopyRow(label: 'Order ID', value: p.providerOrderId),
                    _CopyRow(label: 'Payment ID', value: p.providerPaymentId),
                    DetailRow(label: 'Currency', value: p.currency.toUpperCase()),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Timeline', icon: Icons.schedule_rounded),
              const SizedBox(height: AppSpacing.smd),
              AppCard(
                child: Column(
                  children: [
                    DetailRow(label: 'Created', value: p.createdAt != null ? formatDateTime(p.createdAt!) : '—'),
                    if (p.refundedAt != null) DetailRow(label: 'Refunded', value: formatDateTime(p.refundedAt!)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const InfoBox(
                icon: Icons.support_agent_rounded,
                tone: AppTone.neutral,
                message: 'Payments are read-only here. Refunds and corrections are handled by the Town Shoppy team — reach out with the payment reference above.',
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  static void _copy(BuildContext context, String value, String toast) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(toast)));
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.payment});

  final MerchantPayment payment;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = payment;
    final hint = paymentStatusHint(p.status);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.businessInk, AppColors.businessInkDeep]),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.isPaid || p.isRefunded ? 'AMOUNT PAID' : 'AMOUNT', style: AppTypography.overline.copyWith(color: AppColors.onBusinessInkMuted)),
          const SizedBox(height: AppSpacing.xs),
          Text(formatCurrency(p.amount, p.currency), style: AppTypography.numericFinancialLarge.copyWith(color: AppColors.onBusinessInk)),
          const SizedBox(height: AppSpacing.smd),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(label: paymentStatusLabel(p.status), tone: paymentStatusTone(p.status), large: true),
              if (p.createdAt != null) Text(formatDateTime(p.createdAt!), style: textTheme.labelLarge?.copyWith(color: AppColors.onBusinessInkMuted)),
            ],
          ),
          if (hint.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(hint, style: textTheme.bodySmall?.copyWith(color: AppColors.onBusinessInkMuted)),
          ],
        ],
      ),
    );
  }
}

/// A gateway id with a copy button; "—" when the gateway never issued one
/// (a cash payment, or a checkout that never reached the gateway).
class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return DetailRow(label: label, value: '—');
    return DetailRow(
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(value!, style: AppTypography.numericFinancialInline, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end),
          ),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(
            width: AppSpacing.touchTarget,
            height: AppSpacing.touchTarget,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: AppIconSize.sm,
              icon: const Icon(Icons.copy_rounded, color: AppColors.textSecondary),
              tooltip: 'Copy $label',
              onPressed: () => BusinessPaymentDetailScreen._copy(context, value!, '$label copied'),
            ),
          ),
        ],
      ),
    );
  }
}
