import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../lucky_draw/application/draws_list_controller.dart';
import '../../lucky_draw/data/lucky_draw_repository.dart';
import 'business_context.dart';

/// Business mode's Lucky Draw list (BR-44): the completed draws of THIS
/// shop's own association, same paging as the customer list. A shop reads
/// the same public `GET /draws` as everyone; the backend adds the full
/// details of the winners of the shop's own sponsored prizes.
class BusinessDrawsController extends AsyncNotifier<DrawsListState> {
  @override
  Future<DrawsListState> build() async {
    ref.watch(sessionEpochProvider);
    final merchant = await ref.watch(myMerchantProvider.future);
    final page = await ref.watch(luckyDrawRepositoryProvider).draws(page: 1, associationId: merchant.association?.id);
    return DrawsListState(items: page.items, currentPage: page.currentPage, lastPage: page.lastPage);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final merchant = await ref.read(myMerchantProvider.future);
      final page = await ref
          .read(luckyDrawRepositoryProvider)
          .draws(page: current.currentPage + 1, associationId: merchant.association?.id);
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          currentPage: page.currentPage,
          lastPage: page.lastPage,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final businessDrawsControllerProvider = AsyncNotifierProvider<BusinessDrawsController, DrawsListState>(
  BusinessDrawsController.new,
);
