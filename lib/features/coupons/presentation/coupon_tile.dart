import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/relative_time.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../data/models/coupon.dart';
import 'coupon_status.dart';

class CouponTile extends StatelessWidget {
  const CouponTile({super.key, required this.coupon, this.onTap});

  final Coupon coupon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final activeCadences = coupon.eligibilities.where((e) => e.isActive).map((e) => cadenceLabel(e.cadence)).join(' · ');
    final secondaryLine = activeCadences.isNotEmpty
        ? activeCadences
        : (coupon.issuedAt != null ? 'Issued ${relativeTime(coupon.issuedAt!)}' : 'No active draws');

    // Same "never color-only" reasoning as MerchantCard/NotificationTile --
    // without this, a screen reader gets no button role and no single
    // composed announcement for the row, just its disconnected Text children.
    return Semantics(
      button: onTap != null,
      label: '${coupon.code}, ${couponStatusLabel(coupon.status)}, $secondaryLine',
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(coupon.code, style: Theme.of(context).textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    secondaryLine,
                    style: Theme.of(context).textTheme.labelSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            StatusBadge(label: couponStatusLabel(coupon.status), tone: couponStatusTone(coupon.status)),
          ],
        ),
      ),
    );
  }
}
