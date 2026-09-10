import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/models/offer_redemption.dart';
import '../data/offer_redemptions_repository.dart';

/// Cursor-paginated offer-redemption history -- same shape as
/// `WalletTransactionsController`, since `GET /offer-redemptions` is
/// cursor-paginated.
class OfferRedemptionsListState {
  const OfferRedemptionsListState({required this.items, required this.nextCursor, this.isLoadingMore = false});

  final List<OfferRedemption> items;
  final String? nextCursor;
  final bool isLoadingMore;

  bool get hasMore => nextCursor != null;

  OfferRedemptionsListState copyWith({
    List<OfferRedemption>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool? isLoadingMore,
  }) {
    return OfferRedemptionsListState(
      items: items ?? this.items,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class OfferRedemptionsListController extends AsyncNotifier<OfferRedemptionsListState> {
  @override
  Future<OfferRedemptionsListState> build() async {
    ref.watch(sessionEpochProvider);
    final page = await ref.watch(offerRedemptionsRepositoryProvider).list();
    return OfferRedemptionsListState(items: page.items, nextCursor: page.nextCursor);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref.read(offerRedemptionsRepositoryProvider).list(cursor: current.nextCursor);
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          nextCursor: page.nextCursor,
          clearCursor: page.nextCursor == null,
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

final offerRedemptionsListControllerProvider =
    AsyncNotifierProvider<OfferRedemptionsListController, OfferRedemptionsListState>(
  OfferRedemptionsListController.new,
);
