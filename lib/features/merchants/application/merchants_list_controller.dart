import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/merchants_repository.dart';
import '../data/models/merchant.dart';

/// Offset-paginated merchant list state, plus the real server-side filters
/// `GET /merchants` supports: `category_id`, `search`, `accepts_town_coin`
/// (see `MerchantsRepository`'s own docblock for what was confirmed absent).
class MerchantsListState {
  const MerchantsListState({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.categoryId,
    this.search = '',
    this.acceptsTownCoinOnly = false,
    this.isLoadingMore = false,
    this.isChangingFilter = false,
  });

  final List<Merchant> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final int? categoryId;
  final String search;
  final bool acceptsTownCoinOnly;
  final bool isLoadingMore;
  final bool isChangingFilter;

  bool get hasMore => currentPage < lastPage;

  MerchantsListState copyWith({
    List<Merchant>? items,
    int? currentPage,
    int? lastPage,
    int? total,
    int? categoryId,
    bool clearCategoryId = false,
    String? search,
    bool? acceptsTownCoinOnly,
    bool? isLoadingMore,
    bool? isChangingFilter,
  }) {
    return MerchantsListState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      total: total ?? this.total,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      search: search ?? this.search,
      acceptsTownCoinOnly: acceptsTownCoinOnly ?? this.acceptsTownCoinOnly,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isChangingFilter: isChangingFilter ?? this.isChangingFilter,
    );
  }
}

/// Deliberately does NOT watch `sessionEpochProvider` — see
/// `merchantCategoriesProvider`'s docblock for why: merchant discovery is
/// public, non-personalized data, so there is no per-account cache to
/// isolate here.
class MerchantsListController extends AsyncNotifier<MerchantsListState> {
  @override
  Future<MerchantsListState> build() async {
    final page = await ref.watch(merchantsRepositoryProvider).list(page: 1);
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
      final page = await ref.read(merchantsRepositoryProvider).list(
            page: current.currentPage + 1,
            categoryId: current.categoryId,
            search: current.search,
            acceptsTownCoin: current.acceptsTownCoinOnly,
          );
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
      // A load-more failure keeps the existing list intact — only the
      // trailing loading indicator drops, matching every other paginated
      // list in the app.
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  /// Selecting a category (or clearing it with `null`) resets to page 1 —
  /// it is a fresh query, not something `loadMore` continues. Keeps the
  /// previous list visible (with `isChangingFilter` driving a small inline
  /// indicator) rather than blanking to a full loading screen — the same
  /// "never blank a known value" rule Phase 1 applied to the wallet balance,
  /// and it avoids `AsyncValue.copyWithPrevious`, which is `@internal` in
  /// this Riverpod version and not usable from application code.
  Future<void> filterByCategory(int? categoryId) async {
    final current = state.value;
    if (current == null || current.categoryId == categoryId) return;
    await _refetch(current.copyWith(categoryId: categoryId, clearCategoryId: categoryId == null));
  }

  /// Free-text name search — same fresh-query-to-page-1 shape as
  /// [filterByCategory]. The caller (the search bar) is responsible for
  /// debouncing keystrokes; this always issues the request it's given.
  Future<void> search(String query) async {
    final current = state.value;
    if (current == null || current.search == query) return;
    await _refetch(current.copyWith(search: query));
  }

  Future<void> setAcceptsTownCoinOnly(bool value) async {
    final current = state.value;
    if (current == null || current.acceptsTownCoinOnly == value) return;
    await _refetch(current.copyWith(acceptsTownCoinOnly: value));
  }

  /// Resets category, search, and the Town Coin toggle together as one
  /// request. Deliberately not three separate calls to the methods above —
  /// each of those reads `state.value` and fires its own `_refetch`, so
  /// three fired at once race each other and whichever network response
  /// lands last wins, potentially leaving e.g. the Town Coin toggle's own
  /// state stale even though the list itself came back unfiltered.
  Future<void> clearFilters() async {
    final current = state.value;
    if (current == null) return;
    if (current.categoryId == null && current.search.isEmpty && !current.acceptsTownCoinOnly) return;
    await _refetch(
      current.copyWith(clearCategoryId: true, search: '', acceptsTownCoinOnly: false),
    );
  }

  Future<void> _refetch(MerchantsListState pending) async {
    state = AsyncData(pending.copyWith(isChangingFilter: true));
    try {
      final page = await ref.read(merchantsRepositoryProvider).list(
            page: 1,
            categoryId: pending.categoryId,
            search: pending.search,
            acceptsTownCoin: pending.acceptsTownCoinOnly,
          );
      state = AsyncData(
        MerchantsListState(
          items: page.items,
          currentPage: page.currentPage,
          lastPage: page.lastPage,
          total: page.total,
          categoryId: pending.categoryId,
          search: pending.search,
          acceptsTownCoinOnly: pending.acceptsTownCoinOnly,
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

final merchantsListControllerProvider = AsyncNotifierProvider<MerchantsListController, MerchantsListState>(
  MerchantsListController.new,
);
