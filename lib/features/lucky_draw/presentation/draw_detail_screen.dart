import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/info_box.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/section_header.dart';
import '../application/draws_list_controller.dart';
import '../data/models/draw.dart';
import '../data/models/draw_winner.dart';
import '../data/models/prize.dart';
import 'draw_status_display.dart';

/// A completed draw's public summary: its prizes and masked winner list.
///
/// "Did I win?" is deliberately NOT answered here from the winners list —
/// `DrawWinnerResource.winner_label` is a masked "Priya S." with no
/// customer id, `VoucherResource` carries no `draw_id`, and a prize can be
/// attached to more than one draw, so nothing the customer app receives
/// ties a win to *this* draw without guessing. The banner instead states
/// how winners are picked and sends the customer to My winnings, which is
/// own-account-only and therefore authoritative.
class DrawDetailScreen extends ConsumerWidget {
  const DrawDetailScreen({super.key, required this.drawId});

  final int drawId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draw = ref.watch(drawDetailProvider(drawId));

    return AppScaffold(
      title: 'Draw results',
      padded: false,
      body: draw.when(
        loading: () => const LoadingSkeletonList(count: 2),
        error: (error, _) => ErrorState(
          error: error is AppException ? error : const UnknownAppException(),
          onRetry: () => ref.invalidate(drawDetailProvider(drawId)),
        ),
        data: (drawData) => _DrawDetailBody(draw: drawData),
      ),
    );
  }
}

class _DrawDetailBody extends ConsumerWidget {
  const _DrawDetailBody({required this.draw});

  final Draw draw;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final winners = ref.watch(drawWinnersProvider(draw.id));
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        Text(drawCadenceTitle(draw.cadence), style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xxs),
        Text(_statusLine(draw), style: textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        InfoBox(
          tone: AppTone.neutral,
          icon: Icons.shuffle_rounded,
          message: 'Winners are drawn at random from all eligible coupons. '
              'Any prize you win appears under My winnings with its claim code.',
          action: AppButton(
            label: 'View my winnings',
            variant: AppButtonVariant.text,
            size: AppButtonSize.sm,
            expand: false,
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed: () => context.push('/lucky-draw/my-wins'),
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        const SectionHeader(title: 'Prizes'),
        const SizedBox(height: AppSpacing.sm),
        if (draw.prizes.isEmpty)
          const EmptyState(
            compact: true,
            icon: Icons.card_giftcard_outlined,
            title: 'No prize details published',
            message: 'This draw has no prize list attached.',
          )
        else
          for (final prize in draw.prizes) ...[
            _PrizeCard(prize: prize),
            if (prize != draw.prizes.last) const SizedBox(height: AppSpacing.sm),
          ],
        const SizedBox(height: AppSpacing.section),
        const SectionHeader(title: 'Winners'),
        const SizedBox(height: AppSpacing.sm),
        winners.when(
          loading: () => const LoadingSkeletonCard(),
          error: (error, _) => ErrorState(
            compact: true,
            error: error is AppException ? error : const UnknownAppException(),
            title: 'Could not load winners',
            onRetry: () => ref.invalidate(drawWinnersProvider(draw.id)),
          ),
          data: (winnerList) {
            if (winnerList.isEmpty) {
              return const EmptyState(
                compact: true,
                icon: Icons.emoji_events_outlined,
                title: 'No winners published yet',
                message: 'Winners appear here once the draw has been run and verified.',
              );
            }
            return Column(
              children: [
                for (final winner in winnerList) ...[
                  _WinnerRow(winner: winner),
                  if (winner != winnerList.last) const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  /// Only facts the resource actually carries: when it ran, or — for the
  /// rare non-complete state — its raw status.
  String _statusLine(Draw draw) {
    if (draw.executedAt != null) return 'Drawn on ${_formatDate(draw.executedAt!)}';
    if (draw.poolLockedAt != null) return 'Entries closed on ${_formatDate(draw.poolLockedAt!)}';
    return 'Status: ${draw.status}';
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class _PrizeCard extends StatelessWidget {
  const _PrizeCard({required this.prize});

  final Prize prize;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: AppSize.avatarMd,
            height: AppSize.avatarMd,
            decoration: BoxDecoration(color: AppColors.orangeTint, borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
            child: const Icon(Icons.card_giftcard_rounded, color: AppColors.orange, size: AppIconSize.md),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(prize.name, style: textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (prize.sponsorMerchantName != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Sponsored by ${prize.sponsorMerchantName}',
                    style: textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('×${prize.quantityTotal}', style: textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _WinnerRow extends StatelessWidget {
  const _WinnerRow({required this.winner});

  final DrawWinner winner;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final prizeName = winner.prize?.name;

    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: AppColors.orange, size: AppIconSize.md),
          const SizedBox(width: AppSpacing.sm),
          // Label gets the larger share; the prize name yields first and
          // ellipsizes, so neither can push the row past a 320px card.
          Expanded(
            flex: 3,
            child: Text(winner.winnerLabel, style: textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          if (prizeName != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              flex: 2,
              child: Text(
                prizeName,
                style: textTheme.bodySmall,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
