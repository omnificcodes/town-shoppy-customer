import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/models/product.dart';
import '../data/products_repository.dart';
import 'products_query.dart';

/// Offset-paginated product catalog -- optionally scoped to one merchant
/// (the merchant detail page's Products section) or global (the Shopping
/// tab), same split `OffersListController` doesn't need only because
/// Offers has no per-merchant detail-page section today.
class ProductsListState {
  const ProductsListState({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    this.isLoadingMore = false,
  });

  final List<Product> items;
  final int currentPage;
  final int lastPage;

  /// How many products match, across every page -- what the catalog's
  /// "N items" count states, which is not `items.length` until the last
  /// page has loaded.
  final int total;

  final bool isLoadingMore;

  bool get hasMore => currentPage < lastPage;

  ProductsListState copyWith({List<Product>? items, int? currentPage, int? lastPage, int? total, bool? isLoadingMore}) {
    return ProductsListState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      total: total ?? this.total,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class ProductsListController extends AsyncNotifier<ProductsListState> {
  // Riverpod 3 family notifiers receive their argument via the constructor
  // (see BranchQrController's own precedent for this pattern).
  ProductsListController(this._query);

  final ProductsQuery _query;

  Map<String, dynamic> get _filters => {
    if (_query.search.isNotEmpty) 'search': _query.search,
    ..._query.filter.queryParameters,
  };

  @override
  Future<ProductsListState> build() async {
    ref.watch(sessionEpochProvider);
    final page = await ref
        .watch(productsRepositoryProvider)
        .list(merchantId: _query.merchantId, page: 1, filters: _filters);
    return ProductsListState(
      items: page.items,
      currentPage: page.currentPage,
      lastPage: page.lastPage,
      total: page.total,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref
          .read(productsRepositoryProvider)
          .list(merchantId: _query.merchantId, page: current.currentPage + 1, filters: _filters);
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          currentPage: page.currentPage,
          lastPage: page.lastPage,
          total: page.total,
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
    AsyncNotifierProvider.family<ProductsListController, ProductsListState, ProductsQuery>(ProductsListController.new);

/// A single product, for the standalone (possibly-unauthenticated) product
/// detail page -- `.autoDispose` since it's reached from a one-off deep
/// link/share and never needs to stay warm in memory afterwards.
final productDetailProvider = FutureProvider.autoDispose.family<Product, int>((ref, id) {
  return ref.watch(productsRepositoryProvider).show(id);
});
