import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/relative_time.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../data/models/offer_redemption.dart';
import 'offer_redemption_status.dart';

class OfferRedemptionTile extends StatelessWidget {
  const OfferRedemptionTile({super.key, required this.redemption, this.onTap});

  final OfferRedemption redemption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final statusLabel = offerRedemptionStatusLabel(redemption.status);

    return Semantics(
      button: onTap != null,
      label: '${redemption.title}, ${redemption.coinsRequested} coins, $statusLabel',
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(redemption.title, style: Theme.of(context).textTheme.titleSmall, overflow: TextOverflow.ellipsis),
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
            StatusBadge(label: statusLabel, tone: offerRedemptionStatusTone(redemption.status)),
          ],
        ),
      ),
    );
  }
}
