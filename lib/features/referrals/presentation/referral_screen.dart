import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/relative_time.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../application/referral_summary_provider.dart';
import '../data/models/referral_summary.dart';

/// Shows the customer's own referral code/link and history, from the one
/// real referral endpoint the backend exposes (`GET /referrals/me`).
/// Applying a code happens elsewhere, during registration — see
/// `RegisterScreen` — since the backend only accepts a referral code at
/// that moment, never afterward.
class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(referralSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Referrals')),
      body: SafeArea(
        child: summary.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(children: [LoadingSkeletonCard(), SizedBox(height: AppSpacing.sm), LoadingSkeletonCard()]),
          ),
          error: (error, _) => ErrorState(
            error: error is AppException ? error : const UnknownAppException(),
            onRetry: () => ref.invalidate(referralSummaryProvider),
          ),
          data: (data) {
            if (data.referralCode == null) {
              return const EmptyState(
                icon: Icons.card_giftcard_rounded,
                title: 'Referrals unavailable',
                message: 'Your account does not currently have a referral code.',
              );
            }

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(referralSummaryProvider),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  _CodeCard(summary: data),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(child: _StatCard(label: 'Qualified', value: '${data.qualifiedCount}')),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: _StatCard(label: 'Pending', value: '${data.pendingCount}')),
                    ],
                  ),
                  if (data.nextMilestoneReferralsRemaining != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppCard(
                      child: Text(
                        '${data.nextMilestoneReferralsRemaining} more qualified referral'
                        '${data.nextMilestoneReferralsRemaining == 1 ? '' : 's'} to your next milestone bonus.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                  if (data.referredBy != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text('Referred by', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    _HistoryTile(entry: data.referredBy!, isOutbound: false),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Text('Your referrals', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  if (data.referrals.isEmpty)
                    AppCard(
                      child: Text(
                        "You haven't referred anyone yet. Share your code to get started.",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  else
                    for (final entry in data.referrals) ...[
                      _HistoryTile(entry: entry, isOutbound: true),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.summary});

  final ReferralSummary summary;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your referral code', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  summary.referralCode!,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(letterSpacing: 2, color: AppColors.orange),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded),
                tooltip: 'Copy code',
                onPressed: () => _copy(context, summary.referralCode!, 'Referral code copied'),
              ),
            ],
          ),
          if (summary.referralLink != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    summary.referralLink!,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.share_rounded),
                  tooltip: 'Copy link',
                  onPressed: () => _copy(context, summary.referralLink!, 'Referral link copied'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _copy(BuildContext context, String value, String message) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry, required this.isOutbound});

  final ReferralHistoryEntry entry;
  final bool isOutbound;

  @override
  Widget build(BuildContext context) {
    final name = (isOutbound ? entry.referredName : entry.referrerName) ?? 'Town Shoppy customer';
    final isQualified = entry.status == 'qualified';

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  isQualified && entry.qualifiedAt != null
                      ? 'Qualified ${relativeTime(entry.qualifiedAt!)}'
                      : entry.createdAt != null
                          ? 'Pending since ${relativeTime(entry.createdAt!)}'
                          : 'Pending',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          Icon(
            isQualified ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
            color: isQualified ? AppColors.success : AppColors.pending,
            size: 20,
          ),
        ],
      ),
    );
  }
}
