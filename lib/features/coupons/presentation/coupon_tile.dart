import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/status_badge.dart';
import '../data/models/coupon.dart';
import 'coupon_status.dart';

/// One coupon, as a compact "ticket stub" row -- a navy/gold accent strip
/// (the coupon's brand identity) plus the code, status, which draws it's
/// currently entered in, and when it was issued. Capped well under 150dp
/// tall so a list of many coupons stays scannable; no illustration,
/// sponsor logos or marketing copy -- those belong to the Lucky Draw
/// screens, not repeated on every row of a list.
class CouponTile extends StatelessWidget {
  const CouponTile({super.key, required this.coupon, this.onTap});

  final Coupon coupon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final activeCadences = coupon.eligibilities.where((e) => e.isActive).map((e) => e.cadence).toSet();
    final issuedAt = coupon.issuedAt;

    final semanticsParts = [
      'Lucky Draw coupon ${coupon.code}',
      couponStatusLabel(coupon.status),
      if (activeCadences.isNotEmpty) 'Entered in ${activeCadences.map(cadenceLabel).join(', ')}',
      if (issuedAt != null) 'Issued ${_formatDate(issuedAt)}',
    ];

    return Semantics(
      button: onTap != null,
      label: semanticsParts.join(', '),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 150),
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            side: const BorderSide(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _StubAccent(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.smd),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  coupon.code,
                                  style: AppTypography.textTheme.titleMedium?.copyWith(letterSpacing: 0.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              StatusBadge(
                                label: couponStatusLabel(coupon.status),
                                tone: couponStatusTone(coupon.status),
                                icon: coupon.isWon ? Icons.emoji_events_rounded : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: [
                              for (final cadence in const ['weekly', 'monthly', 'mega'])
                                _CadenceChip(cadence: cadence, active: activeCadences.contains(cadence)),
                            ],
                          ),
                          if (issuedAt != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: AppIconSize.xs, color: AppColors.textSecondary),
                                const SizedBox(width: AppSpacing.xs),
                                Text('Issued ${_formatDate(issuedAt)}', style: AppTypography.caption),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: AppSpacing.sm),
                    child: Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: AppIconSize.md),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The card's brand identity -- a slim navy strip with a gold ticket icon,
/// evoking a coupon stub without the height cost of an illustrated one.
class _StubAccent extends StatelessWidget {
  const _StubAccent();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      alignment: Alignment.center,
      color: AppColors.luckyDrawNavy,
      child: const Icon(Icons.confirmation_number_rounded, color: AppColors.gold, size: AppIconSize.md),
    );
  }
}

class _CadenceChip extends StatelessWidget {
  const _CadenceChip({required this.cadence, required this.active});

  final String cadence;
  final bool active;

  static const _shortLabel = {'weekly': 'Weekly', 'monthly': 'Monthly', 'mega': 'Mega'};

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: active ? AppColors.goldLight : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: active ? AppColors.gold : AppColors.border),
      ),
      child: Text(
        _shortLabel[cadence] ?? cadence,
        style: AppTypography.textTheme.labelSmall?.copyWith(
          color: active ? AppColors.goldDark : AppColors.textDisabled,
        ),
      ),
    );
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _formatDate(DateTime date) => '${date.day} ${_months[date.month - 1]} ${date.year}';
