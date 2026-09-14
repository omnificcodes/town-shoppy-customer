import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/location/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../application/merchant_categories_provider.dart';
import '../application/merchants_list_controller.dart';
import '../application/nearby_merchants_controller.dart';
import 'category_filter_strip.dart';
import 'merchant_card.dart';
import 'merchant_search_bar.dart';
import 'merchants_discovery_header.dart';
import 'nearby_merchant_card.dart';

enum _MerchantsTab { all, nearby }

/// The merchant-discovery browsing screen, following the Google Stitch
/// redesign. "All" supports server-side name search and an
/// `accepts_town_coin` filter (both confirmed real on
/// `MerchantController::index()`), plus category — there is still no
/// `town_id` filter. "Near me" wraps `GET /merchants/nearby` and needs the
/// device's GPS coordinate, requested on demand rather than on screen open;
/// it has no search parameter on the backend, so the search bar only ever
/// appears on the "All" tab.
///
/// Stitch's "Sort: Relevance" control and the "< 3 km" radius in its Near me
/// label are absent on purpose: `GET /merchants` only orders by name, and
/// the nearby radius is a server setting, not a figure this screen can
/// promise.
///
/// One [CustomScrollView] for the whole screen: the header and filters
/// scroll away with the results instead of sitting in a fixed block above
/// them, which overflowed on short viewports (landscape, a large system
/// text scale, or the keyboard open).
class MerchantsListScreen extends ConsumerStatefulWidget {
  const MerchantsListScreen({super.key, this.initialCategoryId});

  /// Set when arriving from Home's category grid (passed as route `extra`) —
  /// applied once the controller's own initial, unfiltered `build()`
  /// resolves, same "resolve on the screen that displays it" deferral
  /// `RequestPurchaseScreen.initState()` already uses.
  final int? initialCategoryId;

  @override
  ConsumerState<MerchantsListScreen> createState() => _MerchantsListScreenState();
}

class _MerchantsListScreenState extends ConsumerState<MerchantsListScreen> {
  final _scrollController = ScrollController();
  _MerchantsTab _tab = _MerchantsTab.all;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    final initialCategoryId = widget.initialCategoryId;
    if (initialCategoryId != null) {
      Future.microtask(() async {
        await ref.read(merchantsListControllerProvider.future);
        if (mounted) {
          ref.read(merchantsListControllerProvider.notifier).filterByCategory(initialCategoryId);
        }
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= _scrollController.position.maxScrollExtent - 200) return;

    switch (_tab) {
      case _MerchantsTab.all:
        ref.read(merchantsListControllerProvider.notifier).loadMore();
      case _MerchantsTab.nearby:
        ref.read(nearbyMerchantsControllerProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _switchTab(_MerchantsTab tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
    // Leaving "Near me" clears its state so a stale permission-denied/error
    // card doesn't linger — coming back gets a fresh "Use my location" ask.
    if (tab == _MerchantsTab.all) {
      ref.read(nearbyMerchantsControllerProvider.notifier).reset();
    }
  }

  Future<void> _refresh() {
    switch (_tab) {
      case _MerchantsTab.all:
        return ref.read(merchantsListControllerProvider.notifier).refresh();
      case _MerchantsTab.nearby:
        final nearby = ref.read(nearbyMerchantsControllerProvider).value;
        if (nearby is NearbyReadyState) {
          return ref.read(nearbyMerchantsControllerProvider.notifier).requestLocationAndLoad();
        }
        return Future.value();
    }
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(merchantsListControllerProvider).value;

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const MerchantsDiscoveryHeader(),
                    if (_tab == _MerchantsTab.all)
                      MerchantSearchBar(
                        onSearchChanged: (value) => ref.read(merchantsListControllerProvider.notifier).search(value),
                        acceptsTownCoinOnly: listState?.acceptsTownCoinOnly ?? false,
                        onToggleAcceptsTownCoin: (value) =>
                            ref.read(merchantsListControllerProvider.notifier).setAcceptsTownCoinOnly(value),
                      ),
                    _TabButtons(tab: _tab, onChanged: _switchTab),
                    const SizedBox(height: AppSpacing.xs),
                    if (_tab == _MerchantsTab.all) _AllCategoryFilterRow() else _NearbyCategoryFilterRow(),
                    if (_tab == _MerchantsTab.all) const _ResultsCountRow(),
                  ],
                ),
              ),
              if (_tab == _MerchantsTab.all) const _AllMerchantsBody() else const _NearbyMerchantsBody(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultsCountRow extends ConsumerWidget {
  const _ResultsCountRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(merchantsListControllerProvider).value;
    if (state == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.smd, AppSpacing.page, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              state.total == 1 ? '1 MERCHANT FOUND' : '${state.total} MERCHANTS FOUND',
              style: AppTypography.overline.copyWith(color: AppColors.textSecondary, letterSpacing: 0.8),
            ),
          ),
          if (state.isChangingFilter)
            const SizedBox(
              width: AppIconSize.xs,
              height: AppIconSize.xs,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.orangeDeep),
            ),
        ],
      ),
    );
  }
}

