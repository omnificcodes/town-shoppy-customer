import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/status_badge.dart';
import '../application/coupon_detail_provider.dart';
import '../data/models/coupon.dart';
import 'coupon_status.dart';

/// Mega → Monthly → Weekly, always in this fixed order regardless of what
/// order the backend's `eligibilities` array happens to come back in —
/// [Coupon.eligibilityFor] looks each one up by cadence rather than this
/// screen iterating the raw list.
const _cadenceOrder = <(String cadence, IconData icon, Color color)>[
  ('mega', Icons.emoji_events_rounded, AppColors.orange),
  ('monthly', Icons.calendar_month_rounded, Color(0xFF1E88E5)),
  ('weekly', Icons.card_giftcard_rounded, Color(0xFF6A1B9A)),
];

const _cadenceSubtitle = <String, String>{
  'mega': 'Year-end grand prize draw',
  'monthly': 'Monthly prize draw',
  'weekly': 'Weekly prize draw',
};

class CouponDetailScreen extends ConsumerWidget {
  const CouponDetailScreen({super.key, required this.couponId});

  final int couponId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(couponDetailProvider(couponId));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: detail.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Column(children: [LoadingSkeletonCard(), SizedBox(height: AppSpacing.sm), LoadingSkeletonCard()]),
                ),
                error: (error, _) => ErrorState(
                  error: error is AppException ? error : const UnknownAppException(),
                  onRetry: () => ref.invalidate(couponDetailProvider(couponId)),
                ),
                data: (coupon) => ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                  children: [
                    _CouponHeroCard(coupon: coupon),
                    const SizedBox(height: AppSpacing.md),
                    _EligibilityCard(coupon: coupon),
                    const SizedBox(height: AppSpacing.md),
                    _CouponInfoCard(coupon: coupon),
                    const SizedBox(height: AppSpacing.md),
                    const _KeepWinningBanner(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Navigator.canPop(), not go_router's own context.canPop() -- the
          // latter throws (via GoRouter.of()) when no GoRouter is present in
          // the widget tree, which a plain MaterialApp(home: ...) widget
          // test builds (see MerchantsDiscoveryHeader's own comment).
          if (Navigator.canPop(context))
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
              tooltip: 'Back',
              onPressed: () => context.pop(),
            )
          else
            const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Coupon Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    'Your lucky draw coupon information',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Transform.rotate(
              angle: 0.35,
              child: const Icon(Icons.confirmation_number_rounded, color: AppColors.orange, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}

class _CouponHeroCard extends StatelessWidget {
  const _CouponHeroCard({required this.coupon});

  final Coupon coupon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Your Unique Coupon Number', style: Theme.of(context).textTheme.labelMedium),
              _HeroStatusPill(status: coupon.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    coupon.code,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Material(
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: coupon.code));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coupon number copied')));
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    child: Icon(Icons.copy_rounded, size: 20, color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text('Use this number for lucky draw reference', style: Theme.of(context).textTheme.bodySmall),
              ),
              if (coupon.isActive) const _GoodLuckFlourish() else if (coupon.isWon) const _WonFlourish(),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStatusPill extends StatelessWidget {
  const _HeroStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final tone = couponStatusTone(status);
    final (bg, fg) = switch (tone) {
      StatusTone.success => (AppColors.successBg, AppColors.success),
      StatusTone.pending => (AppColors.pendingBg, AppColors.pending),
      StatusTone.error => (AppColors.errorBg, AppColors.error),
      StatusTone.neutral => (AppColors.silverLight, AppColors.silverDark),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            couponStatusLabel(status),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _GoodLuckFlourish extends StatelessWidget {
  const _GoodLuckFlourish();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Good Luck!',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, fontWeight: FontWeight.w700, color: AppColors.orange),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.card_giftcard_rounded, color: AppColors.orange, size: 20),
      ],
    );
  }
}

class _WonFlourish extends StatelessWidget {
  const _WonFlourish();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'You Won!',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, fontWeight: FontWeight.w700, color: AppColors.success),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.emoji_events_rounded, color: AppColors.success, size: 20),
      ],
    );
  }
}

class _EligibilityCard extends StatelessWidget {
  const _EligibilityCard({required this.coupon});

  final Coupon coupon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeading(
            icon: Icons.track_changes_rounded,
            iconColor: AppColors.crimson,
            title: 'Lucky Draw Eligibility',
            subtitle: 'Your participation status for each draw',
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final (cadence, icon, color) in _cadenceOrder)
            _EligibilityRow(
              icon: icon,
              color: color,
              label: cadenceLabel(cadence),
              subtitle: _cadenceSubtitle[cadence]!,
              eligibility: coupon.eligibilityFor(cadence),
            ),
        ],
      ),
    );
  }
}

class _EligibilityRow extends StatelessWidget {
  const _EligibilityRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.eligibility,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final CouponEligibility? eligibility;

  @override
  Widget build(BuildContext context) {
    final status = eligibility?.status;
    final (bg, fg) = switch (status) {
      'active' || 'won' => (AppColors.successBg, AppColors.success),
      _ => (AppColors.silverLight, AppColors.silverDark),
    };
    final statusIcon = switch (status) {
      'active' => Icons.check_circle_rounded,
      'won' => Icons.emoji_events_rounded,
      _ => Icons.cancel_rounded,
    };
    final statusLabel = switch (status) {
      'active' => 'In the running',
      'won' => 'Won',
      'closed' => 'Draw closed',
      _ => 'Not entered',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text(subtitle, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 13, color: fg),
                const SizedBox(width: 4),
                Text(
                  statusLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CouponInfoCard extends StatelessWidget {
  const _CouponInfoCard({required this.coupon});

  final Coupon coupon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeading(
            icon: Icons.description_rounded,
            iconColor: AppColors.orange,
            title: 'Coupon Information',
            subtitle: 'Details about how and when you received this coupon',
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(icon: Icons.shopping_cart_outlined, label: 'Earned from', value: _sourceLabel(coupon.sourceType)),
          if (coupon.issuedAt != null)
            _InfoRow(icon: Icons.calendar_today_rounded, label: 'Issued', value: _formatDateTime(coupon.issuedAt!)),
          if (coupon.annualCycleExpiresAt != null)
            _InfoRow(
              icon: Icons.access_time_rounded,
              label: 'Expires',
              value: _formatDateTime(coupon.annualCycleExpiresAt!),
            ),
        ],
      ),
    );
  }

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

class _CardHeading extends StatelessWidget {
  const _CardHeading({required this.icon, required this.iconColor, required this.title, required this.subtitle});

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              Text(subtitle, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _KeepWinningBanner extends StatelessWidget {
  const _KeepWinningBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
            child: const Icon(Icons.emoji_events_rounded, color: AppColors.onYellow, size: 26),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep Shopping\nKeep Winning!',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'More purchases, more chances for bigger rewards.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
