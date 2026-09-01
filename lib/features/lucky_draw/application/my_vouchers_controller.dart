import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/lucky_draw_repository.dart';
import '../data/models/voucher.dart';

class MyVouchersState {
  const MyVouchersState({required this.items, required this.currentPage, required this.lastPage, this.isLoadingMore = false});

  final List<Voucher> items;
  final int currentPage;
  final int lastPage;
  final bool isLoadingMore;

  bool get hasMore => currentPage < lastPage;

  MyVouchersState copyWith({List<Voucher>? items, int? currentPage, int? lastPage, bool? isLoadingMore}) {
    return MyVouchersState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class MyVouchersController extends AsyncNotifier<MyVouchersState> {
  @override
  Future<MyVouchersState> build() async {
    ref.watch(sessionEpochProvider);
    final page = await ref.watch(luckyDrawRepositoryProvider).myVouchers(page: 1);
    return MyVouchersState(items: page.items, currentPage: page.currentPage, lastPage: page.lastPage);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref.read(luckyDrawRepositoryProvider).myVouchers(page: current.currentPage + 1);
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

final myVouchersControllerProvider = AsyncNotifierProvider<MyVouchersController, MyVouchersState>(MyVouchersController.new);

final voucherDetailProvider = FutureProvider.family<Voucher, int>((ref, id) {
  ref.watch(sessionEpochProvider);
  return ref.watch(luckyDrawRepositoryProvider).voucher(id);
});

final voucherQrSecretProvider = FutureProvider.family<String, int>((ref, id) {
  return ref.watch(luckyDrawRepositoryProvider).voucherQrSecret(id);
});
