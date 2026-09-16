import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../merchants/application/merchant_categories_provider.dart';
import '../../../merchants/presentation/category_visual.dart';

/// "Browse by Category": one horizontally scrolling row of rounded tiles,
/// each name shown in full on a single line. Every category from `GET /merchant-categories`
/// is in the row, followed by "More", which opens the full shop list.
/// Tapping a category opens that list pre-filtered.
class CategoryGrid extends ConsumerWidget {
  const CategoryGrid({super.key});

  static const _skeletonCount = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(merchantCategoriesProvider);

    final Widget? row = categories.when(
      loading: () => _row(List.generate(_skeletonCount, (_) => const _TileSkeleton()), scrollable: false),
      // Categories are a discovery bonus, not something Home depends on; a
      // failure collapses to one quiet retry chip.
      error: (_, _) => Align(
        alignment: Alignment.centerLeft,
        child: ActionChip(
          avatar: const Icon(Icons.refresh_rounded, size: AppIconSize.sm),
          label: const Text("Couldn't load categories — retry"),
          onPressed: () => ref.invalidate(merchantCategoriesProvider),
        ),
      ),
      data: (items) {
        if (items.isEmpty) return null;

        return _row([
          for (final category in items)
            _CategoryTile(
              visual: CategoryVisual.forCategory(name: category.name, slug: category.slug),
              label: category.name,
              onTap: () => context.push('/merchants', extra: category.id),
            ),
          _CategoryTile(
            visual: const CategoryVisual(icon: Icons.more_horiz_rounded, color: AppColors.textSecondary),
            label: 'More',
            onTap: () => context.push('/merchants'),
          ),
        ]);
      },
    );

    if (row == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.section),
        SectionHeader(
          title: 'Browse by Category',
          subtitle: 'Explore local stores near you',
          actionLabel: 'See all',
          onAction: () => context.push('/merchants'),
        ),
        const SizedBox(height: AppSpacing.smd),
        row,
      ],
    );
  }

  /// A single line of tiles. A plain Row in a scroll view (not a lazy
  /// list) because there are only ever a couple of dozen categories, and it
  /// lets each tile size itself to its one-line name with no fixed height.
  static Widget _row(List<Widget> tiles, {bool scrollable = true}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: scrollable ? null : const NeverScrollableScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, tile) in tiles.indexed) ...[if (i > 0) const SizedBox(width: AppSpacing.xs), tile],
        ],
      ),
    );
  }
}

/// Stitch's 52dp rounded-square tile.
const double _tileSize = AppSize.avatarLg - AppSpacing.xs;

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.visual, required this.label, required this.onTap});

  final CategoryVisual visual;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: ConstrainedBox(
          // At least the icon tile wide, so short names ("More") still line
          // up; a longer name widens its own tile so it reads in full on one
          // line, never wrapping or cut off.
          constraints: const BoxConstraints(minWidth: _tileSize + AppSpacing.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: _tileSize,
                  height: _tileSize,
                  decoration: BoxDecoration(
                    color: visual.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Icon(visual.icon, color: visual.color, size: AppIconSize.md),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TileSkeleton extends StatelessWidget {
  const _TileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
      child: Column(
        children: [
          LoadingSkeleton(
            width: _tileSize,
            height: _tileSize,
            borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusMd)),
          ),
          SizedBox(height: AppSpacing.xs),
          LoadingSkeleton(width: 40, height: 10),
        ],
      ),
    );
  }
}
