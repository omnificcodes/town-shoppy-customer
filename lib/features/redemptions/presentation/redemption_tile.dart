import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/relative_time.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../data/models/redemption.dart';
import 'redemption_status.dart';

class RedemptionTile extends StatelessWidget {
  const RedemptionTile({super.key, required this.redemption, this.onTap});

  final Redemption redemption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final statusLabel = redemptionStatusLabel(redemption.status);

    // Same "never color-only" reasoning as MerchantCard/NotificationTile --
    // without this, a screen reader gets no button role and no single
    // composed announcement for the row, just its disconnected Text children.
    return Semantics(
      button: onTap != null,
      label: '${redemption.merchantName}, ${redemption.coinsRequested} coins, $statusLabel',
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(redemption.merchantName, style: Theme.of(context).textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '${redemption.coinsRequested} coins · ${redemption.createdAt != null ? relativeTime(redemption.createdAt!) : ''}',
                    style: AppTypography.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            StatusBadge(label: statusLabel, tone: redemptionStatusTone(redemption.status)),
          ],
        ),
      ),
    );
  }
}
