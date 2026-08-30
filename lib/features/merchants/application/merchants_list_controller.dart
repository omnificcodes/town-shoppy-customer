import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/merchants_repository.dart';
import '../data/models/merchant.dart';

/// Offset-paginated merchant list state, plus the one real server-side
/// filter `GET /merchants` supports (`category_id` — see
/// `MerchantsRepository`'s own docblock for what was confirmed absent).
class MerchantsListState {
  const MerchantsListState({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.categoryId,
    this.isLoadingMore = false,
    this.isChangingFilter = false,
  });

  final List<Merchant> items;
  final int currentPage;
  final int lastPage;
  final int? categoryId;
  final bool isLoadingMore;
  final bool isChangingFilter;

  bool get hasMore => currentPage < lastPage;

  MerchantsListState copyWith({
    List<Merchant>? items,
    int? currentPage,
    int? lastPage,
    int? categoryId,
    bool clearCategoryId = false,
    bool? isLoadingMore,
    bool? isChangingFilter,
  }) {
    return MerchantsListState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
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
    return MerchantsListState(items: page.items, currentPage: page.currentPage, lastPage: page.lastPage, categoryId: null);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref.read(merchantsRepositoryProvider).list(
            page: current.currentPage + 1,
            categoryId: current.categoryId,
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

    state = AsyncData(current.copyWith(isChangingFilter: true));
    try {
      final page = await ref.read(merchantsRepositoryProvider).list(page: 1, categoryId: categoryId);
      state = AsyncData(
        MerchantsListState(
          items: page.items,
          currentPage: page.currentPage,
          lastPage: page.lastPage,
          categoryId: categoryId,
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
