import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../data/models/coupon.dart';
import 'coupon_status.dart';

/// A purely decorative color rotation for the ticket icon tile -- the
/// backend has no per-coupon color/theme field (same "no such column"
/// situation as `MerchantCategory`'s missing icon), so this cycles a fixed
/// local palette by id rather than reading anything from the API. Kept
/// local to this file rather than added to `AppColors` -- these tints only
/// ever mean "which row is this visually", never a status or brand meaning
/// `AppColors`' other tokens carry.
const _ticketColors = [
  AppColors.orange,
  AppColors.crimson,
  Color(0xFF6A1B9A),
  Color(0xFF1E88E5),
  Color(0xFF00897B),
];

class CouponTile extends StatelessWidget {
  const CouponTile({super.key, required this.coupon, this.onTap});

  final Coupon coupon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final activeCadences = coupon.eligibilities.where((e) => e.isActive).map((e) => cadenceLabel(e.cadence)).join(' · ');
    final cadenceLine = activeCadences.isNotEmpty ? activeCadences : 'No active draws';
    final validTill = coupon.annualCycleExpiresAt;
    final color = _ticketColors[coupon.id % _ticketColors.length];

    final semanticsParts = [
      coupon.code,
      couponStatusLabel(coupon.status),
      cadenceLine,
      if (validTill != null) 'Valid till ${_formatDate(validTill)}',
    ];

    return Semantics(
      button: onTap != null,
      label: semanticsParts.join(', '),
      child: AppCard(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(Icons.confirmation_number_rounded, color: color, size: 22),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coupon.code,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(letterSpacing: 0.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(cadenceLine, style: Theme.of(context).textTheme.labelSmall, overflow: TextOverflow.ellipsis),
                  if (validTill != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('Valid till ${_formatDate(validTill)}', style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                  ],
                  if (coupon.isWon) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.emoji_events_rounded, size: 13, color: AppColors.orange),
                        const SizedBox(width: 4),
                        Text(
                          'You won a reward!',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: AppColors.orange, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(label: couponStatusLabel(coupon.status), tone: couponStatusTone(coupon.status)),
                const SizedBox(height: AppSpacing.xs),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _formatDate(DateTime date) => '${date.day} ${_months[date.month - 1]} ${date.year}';
