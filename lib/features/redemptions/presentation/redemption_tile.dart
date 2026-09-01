import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
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
    // Same "never color-only" reasoning as MerchantCard/NotificationTile --
    // without this, a screen reader gets no button role and no single
    // composed announcement for the row, just its disconnected Text children.
    return Semantics(
      button: onTap != null,
      label: '${redemption.merchantName}, ${redemption.coinsRequested} coins, ${redemption.status}',
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(redemption.merchantName, style: Theme.of(context).textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${redemption.coinsRequested} coins · ${redemption.createdAt != null ? relativeTime(redemption.createdAt!) : ''}',
                    style: Theme.of(context).textTheme.labelSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            StatusBadge(label: redemption.status, tone: redemptionStatusTone(redemption.status)),
          ],
        ),
      ),
    );
  }
}
