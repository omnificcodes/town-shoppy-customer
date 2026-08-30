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
        child: Row(
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
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.near_me_rounded, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '$distanceLabel away',
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
