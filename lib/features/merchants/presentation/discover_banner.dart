import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// A purely decorative promo strip at the top of merchant discovery — no
/// action attached (there's nowhere meaningful for "Shop Local" to lead to
/// from a screen that already *is* the shopping-local destination), no
/// per-merchant or per-town numbers (nothing backs a "X shops joined" claim
/// today). Tinted, not a saturated full-width fill — this app's own design
/// doc reserves the brand accent for CTAs/badges, never a background behind
/// body content (see `AppColors`'s own docblock).
class DiscoverBanner extends StatelessWidget {
  const DiscoverBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Local Shops, Stronger Together',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Every purchase here keeps a neighbourhood business thriving.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const _BannerIllustration(),
          ],
        ),
      ),
    );
  }
}

class _BannerIllustration extends StatelessWidget {
  const _BannerIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.16), shape: BoxShape.circle),
          ),
          const Icon(Icons.storefront_rounded, color: AppColors.orange, size: 30),
          Positioned(
            right: 0,
            bottom: 2,
            child: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.yellow, shape: BoxShape.circle),
              child: const Icon(Icons.favorite_rounded, color: AppColors.onYellow, size: 12),
            ),
          ),
        ],
      ),
    );
  }
}
