import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/detail_row.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/info_box.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/status_badge.dart';
import '../application/redemption_detail_provider.dart';
import '../data/models/redemption.dart';
import 'redemption_status.dart';

class RedemptionDetailScreen extends ConsumerWidget {
  const RedemptionDetailScreen({super.key, required this.redemptionId});

  final int redemptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(redemptionDetailProvider(redemptionId));

    return AppScaffold(
      title: 'Redemption details',
      padded: false,
      body: detail.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.page),
          child: Column(children: [LoadingSkeletonCard(), SizedBox(height: AppSpacing.sm), LoadingSkeletonCard()]),
        ),
        error: (error, _) => ErrorState(
          error: error is AppException ? error : const UnknownAppException(),
          onRetry: () => ref.invalidate(redemptionDetailProvider(redemptionId)),
        ),
        data: (redemption) {
          final statusNote = _statusNote(redemption);

          return RefreshIndicator(
            onRefresh: () => ref.refresh(redemptionDetailProvider(redemptionId).future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(redemption.merchantName, style: Theme.of(context).textTheme.titleLarge),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          StatusBadge(
                            label: redemptionStatusLabel(redemption.status),
                            tone: redemptionStatusTone(redemption.status),
                            large: true,
                          ),
                        ],
                      ),
                      if (redemption.branch != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(redemption.branch!.name, style: Theme.of(context).textTheme.bodySmall),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.monetization_on_rounded, size: AppIconSize.md, color: AppColors.goldDark),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text('${redemption.coinsRequested} coins', style: AppTypography.numericFinancialMedium),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        redemption.coinsDebited != null
                            ? 'Town Coins set aside when you started this redemption; ${redemption.coinsDebited} were deducted.'
                            : 'Town Coins set aside for this redemption. They are only deducted once the merchant verifies it.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (statusNote != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  statusNote,
                ],
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DetailRow(label: 'Bill amount', value: '₹${redemption.billAmount.toStringAsFixed(2)}'),
                      if (redemption.discountAmount != null)
                        DetailRow(label: 'Discount applied', value: '₹${redemption.discountAmount!.toStringAsFixed(2)}', emphasize: true),
                      if (redemption.remainingBillAmount != null)
                        DetailRow(label: 'Remaining bill', value: '₹${redemption.remainingBillAmount!.toStringAsFixed(2)}'),
                      if (redemption.coinsDebited != null) DetailRow(label: 'Coins debited', value: '${redemption.coinsDebited}'),
                      if (redemption.verificationMethod != null)
                        DetailRow(label: 'Verified via', value: _verificationMethodLabel(redemption.verificationMethod!)),
                      if (redemption.verifiedAt != null) DetailRow(label: 'Verified at', value: _formatDateTime(redemption.verifiedAt!)),
                      if (redemption.createdAt != null) DetailRow(label: 'Date', value: _formatDateTime(redemption.createdAt!)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// "What should I do / what happened" for the statuses that need it.
  /// `settled` needs none -- the figures below say it all.
  Widget? _statusNote(Redemption redemption) {
    switch (redemption.status) {
      case 'initiated':
        final expiresAt = redemption.qrExpiresAt;
        return InfoBox(
          tone: AppTone.pending,
          icon: Icons.qr_code_2_rounded,
          title: 'Show your code to the merchant',
          message: expiresAt != null
              ? 'This redemption completes once the merchant verifies your code. The code expires at ${_formatTime(expiresAt)}.'
              : 'This redemption completes once the merchant verifies your code. Codes expire shortly after they are created.',
        );
      case 'expired':
        return const InfoBox(
          tone: AppTone.error,
          icon: Icons.timer_off_rounded,
          title: 'Expired',
          message: 'The merchant did not verify this in time. No coins were deducted. Start a new redemption to try again.',
        );
      case 'cancelled':
        return const InfoBox(
          tone: AppTone.neutral,
          icon: Icons.cancel_outlined,
          title: 'Cancelled',
          message: 'This redemption was cancelled before it was verified. No coins were deducted.',
        );
      default:
        return null;
    }
  }

  String _verificationMethodLabel(String method) => switch (method) {
        'otp' => 'Verification code',
        'qr' => 'QR scan',
        _ => method,
      };

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final date = '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
    return '$date at ${_formatTime(local)}';
  }
}
