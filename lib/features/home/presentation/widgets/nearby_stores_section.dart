import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../merchants/data/models/nearby_merchant.dart';
import '../../../merchants/presentation/merchant_logo.dart';
import '../../application/home_location_controller.dart';
import '../../application/home_nearby_controller.dart';

/// "Find Stores Near You": a search entry, radius and open-now filters, and
/// a swipeable row of the closest shops.
///
/// Stitch also shows an "Offers Available" filter; the nearby endpoint has
/// no way to ask for that, so it isn't offered. The search field opens the
/// full discovery screen, whose own search matches shop names.
class NearbyStoresSection extends ConsumerWidget {
  const NearbyStoresSection({super.key});

  static const _cardWidth = 196.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(homeLocationControllerProvider);

    // No location means no "near you". The header's location pill already
    // explains why and offers the retry, so this section simply steps aside.
    if (location.hasError) return const SizedBox.shrink();
    final resolved = location.value;
    if (location.hasValue && resolved is! HomeLocationReady) return const SizedBox.shrink();

    final filter = ref.watch(homeNearbyFilterProvider);
    final filters = ref.read(homeNearbyFilterProvider.notifier);
    final nearby = ref.watch(homeNearbyMerchantsProvider);
    final area = resolved is HomeLocationReady ? resolved.label : null;

    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final cardHeight = AppSpacing.smd * 2 + (18 + 16 + 16) * scale + AppSpacing.sm * 2 + 1 + 20 * scale + AppSpacing.xs;

    final Widget? results = nearby.when(
      loading: () => SizedBox(
        height: cardHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 2,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.smd),
          itemBuilder: (_, _) => LoadingSkeleton(
            width: _cardWidth,
            height: cardHeight,
            borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
          ),
        ),
      ),
      error: (error, _) => AppCard(
        child: ErrorState(
          compact: true,
          error: error is AppException ? error : const UnknownAppException(),
          onRetry: () => ref.invalidate(homeNearbyMerchantsProvider),
        ),
      ),
      data: (items) {
        if (items == null) return null;

        if (items.isEmpty) {
          final canWiden = filter.radiusKm < HomeNearbyFilter.wideRadiusKm;
          return AppCard(
            child: EmptyState(
              compact: true,
              icon: Icons.storefront_outlined,
              title: filter.openNowOnly ? 'Nothing open nearby right now' : 'No shops within ${_km(filter.radiusKm)} km',
              message: canWiden
                  ? 'Try widening the search to ${_km(HomeNearbyFilter.wideRadiusKm)} km.'
                  : 'See every shop in town from View all.',
            ),
          );
        }

        return SizedBox(
          height: cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.smd),
            itemBuilder: (context, index) => _StoreCard(item: items[index]),
          ),
        );
      },
    );

    if (results == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.section),
        SectionHeader(
          title: 'Find Stores Near You',
          subtitle: area == null ? 'Local shops around you' : 'Local shops around $area',
          actionLabel: 'View all',
          onAction: () => context.push('/merchants'),
        ),
        const SizedBox(height: AppSpacing.smd),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.border),
            boxShadow: AppElevation.card,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SearchField(),
                const SizedBox(height: AppSpacing.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterPill(
                        label: 'Within ${_km(HomeNearbyFilter.nearRadiusKm)} km',
                        icon: Icons.near_me_rounded,
                        selected: filter.radiusKm == HomeNearbyFilter.nearRadiusKm,
                        onTap: () => filters.setRadius(HomeNearbyFilter.nearRadiusKm),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _FilterPill(
                        label: 'Within ${_km(HomeNearbyFilter.wideRadiusKm)} km',
                        selected: filter.radiusKm == HomeNearbyFilter.wideRadiusKm,
                        onTap: () => filters.setRadius(HomeNearbyFilter.wideRadiusKm),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _FilterPill(
                        label: 'Open now',
                        icon: Icons.schedule_rounded,
                        tone: _PillTone.success,
                        selected: filter.openNowOnly,
                        onTap: filters.toggleOpenNow,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.smd),
        results,
      ],
    );
  }

  static String _km(double km) => km.truncateToDouble() == km ? km.toStringAsFixed(0) : km.toStringAsFixed(1);
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusControl);

    return Semantics(
      button: true,
      label: 'Search shops by name',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surfaceMuted,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: () => context.push('/merchants'),
          child: SizedBox(
            height: AppSize.controlSm,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: AppIconSize.md, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Search shops by name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
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

enum _PillTone { brand, success }

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.tone = _PillTone.brand,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final _PillTone tone;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground, Color? border) = switch ((tone, selected)) {
      (_PillTone.brand, true) => (AppColors.orangeDeep, AppColors.onCrimson, null),
      (_PillTone.brand, false) => (AppColors.surfaceMuted, AppColors.textPrimary, AppColors.border),
      (_PillTone.success, true) => (AppColors.success, AppColors.onCrimson, null),
      (_PillTone.success, false) => (AppColors.successBg, AppColors.success, AppColors.success.withValues(alpha: 0.3)),
    };
    final shownIcon = icon;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: StadiumBorder(side: border == null ? BorderSide.none : BorderSide(color: border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd, vertical: AppSpacing.xs + AppSpacing.xxs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (shownIcon != null) ...[
                  Icon(shownIcon, size: AppIconSize.xs, color: foreground),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: foreground)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.item});

  final NearbyMerchant item;

  @override
  Widget build(BuildContext context) {
    final merchant = item.merchant;
    final branch = item.branch;
    final area = branch.locality ?? branch.name ?? branch.city ?? merchant.category?.name;
    final status = merchant.businessHours?.statusAt(DateTime.now());
    final distance = '${item.distanceKm.toStringAsFixed(1)} km';
    final radius = BorderRadius.circular(AppSpacing.radiusControl);
    final statusColor = status?.isOpen == true ? AppColors.success : AppColors.textSecondary;

    return Semantics(
      button: true,
      label: [merchant.name, ?area, ?status?.label, '$distance away'].join(', '),
      excludeSemantics: true,
      child: SizedBox(
        width: NearbyStoresSection._cardWidth,
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: radius, boxShadow: AppElevation.card),
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: radius, side: const BorderSide(color: AppColors.border)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push('/merchants/${merchant.id}'),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.smd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          child: MerchantLogo(url: merchant.logoUrl, merchantName: merchant.name, size: AppSize.avatarMd),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                merchant.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              if (area != null)
                                Text(area, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption),
                              if (status != null)
                                Row(
                                  children: [
                                    Icon(
                                      status.isOpen ? Icons.check_circle_rounded : Icons.schedule_rounded,
                                      size: AppIconSize.xs,
                                      color: statusColor,
                                    ),
                                    const SizedBox(width: AppSpacing.xxs),
                                    Flexible(
                                      child: Text(
                                        status.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.caption.copyWith(color: statusColor, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Divider(height: AppSpacing.sm * 2 + 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.place_rounded, size: AppIconSize.xs, color: AppColors.orange),
                              const SizedBox(width: AppSpacing.xxs),
                              Flexible(
                                child: Text(
                                  distance,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.orangeTint,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                              child: Text(
                                'View shop',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(color: AppColors.orangeDeep, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
