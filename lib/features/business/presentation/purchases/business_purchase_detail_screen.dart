import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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
import '../../application/voice_alert_service.dart';
import '../../../scratch_cards/application/scratch_cards_providers.dart';
import '../../../stamp_cards/application/stamp_cards_providers.dart';
import '../../../stamp_cards/data/models/stamp_card.dart';
import '../scratch_cards/scratch_card_picker.dart';
import '../stamp_cards/stamp_card_picker.dart';
import '../widgets/business_dialogs.dart';
import 'purchase_review_copy.dart';
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
    final purchase = ref.read(businessPurchaseProvider(widget.purchaseId)).value;
    if (purchase == null) return;

    // A scratch card can go with the approved bill (a plan feature): offer
    // the shop's active designs first, when its plan allows one right now.
    int? scratchCardId;
    final designs = ref.read(scratchCardDesignsProvider).value;
    if (designs != null && designs.canGive) {
      final choice = await showScratchCardPicker(context, designs);
      if (choice == null || !mounted) return;
      scratchCardId = choice.designId;
    }

    // A loyalty stamp can go with it too (a plan feature), never required.
    int? stampCardId;
    final programmes = ref.read(stampCardProgrammesProvider).value;
    if (programmes != null && programmes.canStamp) {
      final customerId = purchase.customer?.id;
      final progress = customerId == null ? const <CustomerStampCard>[] : (await ref.read(customerStampProgressProvider(customerId).future).catchError((_) => <CustomerStampCard>[]));
      if (!mounted) return;
      final choice = await showStampCardPicker(context, programmes, progress: progress, billAmount: purchase.billAmount);
      if (choice == null || !mounted) return;
      stampCardId = choice.programmeId;
    }

    final extras = [
      if (scratchCardId != null) 'A scratch card goes to the customer with it.',
      if (stampCardId != null) 'Their stamp card gets a stamp.',
    ].join(' ');
    final ok = await showBusinessConfirmDialog(
      context,
      title: approveTitle(purchase),
      message: extras.isEmpty ? approveMessage(purchase) : '${approveMessage(purchase)} $extras',
      confirmLabel: 'Approve',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await ref
          .read(businessPurchasesControllerProvider.notifier)
          .approve(widget.purchaseId, scratchCardId: scratchCardId, stampCardId: stampCardId);
      if (scratchCardId != null) ref.invalidate(scratchCardDesignsProvider);
      if (stampCardId != null) ref.invalidate(stampCardProgrammesProvider);
      if (!mounted) return;
      ref.read(voiceAlertServiceProvider).announcePayment(amount: updated.billAmount);
      await showPurchaseCelebration(
        context,
        title: 'Purchase approved!',
        coinsAwarded: updated.coinsAwarded,
        scratchCardTitle: updated.scratchCardTitle,
        stampSummary: updated.stamp?.summary,
      );
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
      message: rejectMessage,
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
              if (p.customer != null) ...[
                const SizedBox(height: AppSpacing.section),
                const SectionHeader(title: 'Customer', icon: Icons.person_outline_rounded),
                const SizedBox(height: AppSpacing.smd),
                AppCard(
                  child: Column(
                    children: [
                      DetailRow(
                        label: 'Name',
                        value: (p.customer!.name?.trim().isNotEmpty ?? false) ? p.customer!.name!.trim() : 'Not provided',
                      ),
                      DetailRow(
                        label: 'Mobile number',
                        child: p.customer!.mobileNumber == null
                            ? const Text('—')
                            : _PhoneLink(mobile: p.customer!.mobileNumber!),
                      ),
                    ],
                  ),
                ),
              ],
              if (p.coinPayment != null) ...[
                const SizedBox(height: AppSpacing.section),
                const SectionHeader(title: 'Town Coin payment', icon: Icons.savings_rounded),
                const SizedBox(height: AppSpacing.smd),
                _CoinPaymentCard(payment: p.coinPayment!, pending: p.isPending),
              ],
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Purchase details', icon: Icons.receipt_long_rounded),
              const SizedBox(height: AppSpacing.smd),
              AppCard(
                child: Column(
                  children: [
                    if (p.transactionId != null) DetailRow(label: 'Transaction ID', value: p.transactionId!),
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

/// The customer's number as "+91 98765 43210", tappable to call them.
class _PhoneLink extends StatelessWidget {
  const _PhoneLink({required this.mobile});

  final String mobile;

  static String _format(String mobile) {
    final digits = mobile.replaceAll(RegExp(r'[^0-9]'), '');
    final local = digits.length == 12 && digits.startsWith('91') ? digits.substring(2) : digits;
    if (local.length != 10) return mobile;
    return '+91 ${local.substring(0, 5)} ${local.substring(5)}';
  }

  @override
  Widget build(BuildContext context) {
    final shown = _format(mobile);
    final dialable = mobile.replaceAll(RegExp(r'[^0-9+]'), '');

    return Semantics(
      button: true,
      label: 'Call $shown',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        onTap: () => launchUrl(Uri(scheme: 'tel', path: dialable)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.call_rounded, size: AppIconSize.sm, color: AppColors.info),
              const SizedBox(width: AppSpacing.xs),
              // A phone number must never be cut or split across lines, so
              // on a narrow row it shrinks to fit instead.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    shown,
                    maxLines: 1,
                    style: AppTypography.numericFinancialInline.copyWith(
                      color: AppColors.info,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the customer's Town Coins do on this bill: what approval deducts
/// and what to collect while it is pending, what was deducted once
/// settled, and a plain "not deducted" for a payment that never went
/// through -- never a silent blank.
class _CoinPaymentCard extends StatelessWidget {
  const _CoinPaymentCard({required this.payment, required this.pending});

  final CoinPayment payment;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, tone) = switch (payment.status) {
      'settled' => ('Deducted', AppTone.success),
      'initiated' => ('Deducted on approval', AppTone.pending),
      _ => ('Not deducted', AppTone.neutral),
    };

    // Only a payment that is live or went through changes what is paid at
    // the counter; a cancelled one changes nothing, so it shows nothing.
    final applies = payment.settled || payment.isWaiting;

    return AppCard(
      child: Column(
        children: [
          DetailRow(label: 'Status', child: StatusBadge(label: statusLabel, tone: tone)),
          DetailRow(
            label: payment.settled
                ? 'Coins deducted'
                : applies
                ? 'Coins to deduct'
                : 'Coins requested',
            value: '${payment.coins} Town Coins',
            emphasize: applies,
          ),
          if (applies) ...[
            DetailRow(label: 'Coin discount', value: '− ${formatMoney(payment.discountAmount)}'),
            DetailRow(
              label: pending ? 'Collect at the counter' : 'Collected at the counter',
              value: formatMoney(payment.amountPayable),
            ),
          ],
        ],
      ),
    );
  }
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
