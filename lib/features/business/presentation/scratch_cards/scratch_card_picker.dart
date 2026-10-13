import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../scratch_cards/data/models/scratch_card.dart';
import '../../../scratch_cards/presentation/scratch_card_theme.dart';

/// A sheet asking "Give a scratch card with this bill?" -- one row per
/// active design plus "No card". Returns the chosen design's id, null for
/// no card, and nothing (sheet dismissed) when the merchant backs out.
Future<({int? designId})?> showScratchCardPicker(BuildContext context, ScratchCardDesigns designs) {
  return showModalBottomSheet<({int? designId})>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final textTheme = Theme.of(context).textTheme;
      final remaining = designs.remaining;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.page),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Give a scratch card?', style: textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                remaining == null ? 'Your plan sets no monthly limit.' : '$remaining left this month on your plan.',
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final design in designs.active) ...[
                      ScratchCardDesignRow(design: design, onTap: () => Navigator.of(context).pop((designId: design.id))),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop((designId: null)),
                icon: const Icon(Icons.block_rounded),
                label: const Text('No card this time'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// One design as a row: a themed swatch, the title and what it gives.
class ScratchCardDesignRow extends StatelessWidget {
  const ScratchCardDesignRow({super.key, required this.design, this.onTap, this.trailing});

  final ScratchCardDesign design;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = ScratchCardTheme.of(design.theme);
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.smd),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(gradient: theme.faceGradient, borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                child: Text(theme.emoji, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(design.title, style: textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      design.isCoins ? '${design.coinAmount} Town Coins' : design.offerText ?? '',
                      style: AppTypography.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: AppSpacing.sm), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}
