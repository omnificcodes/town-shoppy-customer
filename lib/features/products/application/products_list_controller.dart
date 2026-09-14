import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/models/product.dart';
import '../data/products_repository.dart';

/// Offset-paginated product catalog -- optionally scoped to one merchant
/// (the merchant detail page's Products section) or global (the Shopping
/// tab), same split `OffersListController` doesn't need only because
/// Offers has no per-merchant detail-page section today.
class ProductsListState {
  const ProductsListState({required this.items, required this.currentPage, required this.lastPage, this.isLoadingMore = false});

  final List<Product> items;
  final int currentPage;
  final int lastPage;
  final bool isLoadingMore;

  bool get hasMore => currentPage < lastPage;

  ProductsListState copyWith({List<Product>? items, int? currentPage, int? lastPage, bool? isLoadingMore}) {
    return ProductsListState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class ProductsListController extends AsyncNotifier<ProductsListState> {
  // Riverpod 3 family notifiers receive their argument via the constructor
  // (see BranchQrController's own precedent for this pattern).
  ProductsListController(this._merchantId);

  final int? _merchantId;

  @override
  Future<ProductsListState> build() async {
    ref.watch(sessionEpochProvider);
    final page = await ref.watch(productsRepositoryProvider).list(merchantId: _merchantId, page: 1);
    return ProductsListState(items: page.items, currentPage: page.currentPage, lastPage: page.lastPage);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref.read(productsRepositoryProvider).list(merchantId: _merchantId, page: current.currentPage + 1);
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

final productsListControllerProvider =
    AsyncNotifierProvider.family<ProductsListController, ProductsListState, int?>(ProductsListController.new);

/// A single product, for the standalone (possibly-unauthenticated) product
/// detail page -- `.autoDispose` since it's reached from a one-off deep
/// link/share and never needs to stay warm in memory afterwards.
final productDetailProvider = FutureProvider.autoDispose.family<Product, int>((ref, id) {
  return ref.watch(productsRepositoryProvider).show(id);
});
