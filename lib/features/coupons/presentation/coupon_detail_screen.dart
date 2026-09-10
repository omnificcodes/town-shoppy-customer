import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/detail_row.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../merchants/presentation/merchant_logo.dart';
import '../application/coupon_detail_provider.dart';
import '../data/models/coupon.dart';
import 'coupon_status.dart';

/// Mega → Monthly → Weekly, always in this fixed order regardless of what
/// order the backend's `eligibilities` array happens to come back in —
/// [Coupon.eligibilityFor] looks each one up by cadence rather than this
/// screen iterating the raw list.
const _cadenceOrder = <(String cadence, IconData icon, Color color)>[
  ('mega', Icons.emoji_events_rounded, AppColors.orange),
  ('monthly', Icons.calendar_month_rounded, AppColors.info),
  ('weekly', Icons.card_giftcard_rounded, AppColors.silverDark),
];

const _cadenceSubtitle = <String, String>{
  'mega': 'Year-end grand prize draw',
  'monthly': 'Monthly prize draw',
  'weekly': 'Weekly prize draw',
};

/// Answers, top to bottom: what is my coupon number (and its status), which
/// draws is it entered in, and where did it come from. One status signal —
/// the hero badge — rather than a badge plus an italic flourish plus a
/// third "you won" line all saying the same thing.
class CouponDetailScreen extends ConsumerWidget {
  const CouponDetailScreen({super.key, required this.couponId});

  final int couponId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(couponDetailProvider(couponId));

    return AppScaffold(
      title: 'Coupon details',
      padded: false,
      body: detail.when(
        loading: () => const LoadingSkeletonList(count: 3),
        error: (error, _) => ErrorState(
          error: error is AppException ? error : const UnknownAppException(),
          onRetry: () => ref.invalidate(couponDetailProvider(couponId)),
        ),
        data: (coupon) => ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            _CouponHeroCard(coupon: coupon),
            const SizedBox(height: AppSpacing.md),
            _EligibilityCard(coupon: coupon),
            const SizedBox(height: AppSpacing.md),
            _CouponInfoCard(coupon: coupon),
            const SizedBox(height: AppSpacing.md),
            const _KeepShoppingNote(),
          ],
        ),
      ),
    );
  }
}

class _CouponHeroCard extends StatelessWidget {
  const _CouponHeroCard({required this.coupon});

  final Coupon coupon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      tinted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Your coupon number', style: Theme.of(context).textTheme.labelMedium)),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(
                label: couponStatusLabel(coupon.status),
                tone: couponStatusTone(coupon.status),
                icon: coupon.isWon ? Icons.emoji_events_rounded : (coupon.isActive ? Icons.check_circle_rounded : null),
                large: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: AppSize.controlMd),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    coupon.code,
                    style: AppTypography.numericFinancialMedium.copyWith(letterSpacing: 1.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Material(
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: coupon.code));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coupon number copied')));
                  },
                  child: const Tooltip(
                    message: 'Copy coupon number',
                    child: SizedBox(
                      width: AppSize.controlMd,
                      height: AppSize.controlMd,
                      child: Icon(Icons.copy_rounded, size: AppIconSize.md, color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            coupon.isWon
                ? 'This coupon won a draw. See My wins for the prize.'
                : coupon.isActive
                    ? 'Quote this number if you are contacted about a draw.'
                    : 'This coupon is no longer entered in any draw.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
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
          const SectionHeader(
            icon: Icons.track_changes_rounded,
            title: 'Draw entries',
            subtitle: 'Which draws this coupon is entered in',
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
    final (statusIcon, statusLabel) = switch (status) {
      'active' => (Icons.check_circle_rounded, 'In the running'),
      'won' => (Icons.emoji_events_rounded, 'Won'),
      'closed' => (Icons.lock_clock_rounded, 'Draw closed'),
      _ => (Icons.remove_circle_outline_rounded, 'Not entered'),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: AppSize.avatarMd,
            height: AppSize.avatarMd,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: AppIconSize.md),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(subtitle, style: AppTypography.caption),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusBadge(label: statusLabel, tone: eligibilityStatusTone(status ?? ''), icon: statusIcon),
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
          const SectionHeader(icon: Icons.description_rounded, title: 'About this coupon'),
          const SizedBox(height: AppSpacing.xs),
          coupon.merchant != null
              ? _MerchantSourceRow(merchant: coupon.merchant!)
              : DetailRow(icon: Icons.shopping_cart_outlined, label: 'Earned from', value: _sourceLabel(coupon.sourceType)),
          if (coupon.issuedAt != null)
            DetailRow(icon: Icons.calendar_today_rounded, label: 'Issued', value: _formatDateTime(coupon.issuedAt!)),
          if (coupon.annualCycleExpiresAt != null)
            DetailRow(
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

/// The "Earned from" row, but tappable through to the merchant's shop page
/// -- same label/value column split as [DetailRow] (so it lines up with
/// the Issued/Expires rows beneath it), with the value side replaced by a
/// round logo + name instead of plain text.
class _MerchantSourceRow extends StatelessWidget {
  const _MerchantSourceRow({required this.merchant});

  final CouponMerchantRef merchant;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Earned from ${merchant.name}, view shop',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          onTap: () => context.push('/merchants/${merchant.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_outlined, size: AppIconSize.md, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: Text('Earned from', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                ),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  flex: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          merchant.name,
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      MerchantLogo(url: merchant.logoUrl, merchantName: merchant.name, size: AppSize.avatarSm),
                      const SizedBox(width: AppSpacing.xxs),
                      const Icon(Icons.chevron_right_rounded, size: AppIconSize.sm, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KeepShoppingNote extends StatelessWidget {
  const _KeepShoppingNote();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      tinted: true,
      child: Row(
        children: [
          Container(
            width: AppSize.avatarMd,
            height: AppSize.avatarMd,
            decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
            child: const Icon(Icons.emoji_events_rounded, color: AppColors.onYellow, size: AppIconSize.md),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('More purchases, more entries', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Every purchase at a participating merchant earns another coupon.',
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
