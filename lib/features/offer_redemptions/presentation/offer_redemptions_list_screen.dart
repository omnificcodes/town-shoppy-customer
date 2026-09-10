import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../purchases/presentation/load_more_threshold.dart';
import '../application/offer_redemptions_list_controller.dart';
import 'offer_redemption_tile.dart';

class OfferRedemptionsListScreen extends ConsumerStatefulWidget {
  const OfferRedemptionsListScreen({super.key});

  @override
  ConsumerState<OfferRedemptionsListScreen> createState() => _OfferRedemptionsListScreenState();
}

class _OfferRedemptionsListScreenState extends ConsumerState<OfferRedemptionsListScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - kLoadMoreThreshold) {
      ref.read(offerRedemptionsListControllerProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(offerRedemptionsListControllerProvider);

    return AppScaffold(
      title: 'Offer redemptions',
      padded: false,
      body: state.when(
        loading: () => const LoadingSkeletonList(),
        error: (error, _) => ErrorState(
          error: error is AppException ? error : const UnknownAppException(),
          onRetry: () => ref.read(offerRedemptionsListControllerProvider.notifier).refresh(),
        ),
        data: (data) {
          if (data.items.isEmpty) {
            return const EmptyState(
              icon: Icons.local_offer_outlined,
              title: 'No offer redemptions yet',
              message: 'Coin discounts you request on offers, and the merchant\'s decision on each, will show up here.',
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(offerRedemptionsListControllerProvider.notifier).refresh(),
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppSpacing.page),
              itemCount: data.items.length + (data.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                if (index >= data.items.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading more offer redemptions')),
                  );
                }

                final redemption = data.items[index];
                return OfferRedemptionTile(redemption: redemption, onTap: () => context.push('/offer-redemptions/${redemption.id}'));
              },
            ),
          );
        },
      ),
    );
  }
}
