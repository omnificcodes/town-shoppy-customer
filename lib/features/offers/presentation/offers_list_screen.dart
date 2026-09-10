import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../application/offers_list_controller.dart';
import 'offer_tile.dart';

/// The Offers tab -- every currently-active, publicly-visible offer
/// (`GET /offers`), page-paginated. Replaces Wallet as a bottom-nav
/// destination; Wallet itself is unchanged and still reachable from Home's
/// wallet card, just no longer a primary tab (same "still a real route,
/// just a top-level push now" demotion `/notifications` went through
/// earlier -- see `AppShell`'s own docblock).
class OffersListScreen extends ConsumerStatefulWidget {
  const OffersListScreen({super.key});

  @override
  ConsumerState<OffersListScreen> createState() => _OffersListScreenState();
}

class _OffersListScreenState extends ConsumerState<OffersListScreen> {
  static const _loadMoreThreshold = 200.0;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - _loadMoreThreshold) {
      ref.read(offersListControllerProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(offersListControllerProvider);

    return AppScaffold(
      title: 'Offers',
      padded: false,
      body: state.when(
        loading: () => const LoadingSkeletonList(),
        error: (error, _) => ErrorState(
          error: error is AppException ? error : const UnknownAppException(),
          onRetry: () => ref.read(offersListControllerProvider.notifier).refresh(),
        ),
        data: (data) {
          if (data.items.isEmpty) {
            return const EmptyState(
              icon: Icons.local_offer_outlined,
              title: 'No offers right now',
              message: 'Check back soon as participating merchants publish new offers.',
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(offersListControllerProvider.notifier).refresh(),
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppSpacing.page),
              itemCount: data.items.length + (data.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                if (index >= data.items.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading more offers')),
                  );
                }

                final offer = data.items[index];
                return OfferTile(
                  offer: offer,
                  onTap: offer.merchantId == null ? null : () => context.push('/merchants/${offer.merchantId}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
