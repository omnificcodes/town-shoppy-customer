import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/models/wallet_ledger_entry.dart';
import '../data/wallet_repository.dart';

/// Cursor-paginated Town Coin ledger — same shape as
/// `NotificationsController`, since `GET /town-coins/transactions` is
/// cursor-paginated (the ledger only ever grows, never shrinks).
class WalletTransactionsState {
  const WalletTransactionsState({required this.items, required this.nextCursor, this.isLoadingMore = false});

  final List<WalletLedgerEntry> items;
  final String? nextCursor;
  final bool isLoadingMore;

  bool get hasMore => nextCursor != null;

  WalletTransactionsState copyWith({
    List<WalletLedgerEntry>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool? isLoadingMore,
  }) {
    return WalletTransactionsState(
      items: items ?? this.items,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class WalletTransactionsController extends AsyncNotifier<WalletTransactionsState> {
  @override
  Future<WalletTransactionsState> build() async {
    ref.watch(sessionEpochProvider);
    final page = await ref.watch(walletRepositoryProvider).transactions();
    return WalletTransactionsState(items: page.items, nextCursor: page.nextCursor);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref.read(walletRepositoryProvider).transactions(cursor: current.nextCursor);
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

final walletTransactionsControllerProvider = AsyncNotifierProvider<WalletTransactionsController, WalletTransactionsState>(
  WalletTransactionsController.new,
);
