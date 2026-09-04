import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/location/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../application/merchant_categories_provider.dart';
import '../application/merchants_list_controller.dart';
import '../application/nearby_merchants_controller.dart';
import 'category_chip.dart';
import 'merchant_card.dart';
import 'nearby_merchant_card.dart';

enum _MerchantsTab { all, nearby }

/// The merchant-discovery browsing screen. "All" has no server-side text
/// search and no `town_id` filter (confirmed by reading
/// `MerchantController::index()` directly) — only category. "Nearby" wraps
/// `GET /merchants/nearby` (Phase 1 completion audit item #8: the backend
/// endpoint existed but no client called it) and needs the device's GPS
/// coordinate, requested on demand rather than on screen open.
class MerchantsListScreen extends ConsumerStatefulWidget {
  const MerchantsListScreen({super.key, this.initialCategoryId});

  /// Set when arriving from Home's category slider (passed as route
  /// `extra`) — applied once the controller's own initial, unfiltered
  /// `build()` resolves, same "resolve on the screen that displays it"
  /// deferral `RequestPurchaseScreen.initState()` already uses.
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
    // Leaving "Nearby" clears its state so a stale permission-denied/error
    // card doesn't linger — coming back gets a fresh "Use my location" ask.
    if (tab == _MerchantsTab.all) {
      ref.read(nearbyMerchantsControllerProvider.notifier).reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discover merchants')),
      body: SafeArea(
        child: Column(
          children: [
            _TabToggle(tab: _tab, onChanged: _switchTab),
            if (_tab == _MerchantsTab.all)
              _AllCategoryFilterRow()
            else
              _NearbyCategoryFilterRow(),
            Expanded(
              child: _tab == _MerchantsTab.all
                  ? _AllMerchantsBody(scrollController: _scrollController)
                  : _NearbyMerchantsBody(scrollController: _scrollController),
            ),
          ],
        ),
      ),
    );
  }
}

/// A two-way segmented toggle, purpose-built for this fixed-width row
/// (unlike [CategoryChip], which hugs its own content inside a horizontally
/// *scrolling* list and has never needed to shrink its label to fit a tight
/// [Expanded] slot).
class _TabToggle extends StatelessWidget {
  const _TabToggle({required this.tab, required this.onChanged});

