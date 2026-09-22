import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../data/models/product.dart';

/// Money as this app writes it: whole rupees plain, paise only when there
/// are any.
String formatRupees(double value) =>
    value == value.roundToDouble() ? '₹${value.toInt()}' : '₹${value.toStringAsFixed(2)}';

/// A percentage without a pointless ".0".
String formatPercentOff(double value) =>
    value == value.roundToDouble() ? '${value.toInt()}% OFF' : '${value.toStringAsFixed(1)}% OFF';

/// What a product costs: the offer price, the price it was before struck
/// through, and how much that saves -- the same three facts everywhere a
/// product is shown, so a card and the detail page can never disagree.
///
/// The two layouts differ only in shape. A card stacks them and carries the
/// "% OFF" line itself, since a card has no room for a badge; the detail
/// page lays them along one baseline, its percentage already shown on the
/// image as a discount tag.
class ProductPrice extends StatelessWidget {
  const ProductPrice({super.key, required this.product, this.large = false});

  final Product product;

  /// The detail page's bigger treatment; cards use the compact one.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final saving = product.saving;
    final percent = product.savingPercentage;

    final priceStyle = large
        ? textTheme.displaySmall?.copyWith(color: AppColors.orangeDeep, fontWeight: FontWeight.w800)
        : AppTypography.numericFinancialSmall.copyWith(color: AppColors.orangeDeep);

    if (saving == null) {
      return Text(formatRupees(product.price), style: priceStyle);
    }

    if (large) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.smd,
        runSpacing: AppSpacing.sm,
        children: [
          Text(formatRupees(product.price), style: priceStyle),
          Text(
            formatRupees(product.mrp!),
            style: textTheme.titleLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd, vertical: AppSpacing.xs + 2),
            decoration: BoxDecoration(
              color: AppColors.successBg,
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
            ),
            child: Text(
              'You Save ${formatRupees(saving)}',
              style: AppTypography.badgeLabel.copyWith(color: AppColors.success),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (percent != null) ...[
          Text(
            formatPercentOff(percent),
            style: textTheme.labelMedium?.copyWith(color: AppColors.success, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
        ],
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.xs,
          children: [
            Text(
              formatRupees(product.mrp!),
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            Text(formatRupees(product.price), style: priceStyle),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'You save ${formatRupees(saving)}',
          style: AppTypography.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
