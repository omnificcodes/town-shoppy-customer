import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../products/data/models/product.dart';
import '../data/business_products_repository.dart';
import 'business_context.dart';

class BusinessProductsState {
  const BusinessProductsState({required this.items, required this.currentPage, required this.lastPage, this.isLoadingMore = false});

  final List<Product> items;
  final int currentPage;
  final int lastPage;
  final bool isLoadingMore;

  bool get hasMore => currentPage < lastPage;

  BusinessProductsState copyWith({List<Product>? items, int? currentPage, int? lastPage, bool? isLoadingMore}) {
    return BusinessProductsState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class BusinessProductsController extends AsyncNotifier<BusinessProductsState> {
  @override
  Future<BusinessProductsState> build() async {
    ref.watch(sessionEpochProvider);
    final merchantId = ref.watch(myMerchantIdProvider);
    if (merchantId == null) return const BusinessProductsState(items: [], currentPage: 1, lastPage: 1);
    final page = await ref.watch(businessProductsRepositoryProvider).list(merchantId: merchantId);
    return BusinessProductsState(items: page.items, currentPage: page.currentPage, lastPage: page.lastPage);
  }

  Future<void> loadMore() async {
    final current = state.value;
    final merchantId = ref.read(myMerchantIdProvider);
    if (current == null || merchantId == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref.read(businessProductsRepositoryProvider).list(merchantId: merchantId, page: current.currentPage + 1);
      state = AsyncData(current.copyWith(items: [...current.items, ...page.items], currentPage: page.currentPage, lastPage: page.lastPage, isLoadingMore: false));
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> delete(int id) async {
    await ref.read(businessProductsRepositoryProvider).delete(id);
    await refresh();
  }
}

final businessProductsControllerProvider = AsyncNotifierProvider<BusinessProductsController, BusinessProductsState>(BusinessProductsController.new);
