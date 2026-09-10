import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../merchants/application/featured_merchants_provider.dart';
import '../../../merchants/data/models/merchant.dart';
import '../../../merchants/presentation/merchant_logo.dart';

/// A row of Super-Admin-curated merchants (`is_featured`), distinct from
/// [MerchantCard] (a full-width list row meant for `MerchantsListScreen`'s
/// long scroll) — this is a compact vertical tile suited to a horizontal
/// Home carousel. Renders nothing at all when the list is empty, since "no
/// merchant has been featured yet" is a normal, expected state, not an
/// error worth a placeholder for.
class FeaturedBusinessesSection extends ConsumerWidget {
  const FeaturedBusinessesSection({super.key});

  static const _tileWidth = 140.0;
  static const _logoHeight = 72.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(featuredMerchantsProvider);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    // Card padding + logo + gap + name line + gap + category line (both
    // lines scaled) + border/rounding slack.
    final height = AppSpacing.sm * 2 + _logoHeight + AppSpacing.sm + AppSpacing.xxs + (18 + 16) * scale + AppSpacing.sm;

    final Widget? body = featured.when(
      loading: () => SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (_, _) => SizedBox(
            width: _tileWidth,
            child: LoadingSkeleton(borderRadius: BorderRadius.circular(AppSpacing.radiusMd), height: height),
          ),
        ),
      ),
      error: (error, _) => AppCard(
        child: ErrorState(
          compact: true,
          error: error is AppException ? error : const UnknownAppException(),
          onRetry: () => ref.invalidate(featuredMerchantsProvider),
        ),
      ),
      data: (items) {
        if (items.isEmpty) return null;

        return SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) => _FeaturedMerchantTile(merchant: items[index]),
          ),
        );
      },
    );

    if (body == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.section),
        SectionHeader(
          title: 'Featured businesses',
          actionLabel: 'See all',
          onAction: () => context.push('/merchants'),
        ),
        const SizedBox(height: AppSpacing.smd),
        body,
      ],
    );
  }
}

class _FeaturedMerchantTile extends StatelessWidget {
  const _FeaturedMerchantTile({required this.merchant});

  final Merchant merchant;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${merchant.name}, featured${merchant.category != null ? ', ${merchant.category!.name}' : ''}',
      child: SizedBox(
        width: FeaturedBusinessesSection._tileWidth,
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.sm),
          onTap: () => context.push('/merchants/${merchant.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    child: SizedBox(
                      width: double.infinity,
                      height: FeaturedBusinessesSection._logoHeight,
                      child: MerchantLogo(
                        url: merchant.logoUrl,
                        merchantName: merchant.name,
                        size: FeaturedBusinessesSection._logoHeight,
                      ),
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.xs,
                    left: AppSpacing.xs,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                      decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(AppSpacing.radiusPill)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: AppIconSize.xs, color: AppColors.onYellow),
                          const SizedBox(width: AppSpacing.xxs),
                          Text('Featured', style: AppTypography.badgeLabel.copyWith(color: AppColors.onYellow)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(merchant.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
              if (merchant.category != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(merchant.category!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
