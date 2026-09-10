import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/relative_time.dart';
import '../../../shared/widgets/app_card.dart';
import '../data/models/draw.dart';
import 'draw_status_display.dart';

class DrawTile extends StatelessWidget {
  const DrawTile({super.key, required this.draw, this.onTap});

  final Draw draw;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final prizeNames = draw.prizes.map((p) => p.name).join(', ');
    final prizeLine = prizeNames.isNotEmpty ? prizeNames : 'Prize draw';

    // Same "never color-only" reasoning as MerchantCard/NotificationTile --
    // without this, a screen reader gets no button role and no single
    // composed announcement for the row, just its disconnected Text children.
    return Semantics(
      button: onTap != null,
      label: '${drawCadenceTitle(draw.cadence)}, $prizeLine'
          '${draw.winnerCount != null ? ', ${draw.winnerCount} winners' : ''}',
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(drawCadenceTitle(draw.cadence), style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    prizeLine,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (draw.executedAt != null)
                    Text('Drawn ${relativeTime(draw.executedAt!)}', style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
            if (draw.winnerCount != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${draw.winnerCount}', style: Theme.of(context).textTheme.titleMedium),
                  Text('winners', style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
