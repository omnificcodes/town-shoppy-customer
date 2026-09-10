import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../data/models/voucher.dart';
import 'draw_status_display.dart';

class VoucherTile extends StatelessWidget {
  const VoucherTile({super.key, required this.voucher, this.onTap});

  final Voucher voucher;
  final VoidCallback? onTap;

  /// Above this system text scale the badge no longer fits beside a prize
  /// name on a 320px phone, so it drops under the name instead.
  static const double _stackBadgeAtScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final prizeName = voucher.prize?.name ?? 'Prize';
    final textTheme = Theme.of(context).textTheme;
    final stackBadge = MediaQuery.textScalerOf(context).scale(1) >= _stackBadgeAtScale;
    final badge = StatusBadge(label: voucherStatusLabel(voucher.status), tone: voucherStatusTone(voucher.status));

    // Same "never color-only" reasoning as MerchantCard/NotificationTile --
    // without this, a screen reader gets no button role and no single
    // composed announcement for the row, just its disconnected Text children.
    return Semantics(
      button: onTap != null,
      label: '$prizeName, ${voucherStatusLabel(voucher.status)}'
          '${voucher.sponsorMerchantName != null ? ', sponsored by ${voucher.sponsorMerchantName}' : ''}',
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: AppSize.avatarMd,
              height: AppSize.avatarMd,
              decoration: const BoxDecoration(color: AppColors.orangeTint, shape: BoxShape.circle),
              child: const Icon(Icons.emoji_events_rounded, color: AppColors.orange, size: AppIconSize.md),
            ),
            const SizedBox(width: AppSpacing.smd),
            // The name gives way to the badge, never the other way round: a
            // long prize name ellipsizes rather than pushing the status off
            // the card.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(prizeName, style: textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (voucher.sponsorMerchantName != null)
                    Text(
                      voucher.sponsorMerchantName!,
                      style: textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (stackBadge) ...[const SizedBox(height: AppSpacing.xs), badge],
                ],
              ),
            ),
            if (!stackBadge) ...[const SizedBox(width: AppSpacing.sm), badge],
          ],
        ),
      ),
    );
  }
}
