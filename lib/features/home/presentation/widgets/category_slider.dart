import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../merchants/application/merchant_categories_provider.dart';
import '../../../merchants/presentation/category_visual.dart';

/// Horizontally-scrolling "browse by category" row -- every real category
/// `GET /merchant-categories` returns (no arbitrary "first N" truncation,
/// since the backend has no featured/ordering concept to truncate by, see
/// `MerchantCategory`'s own doc comment), ending in a "More" tile that opens
/// the full merchant list rather than a fixed category. Tapping a category
/// pushes `/merchants` pre-filtered the same way `MerchantsListScreen`'s own
/// category strip already does, just from Home instead of from within that
/// screen.
class CategorySlider extends ConsumerWidget {
  const CategorySlider({super.key});

  static const _tileWidth = 72.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(merchantCategoriesProvider);
    // The row is a fixed-height strip (it scrolls sideways), so its height
    // has to follow the system text scale or the label clips.
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final height = AppSize.avatarLg + AppSpacing.xs + 18 * scale + AppSpacing.xs;

    return SizedBox(
      height: height,
      child: categories.when(
        loading: () => ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 5,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
          itemBuilder: (_, _) => const SizedBox(
            width: _tileWidth,
            child: Column(
              children: [
                LoadingSkeleton(width: AppSize.avatarLg, height: AppSize.avatarLg, borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusPill))),
                SizedBox(height: AppSpacing.sm),
                LoadingSkeleton(width: 48, height: 10),
              ],
            ),
          ),
        ),
        // Categories are a discovery bonus, not something Home depends on;
        // a failure collapses to a single quiet retry chip instead of an
        // error panel taking over the section.
        error: (_, _) => Align(
          alignment: Alignment.centerLeft,
          child: ActionChip(
            avatar: const Icon(Icons.refresh_rounded, size: AppIconSize.sm),
            label: const Text("Couldn't load categories — retry"),
            onPressed: () => ref.invalidate(merchantCategoriesProvider),
          ),
        ),
        data: (items) {
          if (items.isEmpty) return const SizedBox.shrink();

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              if (index == items.length) {
                return _CategoryTile(
                  icon: Icons.grid_view_rounded,
                  color: AppColors.textSecondary,
                  label: 'More',
                  onTap: () => context.push('/merchants'),
                );
              }

              final category = items[index];
              final visual = CategoryVisual.forCategory(name: category.name, slug: category.slug);
              return _CategoryTile(
                icon: visual.icon,
                color: visual.color,
                label: category.name,
                onTap: () => context.push('/merchants', extra: category.id),
              );
            },
          );
        },
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.icon, required this.color, required this.label, required this.onTap});

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: SizedBox(
          width: CategorySlider._tileWidth,
          child: Column(
            children: [
              Container(
                width: AppSize.avatarLg,
                height: AppSize.avatarLg,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: AppIconSize.lg),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
