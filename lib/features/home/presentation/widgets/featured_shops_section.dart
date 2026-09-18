import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../merchants/application/featured_merchants_provider.dart';
import '../../../merchants/data/models/merchant.dart';
import '../../../merchants/presentation/merchant_logo.dart';

/// "Featured Shops": the Super-Admin-curated merchants (`is_featured`) as
/// photo cards.
///
/// Stitch's cards show a star rating and distance. Neither exists for a
/// featured merchant -- there are no ratings anywhere, and only the nearby
/// search knows distances -- so the card's footer says whether the shop
/// takes Town Coin instead. Stitch's "Top rated" subtitle went for the same
/// reason; "hand-picked" is what featuring actually means. The badge is the
/// merchant's own Town Coin rate, labelled as such rather than as a
/// storewide discount.
class FeaturedShopsSection extends ConsumerWidget {
  const FeaturedShopsSection({super.key});

  static const _cardWidth = 208.0;
  static const _imageHeight = 128.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(featuredMerchantsProvider);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final height = _imageHeight + AppSpacing.smd * 2 + (20 + 16 + 18) * scale + AppSpacing.xxs + AppSpacing.sm + AppSpacing.xs;

    final Widget? body = featured.when(
      loading: () => SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 2,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.smd),
          itemBuilder: (_, _) => LoadingSkeleton(
            width: _cardWidth,
            height: height,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
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
        // No featured shops yet is an ordinary state, not an error.
        if (items.isEmpty) return null;

        return SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.smd),
            itemBuilder: (context, index) => _ShopCard(merchant: items[index]),
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
          title: 'Featured Shops',
          subtitle: 'Hand-picked by Town Shoppy',
          actionLabel: 'See all',
          onAction: () => context.push('/merchants'),
        ),
        const SizedBox(height: AppSpacing.smd),
        body,
      ],
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.merchant});

  final Merchant merchant;

  @override
  Widget build(BuildContext context) {
    final category = merchant.category?.name;
    final rate = merchant.discountRate;
    final coinRate = merchant.acceptsTownCoin && rate != null && rate > 0 ? rate : null;
    final footer = merchant.acceptsTownCoin ? 'Accepts Town Coin' : merchant.town?.name;
    final radius = BorderRadius.circular(AppSpacing.radiusMd);

    return Semantics(
      button: true,
      label: [
        merchant.name,
        ?category,
        if (coinRate != null) 'save ${_percent(coinRate)} percent with Town Coins',
      ].join(', '),
      excludeSemantics: true,
      child: SizedBox(
        width: FeaturedShopsSection._cardWidth,
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: radius, boxShadow: AppElevation.card),
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: radius, side: const BorderSide(color: AppColors.border)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push('/merchants/${merchant.id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: FeaturedShopsSection._imageHeight,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _Cover(merchant: merchant),
                        if (coinRate != null)
                          Positioned(
                            top: AppSpacing.sm,
                            right: AppSpacing.sm,
                            child: _Badge(label: '${_percent(coinRate)}% with coins', background: AppColors.orangeDeep),
                          ),
                        if (category != null)
                          Positioned(
                            left: AppSpacing.sm,
                            bottom: AppSpacing.sm,
                            child: _Badge(label: category, background: AppColors.scrim.withValues(alpha: 0.6)),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.smd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          merchant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          merchant.tagline ?? category ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption,
                        ),
                        if (footer != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Icon(
                                merchant.acceptsTownCoin ? Icons.toll_rounded : Icons.place_outlined,
                                size: AppIconSize.xs,
                                color: merchant.acceptsTownCoin ? AppColors.gold : AppColors.textSecondary,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  footer,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
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

  static String _percent(double value) =>
      value.truncateToDouble() == value ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
}

/// The merchant's cover photo, or its logo on a warm tint when it has none
/// or the photo fails to load.
class _Cover extends StatelessWidget {
  const _Cover({required this.merchant});

  final Merchant merchant;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: AppColors.orangeTint,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
          child: MerchantLogo(url: merchant.logoUrl, merchantName: merchant.name, size: AppSize.avatarLg),
        ),
      ),
    );

    final url = merchant.coverImageUrl;
    if (url == null) return fallback;

    return Image.network(webHtmlElementStrategy: WebHtmlElementStrategy.fallback, url, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.background});

  final String label;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: FeaturedShopsSection._cardWidth * 0.6),
      child: DecoratedBox(
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppSpacing.radiusXs)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.badgeLabel.copyWith(color: AppColors.onCrimson),
          ),
        ),
      ),
    );
  }
}
