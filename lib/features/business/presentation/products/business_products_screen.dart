import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/load_more_indicator.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../products/data/models/product.dart';
import '../../../purchases/presentation/load_more_threshold.dart';
import '../../application/business_context.dart';
import '../../application/business_products_controller.dart';
import '../../data/business_products_repository.dart';
import '../business_routes.dart';
import '../widgets/business_dialogs.dart';
import '../widgets/business_page_header.dart';

/// The Products tab: this business's own catalog. Owners create, edit and
/// delete from here; staff read (no documented staff capability for the
/// catalog, same rule Offers already follows). Full-width list cards, not
/// the customer-facing Shopping grid -- a management list needs to show
/// status and per-row actions, which a photo-forward grid tile has no room
/// for.
class BusinessProductsScreen extends ConsumerStatefulWidget {
  const BusinessProductsScreen({super.key});

  @override
  ConsumerState<BusinessProductsScreen> createState() => _BusinessProductsScreenState();
}

class _BusinessProductsScreenState extends ConsumerState<BusinessProductsScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - kLoadMoreThreshold) {
        ref.read(businessProductsControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(businessProductsControllerProvider);
    final isOwner = ref.watch(isBusinessOwnerProvider);

    return Scaffold(
      floatingActionButton: isOwner
          ? Padding(
              padding: const EdgeInsets.only(bottom: AppSize.fab),
              child: FloatingActionButton.extended(
                heroTag: 'new-product',
                backgroundColor: AppColors.businessInk,
                foregroundColor: AppColors.onBusinessInk,
                icon: const Icon(Icons.add_rounded),
                label: const Text('New product'),
                onPressed: () => context.push(BusinessRoutes.productNew),
              ),
            )
          : null,
      body: Column(
        children: [
          BusinessPageHeader(
            title: 'Products',
            subtitle: isOwner ? 'Your catalog, ordered via WhatsApp' : 'Your business catalog · read only',
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: state.when(
              loading: () => const LoadingSkeletonList(count: 3),
              error: (e, _) => ErrorState(
                error: e is AppException ? e : const UnknownAppException(),
                title: 'Could not load products.',
                onRetry: () => ref.read(businessProductsControllerProvider.notifier).refresh(),
              ),
              data: (data) {
                if (data.items.isEmpty) {
                  return EmptyState(
                    icon: Icons.shopping_bag_outlined,
                    title: 'No products yet',
                    message: isOwner
                        ? 'Add your first product for customers to browse and order via WhatsApp.'
                        : 'Your business has no products yet.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(businessProductsControllerProvider.notifier).refresh(),
                  child: ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xxl * 2),
                    itemCount: data.items.length + (data.hasMore ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.smd),
                    itemBuilder: (context, i) {
                      if (i >= data.items.length) {
                        return const LoadMoreIndicator();
                      }
                      final product = data.items[i];
                      return _ProductRow(
                        // Keyed by product, not by position: adding a
                        // product puts a new row at the top and shifts
                        // every other one down, and without this Flutter
                        // reuses each row's Image element at its old index
                        // -- which keeps painting the previous occupant's
                        // photo until the new one finishes loading.
                        key: ValueKey(product.id),
                        product: product,
                        onTap: () => context.push('${BusinessRoutes.products}/${product.id}/edit', extra: product),
                        onMore: isOwner ? () => _showActions(context, product) : null,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showActions(BuildContext context, Product product) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.sm),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  product.name,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.of(sheetContext).pop('edit'),
            ),
            ListTile(
              leading: Icon(product.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              title: Text(product.isActive ? 'Mark inactive' : 'Mark active'),
              onTap: () => Navigator.of(sheetContext).pop('toggle'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: const Text('Delete', style: TextStyle(color: AppColors.error)),
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      switch (action) {
        case 'edit':
          context.push('${BusinessRoutes.products}/${product.id}/edit', extra: product);
        case 'toggle':
          final input = ProductInput(
            name: product.name,
            price: product.price,
            description: product.description,
            imageUrls: product.imageUrls,
            townCoinPercentage: product.townCoinPercentage,
            status: product.isActive ? 'inactive' : 'active',
          );
          final merchantId = ref.read(myMerchantIdProvider);
          if (merchantId == null) return;
          await ref.read(businessProductsRepositoryProvider).update(product.id, input);
          await ref.read(businessProductsControllerProvider.notifier).refresh();
          messenger.showSnackBar(SnackBar(content: Text(product.isActive ? 'Marked inactive.' : 'Marked active.')));
        case 'delete':
          final ok = await showBusinessConfirmDialog(
            context,
            title: 'Delete this product?',
            message: 'This cannot be undone.',
            confirmLabel: 'Delete',
            destructive: true,
          );
          if (!ok) return;
          await ref.read(businessProductsControllerProvider.notifier).delete(product.id);
          messenger.showSnackBar(const SnackBar(content: Text('Product deleted.')));
      }
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({super.key, required this.product, required this.onTap, this.onMore});

  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: '${product.name}, ${product.isActive ? 'active' : 'inactive'}',
      child: AppCard(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Thumbnail(product: product),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '₹${_trim(product.price)}',
                    style: textTheme.bodyMedium?.copyWith(color: AppColors.orangeDeep, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      StatusBadge(
                        label: product.isActive ? 'Active' : 'Inactive',
                        tone: product.isActive ? AppTone.success : AppTone.neutral,
                      ),
                      if (product.acceptsTownCoin)
                        StatusBadge(
                          label: '${_trim(product.townCoinPercentage!)}% Coin',
                          tone: AppTone.success,
                          icon: Icons.savings_rounded,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (onMore != null)
              IconButton(
                icon: const Icon(Icons.more_horiz_rounded),
                tooltip: 'Actions for ${product.name}',
                onPressed: onMore,
              ),
          ],
        ),
      ),
    );
  }

  static String _trim(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final hasImage = product.primaryImageUrl != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: hasImage
          ? Image.network(
              // The URL is the image's identity: a different one must
              // build a fresh Image rather than update the old one, which
              // holds its last frame while the new URL loads.
              key: ValueKey(product.primaryImageUrl),
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              product.primaryImageUrl!,
              width: AppSize.avatarLg,
              height: AppSize.avatarLg,
              fit: BoxFit.cover,
            )
          : Container(
              width: AppSize.avatarLg,
              height: AppSize.avatarLg,
              color: AppColors.orangeTint,
              alignment: Alignment.center,
              child: const Icon(Icons.shopping_bag_rounded, color: AppColors.orange, size: AppIconSize.lg),
            ),
    );
  }
}
