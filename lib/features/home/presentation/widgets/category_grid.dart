import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../merchants/application/merchant_categories_provider.dart';
import '../../../merchants/presentation/category_visual.dart';

/// "Browse by Category": two rows of five rounded tiles, as in the Stitch
/// redesign. The real categories from `GET /merchant-categories` fill the
/// first nine slots and the last is always "More", which opens the full
/// shop list. Tapping a category opens that list pre-filtered, exactly as
/// the old horizontal slider did.
class CategoryGrid extends ConsumerWidget {
  const CategoryGrid({super.key});

  static const _columns = 5;
  static const _maxCategories = _columns * 2 - 1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(merchantCategoriesProvider);

    final Widget? grid = categories.when(
      loading: () => _rows(List.generate(_columns, (_) => const _TileSkeleton())),
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

        return _rows([
          for (final category in items.take(_maxCategories))
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

    if (grid == null) return const SizedBox.shrink();

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
        grid,
      ],
    );
  }

  static Widget _rows(List<Widget> tiles) {
    final rows = <Widget>[];
    for (var start = 0; start < tiles.length; start += _columns) {
      final slice = tiles.sublist(start, math.min(start + _columns, tiles.length));
      if (start > 0) rows.add(const SizedBox(height: AppSpacing.smd));
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < _columns; i++) Expanded(child: i < slice.length ? slice[i] : const SizedBox.shrink()),
          ],
        ),
      );
    }
    return Column(children: rows);
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Column(
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textPrimary),
              ),
            ],
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
    return const Column(
      children: [
        LoadingSkeleton(
          width: _tileSize,
          height: _tileSize,
          borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusMd)),
        ),
        SizedBox(height: AppSpacing.xs),
        LoadingSkeleton(width: 40, height: 10),
      ],
    );
  }
}
