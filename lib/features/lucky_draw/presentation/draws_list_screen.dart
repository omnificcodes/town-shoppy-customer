import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../application/draws_list_controller.dart';
import 'draw_tile.dart';

/// Lucky Draw results -- every coupon's eventual destination. Only
/// COMPLETE draws are ever returned here (the backend never exposes an
/// in-progress draw's pool to a customer); if none exist yet (the
/// `lucky_draw` feature flag stays off pending legal review -- see
/// purchase-architecture.md), the empty state explains that plainly rather
/// than implying something is broken.
class DrawsListScreen extends ConsumerStatefulWidget {
  const DrawsListScreen({super.key});

  @override
  ConsumerState<DrawsListScreen> createState() => _DrawsListScreenState();
}

class _DrawsListScreenState extends ConsumerState<DrawsListScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 200) {
      ref.read(drawsListControllerProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(drawsListControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lucky Draw'),
        actions: [
          IconButton(
            icon: const Icon(Icons.card_giftcard_rounded),
            tooltip: 'My winnings',
            onPressed: () => context.push('/lucky-draw/my-wins'),
          ),
        ],
      ),
      body: SafeArea(
        child: state.when(
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, __) => const LoadingSkeletonCard(),
          ),
          error: (error, _) => ErrorState(
            error: error is AppException ? error : const UnknownAppException(),
            onRetry: () => ref.read(drawsListControllerProvider.notifier).refresh(),
          ),
          data: (data) {
            if (data.items.isEmpty) {
              return const EmptyState(
                icon: Icons.emoji_events_outlined,
                title: 'No draw results yet',
                message: 'Every eligible coupon you earn is automatically entered. Results will appear here once a draw runs.',
              );
            }

            return RefreshIndicator(
              onRefresh: () => ref.read(drawsListControllerProvider.notifier).refresh(),
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: data.items.length + 1 + (data.hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return AppCard(
                      onTap: () => context.push('/coupons'),
                      child: Row(
                        children: [
                          const Icon(Icons.confirmation_number_rounded, color: AppColors.orange),
                          const SizedBox(width: AppSpacing.sm),
                          const Expanded(child: Text('Every coupon you hold is an entry in the next draw for its cadence.')),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                        ],
                      ),
                    );
                  }

                  final itemIndex = index - 1;
                  if (itemIndex >= data.items.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final draw = data.items[itemIndex];
                  return DrawTile(draw: draw, onTap: () => context.push('/lucky-draw/${draw.id}'));
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
