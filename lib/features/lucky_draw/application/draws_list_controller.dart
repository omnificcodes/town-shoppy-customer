import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/lucky_draw_repository.dart';
import '../data/models/draw.dart';
import '../data/models/draw_entry.dart';
import '../data/models/draw_winner.dart';

/// Same offset-paginated shape as `PurchasesListState` -- `GET /draws` uses
/// classic page-number pagination, not a cursor.
class DrawsListState {
  const DrawsListState({required this.items, required this.currentPage, required this.lastPage, this.isLoadingMore = false});

  final List<Draw> items;
  final int currentPage;
  final int lastPage;
  final bool isLoadingMore;

  bool get hasMore => currentPage < lastPage;

  DrawsListState copyWith({List<Draw>? items, int? currentPage, int? lastPage, bool? isLoadingMore}) {
    return DrawsListState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class DrawsListController extends AsyncNotifier<DrawsListState> {
  @override
  Future<DrawsListState> build() async {
    ref.watch(sessionEpochProvider);
    final page = await ref.watch(luckyDrawRepositoryProvider).draws(page: 1);
    return DrawsListState(items: page.items, currentPage: page.currentPage, lastPage: page.lastPage);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref.read(luckyDrawRepositoryProvider).draws(page: current.currentPage + 1);
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

final drawsListControllerProvider = AsyncNotifierProvider<DrawsListController, DrawsListState>(DrawsListController.new);

final drawDetailProvider = FutureProvider.family<Draw, int>((ref, id) {
  ref.watch(sessionEpochProvider);
  return ref.watch(luckyDrawRepositoryProvider).draw(id);
});

final drawWinnersProvider = FutureProvider.family<List<DrawWinner>, int>((ref, drawId) {
  ref.watch(sessionEpochProvider);
  return ref.watch(luckyDrawRepositoryProvider).winners(drawId);
});

/// One page of a draw's entries (BR-44); the key is `(drawId, page)`.
final drawEntriesPageProvider = FutureProvider.family<DrawEntriesPage, (int, int)>((ref, key) {
  ref.watch(sessionEpochProvider);
  return ref.watch(luckyDrawRepositoryProvider).entries(key.$1, page: key.$2);
});

/// The shuffled sample of entrant names the draw show scrolls through.
final drawEntriesSampleProvider = FutureProvider.family<List<DrawEntry>, int>((ref, drawId) {
  ref.watch(sessionEpochProvider);
  return ref.watch(luckyDrawRepositoryProvider).entriesSample(drawId);
});
