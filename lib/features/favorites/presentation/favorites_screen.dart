import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/load_more_indicator.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../merchants/presentation/merchant_card.dart';
import '../../purchases/presentation/load_more_threshold.dart';
import '../application/favorites_controller.dart';

/// The customer's saved shops — the same [MerchantCard] the Shops list
/// uses, so a saved shop looks and behaves exactly as it did where it was
/// found: tap to open, tap the heart to remove.
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - kLoadMoreThreshold) {
      ref.read(favoriteMerchantsControllerProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(favoriteMerchantsControllerProvider);
    // The id set flips the instant a heart is tapped, ahead of the list's
    // own refetch — filtering by it makes an un-hearted shop leave the
    // screen immediately instead of lingering with an empty heart.
    final savedIds = ref.watch(favoriteMerchantIdsProvider).value;

    return AppScaffold(
      title: 'Favorites',
      padded: false,
      body: state.when(
        loading: () => const LoadingSkeletonList(),
        error: (error, _) => ErrorState(
          error: error is AppException ? error : const UnknownAppException(),
          onRetry: () => ref.read(favoriteMerchantsControllerProvider.notifier).refresh(),
        ),
        data: (data) {
          final items = savedIds == null ? data.items : data.items.where((m) => savedIds.contains(m.id)).toList();

          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'No favorites yet',
              message: 'Tap the heart on any shop to save it here for quick access.',
              action: FilledButton(onPressed: () => context.push('/merchants'), child: const Text('Discover shops')),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(favoriteMerchantsControllerProvider.notifier).refresh(),
            child: ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.page),
              itemCount: items.length + (data.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.smd),
              itemBuilder: (context, index) {
                if (index >= items.length) {
                  return const LoadMoreIndicator(label: 'Loading more favorites');
                }

                final merchant = items[index];
                return MerchantCard(
                  key: ValueKey(merchant.id),
                  merchant: merchant,
                  onTap: () => context.push('/merchants/${merchant.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
