import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/detail_row.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/info_box.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../purchases/data/models/purchase.dart';
import '../../../purchases/presentation/purchase_status.dart';
import '../../application/business_purchases_controller.dart';
import '../widgets/business_dialogs.dart';
import '../widgets/business_page_header.dart';

/// One purchase as the merchant sees it -- every `PurchaseResource` field
/// the web detail page shows, plus Approve/Reject while it is pending.
class BusinessPurchaseDetailScreen extends ConsumerStatefulWidget {
  const BusinessPurchaseDetailScreen({super.key, required this.purchaseId});

  final int purchaseId;

  @override
  ConsumerState<BusinessPurchaseDetailScreen> createState() => _BusinessPurchaseDetailScreenState();
}

class _BusinessPurchaseDetailScreenState extends ConsumerState<BusinessPurchaseDetailScreen> {
  bool _busy = false;

  Future<void> _approve() async {
    final ok = await showBusinessConfirmDialog(
      context,
      title: 'Approve this purchase?',
      message: "Approving this purchase will record the transaction and issue the customer's applicable Town Coins and Lucky Draw coupons.",
      confirmLabel: 'Approve',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await ref.read(businessPurchasesControllerProvider.notifier).approve(widget.purchaseId);
      if (!mounted) return;
      await showPurchaseCelebration(context, title: 'Purchase approved!', coinsAwarded: updated.coinsAwarded);
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.statusCode == 402 ? '${e.message} Visit Subscriptions to choose a plan.' : e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final reason = await showBusinessReasonDialog(
      context,
      title: 'Reject this purchase',
      message: 'The customer will be notified. No Town Coins or coupons are issued for a rejected purchase.',
      confirmLabel: 'Reject purchase',
      placeholder: 'Why is this purchase being rejected?',
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(businessPurchasesControllerProvider.notifier).reject(widget.purchaseId, reason: reason);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase rejected.')));
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final purchase = ref.watch(businessPurchaseProvider(widget.purchaseId));

    return BusinessScaffold(
      title: 'Purchase #${widget.purchaseId}',
      padded: false,
      bottomBar: purchase.value?.isPending == true
          ? Row(
              children: [
                Expanded(child: AppButton(label: 'Reject', variant: AppButtonVariant.secondary, icon: Icons.block_rounded, onPressed: _busy ? null : _reject)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: AppButton(label: 'Approve', icon: Icons.verified_rounded, isLoading: _busy, onPressed: _approve)),
              ],
            )
          : null,
      body: purchase.when(
        loading: () => const LoadingSkeletonList(count: 4),
        error: (e, _) => ErrorState(
          error: e is AppException ? e : const UnknownAppException(),
          title: 'Could not load this purchase',
          onRetry: () => ref.invalidate(businessPurchaseProvider(widget.purchaseId)),
        ),
        data: (p) => RefreshIndicator(
          onRefresh: () => ref.refresh(businessPurchaseProvider(widget.purchaseId).future),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              _Hero(purchase: p),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Purchase details', icon: Icons.receipt_long_rounded),
              const SizedBox(height: AppSpacing.smd),
              AppCard(
                child: Column(
                  children: [
                    DetailRow(label: 'Bill amount', value: formatMoney(p.billAmount), emphasize: true),
                    DetailRow(label: 'Bill reference', value: p.billReference ?? '—'),
                    if (p.branch != null) DetailRow(label: 'Branch', value: p.branch!.name),
                    DetailRow(label: 'Source', value: _sourceLabel(p.source)),
                    DetailRow(label: 'Coins awarded', value: '${p.coinsAwarded}'),
                    if (p.couponsIssued != null) DetailRow(label: 'Coupons issued', value: '${p.couponsIssued}'),
                  ],
                ),
              ),
              if (p.duplicateFlagNotes != null && p.duplicateFlagNotes!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                InfoBox(icon: Icons.flag_outlined, tone: AppTone.pending, title: 'Flag notes', message: p.duplicateFlagNotes!),
              ],
              if (p.isRejected && p.rejectionReason != null) ...[
                const SizedBox(height: AppSpacing.md),
                InfoBox(icon: Icons.block_rounded, tone: AppTone.error, title: 'Rejection reason', message: p.rejectionReason!),
              ],
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Timeline', icon: Icons.schedule_rounded),
              const SizedBox(height: AppSpacing.smd),
              AppCard(
                child: Column(
                  children: [
                    if (p.createdAt != null) DetailRow(label: 'Submitted', value: formatDateTime(p.createdAt!)),
                    if (p.reviewedAt != null) DetailRow(label: 'Reviewed', value: formatDateTime(p.reviewedAt!)),
                    if (p.updatedAt != null) DetailRow(label: 'Last updated', value: formatDateTime(p.updatedAt!)),
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

  static String _sourceLabel(String? source) => switch (source) {
        'merchant_mobile_entry' => 'Counter — mobile number',
        'merchant_customer_qr' => 'Counter — customer QR',
        'customer_merchant_qr' => 'Customer scanned your QR',
        'merchant_app' => 'Merchant app',
        null => '—',
        _ => source.replaceAll('_', ' '),
      };
}

class _Hero extends StatelessWidget {
  const _Hero({required this.purchase});

  final Purchase purchase;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.businessInk, AppColors.businessInkDeep]),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BILL AMOUNT', style: AppTypography.overline.copyWith(color: AppColors.onBusinessInkMuted)),
          const SizedBox(height: AppSpacing.xs),
          Text(formatMoney(purchase.billAmount), style: AppTypography.numericFinancialLarge.copyWith(color: AppColors.onBusinessInk)),
          const SizedBox(height: AppSpacing.smd),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(label: purchaseStatusLabel(purchase.status), tone: purchaseStatusTone(purchase.status), large: true),
              if (purchase.coinsAwarded > 0)
                Text('+${purchase.coinsAwarded} Town Coins', style: textTheme.labelLarge?.copyWith(color: AppColors.yellow)),
            ],
          ),
          if (purchase.isPending) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'A customer submitted this bill by scanning your Purchase QR. Approve it to record the sale and issue their coins and coupons.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.onBusinessInkMuted),
            ),
          ],
        ],
      ),
    );
  }
}
