import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import 'category_visual.dart';

/// A horizontally-scrolling, *selectable* row of category tiles — the
/// filter-row counterpart to Home's [CategorySlider] (which only ever
/// navigates, never shows a selected state). Reuses the same
/// [CategoryVisual] keyword lookup so a category reads identically wherever
/// it appears in the app.
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        itemCount: categoryNames.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CategoryFilterTile(
              icon: Icons.apps_rounded,
              color: AppColors.orange,
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

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: selected ? '$label, selected' : label,
      child: Material(
        color: selected ? color.withValues(alpha: 0.1) : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 72, maxWidth: 124),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: selected ? color : AppColors.border, width: selected ? 1.5 : 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 19),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                        color: selected ? AppColors.textPrimary : AppColors.textSecondary,
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
