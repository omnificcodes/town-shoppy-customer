import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../merchants/presentation/merchant_logo.dart';
import '../../data/models/offer.dart';
import '../offer_labels.dart';

/// One offer in the Offers feed: a photo header carrying the discount and
/// deadline, then the shop, the deal and a single action.
///
/// The action is "Claim offer" only when the offer really can be redeemed
/// with Town Coin (`/offers/{id}/redeem`); anything else sends the customer
/// to the shop, since no other claim flow exists.
class OfferFeedCard extends StatelessWidget {
  const OfferFeedCard({super.key, required this.offer});

  final Offer offer;

  @override
  Widget build(BuildContext context) {
    final merchantId = offer.merchantId;
    final radius = BorderRadius.circular(AppSpacing.radiusLg);

    return Semantics(
      container: true,
      label: [offer.merchantName, offer.title, ?offerDiscountLabel(offer), offerEndsInLabel(offer.endsAt)].join(', '),
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: AppElevation.card),
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: radius, side: const BorderSide(color: AppColors.border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: merchantId == null ? null : () => context.push('/merchants/$merchantId'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Hero(offer: offer),
                Padding(padding: const EdgeInsets.all(AppSpacing.md), child: _Body(offer: offer)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.offer});

  final Offer offer;

  @override
  Widget build(BuildContext context) {
    final imageUrl = offer.imageUrl;
    final fallback = _HeroFallback(offer: offer);

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl == null)
            fallback
          else ...[
            Image.network(webHtmlElementStrategy: WebHtmlElementStrategy.fallback, imageUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
            // Keeps the chips legible over a busy photo.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.scrim.withValues(alpha: 0.28),
                    AppColors.scrim.withValues(alpha: 0),
                    AppColors.scrim.withValues(alpha: 0.55),
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
          ],
          if (offer.isCoinRedeemable) const Positioned(top: AppSpacing.smd, left: AppSpacing.smd, child: _TownCoinBadge()),
          Positioned(
            left: AppSpacing.smd,
            right: AppSpacing.smd,
            bottom: AppSpacing.smd,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(child: _DiscountChip(label: offerDiscountLabel(offer) ?? 'Special offer')),
                const SizedBox(width: AppSpacing.sm),
                Flexible(child: _DeadlineChip(offer: offer)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// No photo: a warm wash with the shop's own logo, never a stock image.
class _HeroFallback extends StatelessWidget {
  const _HeroFallback({required this.offer});

  final Offer offer;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.warmWash),
      child: Center(
        child: MerchantLogo(url: offer.merchantLogoUrl, merchantName: offer.merchantName, size: AppSize.avatarLg),
      ),
    );
  }
}

class _TownCoinBadge extends StatelessWidget {
  const _TownCoinBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(AppSpacing.radiusXs)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.toll_rounded, size: AppIconSize.xs, color: AppColors.onYellow),
            const SizedBox(width: AppSpacing.xxs),
            Text('TOWN COIN', style: AppTypography.overline.copyWith(color: AppColors.onYellow)),
          ],
        ),
      ),
    );
  }
}

class _DiscountChip extends StatelessWidget {
  const _DiscountChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.scrim.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.onScrim.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_offer_rounded, size: AppIconSize.xs, color: AppColors.yellow),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.badgeLabel.copyWith(color: AppColors.onScrim),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeadlineChip extends StatelessWidget {
  const _DeadlineChip({required this.offer});

  final Offer offer;

  @override
  Widget build(BuildContext context) {
    final coinRate = offer.coinDiscountRate;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule_rounded, size: AppIconSize.xs, color: AppColors.error),
                const SizedBox(width: AppSpacing.xxs),
                Flexible(
                  child: Text(
                    // "ENDS IN 14d": the unit stays lowercase so it reads as days.
                    offerEndsInLabel(offer.endsAt).toUpperCase().replaceAllMapped(RegExp(r'(\d)D$'), (m) => '${m[1]}d'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.badgeLabel.copyWith(color: AppColors.error, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            if (coinRate != null)
              Text(
                '${_percent(coinRate)}% WITH COINS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.overline.copyWith(color: AppColors.success),
              ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.offer});

  final Offer offer;

  @override
  Widget build(BuildContext context) {
    final validTill = offerValidTillLabel(offer.endsAt);
    final detail = offer.applicableItem ?? offer.description;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.orangeTint,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                  border: Border.all(color: AppColors.orangeBorder),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                  child: Text(
                    offerTypeLabel(offer).toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.overline.copyWith(color: AppColors.orangeDeep),
                  ),
                ),
              ),
            ),
            if (validTill != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  validTill,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: AppTypography.caption,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
              child: MerchantLogo(url: offer.merchantLogoUrl, merchantName: offer.merchantName, size: AppIconSize.xl),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                offer.merchantName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.sectionTitle,
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.smd),
          child: Divider(height: 1, color: AppColors.border),
        ),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (detail != null && detail.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _ActionButton(offer: offer),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.offer});

  final Offer offer;

  @override
  Widget build(BuildContext context) {
    final merchantId = offer.merchantId;
    final String label;
    final VoidCallback? onTap;

    if (offer.isCoinRedeemable) {
      label = 'Claim offer';
      onTap = () => context.push('/offers/${offer.id}/redeem');
    } else if (merchantId != null) {
      label = 'View shop';
      onTap = () => context.push('/merchants/$merchantId');
    } else {
      return const SizedBox.shrink();
    }

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: AppColors.orangeDeep,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSize.controlSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.onCrimson,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(Icons.arrow_forward_rounded, size: AppIconSize.sm, color: AppColors.onCrimson),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _percent(double value) => value.truncateToDouble() == value ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
