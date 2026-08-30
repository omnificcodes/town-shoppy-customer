import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/models/purchase.dart';
import '../data/purchases_repository.dart';

/// Offset-paginated list state — the `GET /purchases` equivalent of
/// `NotificationsListState`, but tracking `{current_page, last_page}`
/// instead of a cursor, since `PurchaseController::index()` uses classic
/// page-number pagination (see `OffsetPage`).
class PurchasesListState {
  const PurchasesListState({required this.items, required this.currentPage, required this.lastPage, this.isLoadingMore = false});

  final List<Purchase> items;
  final int currentPage;
  final int lastPage;
  final bool isLoadingMore;

  bool get hasMore => currentPage < lastPage;

  PurchasesListState copyWith({List<Purchase>? items, int? currentPage, int? lastPage, bool? isLoadingMore}) {
    return PurchasesListState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class PurchasesListController extends AsyncNotifier<PurchasesListState> {
  @override
  Future<PurchasesListState> build() async {
    ref.watch(sessionEpochProvider);
    final page = await ref.watch(purchasesRepositoryProvider).list(page: 1);
    return PurchasesListState(items: page.items, currentPage: page.currentPage, lastPage: page.lastPage);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref.read(purchasesRepositoryProvider).list(page: current.currentPage + 1);
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
      // trailing loading indicator drops, so the user can retry by
      // scrolling again rather than losing what already loaded.
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final purchasesListControllerProvider = AsyncNotifierProvider<PurchasesListController, PurchasesListState>(
  PurchasesListController.new,
);
