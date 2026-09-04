import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../data/models/nearby_merchant.dart';
import 'merchant_logo.dart';

/// Same visual language as [MerchantCard], but for a `GET /merchants/nearby`
/// result: shows the specific branch's address and its distance instead of
/// the merchant's category/town — that's what a "nearby" list needs to
/// convey, matching branch info rather than the merchant's primary branch.
class NearbyMerchantCard extends StatelessWidget {
  const NearbyMerchantCard({super.key, required this.result, this.onTap});

  final NearbyMerchant result;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final merchant = result.merchant;
    final address = result.branch.formattedAddress;
    final distanceLabel = result.distanceKm < 1
        ? '${(result.distanceKm * 1000).round()} m'
        : '${result.distanceKm.toStringAsFixed(1)} km';

    return Semantics(
      button: onTap != null,
      label: '${merchant.name}, $distanceLabel away',
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
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          address,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                const Icon(Icons.near_me_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '$distanceLabel away',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ),
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
