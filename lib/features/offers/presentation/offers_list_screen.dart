import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/load_more_indicator.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../merchants/application/merchant_categories_provider.dart';
import '../application/offers_list_controller.dart';
import 'widgets/offer_category_strip.dart';
import 'widgets/offer_feed_card.dart';

/// The Offers tab, following the Google Stitch redesign: expiry tabs, a
/// category strip, a live count, then one large card per offer.
///
/// Everything filters server-side through `GET /offers` (`category_id`,
/// `expiring_within_days`), so a filtered list paginates correctly. Stitch's
/// ratings, review counts, favourites and "Mega Sale" / "Flash Deals" tabs
/// are absent on purpose: the backend defines none of them.
class OffersListScreen extends ConsumerStatefulWidget {
  const OffersListScreen({super.key});

  @override
  ConsumerState<OffersListScreen> createState() => _OffersListScreenState();
}

class _OffersListScreenState extends ConsumerState<OffersListScreen> {
  static const _loadMoreThreshold = 400.0;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - _loadMoreThreshold) {
      ref.read(offersListControllerProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(offersFilterProvider);
    final filters = ref.read(offersFilterProvider.notifier);
    final state = ref.watch(offersListControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ExpiryTabs(selected: filter.expiry, onSelected: filters.setExpiry),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(merchantCategoriesProvider);
                  await ref.read(offersListControllerProvider.notifier).refresh();
                },
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: OfferCategoryStrip(selectedId: filter.categoryId, onToggle: filters.toggleCategory),
                    ),
                    SliverToBoxAdapter(child: _FeedHeading(total: state.value?.total, categoryId: filter.categoryId)),
                    ...state.when(
                      loading: () => [
                        SliverPadding(
                          padding: const EdgeInsets.all(AppSpacing.page),
                          sliver: SliverList.separated(
                            itemCount: 2,
                            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.lg),
                            itemBuilder: (_, _) => LoadingSkeleton(
                              height: 320,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                            ),
                          ),
                        ),
                      ],
                      error: (error, _) => [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: ErrorState(
                            error: error is AppException ? error : const UnknownAppException(),
                            onRetry: () => ref.read(offersListControllerProvider.notifier).refresh(),
                          ),
                        ),
                      ],
                      data: (data) {
                        if (data.items.isEmpty) {
                          return [
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: EmptyState(
                                icon: Icons.local_offer_outlined,
                                title: filter.isFiltered ? 'No offers match' : 'No offers right now',
                                message: filter.isFiltered
                                    ? 'Try another category or a longer time range.'
                                    : 'Check back soon as participating merchants publish new offers.',
                                action: filter.isFiltered
                                    ? TextButton(onPressed: filters.reset, child: const Text('Show all offers'))
                                    : null,
                              ),
                            ),
                          ];
                        }

                        return [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.page,
                              AppSpacing.sm,
                              AppSpacing.page,
                              AppSpacing.xxl * 2,
                            ),
                            sliver: SliverList.separated(
                              itemCount: data.items.length + (data.hasMore ? 1 : 0),
                              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.lg),
                              itemBuilder: (context, index) {
                                if (index >= data.items.length) {
                                  return const LoadMoreIndicator(label: 'Loading more offers');
                                }
                                return OfferFeedCard(offer: data.items[index]);
                              },
                            ),
                          ),
                        ];
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The tab row across the top. Only time ranges the API can filter on.
class _ExpiryTabs extends StatelessWidget {
  const _ExpiryTabs({required this.selected, required this.onSelected});

  final OfferExpiryFilter selected;
  final ValueChanged<OfferExpiryFilter> onSelected;

  static (IconData, String) _tab(OfferExpiryFilter filter) => switch (filter) {
        OfferExpiryFilter.all => (Icons.grid_view_rounded, 'All offers'),
        OfferExpiryFilter.thisWeek => (Icons.bolt_rounded, 'Ending this week'),
        OfferExpiryFilter.nextDay => (Icons.timer_outlined, 'Ending in 24h'),
      };

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          children: [
            for (final filter in OfferExpiryFilter.values)
              _TabButton(
                icon: _tab(filter).$1,
                label: _tab(filter).$2,
                selected: filter == selected,
                onTap: () => onSelected(filter),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.orangeDeep : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: selected ? AppColors.orangeDeep : Colors.transparent, width: 2.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: AppIconSize.sm, color: color),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "12 offers to explore", scoped to the selected category when there is one.
class _FeedHeading extends ConsumerWidget {
  const _FeedHeading({required this.total, required this.categoryId});

  final int? total;
  final int? categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String? categoryName;
    if (categoryId != null) {
      for (final category in ref.watch(merchantCategoriesProvider).value ?? const []) {
        if (category.id == categoryId) categoryName = category.name;
      }
    }

    final count = total;
    final title = count == null
        ? 'Offers to explore'
        : count == 1
            ? '1 offer to explore'
            : '$count offers to explore';

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text(title, style: AppTypography.greeting)),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            categoryName == null ? 'Live deals from shops across town' : 'Live deals from $categoryName shops',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}
