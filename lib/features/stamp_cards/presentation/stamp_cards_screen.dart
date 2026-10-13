import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../application/stamp_cards_providers.dart';
import '../data/models/stamp_card.dart';
import 'stamp_card_face.dart';

/// Every stamp card the customer is collecting, as the cards themselves
/// (shop logo, title, reward, stamps), full ones first; rewards already
/// claimed are listed quietly underneath.
class StampCardsScreen extends ConsumerWidget {
  const StampCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myStampCardsProvider);

    return AppScaffold(
      title: 'My stamp cards',
      padded: false,
      body: async.when(
        loading: () => const LoadingSkeletonList(),
        error: (e, _) => ErrorState(
          error: e is AppException ? e : const UnknownAppException(),
          onRetry: () => ref.invalidate(myStampCardsProvider),
        ),
        data: (cards) {
          if (cards.isEmpty) {
            return const EmptyState(
              icon: Icons.loyalty_rounded,
              title: 'No stamp cards yet',
              message: 'Shops stamp a card each time you buy. Collect every stamp and the shop gives you the reward.',
            );
          }
          final live = cards.where((c) => c.isLive).toList();
          final claimed = cards.where((c) => c.isRewarded).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myStampCardsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.page, AppSpacing.page, AppSpacing.xxl),
              children: [
                for (final card in live) ...[
                  Semantics(
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
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (claimed.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text('REWARDS CLAIMED', style: AppTypography.overline.copyWith(color: AppColors.textSecondary, letterSpacing: 0.8)),
                  const SizedBox(height: AppSpacing.sm),
                  for (final card in claimed) ...[
                    _ClaimedRow(card: card, onTap: () => context.push('/stamp-cards/${card.id}')),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ClaimedRow extends StatelessWidget {
  const _ClaimedRow({required this.card, required this.onTap});

  final CustomerStampCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              const Icon(Icons.card_giftcard_rounded, color: AppColors.success),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.rewardText, style: textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${card.title} · ${card.shopName}', style: AppTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
