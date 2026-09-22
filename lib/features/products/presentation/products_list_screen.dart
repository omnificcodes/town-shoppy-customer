import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/load_more_indicator.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../cart/presentation/bag_bar.dart';
import '../application/products_list_controller.dart';
import '../application/products_query.dart';
import '../data/models/product.dart';
import 'add_to_bag_button.dart';
import 'product_card.dart';
import 'product_price.dart';

/// The Shopping catalog, following the Google Stitch redesign: a search
/// field and filter pills pinned under the app bar, what is on offer
/// today, the biggest saving as a featured card, then the 2-column grid
/// and the bag.
///
/// Also reused, scoped to one merchant, by [MerchantDetailScreen]'s
/// Products section via [merchantId]/[merchantName].
///
/// The pills filter on columns the catalog actually has (a discount, Town
/// Coin, a price ceiling). Stitch's category pills -- "Butter Cookies",
/// "Kerala Spiced" -- are absent because products carry no category, and
/// so are its star ratings, "Fresh Batch" chip, pack weights and the
/// artisan trust badges: nothing records them.
class ProductsListScreen extends ConsumerStatefulWidget {
  const ProductsListScreen({super.key, this.merchantId, this.merchantName});

  final int? merchantId;
  final String? merchantName;

  @override
  ConsumerState<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends ConsumerState<ProductsListScreen> {
  static const _loadMoreThreshold = 300.0;
  static const _searchDebounce = Duration(milliseconds: 350);

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  Timer? _debounce;
  late ProductsQuery _query = ProductsQuery(merchantId: widget.merchantId);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - _loadMoreThreshold) {
      ref.read(productsListControllerProvider(_query).notifier).loadMore();
    }
  }

  /// One fetch per pause in typing, not one per keystroke.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      final term = value.trim();
      if (term == _query.search) return;
      setState(() => _query = _query.copyWith(search: term));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsListControllerProvider(_query));

    return AppScaffold(
      title: widget.merchantName ?? 'Shopping',
      padded: false,
      actions: const [BagButton()],
      bottomBar: const BagBar(),
      backgroundColor: AppColors.surfaceMuted,
      body: Column(
        children: [
          _CatalogControls(
            controller: _searchController,
            filter: _query.filter,
            onSearchChanged: _onSearchChanged,
            onFilterChanged: (filter) => setState(() => _query = _query.copyWith(filter: filter)),
          ),
          Expanded(
            child: state.when(
              loading: () => const LoadingSkeletonList(),
              error: (error, _) => ErrorState(
                error: error is AppException ? error : const UnknownAppException(),
                onRetry: () => ref.read(productsListControllerProvider(_query).notifier).refresh(),
              ),
              data: (data) => RefreshIndicator(
                onRefresh: () => ref.read(productsListControllerProvider(_query).notifier).refresh(),
                child: data.items.isEmpty
                    ? _EmptyCatalog(query: _query, scrollController: _scrollController)
                    : _CatalogBody(
                        state: data,
                        query: _query,
                        scrollController: _scrollController,
                        showMerchantName: widget.merchantId == null,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The search field and the filter pills, pinned above the catalog.
class _CatalogControls extends StatelessWidget {
  const _CatalogControls({
    required this.controller,
    required this.filter,
    required this.onSearchChanged,
    required this.onFilterChanged,
  });

  final TextEditingController controller;
  final ProductFilter filter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ProductFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.sm),
            child: AppTextField(
              controller: controller,
              label: 'Search products',
              hintText: 'Search products by name',
              prefixIcon: Icons.search_rounded,
              textInputAction: TextInputAction.search,
              onChanged: onSearchChanged,
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.smd),
            child: Row(
              children: [
                for (final option in ProductFilter.values) ...[
                  _FilterPill(label: option.label, selected: option == filter, onTap: () => onFilterChanged(option)),
                  if (option != ProductFilter.values.last) const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.deepMaroon : AppColors.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.deepMaroon : AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd, vertical: AppSpacing.sm),
            child: Text(
              label,
              style: AppTypography.textTheme.labelMedium?.copyWith(
                color: selected ? AppColors.surface : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nothing matched — worded for what the customer actually did, since an
/// empty search result and an empty catalog need different advice.
class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog({required this.query, required this.scrollController});

  final ProductsQuery query;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    // Scrollable so pull-to-refresh still works on an empty catalog.
    return ListView(
      controller: scrollController,
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: query.isFiltered
              ? EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Nothing matched',
                  message: query.search.isEmpty
                      ? 'No products under this filter right now. Try another one.'
                      : 'No products match "${query.search}". Try a different word, or clear the filter.',
                )
              : const EmptyState(
                  icon: Icons.shopping_bag_outlined,
                  title: 'No products yet',
                  message: 'Check back soon as participating merchants list their products.',
                ),
        ),
      ],
    );
  }
}

class _CatalogBody extends StatelessWidget {
  const _CatalogBody({
    required this.state,
    required this.query,
    required this.scrollController,
    required this.showMerchantName,
  });

  final ProductsListState state;
  final ProductsQuery query;
  final ScrollController scrollController;
  final bool showMerchantName;

  @override
  Widget build(BuildContext context) {
    final items = state.items;

    // Picked from the first page only, so the featured product does not
    // swap under the reader as more pages load.
    final featured = query.isFiltered ? null : _bestSaving(items.take(20));
    final rest = featured == null ? items : items.where((product) => product.id != featured.id).toList();
    final discounted = items.where((product) => product.hasDiscount).length;

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        if (featured != null) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.smd, AppSpacing.page, 0),
              child: _OffersBanner(best: featured.savingPercentage!, count: discounted),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, 0),
              child: Text('BIGGEST SAVING', style: AppTypography.overline),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, 0),
              child: _FeaturedProductCard(product: featured, showMerchantName: showMerchantName),
            ),
          ),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.lg, AppSpacing.page, AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(featured == null ? 'All products' : 'More products', style: AppTypography.sectionTitle),
                ),
                Text('${state.total} ${state.total == 1 ? 'item' : 'items'}', style: AppTypography.caption),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.smd,
              crossAxisSpacing: AppSpacing.smd,
              childAspectRatio: 0.56,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final product = rest[index];
              return ProductCard(
                // Same reason as the merchant catalog's rows: a new
                // product shifts every tile along, and unkeyed tiles would
                // each keep the previous occupant's photo.
                key: ValueKey(product.id),
                product: product,
                showMerchantName: showMerchantName,
                onTap: () => context.push('/products/${product.id}'),
              );
            }, childCount: rest.length),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.lg),
            child: state.isLoadingMore
                ? const LoadMoreIndicator(label: 'Loading more products')
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  /// The loaded product whose offer takes the most off, or null when
  /// nothing on the page is discounted.
  static Product? _bestSaving(Iterable<Product> products) {
    Product? best;
    for (final product in products) {
      final percent = product.savingPercentage;
      if (percent == null) continue;
      if (best == null || percent > best.savingPercentage!) best = product;
    }
    return best;
  }
}

