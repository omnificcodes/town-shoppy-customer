import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/models/offer.dart';
import '../data/offers_repository.dart';

/// Offset-paginated list state -- the `GET /offers` equivalent of
/// `RedemptionsListState`/`MerchantsListController`'s "All" tab, since
/// `OfferController::index()` is page-paginated.
class OffersListState {
  const OffersListState({required this.items, required this.currentPage, required this.lastPage, this.isLoadingMore = false});

  final List<Offer> items;
  final int currentPage;
  final int lastPage;
  final bool isLoadingMore;

  bool get hasMore => currentPage < lastPage;

  OffersListState copyWith({List<Offer>? items, int? currentPage, int? lastPage, bool? isLoadingMore}) {
    return OffersListState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class OffersListController extends AsyncNotifier<OffersListState> {
  @override
  Future<OffersListState> build() async {
    ref.watch(sessionEpochProvider);
    final page = await ref.watch(offersRepositoryProvider).list(page: 1);
    return OffersListState(items: page.items, currentPage: page.currentPage, lastPage: page.lastPage);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref.read(offersRepositoryProvider).list(page: current.currentPage + 1);
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

final offersListControllerProvider = AsyncNotifierProvider<OffersListController, OffersListState>(
  OffersListController.new,
);
