import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/relative_time.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../data/models/purchase.dart';
import 'purchase_status.dart';

class PurchaseTile extends StatelessWidget {
  const PurchaseTile({super.key, required this.purchase, this.onTap});

  final Purchase purchase;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final statusLabel = purchaseStatusLabel(purchase.status);

    // Same "never color-only" reasoning as MerchantCard/NotificationTile --
    // without this, a screen reader gets no button role and no single
    // composed announcement for the row, just its disconnected Text children.
    return Semantics(
      button: onTap != null,
      label: '${purchase.merchantName}, ₹${purchase.billAmount.toStringAsFixed(2)}, $statusLabel'
          '${purchase.coinsAwarded > 0 ? ', +${purchase.coinsAwarded} coins' : ''}',
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(purchase.merchantName, style: Theme.of(context).textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '₹${purchase.billAmount.toStringAsFixed(2)} · ${purchase.createdAt != null ? relativeTime(purchase.createdAt!) : ''}',
                    style: AppTypography.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(label: statusLabel, tone: purchaseStatusTone(purchase.status)),
                if (purchase.coinsAwarded > 0) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text('+${purchase.coinsAwarded} coins', style: AppTypography.numericFinancialInline),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
