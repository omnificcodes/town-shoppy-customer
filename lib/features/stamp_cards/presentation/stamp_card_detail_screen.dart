import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/info_box.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../application/stamp_cards_providers.dart';
import '../data/models/stamp_card.dart';
import 'stamp_card_face.dart';

/// One card up close: the card, what to do next, and every stamp with the
/// day it was given. A full card is what the customer shows at the shop.
class StampCardDetailScreen extends ConsumerWidget {
  const StampCardDetailScreen({super.key, required this.cardId});

  final int cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(stampCardProvider(cardId));
    final allCards = ref.watch(myStampCardsProvider).value;

    return AppScaffold(
      title: 'Stamp card',
      padded: false,
      body: async.when(
        loading: () => const LoadingSkeletonList(count: 3),
        error: (e, _) => ErrorState(
          error: e is AppException ? e : const UnknownAppException(),
          onRetry: () => ref.invalidate(stampCardProvider(cardId)),
        ),
        data: (card) {
          final claimedHere = allCards?.where((c) => c.stampCardId == card.stampCardId && c.isRewarded).length ?? 0;
          final textTheme = Theme.of(context).textTheme;

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(stampCardProvider(cardId)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.page, AppSpacing.page, AppSpacing.xxl),
              children: [
                StampCardFace(
                  title: card.title,
                  rewardText: card.rewardText,
                  stampsRequired: card.stampsRequired,
                  stampsCount: card.stampsCount,
                  icon: card.icon,
                  merchantName: card.shopName,
                  merchantLogoUrl: card.merchantLogoUrl,
                  status: card.status,
                  animateLastStamp: card.isCollecting && card.stampsCount > 0,
                ),
                const SizedBox(height: AppSpacing.md),
                if (card.isFull)
                  InfoBox(
                    icon: Icons.celebration_rounded,
                    tone: AppTone.success,
                    message: 'Your card is full! Show this screen at ${card.shopName} to claim your ${card.rewardText}. A fresh card starts right after.',
                  )
                else if (card.isRewarded)
                  InfoBox(
                    icon: Icons.check_circle_rounded,
                    tone: AppTone.success,
                    message: 'You claimed your ${card.rewardText}${card.rewardedAt != null ? ' on ${formatDate(card.rewardedAt!)}' : ''}.',
                  )
                else
                  InfoBox(
                    icon: Icons.info_outline_rounded,
                    message: card.minBillAmount != null
                        ? 'Each bill of ${formatMoney(card.minBillAmount!)} or more at ${card.shopName} earns a stamp. ${card.remaining} more and the ${card.rewardText} is yours.'
                        : 'Each bill at ${card.shopName} earns a stamp. ${card.remaining} more and the ${card.rewardText} is yours.',
                  ),
                if (claimedHere > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    claimedHere == 1 ? 'You have claimed this reward once before.' : 'You have claimed this reward $claimedHere times before.',
                    style: AppTypography.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
                if (card.stamps.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('YOUR STAMPS', style: AppTypography.overline.copyWith(color: AppColors.textSecondary, letterSpacing: 0.8)),
                  const SizedBox(height: AppSpacing.sm),
                  for (final (i, stamp) in card.stamps.indexed) _StampHistoryRow(number: i + 1, stamp: stamp, textTheme: textTheme),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StampHistoryRow extends StatelessWidget {
  const _StampHistoryRow({required this.number, required this.stamp, required this.textTheme});

  final int number;
  final StampEntry stamp;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: AppSize.avatarSm,
            height: AppSize.avatarSm,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.successBg, shape: BoxShape.circle),
            child: Text('$number', style: textTheme.labelMedium?.copyWith(color: AppColors.success, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Text(
              stamp.givenAt != null ? 'Stamped on ${formatDateTime(stamp.givenAt!)}' : 'Stamped',
              style: textTheme.bodyMedium,
            ),
          ),
          if (stamp.purchaseId != null) Text('Bill #${stamp.purchaseId}', style: AppTypography.caption),
        ],
      ),
    );
  }
}
