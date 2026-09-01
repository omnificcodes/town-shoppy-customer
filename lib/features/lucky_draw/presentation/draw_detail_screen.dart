import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../application/draws_list_controller.dart';
import 'draw_status_display.dart';

class DrawDetailScreen extends ConsumerWidget {
  const DrawDetailScreen({super.key, required this.drawId});

  final int drawId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draw = ref.watch(drawDetailProvider(drawId));
    final winners = ref.watch(drawWinnersProvider(drawId));

    return Scaffold(
      appBar: AppBar(title: const Text('Draw results')),
      body: SafeArea(
        child: draw.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(children: [LoadingSkeletonCard(), SizedBox(height: AppSpacing.sm), LoadingSkeletonCard()]),
          ),
          error: (error, _) => ErrorState(
            error: error is AppException ? error : const UnknownAppException(),
            onRetry: () => ref.invalidate(drawDetailProvider(drawId)),
          ),
          data: (drawData) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(drawCadenceTitle(drawData.cadence), style: Theme.of(context).textTheme.headlineSmall),
                if (drawData.executedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Drawn on ${_formatDate(drawData.executedAt!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Text('Prizes', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                for (final prize in drawData.prizes) ...[
                  AppCard(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: AppColors.yellow.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                          child: const Icon(Icons.card_giftcard_rounded, color: AppColors.orange),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(prize.name, style: Theme.of(context).textTheme.titleSmall),
                              if (prize.sponsorMerchantName != null)
                                Text('Sponsored by ${prize.sponsorMerchantName}', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        Text('×${prize.quantityTotal}', style: Theme.of(context).textTheme.titleSmall),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                const SizedBox(height: AppSpacing.md),
                Text('Winners', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                winners.when(
                  loading: () => const LoadingSkeletonCard(),
                  error: (_, __) => Text('Could not load winners.', style: Theme.of(context).textTheme.bodySmall),
                  data: (winnerList) {
                    if (winnerList.isEmpty) {
                      return Text('No winners published yet.', style: Theme.of(context).textTheme.bodySmall);
                    }
                    return Column(
                      children: [
                        for (final winner in winnerList) ...[
                          AppCard(
                            child: Row(
                              children: [
                                const Icon(Icons.emoji_events_rounded, color: AppColors.orange, size: 20),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(winner.winnerLabel, style: Theme.of(context).textTheme.titleSmall),
                                ),
                                if (winner.prize != null)
                                  Text(winner.prize!.name, style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}
