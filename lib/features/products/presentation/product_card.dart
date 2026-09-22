import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../cart/application/cart_controller.dart';
import '../data/models/product.dart';
import 'add_to_bag_button.dart';
import 'product_price.dart';

/// One tile in the 2-column Shopping grid -- this app's first grid layout
/// (every other list here is a full-width row; see the Products feature's
/// own design note), so the card leans photo-forward like a shop catalog:
/// a square image carrying the discount and Town Coin badges, then the
/// shop, the name, and the price beside the bag control.
class ProductCard extends ConsumerWidget {
  const ProductCard({super.key, required this.product, this.onTap, this.showMerchantName = true});

  final Product product;
  final VoidCallback? onTap;
  final bool showMerchantName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final percent = product.savingPercentage;
    final inBag = ref.watch(cartQuantityProvider(product.id));

    return Semantics(
      button: onTap != null,
      label: [
        product.name,
        formatRupees(product.price),
        if (product.saving != null) 'was ${formatRupees(product.mrp!)}, you save ${formatRupees(product.saving!)}',
        if (inBag > 0) '$inBag in bag',
      ].join(', '),
      // Same surface as AppCard: hairline border plus the shared whisper
      // lift, drawn outside the Material so its clip doesn't eat the shadow.
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          boxShadow: AppElevation.card,
        ),
        child: Material(
          color: AppColors.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            side: const BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (product.primaryImageUrl != null)
                        Image.network(
                          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                          product.primaryImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const _ProductPlaceholder(),
                        )
                      else
                        const _ProductPlaceholder(),
                      if (percent != null)
                        Positioned(
                          left: AppSpacing.xs,
                          top: AppSpacing.xs,
                          child: _DiscountFlag(percent: percent),
                        ),
                      if (product.acceptsTownCoin)
                        Positioned(
                          left: AppSpacing.xs,
                          bottom: AppSpacing.xs,
                          child: StatusBadge(
                            label: '${_trim(product.townCoinPercentage!)}% Coin',
                            tone: AppTone.success,
                            icon: Icons.savings_rounded,
                          ),
                        ),
                    ],
                  ),
                ),
                // Expanded, so the tile's leftover height lands in this
                // block rather than under it: the price row then sits on
                // the card's bottom edge whatever the grid's aspect ratio,
                // and a long name cannot push it out of the tile.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.smd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showMerchantName && product.merchantName.isNotEmpty) ...[
                                Text(
                                  product.merchantName,
                                  style: AppTypography.caption,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                              ],
                              Flexible(
                                child: Text(
                                  product.name,
                                  style: textTheme.titleSmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // orangeDeep, not orange: brand orange is 2.9:1
                            // as text on white (see AppColors.orangeDeep).
                            Expanded(child: ProductPrice(product: product)),
                            const SizedBox(width: AppSpacing.xs),
                            AddToBagButton(product: product),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _trim(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

/// The corner flag on a discounted product's photo.
class _DiscountFlag extends StatelessWidget {
  const _DiscountFlag({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(color: AppColors.orangeDeep, borderRadius: BorderRadius.circular(AppSpacing.radiusXs)),
      child: Text(formatPercentOff(percent), style: AppTypography.badgeLabel.copyWith(color: AppColors.onCrimson)),
    );
  }
}

class _ProductPlaceholder extends StatelessWidget {
  const _ProductPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.orangeTintStrong, AppColors.orangeTint])),
      child: Center(
        child: Icon(Icons.shopping_bag_rounded, color: AppColors.orange, size: AppIconSize.xl),
      ),
    );
  }
}
