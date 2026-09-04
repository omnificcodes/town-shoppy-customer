import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../data/models/merchant.dart';
import 'merchant_logo.dart';

/// A premium merchant summary card — logo, name, category, town, and an
/// optional discount badge, using only fields `MerchantPublicResource`
/// actually returns. `branch_count` is deliberately not shown: the public
/// resource only ever exposes a merchant's single primary branch, never a
/// count of all its branches (see the phase report's backend-limitations
/// section). The heart icon is a UI-only stub — there is no favorites/
/// wishlist concept anywhere in the backend yet, so it surfaces a "coming
/// soon" message rather than pretending to persist anything, same pattern
/// Wallet's Terms & Conditions/Help & Support use.
class MerchantCard extends StatelessWidget {
  const MerchantCard({super.key, required this.merchant, this.onTap});

  final Merchant merchant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      merchant.category?.name,
      merchant.town?.name,
    ].whereType<String>().where((p) => p.isNotEmpty).join(' · ');

    return Semantics(
      button: onTap != null,
      label: '${merchant.name}${subtitleParts.isNotEmpty ? ', $subtitleParts' : ''}',
      child: AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MerchantLogo(url: merchant.logoUrl, merchantName: merchant.name, size: 56),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        merchant.name,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitleParts.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitleParts,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (merchant.discountRate != null && merchant.discountRate! > 0) ...[
                        const SizedBox(height: AppSpacing.xs),
                        _DiscountBadge(rate: merchant.discountRate!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                _FavoriteButton(merchantName: merchant.name),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (merchant.town != null) ...[
                  const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      merchant.town!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ] else
                  const Spacer(),
                Text(
                  'View Store',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: AppColors.orange, fontWeight: FontWeight.w700),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.merchantName});

  final String merchantName;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Favorite $merchantName',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Favorites is coming soon.'))),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.favorite_border_rounded, size: 20, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _DiscountBadge extends StatelessWidget {
  const _DiscountBadge({required this.rate});

  final double rate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
      child: Text(
        '${rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 1)}% off with Town Coin',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onYellow, fontWeight: FontWeight.w700),
      ),
    );
  }
}
