import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/status_badge.dart';
import '../data/models/product.dart';

/// One tile in the 2-column Shopping grid -- this app's first grid layout
/// (every other list here is a full-width row; see the Products feature's
/// own design note), so the card leans photo-forward like a shop catalog:
/// a square image on top, title/price/Town-Coin badge stacked below.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, this.onTap, this.showMerchantName = true});

  final Product product;
  final VoidCallback? onTap;
  final bool showMerchantName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: onTap != null,
      label: '${product.name}, ₹${_trim(product.price)}',
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd), side: const BorderSide(color: AppColors.border)),
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
                      Image.network(product.primaryImageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const _ProductPlaceholder())
                    else
                      const _ProductPlaceholder(),
                    if (product.acceptsTownCoin)
                      Positioned(
                        left: AppSpacing.xs,
                        top: AppSpacing.xs,
                        child: StatusBadge(label: '${_trim(product.townCoinPercentage!)}% Coin', tone: AppTone.success, icon: Icons.savings_rounded),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.smd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (showMerchantName && product.merchantName.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(product.merchantName, style: AppTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Text('₹${_trim(product.price)}', style: textTheme.titleMedium?.copyWith(color: AppColors.orange)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _trim(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

class _ProductPlaceholder extends StatelessWidget {
  const _ProductPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.orangeTintStrong, AppColors.orangeTint])),
      child: Center(child: Icon(Icons.shopping_bag_rounded, color: AppColors.orange, size: AppIconSize.xl)),
    );
  }
}