/// "All merchants" and "Near me" as two side-by-side buttons, the selected
/// one filled in the brand's deep orange.
class _TabButtons extends StatelessWidget {
  const _TabButtons({required this.tab, required this.onChanged});

  final _MerchantsTab tab;
  final ValueChanged<_MerchantsTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.smd, AppSpacing.page, 0),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: 'All merchants',
              selected: tab == _MerchantsTab.all,
              onTap: () => onChanged(_MerchantsTab.all),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _TabButton(
              label: 'Near me',
              icon: Icons.navigation_rounded,
              selected: tab == _MerchantsTab.nearby,
              onTap: () => onChanged(_MerchantsTab.nearby),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusControl);
    final foreground = selected ? AppColors.onCrimson : AppColors.textPrimary;
    final shownIcon = icon;

    return Semantics(
      button: true,
      selected: selected,
      label: selected ? '$label, selected' : label,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.orangeDeep : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: selected ? AppColors.orangeDeep : AppColors.border),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (shownIcon != null) ...[
                    Icon(shownIcon, size: AppIconSize.sm, color: selected ? foreground : AppColors.orangeDeep),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: foreground, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _listPadding = EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.smd, AppSpacing.page, AppSpacing.xxl);

/// Placeholder cards while a list is loading — a sliver so it can sit
/// inside the screen's single [CustomScrollView].
class _SkeletonSliver extends StatelessWidget {
  const _SkeletonSliver();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: _listPadding,
      sliver: SliverList.separated(
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, _) => LoadingSkeleton(height: 190, borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
      ),
    );
  }
}

/// Fills whatever is left below the header so a prompt/empty/error card
/// reads as the screen's content, not a stub tucked under the filters.
class _FillSliver extends StatelessWidget {
  const _FillSliver({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(hasScrollBody: false, child: child);
  }
}

class _AllMerchantsBody extends ConsumerWidget {
  const _AllMerchantsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(merchantsListControllerProvider);

    return state.when(
      loading: () => const _SkeletonSliver(),
      error: (error, _) => _FillSliver(
        child: ErrorState(
          error: error is AppException ? error : const UnknownAppException(),
          onRetry: () => ref.read(merchantsListControllerProvider.notifier).refresh(),
        ),
      ),
      data: (data) {
        if (data.items.isEmpty) {
          final hasFilter = data.categoryId != null || data.search.isNotEmpty || data.acceptsTownCoinOnly;
          return _FillSliver(
            child: EmptyState(
              icon: Icons.storefront_outlined,
              title: hasFilter ? 'No merchants match this search' : 'No participating merchants found',
              message: hasFilter
                  ? 'Try a different category, search term, or clear the filters.'
                  : 'Check back soon as more businesses join Town Shoppy.',
              action: hasFilter
                  ? AppButton(
                      label: 'Clear filters',
                      variant: AppButtonVariant.secondary,
                      onPressed: () => ref.read(merchantsListControllerProvider.notifier).clearFilters(),
                    )
                  : null,
            ),
          );
        }

        return SliverPadding(
          padding: _listPadding,
          sliver: SliverList.separated(
            itemCount: data.items.length + (data.hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              if (index >= data.items.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final merchant = data.items[index];
              return MerchantCard(merchant: merchant, onTap: () => context.push('/merchants/${merchant.id}'));
            },
          ),
        );
      },
    );
  }
}

class _AllCategoryFilterRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentCategoryId = ref.watch(merchantsListControllerProvider).value?.categoryId;

    return _CategoryFilterRow(
      currentCategoryId: currentCategoryId,
      onSelect: (categoryId) => ref.read(merchantsListControllerProvider.notifier).filterByCategory(categoryId),
    );
  }
}

