import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/merchants_repository.dart';
import 'merchants_list_controller.dart';

/// Every merchant of one association, for the screen behind a Home
/// association tile -- `GET /merchants?association_id=`, offset-paginated
/// the same way as the main Shops list. Public, non-personalized data, so
/// (like [MerchantsListController]) it does not watch `sessionEpochProvider`.
class AssociationMerchantsController extends AsyncNotifier<MerchantsListState> {
  // Riverpod 3 family notifiers receive their argument via the constructor.
  AssociationMerchantsController(this._associationId);

  final int _associationId;

  @override
  Future<MerchantsListState> build() async {
    final page = await ref.watch(merchantsRepositoryProvider).list(page: 1, associationId: _associationId);
    return MerchantsListState(
      items: page.items,
      currentPage: page.currentPage,
      lastPage: page.lastPage,
      total: page.total,
      categoryId: null,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref
          .read(merchantsRepositoryProvider)
          .list(page: current.currentPage + 1, associationId: _associationId);
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          currentPage: page.currentPage,
          lastPage: page.lastPage,
          total: page.total,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      // Keeps the list already shown; only the trailing indicator drops.
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final associationMerchantsProvider =
    AsyncNotifierProvider.family<AssociationMerchantsController, MerchantsListState, int>(
      AssociationMerchantsController.new,
    );
