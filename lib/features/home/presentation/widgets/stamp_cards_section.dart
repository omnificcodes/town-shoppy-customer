import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../stamp_cards/application/stamp_cards_providers.dart';
import '../../../stamp_cards/presentation/stamp_card_face.dart';

/// "My stamp cards" on Home: the cards the customer is collecting, as a
/// swipeable strip, full ones first. Hidden while there are none, so Home
/// never advertises a feature the customer has not met yet.
class StampCardsSection extends ConsumerWidget {
  const StampCardsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(myStampCardsProvider).value?.where((c) => c.isLive).toList() ?? const [];
    if (cards.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: const Text('My stamp cards', style: AppTypography.sectionTitle)),
                    const SizedBox(height: AppSpacing.xxs),
                    Text('Collect stamps, claim the reward', style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              TextButton(onPressed: () => context.push('/stamp-cards'), child: const Text('See all')),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: cards.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final card = cards[index];
                return SizedBox(
                  width: 280,
                  child: Semantics(
                    button: true,
                    label: '${card.title} at ${card.shopName}, ${card.stampsCount} of ${card.stampsRequired} stamps',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => context.push('/stamp-cards/${card.id}'),
                      child: StampCardFace(
                        title: card.title,
                        rewardText: card.rewardText,
                        stampsRequired: card.stampsRequired,
                        stampsCount: card.stampsCount,
                        icon: card.icon,
                        merchantName: card.shopName,
                        merchantLogoUrl: card.merchantLogoUrl,
                        status: card.status,
                        compact: true,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