class _NearbyMerchantsBody extends ConsumerWidget {
  const _NearbyMerchantsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nearbyMerchantsControllerProvider);

    return state.when(
      loading: () => const _SkeletonSliver(),
      error: (error, _) => _FillSliver(
        child: ErrorState(
          error: error is AppException ? error : const UnknownAppException(),
          onRetry: () => ref.read(nearbyMerchantsControllerProvider.notifier).requestLocationAndLoad(),
        ),
      ),
      // Every non-results sub-state is an EmptyState with a real recovery
      // step as its primary action (and, for a service/permission failure,
      // a retry as the secondary one) — not just a "try again".
      data: (uiState) => switch (uiState) {
        NearbyPromptState() => _FillSliver(
          child: EmptyState(
            icon: Icons.my_location_rounded,
            title: 'Find merchants near you',
            message: 'Town Shoppy will ask for your location to show the closest participating businesses.',
            action: AppButton(
              label: 'Use my location',
              onPressed: () => ref.read(nearbyMerchantsControllerProvider.notifier).requestLocationAndLoad(),
            ),
          ),
        ),
        NearbyLocatingState() => const _SkeletonSliver(),
        NearbyServiceDisabledState() => _FillSliver(
          child: EmptyState(
            icon: Icons.location_disabled_rounded,
            title: 'Location services are off',
            message: 'Turn on location services for this device to find nearby merchants.',
            action: AppButton(
              label: 'Open location settings',
              onPressed: () async {
                await ref.read(locationServiceProvider).openLocationSettings();
              },
            ),
            secondaryAction: AppButton(
              label: 'Try again',
              variant: AppButtonVariant.text,
              onPressed: () => ref.read(nearbyMerchantsControllerProvider.notifier).requestLocationAndLoad(),
            ),
          ),
        ),
        NearbyPermissionDeniedState(:final forever) => _FillSliver(
          child: EmptyState(
            icon: Icons.location_off_rounded,
            title: 'Location permission needed',
            message: forever
                ? "Town Shoppy can't ask for location permission again — enable it from this app's settings."
                : 'Allow location access to find merchants near you.',
            action: AppButton(
              label: forever ? 'Open app settings' : 'Allow location',
              onPressed: () async {
                if (forever) {
                  await ref.read(locationServiceProvider).openAppSettings();
                } else {
                  await ref.read(nearbyMerchantsControllerProvider.notifier).requestLocationAndLoad();
                }
              },
            ),
          ),
        ),
        NearbyReadyState(:final data) => _NearbyResultsSliver(data: data),
      },
    );
  }
}

class _NearbyResultsSliver extends ConsumerWidget {
  const _NearbyResultsSliver({required this.data});

  final NearbyMerchantsData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (data.items.isEmpty) {
      return _FillSliver(
        child: EmptyState(
          icon: Icons.location_searching_rounded,
          title: data.categoryId != null ? 'No merchants match this category nearby' : 'No merchants nearby yet',
          message: data.categoryId != null
              ? 'Try a different category or clear the filter.'
              : 'Check back soon as more businesses join Town Shoppy in your area.',
          action: data.categoryId != null
              ? AppButton(
                  label: 'Clear filter',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => ref.read(nearbyMerchantsControllerProvider.notifier).filterByCategory(null),
                )
              : null,
        ),
      );
    }

    return SliverPadding(
      padding: _listPadding,
      sliver: SliverList.separated(
        itemCount: data.items.length + (data.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          if (index >= data.items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final result = data.items[index];
          return NearbyMerchantCard(result: result, onTap: () => context.push('/merchants/${result.merchant.id}'));
        },
      ),
    );
  }
}

class _NearbyCategoryFilterRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(nearbyMerchantsControllerProvider).value;
    if (uiState is! NearbyReadyState) return const SizedBox.shrink();

    return _CategoryFilterRow(
      currentCategoryId: uiState.data.categoryId,
      onSelect: (categoryId) => ref.read(nearbyMerchantsControllerProvider.notifier).filterByCategory(categoryId),
    );
  }
}

class _CategoryFilterRow extends ConsumerWidget {
  const _CategoryFilterRow({required this.currentCategoryId, required this.onSelect});

  final int? currentCategoryId;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(merchantCategoriesProvider);

    return categories.when(
      // Same height as the real strip so the list below doesn't jump once
      // the categories arrive.
      loading: () => const CategoryFilterStripSkeleton(),
      // Categories failing to load is not fatal to the merchant list itself
      // — the list still works without the filter row, so this collapses
      // to nothing rather than blocking the screen with an ErrorState.
      error: (_, _) => const SizedBox.shrink(),
      data: (categories) {
        if (categories.isEmpty) return const SizedBox.shrink();

        return CategoryFilterStrip(
          categoryNames: categories.map((c) => (c.id, c.name, c.slug)).toList(),
          currentCategoryId: currentCategoryId,
          onSelect: onSelect,
        );
      },
    );
  }
}
