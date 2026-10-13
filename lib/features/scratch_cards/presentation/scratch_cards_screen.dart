import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/status_badge.dart';
import '../application/scratch_cards_providers.dart';
import '../data/models/scratch_card.dart';
import 'scratch_card_theme.dart';

/// Every scratch card the customer has been given: the ones still under
/// foil first, as glossy tiles that open the reveal; then the scratched
/// ones with their code and status.
class ScratchCardsScreen extends ConsumerWidget {
  const ScratchCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myScratchCardsProvider);

    return AppScaffold(
      title: 'Scratch cards',
      padded: false,
      body: async.when(
        loading: () => const LoadingSkeletonList(),
        error: (e, _) => ErrorState(
          error: e is AppException ? e : const UnknownAppException(),
          onRetry: () => ref.invalidate(myScratchCardsProvider),
        ),
        data: (cards) {
          if (cards.isEmpty) {
            return const EmptyState(
              icon: Icons.card_giftcard_rounded,
              title: 'No scratch cards yet',
              message: 'Shops give scratch cards with your purchases. Scratch one here to reveal an offer or Town Coins.',
            );
          }
          final waiting = cards.where((c) => c.isUnscratched).toList();
          final done = cards.where((c) => !c.isUnscratched).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myScratchCardsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.page, AppSpacing.page, AppSpacing.xxl),
              children: [
                if (waiting.isNotEmpty) ...[
                  Text('SCRATCH NOW', style: AppTypography.overline.copyWith(color: AppColors.textSecondary, letterSpacing: 0.8)),
                  const SizedBox(height: AppSpacing.sm),
                  for (final card in waiting) ...[
                    _WaitingTile(card: card, onTap: () => context.push('/scratch-cards/${card.id}')),
                    const SizedBox(height: AppSpacing.smd),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (done.isNotEmpty) ...[
                  Text('SCRATCHED', style: AppTypography.overline.copyWith(color: AppColors.textSecondary, letterSpacing: 0.8)),
                  const SizedBox(height: AppSpacing.sm),
                  for (final card in done) ...[
                    _DoneRow(card: card, onTap: () => context.push('/scratch-cards/${card.id}')),
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

/// An unscratched card: the themed face with a foil-like band inviting a tap.
class _WaitingTile extends StatelessWidget {
  const _WaitingTile({required this.card, required this.onTap});

  final CustomerScratchCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ScratchCardTheme.of(card.theme);
    final textTheme = Theme.of(context).textTheme;
    final ink = Colors.black.withValues(alpha: 0.78);

    return Semantics(
      button: true,
      label: '${card.title} from ${card.shopName}, scratch now',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          boxShadow: [BoxShadow(color: theme.accent.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: Material(
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: InkWell(
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(gradient: theme.faceGradient),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFE6E9EF), Color(0xFFB9BEC9), Color(0xFFE6E9EF)]),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: Text(theme.emoji, style: const TextStyle(fontSize: 28)),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(card.title, style: textTheme.titleMedium?.copyWith(color: ink, fontWeight: FontWeight.w900), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: AppSpacing.xxs),
                          Text('From ${card.shopName}', style: textTheme.bodySmall?.copyWith(color: ink.withValues(alpha: 0.8))),
                          if (card.expiresAt != null)
                            Text('Scratch before ${formatDate(card.expiresAt!)}', style: textTheme.bodySmall?.copyWith(color: ink.withValues(alpha: 0.7))),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(AppSpacing.radiusPill)),
                      child: Text('Scratch', style: textTheme.labelLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DoneRow extends StatelessWidget {
  const _DoneRow({required this.card, required this.onTap});

  final CustomerScratchCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ScratchCardTheme.of(card.theme);
    final textTheme = Theme.of(context).textTheme;
    final reward = card.reward;
    final (label, tone) = switch (card.status) {
      'redeemed' => ('Used', AppTone.success),
      'expired' => ('Expired', AppTone.neutral),
      _ => (reward?.isCoins == true ? 'Coins added' : 'Show at shop', reward?.isCoins == true ? AppTone.success : AppTone.pending),
    };
    final summary = reward == null
        ? '—'
        : reward.isCoins
        ? '+${reward.coinAmount} Town Coins'
        : '${reward.offerText}  ·  ${reward.formattedCode}';

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
            boxShadow: AppElevation.card,
          ),
          child: Row(
            children: [
              Container(
                width: AppSize.avatarMd,
                height: AppSize.avatarMd,
                alignment: Alignment.center,
                decoration: BoxDecoration(gradient: theme.faceGradient, borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                child: Text(theme.emoji, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.title, style: textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(summary, style: AppTypography.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(card.shopName, style: AppTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(label: label, tone: tone),
            ],
          ),
        ),
      ),
    );
  }
}
