import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/models/redemption.dart';
import '../data/redemptions_repository.dart';

/// Offset-paginated list state — the `GET /redemptions` equivalent of
/// `PurchasesListState` (see that class's docblock for why offset
/// pagination, not a cursor, is the correct model here).
class RedemptionsListState {
  const RedemptionsListState({required this.items, required this.currentPage, required this.lastPage, this.isLoadingMore = false});

  final List<Redemption> items;
  final int currentPage;
  final int lastPage;
  final bool isLoadingMore;

  bool get hasMore => currentPage < lastPage;

  RedemptionsListState copyWith({List<Redemption>? items, int? currentPage, int? lastPage, bool? isLoadingMore}) {
    return RedemptionsListState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class RedemptionsListController extends AsyncNotifier<RedemptionsListState> {
  @override
  Future<RedemptionsListState> build() async {
    ref.watch(sessionEpochProvider);
    final page = await ref.watch(redemptionsRepositoryProvider).list(page: 1);
    return RedemptionsListState(items: page.items, currentPage: page.currentPage, lastPage: page.lastPage);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref.read(redemptionsRepositoryProvider).list(page: current.currentPage + 1);
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

final redemptionsListControllerProvider = AsyncNotifierProvider<RedemptionsListController, RedemptionsListState>(
  RedemptionsListController.new,
);
