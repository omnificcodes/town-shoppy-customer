import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../data/models/offer.dart';

/// A full-width offer row for the Offers tab list -- same information
/// hierarchy as Home's `_TrendingOfferCard` (WHAT -> HOW MUCH -> FROM WHOM)
/// but as a list tile rather than a fixed-width carousel card, matching
/// `MerchantCard`'s row layout so the tab reads consistently with the
/// rest of the app's list screens.
class OfferTile extends StatelessWidget {
  const OfferTile({super.key, required this.offer, this.onTap});

  final Offer offer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '${offer.title}, ${offer.merchantName}',
      child: AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Thumbnail(offer: offer),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.title,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        offer.merchantName,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          if (offer.discountValue != null) ...[
                            _DiscountChip(offer: offer),
                            const SizedBox(width: AppSpacing.xs),
                          ],
                          Flexible(
                            child: Text(
                              _endsInLabel(offer.endsAt),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (offer.isCoinRedeemable) ...[
              const SizedBox(height: AppSpacing.sm),
              _RedeemChip(offerId: offer.id),
            ],
          ],
        ),
      ),
    );
  }

  String _endsInLabel(DateTime? endsAt) {
    if (endsAt == null) return 'Limited time';
    final remaining = endsAt.difference(DateTime.now());
    if (remaining.isNegative) return 'Ending soon';
    if (remaining.inHours < 24) return 'Ends today';
    return 'Ends in ${remaining.inDays}d';
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.offer});

  final Offer offer;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.decorativeAccents[offer.id % AppColors.decorativeAccents.length];
    final hasImage = offer.imageUrl != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: hasImage
          ? Image.network(offer.imageUrl!, width: AppSize.avatarLg, height: AppSize.avatarLg, fit: BoxFit.cover)
          : Container(
              width: AppSize.avatarLg,
              height: AppSize.avatarLg,
              color: accent.withValues(alpha: 0.12),
              alignment: Alignment.center,
              child: Icon(Icons.local_offer_rounded, color: accent, size: AppIconSize.lg),
            ),
    );
  }
}

class _DiscountChip extends StatelessWidget {
  const _DiscountChip({required this.offer});

  final Offer offer;

  @override
  Widget build(BuildContext context) {
    final value = offer.discountValue!;
    final formatted = value.truncateToDouble() == value ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    final label = offer.offerType == 'fixed_discount' ? '₹$formatted OFF' : '$formatted% OFF';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
      child: Text(label, style: AppTypography.badgeLabel.copyWith(color: AppColors.onYellow)),
    );
  }
}

/// Coin Economy V2 (coin-economy-v2.md §6.1) -- same nested-`InkWell`
/// pattern as Home's `_RedeemWithCoinChip` so this tap target wins the
/// gesture arena over the tile's own `onTap`.
class _RedeemChip extends StatelessWidget {
  const _RedeemChip({required this.offerId});

  final int offerId;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Redeem with Town Coin',
      child: Material(
        color: AppColors.goldLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          onTap: () => context.push('/offers/$offerId/redeem'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.savings_rounded, size: AppIconSize.xs, color: AppColors.goldDark),
                const SizedBox(width: AppSpacing.xxs),
                Text('Redeem with Town Coin', style: AppTypography.badgeLabel.copyWith(color: AppColors.goldDark)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
