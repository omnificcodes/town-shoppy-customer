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
import '../../../offers/application/trending_offers_provider.dart';
import '../../../offers/data/models/offer.dart';

/// Home's "Offers near you" carousel — see `trending_offers_provider.dart`
/// for why "trending" means "nearest currently-active offers", the only
/// signal `GET /offers/nearby` actually gives. Renders nothing (no header,
/// no empty-state card) when there are none nearby or location isn't
/// available yet — this is a bonus discovery surface, not a core section
/// Home depends on always having content for.
///
/// Cards follow the offer hierarchy WHAT → HOW MUCH → FROM WHOM: a
/// prominent discount chip, the offer title, the merchant, then validity.
/// An offer with an image gets a photo card with a dark scrim; one without
/// gets a tinted card with dark text — never a saturated gradient behind
/// body copy.
class TrendingOffersSection extends ConsumerWidget {
  const TrendingOffersSection({super.key});

  static const _cardWidth = 250.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(trendingOffersProvider);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5);
    final height = 150 + 40 * (scale - 1);

    final Widget? body = offers.when(
      loading: () => SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 2,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
          itemBuilder: (_, _) => SizedBox(
            width: _cardWidth,
            child: LoadingSkeleton(borderRadius: BorderRadius.circular(AppSpacing.radiusMd), height: height),
          ),
        ),
      ),
      error: (error, _) => AppCard(
        child: ErrorState(
          compact: true,
          error: error is AppException ? error : const UnknownAppException(),
          onRetry: () => ref.invalidate(trendingOffersProvider),
        ),
      ),
      data: (items) {
        if (items.isEmpty) return null;

        return SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) => _TrendingOfferCard(offer: items[index]),
          ),
        );
      },
    );

    if (body == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.section),
        const SectionHeader(title: 'Offers near you'),
        const SizedBox(height: AppSpacing.smd),
        body,
      ],
    );
  }
}

class _TrendingOfferCard extends StatelessWidget {
  const _TrendingOfferCard({required this.offer});

  final Offer offer;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.decorativeAccents[offer.id % AppColors.decorativeAccents.length];
    final hasImage = offer.imageUrl != null;
    final onSurface = hasImage ? AppColors.onScrim : AppColors.textPrimary;
    final onSurfaceMuted = hasImage ? AppColors.onScrimMuted : AppColors.textSecondary;

    return Semantics(
      button: true,
      label: '${offer.title}, ${offer.merchantName}',
      child: Material(
        color: hasImage ? AppColors.scrim : accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: offer.merchantId == null ? null : () => context.push('/merchants/${offer.merchantId}'),
          child: Ink(
            width: TrendingOffersSection._cardWidth,
            decoration: BoxDecoration(
              border: hasImage ? null : Border.all(color: accent.withValues(alpha: 0.25)),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              image: hasImage
                  ? DecorationImage(
                      image: NetworkImage(offer.imageUrl!),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(AppColors.scrim.withValues(alpha: 0.45), BlendMode.darken),
                    )
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (offer.discountValue != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: hasImage ? AppColors.surface : accent,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                          ),
                          child: Text(
                            _discountLabel(offer),
                            style: AppTypography.badgeLabel.copyWith(color: hasImage ? AppColors.deepMaroon : AppColors.surface),
                          ),
                        ),
                      const Spacer(),
                      Icon(Icons.local_offer_rounded, color: hasImage ? AppColors.onScrim : accent, size: AppIconSize.md),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    offer.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: onSurface),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    offer.merchantName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: onSurfaceMuted),
                  ),
                  if (offer.isCoinRedeemable) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _RedeemWithCoinChip(offerId: offer.id, hasImage: hasImage),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: AppIconSize.xs, color: onSurfaceMuted),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          _endsInLabel(offer.endsAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(color: onSurfaceMuted),
                        ),
                      ),
                      if (offer.distanceKm != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Icon(Icons.place_rounded, size: AppIconSize.xs, color: onSurfaceMuted),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          '${offer.distanceKm!.toStringAsFixed(1)} km',
                          style: AppTypography.caption.copyWith(color: onSurfaceMuted),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _discountLabel(Offer offer) {
    final value = offer.discountValue!;
    final formatted = value.truncateToDouble() == value ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    return offer.offerType == 'fixed_discount' ? '₹$formatted OFF' : '$formatted% OFF';
  }

  String _endsInLabel(DateTime? endsAt) {
    if (endsAt == null) return 'Limited time';
    final remaining = endsAt.difference(DateTime.now());
    if (remaining.isNegative) return 'Ending soon';
    if (remaining.inHours < 24) return 'Ends today';
    return 'Ends in ${remaining.inDays}d';
  }
}

/// Coin Economy V2 (coin-economy-v2.md §6.1) -- a small standalone tap
/// target nested inside the card's own `InkWell` (its `onTap` wins the
/// gesture arena and the outer merchant-detail navigation never fires,
/// same well-established "inner InkWell absorbs the tap" Flutter pattern
/// used elsewhere for a card with an embedded button).
class _RedeemWithCoinChip extends StatelessWidget {
  const _RedeemWithCoinChip({required this.offerId, required this.hasImage});

  final int offerId;
  final bool hasImage;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Redeem with Town Coin',
      child: Material(
        color: hasImage ? AppColors.onScrimMuted.withValues(alpha: 0.18) : AppColors.orangeTintStrong,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          onTap: () => context.push('/offers/$offerId/redeem'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.savings_rounded, size: AppIconSize.xs, color: hasImage ? AppColors.onScrim : AppColors.orange),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  'Redeem with Town Coin',
                  style: AppTypography.badgeLabel.copyWith(color: hasImage ? AppColors.onScrim : AppColors.deepMaroon),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
