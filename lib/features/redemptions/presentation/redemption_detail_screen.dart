import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/status_badge.dart';
import '../application/redemption_detail_provider.dart';
import 'redemption_status.dart';

class RedemptionDetailScreen extends ConsumerWidget {
  const RedemptionDetailScreen({super.key, required this.redemptionId});

  final int redemptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(redemptionDetailProvider(redemptionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Redemption details')),
      body: SafeArea(
        child: detail.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(children: [LoadingSkeletonCard(), SizedBox(height: AppSpacing.sm), LoadingSkeletonCard()]),
          ),
          error: (error, _) => ErrorState(
            error: error is AppException ? error : const UnknownAppException(),
            onRetry: () => ref.invalidate(redemptionDetailProvider(redemptionId)),
          ),
          data: (redemption) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(redemption.merchantName, style: Theme.of(context).textTheme.titleLarge),
                          ),
                          StatusBadge(label: redemption.status, tone: redemptionStatusTone(redemption.status)),
                        ],
                      ),
                      if (redemption.branch != null) ...[
                        const SizedBox(height: 2),
                        Text(redemption.branch!.name, style: Theme.of(context).textTheme.bodySmall),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Text('${redemption.coinsRequested} coins', style: Theme.of(context).textTheme.headlineMedium),
                      Text('requested for this redemption', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow(label: 'Bill amount', value: '₹${redemption.billAmount.toStringAsFixed(2)}'),
                      if (redemption.discountAmount != null)
                        _DetailRow(label: 'Discount applied', value: '₹${redemption.discountAmount!.toStringAsFixed(2)}'),
                      if (redemption.remainingBillAmount != null)
                        _DetailRow(label: 'Remaining bill', value: '₹${redemption.remainingBillAmount!.toStringAsFixed(2)}'),
                      if (redemption.coinsDebited != null) _DetailRow(label: 'Coins debited', value: '${redemption.coinsDebited}'),
                      if (redemption.verificationMethod != null)
                        _DetailRow(label: 'Verified via', value: redemption.verificationMethod!),
                      if (redemption.verifiedAt != null) _DetailRow(label: 'Verified at', value: _formatDateTime(redemption.verifiedAt!)),
                      if (redemption.createdAt != null) _DetailRow(label: 'Date', value: _formatDateTime(redemption.createdAt!)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final date = '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
    final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date at $time';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, style: Theme.of(context).textTheme.bodyMedium, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
