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
import '../../../offers/presentation/offer_labels.dart';

/// "Best Offers Near You": live offers from shops around the customer, as a
/// two-column grid of tinted cards.
///
/// The nearest offer already leads Home as the hero banner, so this grid
/// starts from the second one instead of repeating it. It hides when there
/// is nothing left to show, including when location isn't available,
/// because the nearby offers search needs a position.
class BestOffersSection extends ConsumerWidget {
  const BestOffersSection({super.key});

  static const _maxOffers = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(trendingOffersProvider);

    final Widget? body = offers.when(
      loading: () => const Row(
        children: [
          Expanded(child: LoadingSkeletonCard()),
          SizedBox(width: AppSpacing.smd),
          Expanded(child: LoadingSkeletonCard()),
        ],
      ),
      error: (error, _) => AppCard(
        child: ErrorState(
          compact: true,
          error: error is AppException ? error : const UnknownAppException(),
          onRetry: () => ref.invalidate(trendingOffersProvider),
        ),
      ),
      data: (items) {
        final rest = items.skip(1).take(_maxOffers).toList();
        return rest.isEmpty ? null : _OfferGrid(offers: rest);
      },
    );

    if (body == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.section),
        SectionHeader(
          title: 'Best Offers Near You',
          subtitle: 'Deals from shops around you',
          actionLabel: 'See all',
          onAction: () => context.go('/offers'),
        ),
        const SizedBox(height: AppSpacing.smd),
        body,
      ],
    );
  }
}

class _OfferGrid extends StatelessWidget {
  const _OfferGrid({required this.offers});

  final List<Offer> offers;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < offers.length; start += 2) {
      if (start > 0) rows.add(const SizedBox(height: AppSpacing.smd));

      // Warm and green alternate in a checkerboard, as in the design.
      final warmFirst = start % 4 == 0;
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _OfferTile(offer: offers[start], warm: warmFirst)),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: start + 1 < offers.length
                    ? _OfferTile(offer: offers[start + 1], warm: !warmFirst)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({required this.offer, required this.warm});

  final Offer offer;
  final bool warm;

  @override
  Widget build(BuildContext context) {
    final background = warm ? AppColors.orangeTint : AppColors.successBg;
    final border = warm ? AppColors.orangeBorder : AppColors.success.withValues(alpha: 0.25);
    final chip = warm ? AppColors.orangeTintStrong : AppColors.success.withValues(alpha: 0.14);
    final ink = warm ? AppColors.orangeDeep : AppColors.success;
    final endsIn = offerEndsInLabel(offer.endsAt);
    final radius = BorderRadius.circular(AppSpacing.radiusMd);

    return Semantics(
      button: true,
      label: '${offer.title}, ${offer.merchantName}, $endsIn',
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.smd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A Wrap, not a Row: in a narrow tile the deadline drops to
                // its own line instead of both labels being cut short.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(color: chip, borderRadius: BorderRadius.circular(AppSpacing.radiusXs)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                        child: Text(
                          offerDiscountLabel(offer) ?? 'OFFER',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.overline.copyWith(color: ink),
                        ),
                      ),
                    ),
                    Text(
                      endsIn,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(color: ink, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  offer.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(offer.merchantName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption),
                const SizedBox(height: AppSpacing.smd),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Flexible so a narrow two-column tile (or a large
                    // system text size) shrinks the button's label rather
                    // than overflowing the row.
                    Flexible(
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(AppSpacing.radiusPill)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd, vertical: AppSpacing.xs),
                          child: Text(
                            offer.isCoinRedeemable ? 'Redeem ›' : 'View ›',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(color: AppColors.onCrimson, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      offer.isCoinRedeemable ? Icons.toll_rounded : Icons.local_offer_rounded,
                      color: ink,
                      size: AppIconSize.xl,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    final merchantId = offer.merchantId;
    if (offer.isCoinRedeemable) {
      context.push('/offers/${offer.id}/redeem');
    } else if (merchantId != null) {
      context.push('/merchants/$merchantId');
    } else {
      context.go('/offers');
    }
  }
}
