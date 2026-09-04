import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../merchants/application/merchant_categories_provider.dart';
import '../../../merchants/presentation/category_visual.dart';

/// Horizontally-scrolling "browse by category" row -- every real category
/// `GET /merchant-categories` returns (no arbitrary "first N" truncation,
/// since the backend has no featured/ordering concept to truncate by, see
/// `MerchantCategory`'s own doc comment), ending in a "More" tile that opens
/// the full merchant list rather than a fixed category. Tapping a category
/// pushes `/merchants` pre-filtered the same way `MerchantsListScreen`'s own
/// `CategoryChip` row already does, just from Home instead of from within
/// that screen.
class CategorySlider extends ConsumerWidget {
  const CategorySlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(merchantCategoriesProvider);

    return categories.when(
      loading: () => const SizedBox(height: 92, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 92,
          child: ListView.separated(
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
          ),
        );
      },
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
          width: 72,
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 26),
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
