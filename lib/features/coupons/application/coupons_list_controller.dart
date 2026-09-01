import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/coupons_repository.dart';
import '../data/models/coupon.dart';

/// Offset-paginated list state -- the `GET /coupons` equivalent of
/// `PurchasesListState`, same shape and same reasoning (classic
/// page-number pagination via `OffsetPage`, not a cursor).
class CouponsListState {
  const CouponsListState({required this.items, required this.currentPage, required this.lastPage, this.isLoadingMore = false});

  final List<Coupon> items;
  final int currentPage;
  final int lastPage;
  final bool isLoadingMore;

  bool get hasMore => currentPage < lastPage;

  CouponsListState copyWith({List<Coupon>? items, int? currentPage, int? lastPage, bool? isLoadingMore}) {
    return CouponsListState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class CouponsListController extends AsyncNotifier<CouponsListState> {
  @override
  Future<CouponsListState> build() async {
    ref.watch(sessionEpochProvider);
    final page = await ref.watch(couponsRepositoryProvider).list(page: 1);
    return CouponsListState(items: page.items, currentPage: page.currentPage, lastPage: page.lastPage);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref.read(couponsRepositoryProvider).list(page: current.currentPage + 1);
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

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final couponsListControllerProvider = AsyncNotifierProvider<CouponsListController, CouponsListState>(
  CouponsListController.new,
);
