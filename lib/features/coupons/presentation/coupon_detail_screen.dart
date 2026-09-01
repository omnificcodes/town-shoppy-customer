import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/status_badge.dart';
import '../application/coupon_detail_provider.dart';
import 'coupon_status.dart';

class CouponDetailScreen extends ConsumerWidget {
  const CouponDetailScreen({super.key, required this.couponId});

  final int couponId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(couponDetailProvider(couponId));

    return Scaffold(
      appBar: AppBar(title: const Text('Coupon details')),
      body: SafeArea(
        child: detail.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(children: [LoadingSkeletonCard(), SizedBox(height: AppSpacing.sm), LoadingSkeletonCard()]),
          ),
          error: (error, _) => ErrorState(
            error: error is AppException ? error : const UnknownAppException(),
            onRetry: () => ref.invalidate(couponDetailProvider(couponId)),
          ),
          data: (coupon) {
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
                            child: Text(coupon.code, style: Theme.of(context).textTheme.titleLarge),
                          ),
                          StatusBadge(label: couponStatusLabel(coupon.status), tone: couponStatusTone(coupon.status)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('Your unique coupon number', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lucky Draw eligibility', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: AppSpacing.sm),
                      if (coupon.eligibilities.isEmpty)
                        Text('Not entered into any draw.', style: Theme.of(context).textTheme.bodySmall)
                      else
                        for (final eligibility in coupon.eligibilities)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(cadenceLabel(eligibility.cadence), style: Theme.of(context).textTheme.bodyMedium),
                                StatusBadge(
                                  label: _eligibilityLabel(eligibility.status),
                                  tone: eligibilityStatusTone(eligibility.status),
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow(label: 'Earned from', value: _sourceLabel(coupon.sourceType)),
                      if (coupon.issuedAt != null) _DetailRow(label: 'Issued', value: _formatDateTime(coupon.issuedAt!)),
                      if (coupon.annualCycleExpiresAt != null)
                        _DetailRow(label: 'Expires', value: _formatDateTime(coupon.annualCycleExpiresAt!)),
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

  String _eligibilityLabel(String status) => switch (status) {
        'active' => 'In the running',
        'won' => 'Won',
        'closed' => 'Draw closed',
        _ => status,
      };

  String _sourceLabel(String sourceType) => switch (sourceType) {
        'purchase' => 'A purchase',
        'referral_milestone' => 'Referral milestone',
        'free_entry' => 'Free entry',
        'admin_grant' => 'Town Shoppy',
        'campaign' => 'A campaign',
        _ => sourceType,
      };

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
