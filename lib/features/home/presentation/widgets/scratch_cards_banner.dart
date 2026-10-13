import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../scratch_cards/application/scratch_cards_providers.dart';
import '../../../scratch_cards/presentation/scratch_card_theme.dart';

/// "You have N scratch cards waiting" -- shown above the hero banner only
/// while the customer holds unscratched cards, and gone otherwise, so Home
/// never advertises a feature the customer has nothing to do with yet.
class ScratchCardsBanner extends ConsumerWidget {
  const ScratchCardsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(myScratchCardsProvider).value?.where((c) => c.isUnscratched).toList() ?? const [];
    if (cards.isEmpty) return const SizedBox.shrink();

    final theme = ScratchCardTheme.of(cards.first.theme);
    final textTheme = Theme.of(context).textTheme;
    final count = cards.length;
    final target = count == 1 ? '/scratch-cards/${cards.first.id}' : '/scratch-cards';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Semantics(
        button: true,
        label: count == 1 ? 'You have a scratch card waiting, scratch now' : 'You have $count scratch cards waiting, scratch now',
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            boxShadow: [BoxShadow(color: theme.accent.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: Material(
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: InkWell(
              onTap: () => context.push(target),
              child: Ink(
                decoration: BoxDecoration(gradient: theme.faceGradient),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      const Text('🎁', style: TextStyle(fontSize: 34)),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              count == 1 ? 'A scratch card is waiting!' : '$count scratch cards are waiting!',
                              style: textTheme.titleMedium?.copyWith(color: Colors.black.withValues(alpha: 0.8), fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              count == 1 ? 'From ${cards.first.shopName}. Scratch to reveal your prize.' : 'Scratch them to reveal your prizes.',
                              style: textTheme.bodySmall?.copyWith(color: Colors.black.withValues(alpha: 0.7)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd, vertical: AppSpacing.xs),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(AppSpacing.radiusPill)),
                        child: Text('Scratch', style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
