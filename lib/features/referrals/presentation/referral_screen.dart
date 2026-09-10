import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/relative_time.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/info_box.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';
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

    return AppScaffold(
      title: 'Referrals',
      padded: false,
      body: summary.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.page),
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
            onRefresh: () => ref.refresh(referralSummaryProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                _CodeCard(summary: data),
                const SizedBox(height: AppSpacing.md),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _StatCard(label: 'Qualified', value: '${data.qualifiedCount}')),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: _StatCard(label: 'Pending', value: '${data.pendingCount}')),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: _StatCard(label: 'Bonus coupons', value: '${data.bonusCouponsEarned}')),
                    ],
                  ),
                ),
                // The rule is only stated when the backend told us the
                // milestone size -- the coin amounts per referral are not
                // in this response, so they are deliberately not quoted.
                if (data.milestoneReferralCount > 0) ...[
                  const SizedBox(height: AppSpacing.md),
                  InfoBox(
                    icon: Icons.card_giftcard_rounded,
                    title: 'How it works',
                    message: 'Someone who joins with your code qualifies once they make their first purchase, and you both '
                        'earn Town Coins. Every ${data.milestoneReferralCount} qualified referrals also earn you a '
                        'bonus Lucky Draw coupon.'
                        '${data.nextMilestoneReferralsRemaining != null ? ' ${data.nextMilestoneReferralsRemaining} more to your next bonus.' : ''}',
                  ),
                ],
                if (data.referredBy != null) ...[
                  const SizedBox(height: AppSpacing.section),
                  const SectionHeader(title: 'Referred by'),
                  const SizedBox(height: AppSpacing.sm),
                  _HistoryTile(entry: data.referredBy!, isOutbound: false),
                ],
                const SizedBox(height: AppSpacing.section),
                const SectionHeader(title: 'Your referrals'),
                const SizedBox(height: AppSpacing.sm),
                if (data.referrals.isEmpty)
                  const AppCard(
                    child: EmptyState(
                      compact: true,
                      icon: Icons.person_add_alt_1_rounded,
                      title: 'No referrals yet',
                      message: 'Share your code to get started.',
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
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.summary});

  final ReferralSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final code = summary.referralCode!;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your referral code', style: textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.smd),
                  decoration: BoxDecoration(
                    color: AppColors.orangeTint,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                  ),
                  child: Semantics(
                    label: 'Referral code ${code.split('').join(' ')}',
                    excludeSemantics: true,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        code,
                        style: AppTypography.numericFinancialMedium.copyWith(color: AppColors.textPrimary, letterSpacing: 2),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _CopyButton(
                tooltip: 'Copy code',
                onPressed: () => _copy(context, code, 'Referral code copied'),
              ),
            ],
          ),
          if (summary.referralLink != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(summary.referralLink!, style: textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: AppSpacing.sm),
                _CopyButton(
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

/// A 48dp copy target. The app has no share sheet, so "copy" is the honest
/// verb for both the code and the link.
class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSpacing.touchTarget,
      height: AppSpacing.touchTarget,
      child: IconButton(
        icon: const Icon(Icons.copy_rounded, size: AppIconSize.md),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(value, style: AppTypography.numericFinancialMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
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
    final statusLabel = _statusLabel(entry.status);
    final coins = isOutbound ? entry.rewardCoinsReferrer : entry.rewardCoinsReferred;

    final whenLine = isQualified && entry.qualifiedAt != null
        ? 'Qualified ${relativeTime(entry.qualifiedAt!)}'
        : entry.status == 'pending' && entry.createdAt != null
            ? 'Pending since ${relativeTime(entry.createdAt!)}'
            : entry.createdAt != null
                ? 'Joined ${relativeTime(entry.createdAt!)}'
                : statusLabel;
    final subtitle = coins != null && coins > 0 ? '$whenLine · +$coins coins' : whenLine;

    return Semantics(
      label: '$name, $subtitle, $statusLabel',
      excludeSemantics: true,
      child: AppCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(subtitle, style: AppTypography.caption),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            StatusBadge(
              label: statusLabel,
              tone: _statusTone(entry.status),
              icon: isQualified ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
            ),
          ],
        ),
      ),
    );
  }

  /// `ReferralStatus`: pending / qualified / rejected / expired.
  String _statusLabel(String status) => switch (status) {
        'qualified' => 'Qualified',
        'pending' => 'Pending',
        'rejected' => 'Rejected',
        'expired' => 'Expired',
        _ => status.isEmpty ? status : '${status[0].toUpperCase()}${status.substring(1)}',
      };

  AppTone _statusTone(String status) => switch (status) {
        'qualified' => AppTone.success,
        'pending' => AppTone.pending,
        'rejected' => AppTone.error,
        'expired' => AppTone.neutral,
        _ => AppTone.neutral,
      };
}
