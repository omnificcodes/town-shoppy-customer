import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/detail_row.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/info_box.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/status_badge.dart';
import '../application/offer_redemption_detail_provider.dart';
import '../data/models/offer_redemption.dart';
import 'offer_redemption_status.dart';

class OfferRedemptionDetailScreen extends ConsumerWidget {
  const OfferRedemptionDetailScreen({super.key, required this.offerRedemptionId});

  final int offerRedemptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(offerRedemptionDetailProvider(offerRedemptionId));

    return AppScaffold(
      title: 'Offer redemption',
      padded: false,
      body: detail.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.page),
          child: Column(children: [LoadingSkeletonCard(), SizedBox(height: AppSpacing.sm), LoadingSkeletonCard()]),
        ),
        error: (error, _) => ErrorState(
          error: error is AppException ? error : const UnknownAppException(),
          onRetry: () => ref.invalidate(offerRedemptionDetailProvider(offerRedemptionId)),
        ),
        data: (redemption) {
          final statusNote = _statusNote(redemption);

          return RefreshIndicator(
            onRefresh: () => ref.refresh(offerRedemptionDetailProvider(offerRedemptionId).future),
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
                          Expanded(child: Text(redemption.title, style: Theme.of(context).textTheme.titleLarge)),
                          const SizedBox(width: AppSpacing.sm),
                          StatusBadge(
                            label: offerRedemptionStatusLabel(redemption.status),
                            tone: offerRedemptionStatusTone(redemption.status),
                            large: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (statusNote != null) ...[const SizedBox(height: AppSpacing.md), statusNote],
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DetailRow(label: 'Bill amount', value: '₹${redemption.billAmount.toStringAsFixed(2)}'),
                      DetailRow(
                        label: redemption.status == 'approved' ? 'Discount applied' : 'Discount requested (up to)',
                        value: '₹${(redemption.discountAmount ?? redemption.maxDiscountAmount).toStringAsFixed(2)}',
                        emphasize: true,
                      ),
                      DetailRow(
                        label: redemption.status == 'approved' ? 'Coins used' : 'Coins requested',
                        value: '${redemption.coinsApplied ?? redemption.coinsRequested}',
                      ),
                      if (redemption.createdAt != null) DetailRow(label: 'Requested', value: _formatDateTime(redemption.createdAt!)),
                      if (redemption.reviewedAt != null) DetailRow(label: 'Reviewed', value: _formatDateTime(redemption.reviewedAt!)),
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
  /// `approved` needs none -- the figures above say it all.
  Widget? _statusNote(OfferRedemption redemption) {
    switch (redemption.status) {
      case 'pending':
        return const InfoBox(
          tone: AppTone.pending,
          icon: Icons.hourglass_top_rounded,
          title: 'Waiting on the merchant',
          message: 'No coins have been deducted yet. The merchant reviews this at the counter and either approves or rejects it.',
        );
      case 'rejected':
        return InfoBox(
          tone: AppTone.error,
          icon: Icons.cancel_outlined,
          title: 'Rejected',
          message: redemption.rejectionReason ?? 'The merchant declined this request. No coins were deducted.',
        );
      default:
        return null;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour24 = local.hour;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour24 < 12 ? 'AM' : 'PM';
    final date = '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
    return '$date at $hour12:$minute $period';
  }
}
