import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import 'category_visual.dart';

/// A horizontally-scrolling, *selectable* row of category tiles — the
/// filter-row counterpart to Home's category grid (which only ever
/// navigates, never shows a selected state). Reuses the same
/// [CategoryVisual] keyword lookup so a category reads identically wherever
/// it appears in the app. The selected tile gets the brand-orange border
/// the Stitch redesign uses.
class CategoryFilterStrip extends StatelessWidget {
  const CategoryFilterStrip({
    super.key,
    required this.categoryNames,
    required this.currentCategoryId,
    required this.onSelect,
  });

  final List<(int id, String name, String slug)> categoryNames;
  final int? currentCategoryId;
  final ValueChanged<int?> onSelect;

  /// The strip's height at the default text scale: a tile (icon badge +
  /// gap + one label line + padding + border) plus the strip's own vertical
  /// padding. [CategoryFilterStripSkeleton] uses the same figure so the
  /// loading → loaded transition never shifts the list below.
  static const double _baseHeight = 104;

  /// How much one label line grows per unit of text scale — `labelSmall`
  /// is 12sp at 1.35 line height.
  static const double _labelLineHeight = 17;

  /// Grows with the system text scale (capped) so the tile's label line
  /// still fits inside the fixed-height strip at 2x instead of overflowing.
  static double heightFor(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    return _baseHeight + (scale - 1) * _labelLineHeight;
  }

  static const _padding = EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: AppSpacing.xs);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: heightFor(context),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: _padding,
        itemCount: categoryNames.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CategoryFilterTile(
              icon: Icons.apps_rounded,
              color: AppColors.orangeDeep,
              label: 'All',
              selected: currentCategoryId == null,
              onTap: () => onSelect(null),
            );
          }

          final (id, name, slug) = categoryNames[index - 1];
          final visual = CategoryVisual.forCategory(name: name, slug: slug);
          return _CategoryFilterTile(
            icon: visual.icon,
            color: visual.color,
            label: name,
            selected: currentCategoryId == id,
            onTap: () => onSelect(id),
          );
        },
      ),
    );
  }
}

/// Placeholder tiles occupying exactly [CategoryFilterStrip]'s height and
/// padding, so the results list doesn't jump when the real strip arrives.
class CategoryFilterStripSkeleton extends StatelessWidget {
  const CategoryFilterStripSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final tileHeight = CategoryFilterStrip.heightFor(context) - CategoryFilterStrip._padding.vertical;

    return SizedBox(
      height: CategoryFilterStrip.heightFor(context),
      child: Padding(
        padding: CategoryFilterStrip._padding,
        child: Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              LoadingSkeleton(
                width: _CategoryFilterTile.minWidth,
                height: tileHeight,
                borderRadius: const BorderRadius.all(Radius.circular(AppSpacing.radiusMd)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sized to its own label (within a floor/cap) so short names like
/// "Bakery" get a compact tile while long ones like "Agriculture & Farming
/// Supplies" stay on one line and ellipsize instead of breaking mid-word
/// across two lines.
class _CategoryFilterTile extends StatelessWidget {
  const _CategoryFilterTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const double minWidth = 88;
  static const double maxWidth = 124;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusMd);

    return Semantics(
      button: true,
      selected: selected,
      label: selected ? '$label, selected' : label,
      child: Material(
        color: selected ? AppColors.orangeTint : AppColors.surface,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.smd),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: selected ? AppColors.orangeDeep : AppColors.border, width: selected ? 2 : 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: AppSize.controlSm,
                  height: AppSize.controlSm,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                  ),
                  child: Icon(icon, color: color, size: AppIconSize.md),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
