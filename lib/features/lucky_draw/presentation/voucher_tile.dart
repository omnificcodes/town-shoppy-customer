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

  @override
  Widget build(BuildContext context) {
    final prizeName = voucher.prize?.name ?? 'Prize';

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
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: AppColors.yellow.withValues(alpha: 0.25), shape: BoxShape.circle),
              child: const Icon(Icons.emoji_events_rounded, color: AppColors.orange),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(prizeName, style: Theme.of(context).textTheme.titleSmall),
                  if (voucher.sponsorMerchantName != null)
                    Text(voucher.sponsorMerchantName!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            StatusBadge(label: voucherStatusLabel(voucher.status), tone: voucherStatusTone(voucher.status)),
          ],
        ),
      ),
    );
  }
}
