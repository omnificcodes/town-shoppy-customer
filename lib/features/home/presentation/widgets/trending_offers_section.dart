import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../offers/application/trending_offers_provider.dart';
import '../../../offers/data/models/offer.dart';

/// Home's "Trending offers near you" carousel — see
/// `trending_offers_provider.dart` for why "trending" means "nearest
/// currently-active offers", the only signal `GET /offers/nearby` actually
/// gives. Renders nothing (no header, no empty-state card) when there are
/// none nearby or location isn't available yet — this is a bonus discovery
/// surface, not a core section Home depends on always having content for.
class TrendingOffersSection extends ConsumerWidget {
  const TrendingOffersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(trendingOffersProvider);

    return offers.when(
      loading: () => const SizedBox(height: 190, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) => _TrendingOfferCard(offer: items[index]),
          ),
        );
      },
    );
  }
}

const _cardGradients = [
  [Color(0xFFFF6B00), Color(0xFFE50914)],
  [Color(0xFF3B5BA9), Color(0xFF6A1B9A)],
  [Color(0xFF00897B), Color(0xFF2E7D32)],
  [Color(0xFFD81B60), Color(0xFFAD1457)],
];

class _TrendingOfferCard extends StatelessWidget {
  const _TrendingOfferCard({required this.offer});

  final Offer offer;

  @override
  Widget build(BuildContext context) {
    final gradient = _cardGradients[offer.id % _cardGradients.length];

    return Semantics(
      button: true,
      label: '${offer.title}, ${offer.merchantName}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          onTap: offer.merchantId == null ? null : () => context.push('/merchants/${offer.merchantId}'),
          child: Container(
            width: 260,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
              image: offer.imageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(offer.imageUrl!),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.35), BlendMode.darken),
                    )
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (offer.discountValue != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                        child: Text(
                          _discountLabel(offer),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: AppColors.deepMaroon, fontWeight: FontWeight.w800),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    const Icon(Icons.local_offer_rounded, color: Colors.white, size: 18),
                  ],
                ),
                const Spacer(),
                Text(
                  offer.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  offer.merchantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 13, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      _endsInLabel(offer.endsAt),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70),
                    ),
                    if (offer.distanceKm != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      const Icon(Icons.place_rounded, size: 13, color: Colors.white70),
                      const SizedBox(width: 2),
                      Text(
                        '${offer.distanceKm!.toStringAsFixed(1)} km',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ],
                ),
              ],
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
