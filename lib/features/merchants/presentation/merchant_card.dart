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
/// section).
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
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
      child: Text(
        '${rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 1)}% off with Town Coin',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onYellow, fontWeight: FontWeight.w700),
      ),
    );
  }
}
