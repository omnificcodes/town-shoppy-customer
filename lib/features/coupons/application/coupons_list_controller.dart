import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/coupons_repository.dart';
import '../data/models/coupon.dart';

/// Offset-paginated list state -- the `GET /coupons` equivalent of
/// `PurchasesListState`, same shape and same reasoning (classic
/// page-number pagination via `OffsetPage`, not a cursor). `statusFilter`
/// mirrors `MerchantsListState.categoryId` -- `null` means "all statuses".
class CouponsListState {
  const CouponsListState({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.statusFilter,
    this.isLoadingMore = false,
    this.isChangingFilter = false,
  });

  final List<Coupon> items;
  final int currentPage;
  final int lastPage;
  final String? statusFilter;
  final bool isLoadingMore;
  final bool isChangingFilter;

  bool get hasMore => currentPage < lastPage;

  CouponsListState copyWith({
    List<Coupon>? items,
    int? currentPage,
    int? lastPage,
    String? statusFilter,
    bool clearStatusFilter = false,
    bool? isLoadingMore,
    bool? isChangingFilter,
  }) {
    return CouponsListState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      statusFilter: clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isChangingFilter: isChangingFilter ?? this.isChangingFilter,
    );
  }
}

class CouponsListController extends AsyncNotifier<CouponsListState> {
  @override
  Future<CouponsListState> build() async {
    ref.watch(sessionEpochProvider);
    final page = await ref.watch(couponsRepositoryProvider).list(page: 1);
    return CouponsListState(items: page.items, currentPage: page.currentPage, lastPage: page.lastPage, statusFilter: null);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref.read(couponsRepositoryProvider).list(
            page: current.currentPage + 1,
            status: current.statusFilter,
          );
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          currentPage: page.currentPage,
          lastPage: page.lastPage,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      // A load-more failure keeps the existing list intact -- only the
      // trailing loading indicator drops, so the user can retry by
      // scrolling again rather than losing what already loaded.
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  /// Selecting a filter tab (or "All Coupons" with `null`) resets to page 1
  /// -- a fresh query, not something `loadMore` continues. Same
  /// keep-the-previous-list-visible pattern as
  /// `MerchantsListController.filterByCategory`.
  Future<void> filterByStatus(String? status) async {
    final current = state.value;
    if (current == null || current.statusFilter == status) return;

    state = AsyncData(current.copyWith(isChangingFilter: true));
    try {
      final page = await ref.read(couponsRepositoryProvider).list(page: 1, status: status);
      state = AsyncData(
        CouponsListState(
          items: page.items,
          currentPage: page.currentPage,
          lastPage: page.lastPage,
          statusFilter: status,
        ),
      );
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final couponsListControllerProvider = AsyncNotifierProvider<CouponsListController, CouponsListState>(
  CouponsListController.new,
);

/// Per-status totals for the filter tabs (e.g. "Active (7)") -- there is no
/// backend counts/summary endpoint, so this reads `meta.total` off three
/// minimal `per_page=1` requests (one per real `CouponStatus` value) rather
/// than paginating through the customer's entire coupon history just to
/// count it client-side. "All Coupons" is the sum, not a 4th request, since
/// every coupon is in exactly one of these three statuses.
class CouponCounts {
  const CouponCounts({required this.active, required this.won, required this.expired});

  final int active;
  final int won;
  final int expired;

  int get all => active + won + expired;
}

final couponCountsProvider = FutureProvider<CouponCounts>((ref) async {
  ref.watch(sessionEpochProvider);
  final repository = ref.watch(couponsRepositoryProvider);

  final results = await Future.wait([
    repository.list(page: 1, perPage: 1, status: 'active'),
    repository.list(page: 1, perPage: 1, status: 'won'),
    repository.list(page: 1, perPage: 1, status: 'expired'),
  ]);

  return CouponCounts(active: results[0].total, won: results[1].total, expired: results[2].total);
});
