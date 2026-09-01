import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../merchants/data/merchants_repository.dart';
import '../../merchants/data/models/merchant.dart';

/// "Which merchants can I redeem Town Coin at" -- a fixed
/// `accepts_town_coin=1` filter over the same public `GET /merchants`
/// endpoint merchant discovery uses, kept as its own small controller
/// rather than reusing `MerchantsListController` (that controller's
/// category-filter state machine is more than this fixed-filter screen
/// needs).
class RedeemOffersState {
  const RedeemOffersState({required this.items, required this.currentPage, required this.lastPage, this.isLoadingMore = false});

  final List<Merchant> items;
  final int currentPage;
  final int lastPage;
  final bool isLoadingMore;

  bool get hasMore => currentPage < lastPage;

  RedeemOffersState copyWith({List<Merchant>? items, int? currentPage, int? lastPage, bool? isLoadingMore}) {
    return RedeemOffersState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class RedeemOffersController extends AsyncNotifier<RedeemOffersState> {
  @override
  Future<RedeemOffersState> build() async {
    final page = await ref.watch(merchantsRepositoryProvider).list(page: 1, acceptsTownCoin: true);
    return RedeemOffersState(items: page.items, currentPage: page.currentPage, lastPage: page.lastPage);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref.read(merchantsRepositoryProvider).list(
            page: current.currentPage + 1,
            acceptsTownCoin: true,
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
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final redeemOffersControllerProvider = AsyncNotifierProvider<RedeemOffersController, RedeemOffersState>(
  RedeemOffersController.new,
);