/// What today's offers add up to, stated from the catalog itself rather
/// than from a campaign the backend does not have.
class _OffersBanner extends StatelessWidget {
  const _OffersBanner({required this.best, required this.count});

  final double best;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.smd),
      decoration: BoxDecoration(
        color: AppColors.orangeTint,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.orangeBorder),
      ),
      child: Row(
        children: [
          Container(
            width: AppSize.controlSm,
            height: AppSize.controlSm,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: const Icon(Icons.local_offer_rounded, size: AppIconSize.md, color: AppColors.orangeDeep),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Up to ${formatPercentOff(best)} today', style: AppTypography.textTheme.titleSmall),
                Text(
                  '$count ${count == 1 ? 'product is' : 'products are'} on offer',
                  style: AppTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The catalog's headline product: a wide photo, what it is, and the
/// price beside the bag control.
class _FeaturedProductCard extends StatelessWidget {
  const _FeaturedProductCard({required this.product, required this.showMerchantName});

  final Product product;
  final bool showMerchantName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final description = product.description?.trim() ?? '';
    final percent = product.savingPercentage;

    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppSpacing.radiusLg), boxShadow: AppElevation.card),
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: () => context.push('/products/${product.id}'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.smd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 4 / 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        child: ColoredBox(
                          color: AppColors.surfaceMuted,
                          child: product.primaryImageUrl == null
                              ? const _FeaturedPlaceholder()
                              : Image.network(
                                  key: ValueKey(product.primaryImageUrl),
                                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                                  product.primaryImageUrl!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (_, _, _) => const _FeaturedPlaceholder(),
                                ),
                        ),
                      ),
                    ),
                    if (percent != null)
                      Positioned(
                        top: AppSpacing.sm,
                        right: AppSpacing.sm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd, vertical: AppSpacing.xs + 2),
                          decoration: BoxDecoration(
                            color: AppColors.orangeDeep,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: Text(
                            formatPercentOff(percent),
                            style: AppTypography.badgeLabel.copyWith(color: AppColors.onCrimson),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.smd),
                Text(product.name, style: textTheme.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (showMerchantName && product.merchantName.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    product.merchantName,
                    style: AppTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(description, style: textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.smd),
                  child: Divider(height: 1, color: AppColors.border),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: ProductPrice(product: product, large: true)),
                    const SizedBox(width: AppSpacing.sm),
                    AddToBagButton(product: product, large: true),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedPlaceholder extends StatelessWidget {
  const _FeaturedPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.orangeTintStrong, AppColors.orangeTint])),
      child: Center(
        child: Icon(Icons.shopping_bag_rounded, color: AppColors.orange, size: AppIconSize.display),
      ),
    );
  }
}
