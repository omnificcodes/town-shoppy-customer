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
import '../../../redemptions/data/models/redemption.dart';
import '../../../redemptions/presentation/redemption_status.dart';
import '../../application/business_redemptions_controller.dart';
import '../widgets/business_dialogs.dart';
import '../widgets/business_page_header.dart';
import 'verify_redemption_sheet.dart';

/// One redemption as the merchant sees it. Note `GET /redemptions/{id}`
/// carries no customer relation -- the list row passed in via `extra`
/// (when it came from the list) supplies the name; a deep link shows
/// "Redemption #id".
class BusinessRedemptionDetailScreen extends ConsumerStatefulWidget {
  const BusinessRedemptionDetailScreen({super.key, required this.redemptionId, this.listRow});

  final int redemptionId;
  final Redemption? listRow;

  @override
  ConsumerState<BusinessRedemptionDetailScreen> createState() => _BusinessRedemptionDetailScreenState();
}

class _BusinessRedemptionDetailScreenState extends ConsumerState<BusinessRedemptionDetailScreen> {
  bool _busy = false;

  Future<void> _verify(Redemption r) async {
    final verified = await showVerifyRedemptionSheet(context, ref, redemption: r);
    if (verified && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Redemption verified.')));
    }
  }

  Future<void> _approveAtCounter(Redemption r) async {
    setState(() => _busy = true);
    try {
      await ref.read(businessRedemptionsControllerProvider.notifier).verify(r.id, method: 'counter_confirm');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Redemption verified.')));
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
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
    setState(() => _busy = true);
    try {
      await ref.read(businessRedemptionsControllerProvider.notifier).cancel(r.id, reason: reason);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Redemption cancelled.')));
    } on AppException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(businessRedemptionProvider(widget.redemptionId));
    final textTheme = Theme.of(context).textTheme;

    return BusinessScaffold(
      title: 'Redemption #${widget.redemptionId}',
      padded: false,
      bottomBar: async.value?.isInitiated == true
          ? Row(
              children: [
                Expanded(child: AppButton(label: 'Cancel', variant: AppButtonVariant.secondary, icon: Icons.block_rounded, onPressed: _busy ? null : () => _cancel(_withCustomer(async.value!)))),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: AppButton(label: 'Verify', icon: Icons.verified_rounded, isLoading: _busy, onPressed: () => _verify(_withCustomer(async.value!)))),
              ],
            )
          : null,
      body: async.when(
        loading: () => const LoadingSkeletonList(count: 4),
        error: (e, _) => ErrorState(
          error: e is AppException ? e : const UnknownAppException(),
          title: 'Could not load this redemption',
          onRetry: () => ref.invalidate(businessRedemptionProvider(widget.redemptionId)),
        ),
        data: (fetched) {
          final r = _withCustomer(fetched);
          final counter = r.isInitiated && r.counterPresenceVerified;
          final payable = r.maxDiscountAmount != null ? r.billAmount - r.maxDiscountAmount! : null;
          final banner = _banner(r.status);

          return RefreshIndicator(
            onRefresh: () => ref.refresh(businessRedemptionProvider(widget.redemptionId).future),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.businessInk, AppColors.businessInkDeep]),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.customer?.name.toUpperCase() ?? 'CUSTOMER', style: AppTypography.overline.copyWith(color: AppColors.onBusinessInkMuted)),
                      const SizedBox(height: AppSpacing.xs),
                      Text('${r.coinsRequested} coins', style: AppTypography.numericFinancialLarge.copyWith(color: AppColors.onBusinessInk)),
                      Text('on a ${formatMoney(r.billAmount)} bill', style: textTheme.bodyMedium?.copyWith(color: AppColors.onBusinessInkMuted)),
                      const SizedBox(height: AppSpacing.smd),
                      StatusBadge(label: redemptionStatusLabel(r.status), tone: redemptionStatusTone(r.status), large: true),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (counter)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.storefront_rounded, color: AppColors.success, size: AppIconSize.md),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: Text('Started at your counter', style: textTheme.titleSmall?.copyWith(color: AppColors.success))),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          payable != null
                              ? '${r.customer?.name ?? 'This customer'} is paying ${formatMoney(payable)} after a ${formatMoney(r.maxDiscountAmount!)} Town Coin discount.'
                              : 'This customer scanned your counter QR, so you can approve without a PIN.',
                          style: textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.smd),
                        Row(
                          children: [
                            Expanded(child: AppButton(label: 'Ask for PIN', variant: AppButtonVariant.secondary, size: AppButtonSize.sm, onPressed: _busy ? null : () => _verify(r))),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: AppButton(label: 'Approve', size: AppButtonSize.sm, icon: Icons.verified_rounded, isLoading: _busy, onPressed: () => _approveAtCounter(r))),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  InfoBox(icon: banner.$2, tone: banner.$1, title: banner.$3, message: banner.$4),
                const SizedBox(height: AppSpacing.section),
                const SectionHeader(title: 'Redemption details', icon: Icons.receipt_long_rounded),
                const SizedBox(height: AppSpacing.smd),
                AppCard(
                  child: Column(
                    children: [
                      if (r.customer != null) DetailRow(label: 'Customer', value: r.customer!.name),
                      if (r.customer?.mobileNumber != null) DetailRow(label: 'Mobile', value: r.customer!.mobileNumber!),
                      if (r.branch != null) DetailRow(label: 'Branch', value: r.branch!.name),
                      DetailRow(label: 'Bill amount', value: formatMoney(r.billAmount)),
                      if (r.merchantDiscountRate != null) DetailRow(label: 'Discount rate', value: '${_trim(r.merchantDiscountRate!)}%'),
                      if (r.maxDiscountAmount != null) DetailRow(label: 'Max discount', value: formatMoney(r.maxDiscountAmount!)),
                      DetailRow(label: 'Coins requested', value: '${r.coinsRequested}'),
                      if (r.coinsDebited != null) DetailRow(label: 'Coins debited', value: '${r.coinsDebited}'),
                      if (r.discountAmount != null) DetailRow(label: 'Discount applied', value: formatMoney(r.discountAmount!), emphasize: true),
                      if (r.remainingBillAmount != null) DetailRow(label: 'Customer paid', value: formatMoney(r.remainingBillAmount!), emphasize: true),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                const SectionHeader(title: 'Verification', icon: Icons.verified_outlined),
                const SizedBox(height: AppSpacing.smd),
                AppCard(
                  child: Column(
                    children: [
                      DetailRow(label: 'Method', value: _methodLabel(r.verificationMethod)),
                      DetailRow(label: 'Verified at', value: r.verifiedAt != null ? formatDateTime(r.verifiedAt!) : '—'),
                      DetailRow(label: 'Code expires', value: r.qrExpiresAt != null ? formatDateTime(r.qrExpiresAt!) : '—'),
                      if (r.createdAt != null) DetailRow(label: 'Requested', value: formatDateTime(r.createdAt!)),
                      if (r.updatedAt != null) DetailRow(label: 'Last updated', value: formatDateTime(r.updatedAt!)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          );
        },
      ),
    );
  }

  /// The detail endpoint never loads the customer; borrow it from the
  /// list row when we came from the list.
  Redemption _withCustomer(Redemption fetched) {
    final row = widget.listRow;
    if (fetched.customer != null || row == null || row.id != fetched.id) return fetched;
    return Redemption(
      id: fetched.id,
      merchant: fetched.merchant ?? row.merchant,
      branch: fetched.branch ?? row.branch,
      billAmount: fetched.billAmount,
      discountAmount: fetched.discountAmount,
      remainingBillAmount: fetched.remainingBillAmount,
      coinsRequested: fetched.coinsRequested,
      coinsDebited: fetched.coinsDebited,
      status: fetched.status,
      verificationMethod: fetched.verificationMethod,
      verifiedAt: fetched.verifiedAt,
      createdAt: fetched.createdAt,
      qrExpiresAt: fetched.qrExpiresAt,
      customer: row.customer,
      counterPresenceVerified: fetched.counterPresenceVerified,
      merchantDiscountRate: fetched.merchantDiscountRate,
      maxDiscountAmount: fetched.maxDiscountAmount,
      updatedAt: fetched.updatedAt,
    );
  }

  static String _trim(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  static String _methodLabel(String? m) => switch (m) {
        'otp' => 'PIN typed at the counter',
        'qr' => 'Redemption QR',
        'counter_confirm' => 'Approved at the counter',
        null => '—',
        _ => m,
      };

  static (AppTone, IconData, String, String) _banner(String status) => switch (status) {
        'initiated' => (AppTone.pending, Icons.schedule_rounded, 'Awaiting your verification', 'Ask the customer for their code and use Verify below to complete this redemption.'),
        'verified' => (AppTone.info, Icons.verified_rounded, 'Verified', 'This redemption has been verified and is being settled.'),
        'settled' => (AppTone.success, Icons.verified_rounded, 'Completed', 'This redemption was verified and the discount has been settled.'),
        'expired' => (AppTone.error, Icons.timer_off_rounded, 'Expired', 'The verification window closed before this redemption was completed. It can no longer be verified.'),
        'cancelled' => (AppTone.error, Icons.cancel_rounded, 'Cancelled', 'This redemption was cancelled and can no longer be verified.'),
        _ => (AppTone.neutral, Icons.info_outline_rounded, status, ''),
      };
}
