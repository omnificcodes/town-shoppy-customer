import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../merchants/application/merchant_categories_provider.dart';
import '../../../merchants/presentation/category_visual.dart';

/// The round category shortcuts under the Offers tabs. Tapping one filters
/// the feed to that merchant category; tapping it again clears it.
///
/// Stitch shows a photo in each circle. Categories carry no image in the
/// API, so each circle uses the same icon and tint as Home's category grid.
/// The strip hides itself while categories load or when there are none.
class OfferCategoryStrip extends ConsumerWidget {
  const OfferCategoryStrip({super.key, required this.selectedId, required this.onToggle});

  final int? selectedId;
  final ValueChanged<int> onToggle;

  static const _circle = 64.0;
  static const _itemWidth = 76.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(merchantCategoriesProvider).value;
    if (categories == null || categories.isEmpty) return const SizedBox.shrink();

    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final height = AppSpacing.md + _circle + AppSpacing.xs + 18 * scale + AppSpacing.sm;

    return ColoredBox(
      color: AppColors.surface,
      child: SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.sm),
          itemCount: categories.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
          itemBuilder: (context, index) {
            final category = categories[index];
            final selected = category.id == selectedId;
            final visual = CategoryVisual.forCategory(name: category.name, slug: category.slug);

            return Semantics(
              button: true,
              selected: selected,
              label: '${category.name} offers',
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                onTap: () => onToggle(category.id),
                child: SizedBox(
                  width: _itemWidth,
                  child: Column(
                    children: [
                      Container(
                        width: _circle,
                        height: _circle,
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: selected ? AppGradients.promoHero : null,
                          color: selected ? null : AppColors.border,
                        ),
                        child: Container(
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.surface),
                          padding: const EdgeInsets.all(2),
                          child: DecoratedBox(
                            decoration: BoxDecoration(shape: BoxShape.circle, color: visual.color.withValues(alpha: 0.12)),
                            child: Icon(visual.icon, color: visual.color, size: AppIconSize.lg),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTypography.caption.copyWith(
                          color: selected ? AppColors.orangeDeep : AppColors.textPrimary,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
