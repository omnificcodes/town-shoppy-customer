import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/info_box.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/nav_link_card.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../application/billing_controller.dart';
import '../../data/models/billing.dart';
import '../business_routes.dart';
import '../widgets/business_page_header.dart';

/// One invoice, laid out the way a paper tax invoice reads: who it is
/// for, the number and date, then subtotal / tax / total.
class BusinessInvoiceDetailScreen extends ConsumerWidget {
  const BusinessInvoiceDetailScreen({super.key, required this.invoiceId});

  final int invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(businessInvoiceProvider(invoiceId));
    final invoice = async.value;

    return BusinessScaffold(
      title: 'Invoice',
      padded: false,
      actions: [
        if (invoice != null)
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy invoice number',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: invoice.invoiceNumber));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Invoice number copied')));
            },
          ),
      ],
      body: async.when(
        loading: () => const LoadingSkeletonList(count: 3),
        error: (e, _) => ErrorState(
          error: e is AppException ? e : const UnknownAppException(),
          title: 'Could not load this invoice',
          onRetry: () => ref.invalidate(businessInvoiceProvider(invoiceId)),
        ),
        data: (i) => RefreshIndicator(
          onRefresh: () => ref.refresh(businessInvoiceProvider(invoiceId).future),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              _InvoiceSheet(invoice: i),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Linked payment', icon: Icons.link_rounded),
              const SizedBox(height: AppSpacing.smd),
              AppCard(
                padding: EdgeInsets.zero,
                child: NavLinkRow(
                  icon: Icons.credit_card_rounded,
                  iconColor: AppColors.businessInk,
                  title: i.paymentId != null ? 'Payment #${i.paymentId}' : 'Payment',
                  subtitle: 'The transaction this invoice was issued for',
                  onTap: i.paymentId == null ? () => context.push(BusinessRoutes.payments) : () => context.push('${BusinessRoutes.payments}/${i.paymentId}'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const InfoBox(
                icon: Icons.verified_outlined,
                tone: AppTone.neutral,
                message: 'Invoices are generated automatically when a payment succeeds and cannot be edited. For a GST query, contact Town Shoppy with the invoice number.',
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

/// The invoice itself: a maroon header strip with the number and date,
/// then the amount breakdown on white with the total ruled off.
class _InvoiceSheet extends StatelessWidget {
  const _InvoiceSheet({required this.invoice});

  final MerchantInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final i = invoice;
    final radius = BorderRadius.circular(AppSpacing.radiusLg);
    final sheet = Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: radius, side: const BorderSide(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.businessInk, AppColors.businessInkDeep])),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('TAX INVOICE', style: AppTypography.overline.copyWith(color: AppColors.yellow))),
                    const Icon(Icons.receipt_long_rounded, color: AppColors.onBusinessInkMuted, size: AppIconSize.lg),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(i.invoiceNumber, style: textTheme.headlineSmall?.copyWith(color: AppColors.onBusinessInk)),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  i.issuedAt != null ? 'Issued ${formatDateTime(i.issuedAt!)}' : 'Issue date unavailable',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.onBusinessInkMuted),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (i.merchantName != null) ...[
                  Text('BILLED TO', style: AppTypography.overline.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(i.merchantName!, style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.md),
                ],
                _Line(label: 'Subtotal', value: formatCurrency(i.amount, i.currency)),
                const SizedBox(height: AppSpacing.sm),
                _Line(label: 'Tax (GST)', value: formatCurrency(i.taxAmount, i.currency)),
                const SizedBox(height: AppSpacing.md),
                const Divider(height: 1, color: AppColors.businessInk),
                const SizedBox(height: AppSpacing.md),
                _Line(label: 'Total', value: formatCurrency(i.totalAmount, i.currency), emphasize: true),
                const SizedBox(height: AppSpacing.xs),
                Text('All amounts in ${i.currency.toUpperCase()}', style: AppTypography.caption, textAlign: TextAlign.end),
              ],
            ),
          ),
        ],
      ),
    );

    // Same lift as AppCard, outside the Material so its clip keeps the shadow.
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: AppElevation.card),
      child: sheet,
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Text(label, style: emphasize ? textTheme.titleMedium : textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary))),
        const SizedBox(width: AppSpacing.sm),
        Text(value, style: emphasize ? AppTypography.numericFinancialMedium : AppTypography.numericFinancialSmall),
      ],
    );
  }
}
