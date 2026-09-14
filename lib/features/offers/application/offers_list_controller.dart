import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/models/offer.dart';
import '../data/offers_repository.dart';

/// How close to its end date an offer must be to show. Each value is
/// `GET /offers?expiring_within_days=` itself, so the server filters and
/// the page count describes the filtered set, not a client-side subset.
enum OfferExpiryFilter {
  all(null),
  thisWeek(7),
  nextDay(1);

  const OfferExpiryFilter(this.withinDays);

  final int? withinDays;
}

class OffersFilter {
  const OffersFilter({this.expiry = OfferExpiryFilter.all, this.categoryId});

  final OfferExpiryFilter expiry;

  /// A merchant category id (`GET /offers?category_id=`), or null for all.
  final int? categoryId;

  bool get isFiltered => expiry != OfferExpiryFilter.all || categoryId != null;
}

class OffersFilterController extends Notifier<OffersFilter> {
  @override
  OffersFilter build() => const OffersFilter();

  void setExpiry(OfferExpiryFilter expiry) {
    if (expiry == state.expiry) return;
    state = OffersFilter(expiry: expiry, categoryId: state.categoryId);
  }

  /// Tapping the selected category again clears it.
  void toggleCategory(int categoryId) {
    state = OffersFilter(expiry: state.expiry, categoryId: state.categoryId == categoryId ? null : categoryId);
  }

  void reset() => state = const OffersFilter();
}

final offersFilterProvider = NotifierProvider<OffersFilterController, OffersFilter>(OffersFilterController.new);

/// Offset-paginated list state -- the `GET /offers` equivalent of
/// `RedemptionsListState`/`MerchantsListController`'s "All" tab, since
/// `OfferController::index()` is page-paginated.
class OffersListState {
  const OffersListState({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    this.isLoadingMore = false,
  });

  final List<Offer> items;
  final int currentPage;
  final int lastPage;

  /// Every offer matching the current filter, not just the loaded pages.
  final int total;
  final bool isLoadingMore;

  bool get hasMore => currentPage < lastPage;

  OffersListState copyWith({List<Offer>? items, int? currentPage, int? lastPage, int? total, bool? isLoadingMore}) {
    return OffersListState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      total: total ?? this.total,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class OffersListController extends AsyncNotifier<OffersListState> {
  @override
  Future<OffersListState> build() async {
    ref.watch(sessionEpochProvider);
    final filter = ref.watch(offersFilterProvider);
    final page = await ref.watch(offersRepositoryProvider).list(
          page: 1,
          categoryId: filter.categoryId,
          expiringWithinDays: filter.expiry.withinDays,
        );
    return OffersListState(
      items: page.items,
      currentPage: page.currentPage,
      lastPage: page.lastPage,
      total: page.total,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore || state.isLoading) return;

    final filter = ref.read(offersFilterProvider);
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref.read(offersRepositoryProvider).list(
            page: current.currentPage + 1,
            categoryId: filter.categoryId,
            expiringWithinDays: filter.expiry.withinDays,
          );
      // A filter change while this page was in flight rebuilt the list;
      // appending the old filter's page would mix two result sets.
      if (!ref.mounted || !identical(ref.read(offersFilterProvider), filter)) return;
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
      if (!ref.mounted || !identical(ref.read(offersFilterProvider), filter)) return;
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
