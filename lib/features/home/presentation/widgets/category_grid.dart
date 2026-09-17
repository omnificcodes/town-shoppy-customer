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
        // Just the title, as in the reference design -- the row's own "More"
        // tile is the way to the full list.
        const SectionHeader(title: 'Browse by category'),
        const SizedBox(height: AppSpacing.md),
        row,
      ],
    );
  }

  /// A single line of equal-width tiles. A plain Row in a scroll view (not a
  /// lazy list) because there are only ever a couple of dozen categories,
  /// and it needs no fixed height at any text size.
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

/// The round icon badge.
const double _circleSize = AppSize.avatarLg - AppSpacing.xxs;

/// Every tile the same width, so four or so show on a phone.
const double _tileWidth = 80;

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
        child: SizedBox(
          width: _tileWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: _circleSize,
                  height: _circleSize,
                  decoration: BoxDecoration(color: visual.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(visual.icon, color: visual.color, size: AppIconSize.lg),
                ),
                const SizedBox(height: AppSpacing.sm),
                // One line; a long name ends in "…" (the full name is the
                // tile's semantics label).
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
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
    return const SizedBox(
      width: _tileWidth,
      child: Column(
        children: [
          LoadingSkeleton(
            width: _circleSize,
            height: _circleSize,
            borderRadius: BorderRadius.all(Radius.circular(_circleSize / 2)),
          ),
          SizedBox(height: AppSpacing.xs),
          LoadingSkeleton(width: 40, height: 10),
        ],
      ),
    );
  }
}
