import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_card.dart';
import '../data/models/merchant.dart';
import 'favorite_button.dart';
import 'merchant_logo.dart';
import 'view_store_link.dart';

/// A premium merchant summary card — logo, name, category, town, and an
/// optional discount badge, using only fields `MerchantPublicResource`
/// actually returns. `branch_count` is deliberately not shown: the public
/// resource only ever exposes a merchant's single primary branch, never a
/// count of all its branches (see the phase report's backend-limitations
/// section). The heart icon is [FavoriteButton]'s "coming soon" stub.
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
                MerchantLogo(url: merchant.logoUrl, merchantName: merchant.name, size: AppSize.avatarLg),
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
                        const SizedBox(height: AppSpacing.xxs),
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
                FavoriteButton(merchantName: merchant.name),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (merchant.town != null) ...[
                  const Icon(Icons.location_on_outlined, size: AppIconSize.xs, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.xs),
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
                const SizedBox(width: AppSpacing.sm),
                const ViewStoreLink(),
              ],
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
      child: Text(
        '${rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 1)}% off with Town Coin',
        style: AppTypography.badgeLabel.copyWith(color: AppColors.onYellow),
      ),
    );
  }
}
