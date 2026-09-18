import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../merchants/data/models/merchant.dart';
import '../data/favorites_repository.dart';

/// The set of merchant ids the signed-in customer has saved — the single
/// source of truth every heart in the app reads. Watches
/// `sessionEpochProvider` so one account's hearts never survive into the
/// next account's session.
class FavoriteMerchantIdsController extends AsyncNotifier<Set<int>> {
  /// Merchants with a save/remove request in flight, so a rapid second tap
  /// on the same heart is ignored instead of racing the first.
  final Set<int> _inFlight = {};

  @override
  Future<Set<int>> build() {
    ref.watch(sessionEpochProvider);
    return ref.watch(favoritesRepositoryProvider).ids();
  }

  /// Flips one merchant optimistically — the heart fills the instant it is
  /// tapped — and rolls back if the server refuses. Returns the new state
  /// (`true` = now saved), or `null` when the tap was ignored. Rethrows
  /// after rolling back so the caller can show the error.
  Future<bool?> toggle(int merchantId) async {
    if (_inFlight.contains(merchantId)) return null;

    // A failed initial load still allows toggling: start from "nothing
    // saved" rather than leaving every heart dead until a manual refresh.
    final before = state.value ?? const <int>{};
    final willBeFavorite = !before.contains(merchantId);

    _inFlight.add(merchantId);
    state = AsyncData(willBeFavorite ? {...before, merchantId} : ({...before}..remove(merchantId)));

    try {
      final repository = ref.read(favoritesRepositoryProvider);
      await (willBeFavorite ? repository.add(merchantId) : repository.remove(merchantId));
      // The Favorites screen lists full merchants, not ids; drop its cache
      // so it refetches the next time it is shown.
      ref.invalidate(favoriteMerchantsControllerProvider);
      return willBeFavorite;
    } catch (_) {
      final current = state.value ?? const <int>{};
      state = AsyncData(willBeFavorite ? ({...current}..remove(merchantId)) : {...current, merchantId});
      rethrow;
    } finally {
      _inFlight.remove(merchantId);
    }
  }
}

final favoriteMerchantIdsProvider = AsyncNotifierProvider<FavoriteMerchantIdsController, Set<int>>(
  FavoriteMerchantIdsController.new,
);

/// Whether one merchant is saved. Narrow on purpose: a card rebuilds only
/// when its own heart changes, not on every toggle elsewhere in the list.
final isFavoriteMerchantProvider = Provider.family<bool, int>((ref, merchantId) {
  return ref.watch(favoriteMerchantIdsProvider.select((ids) => ids.value?.contains(merchantId) ?? false));
});

class FavoriteMerchantsState {
  const FavoriteMerchantsState({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    this.isLoadingMore = false,
  });

  final List<Merchant> items;
  final int currentPage;
  final int lastPage;
  final bool isLoadingMore;

  bool get hasMore => currentPage < lastPage;

  FavoriteMerchantsState copyWith({List<Merchant>? items, int? currentPage, int? lastPage, bool? isLoadingMore}) {
    return FavoriteMerchantsState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// The Favorites screen's paginated list of full merchants.
class FavoriteMerchantsController extends AsyncNotifier<FavoriteMerchantsState> {
  @override
  Future<FavoriteMerchantsState> build() async {
    ref.watch(sessionEpochProvider);
    final page = await ref.watch(favoritesRepositoryProvider).list(page: 1);
    return FavoriteMerchantsState(items: page.items, currentPage: page.currentPage, lastPage: page.lastPage);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref.read(favoritesRepositoryProvider).list(page: current.currentPage + 1);
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          currentPage: page.currentPage,
          lastPage: page.lastPage,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      // Same rule as every other paginated list: a load-more failure keeps
      // what is already on screen.
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}

final favoriteMerchantsControllerProvider = AsyncNotifierProvider<FavoriteMerchantsController, FavoriteMerchantsState>(
  FavoriteMerchantsController.new,
);