  final _MerchantsTab tab;
  final ValueChanged<_MerchantsTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
        child: Row(
          children: [
            Expanded(
              child: _TabToggleSegment(
                label: 'All',
                selected: tab == _MerchantsTab.all,
                onTap: () => onChanged(_MerchantsTab.all),
              ),
            ),
            Expanded(
              child: _TabToggleSegment(
                label: 'Near me',
                selected: tab == _MerchantsTab.nearby,
                onTap: () => onChanged(_MerchantsTab.nearby),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabToggleSegment extends StatelessWidget {
  const _TabToggleSegment({required this.label, required this.selected, required this.onTap});

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
        color: selected ? AppColors.orange : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          onTap: onTap,
          child: Padding(
            // Same touch-target fix as CategoryChip -- see its own comment.
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? AppColors.onOrange : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AllMerchantsBody extends ConsumerWidget {
  const _AllMerchantsBody({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(merchantsListControllerProvider);

    return state.when(
      loading: () => ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, __) => const LoadingSkeletonCard(),
      ),
      error: (error, _) => ErrorState(
        error: error is AppException ? error : const UnknownAppException(),
        onRetry: () => ref.read(merchantsListControllerProvider.notifier).refresh(),
      ),
      data: (data) {
        if (data.items.isEmpty) {
          return EmptyState(
            icon: Icons.storefront_outlined,
            title: data.categoryId != null ? 'No merchants match this category' : 'No participating merchants found',
            message: data.categoryId != null
                ? 'Try a different category or clear the filter.'
                : 'Check back soon as more businesses join Town Shoppy.',
            action: data.categoryId != null
                ? AppButton(
                    label: 'Clear filter',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => ref.read(merchantsListControllerProvider.notifier).filterByCategory(null),
                  )
                : null,
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.read(merchantsListControllerProvider.notifier).refresh(),
          child: ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: data.items.length + (data.hasMore ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
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
  const _NearbyMerchantsBody({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nearbyMerchantsControllerProvider);

    return state.when(
      loading: () => ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, __) => const LoadingSkeletonCard(),
      ),
      error: (error, _) => ErrorState(
        error: error is AppException ? error : const UnknownAppException(),
        onRetry: () => ref.read(nearbyMerchantsControllerProvider.notifier).requestLocationAndLoad(),
      ),
      data: (uiState) => switch (uiState) {
        NearbyPromptState() => _LocationPromptCard(
            icon: Icons.my_location_rounded,
            title: 'Find merchants near you',
            message: 'Town Shoppy will ask for your location to show the closest participating businesses.',
            actionLabel: 'Use my location',
            onAction: () => ref.read(nearbyMerchantsControllerProvider.notifier).requestLocationAndLoad(),
          ),
        NearbyLocatingState() => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, __) => const LoadingSkeletonCard(),
          ),
        NearbyServiceDisabledState() => _LocationPromptCard(
            icon: Icons.location_disabled_rounded,
            title: 'Location services are off',
            message: 'Turn on location services for this device to find nearby merchants.',
            actionLabel: 'Open location settings',
            onAction: () async {
              await ref.read(locationServiceProvider).openLocationSettings();
            },
            secondaryLabel: 'Try again',
            onSecondaryAction: () => ref.read(nearbyMerchantsControllerProvider.notifier).requestLocationAndLoad(),
          ),
        NearbyPermissionDeniedState(:final forever) => _LocationPromptCard(
            icon: Icons.location_off_rounded,
            title: 'Location permission needed',
            message: forever
                ? "Town Shoppy can't ask for location permission again — enable it from this app's settings."
                : 'Allow location access to find merchants near you.',
            actionLabel: forever ? 'Open app settings' : 'Allow location',
            onAction: () async {
              if (forever) {
                await ref.read(locationServiceProvider).openAppSettings();
              } else {
                await ref.read(nearbyMerchantsControllerProvider.notifier).requestLocationAndLoad();
              }
            },
          ),
        NearbyReadyState(:final data) => _NearbyResultsList(data: data, scrollController: scrollController),
      },
    );
  }
}

class _NearbyResultsList extends ConsumerWidget {
  const _NearbyResultsList({required this.data, required this.scrollController});

  final NearbyMerchantsData data;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (data.items.isEmpty) {
      return EmptyState(
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
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: data.items.length + (data.hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
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

/// A prompt/error card shared by every "Nearby" sub-state that isn't a
/// results list — same visual shape as [EmptyState] but with up to two
/// actions, since a permission/service failure needs a real recovery step,
/// not just a retry.
class _LocationPromptCard extends StatelessWidget {
  const _LocationPromptCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.secondaryLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl, horizontal: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.textDisabled),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(message, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          AppButton(label: actionLabel, onPressed: onAction),
          if (secondaryLabel != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(label: secondaryLabel!, variant: AppButtonVariant.text, onPressed: onSecondaryAction),
          ],
        ],
      ),
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
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: SizedBox(
          height: 40,
          child: Row(
            children: [
              LoadingSkeleton(width: 80, height: 32, borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusLg))),
              SizedBox(width: AppSpacing.sm),
              LoadingSkeleton(width: 80, height: 32, borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusLg))),
            ],
          ),
        ),
      ),
      // Categories failing to load is not fatal to the merchant list itself
      // — the list still works without the filter row, so this collapses
      // to nothing rather than blocking the screen with an ErrorState.
      error: (_, __) => const SizedBox.shrink(),
      data: (categories) {
        if (categories.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            // Vertical padding reduced from AppSpacing.sm so each
            // CategoryChip has room to reach the app's touchTarget minimum
            // within this row's own fixed height -- see CategoryChip's
            // padding comment for the full accessibility rationale.
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
            itemCount: categories.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              if (index == 0) {
                return CategoryChip(
                  label: 'All',
                  selected: currentCategoryId == null,
                  onTap: () => onSelect(null),
                );
              }

              final category = categories[index - 1];
              return CategoryChip(
                label: category.name,
                selected: currentCategoryId == category.id,
                onTap: () => onSelect(category.id),
              );
            },
          ),
        );
      },
    );
  }
}
