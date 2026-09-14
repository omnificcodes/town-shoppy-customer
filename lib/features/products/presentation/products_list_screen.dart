import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../application/products_list_controller.dart';
import 'product_card.dart';

/// The Shopping catalog -- every active product from every active merchant
/// (`GET /products`), 2-column grid, page-paginated. Also reused, scoped to
/// one merchant, by [MerchantDetailScreen]'s Products section via
/// [merchantId]/[merchantName].
class ProductsListScreen extends ConsumerStatefulWidget {
  const ProductsListScreen({super.key, this.merchantId, this.merchantName});

  final int? merchantId;
  final String? merchantName;

  @override
  ConsumerState<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends ConsumerState<ProductsListScreen> {
  static const _loadMoreThreshold = 300.0;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - _loadMoreThreshold) {
      ref.read(productsListControllerProvider(widget.merchantId).notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsListControllerProvider(widget.merchantId));

    return AppScaffold(
      title: widget.merchantName ?? 'Shopping',
      padded: false,
      body: state.when(
        loading: () => const LoadingSkeletonList(),
        error: (error, _) => ErrorState(
          error: error is AppException ? error : const UnknownAppException(),
          onRetry: () => ref.read(productsListControllerProvider(widget.merchantId).notifier).refresh(),
        ),
        data: (data) {
          if (data.items.isEmpty) {
            return const EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'No products yet',
              message: 'Check back soon as participating merchants list their products.',
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(productsListControllerProvider(widget.merchantId).notifier).refresh(),
            child: GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppSpacing.page),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.smd,
                crossAxisSpacing: AppSpacing.smd,
                childAspectRatio: 0.58,
              ),
              itemCount: data.items.length,
              itemBuilder: (context, index) {
                final product = data.items[index];
                return ProductCard(
                  product: product,
                  showMerchantName: widget.merchantId == null,
                  onTap: () => context.push('/products/${product.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
