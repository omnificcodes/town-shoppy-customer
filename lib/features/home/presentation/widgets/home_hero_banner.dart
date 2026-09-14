import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../offers/application/trending_offers_provider.dart';
import '../../../offers/presentation/offer_labels.dart';

/// The saturated promo card under the stats row.
///
/// Stitch shows a "Sponsored" campaign with a promo code, but there is no
/// promotions or sponsorship API, so nothing real could fill it. The card
/// instead leads with the nearest live offer -- the same data Best Offers
/// uses -- and falls back to an invitation to discover shops while location
/// or offers aren't available. It never says "Sponsored".
class HomeHeroBanner extends ConsumerWidget {
  const HomeHeroBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(trendingOffersProvider).value;
    final offer = (offers == null || offers.isEmpty) ? null : offers.first;

    if (offer == null) {
      return _PromoBanner(
        eyebrow: 'TOWN SHOPPY',
        title: 'Discover shops near you',
        subtitle: 'Earn Town Coins and Lucky Draw coupons when you shop local.',
        ctaLabel: 'Explore',
        icon: Icons.storefront_rounded,
        onTap: () => context.push('/merchants'),
      );
    }

    final distance = offer.distanceKm;
    final merchantId = offer.merchantId;

    return _PromoBanner(
      eyebrow: offerDiscountLabel(offer) ?? 'OFFER',
      tag: offerEndsInLabel(offer.endsAt),
      title: offer.title,
      subtitle: distance == null ? offer.merchantName : '${offer.merchantName} · ${distance.toStringAsFixed(1)} km away',
      ctaLabel: offer.isCoinRedeemable ? 'Redeem now' : 'View shop',
      icon: offer.isCoinRedeemable ? Icons.toll_rounded : Icons.local_offer_rounded,
      onTap: () {
        if (offer.isCoinRedeemable) {
          context.push('/offers/${offer.id}/redeem');
        } else if (merchantId != null) {
          context.push('/merchants/$merchantId');
        } else {
          context.go('/offers');
        }
      },
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.icon,
    required this.onTap,
    this.tag,
  });

  final String eyebrow;
  final String? tag;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final IconData icon;
  final VoidCallback onTap;

  /// The copy stays over the deep half of [AppGradients.promoHero]; the
  /// artwork owns the rest.
  static const _copyWidthFactor = 0.7;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppSpacing.radiusMd);
    final shownTag = tag;

    return Semantics(
      button: true,
      label: '$title. $subtitle. $ctaLabel',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: AppElevation.subtle),
        child: ClipRRect(
          borderRadius: radius,
          child: DecoratedBox(
            decoration: const BoxDecoration(gradient: AppGradients.promoHero),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                child: Stack(
                  children: [
                    Positioned(
                      right: -AppSpacing.sm,
                      bottom: -AppSpacing.sm,
                      child: Container(
                        width: AppIconSize.hero + AppSpacing.xl,
                        height: AppIconSize.hero + AppSpacing.xl,
                        decoration: BoxDecoration(
                          color: AppColors.onCrimson.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: AppIconSize.display, color: AppColors.goldLight),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: FractionallySizedBox(
                        widthFactor: _copyWidthFactor,
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                                  decoration: BoxDecoration(
                                    color: AppColors.businessInkDeep.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                                  ),
                                  child: Text(eyebrow, style: AppTypography.overline.copyWith(color: AppColors.goldLight)),
                                ),
                                if (shownTag != null) ...[
                                  const SizedBox(width: AppSpacing.sm),
                                  Flexible(
                                    child: Text(
                                      shownTag,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.caption.copyWith(color: AppColors.goldLight, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.headlineSmall?.copyWith(color: AppColors.onCrimson, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.onCrimson),
                            ),
                            const SizedBox(height: AppSpacing.smd),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd, vertical: AppSpacing.xs + AppSpacing.xxs),
                                child: Text(
                                  '$ctaLabel ›',
                                  style: theme.textTheme.labelMedium?.copyWith(color: AppColors.orangeDeep, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
