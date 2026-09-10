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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.orangeTint,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.orangeBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Local Shops, Stronger Together', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Every purchase here keeps a neighbourhood business thriving.',
                    style: Theme.of(context).textTheme.bodySmall,
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
      width: AppIconSize.hero,
      height: AppIconSize.hero,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: AppSize.avatarLg,
            height: AppSize.avatarLg,
            decoration: const BoxDecoration(color: AppColors.orangeTintStrong, shape: BoxShape.circle),
          ),
          const Icon(Icons.storefront_rounded, color: AppColors.orange, size: AppIconSize.xl),
          Positioned(
            right: 0,
            bottom: AppSpacing.xxs,
            child: Container(
              width: AppSpacing.lg,
              height: AppSpacing.lg,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.yellow, shape: BoxShape.circle),
              child: const Icon(Icons.favorite_rounded, color: AppColors.onYellow, size: AppIconSize.xs),
            ),
          ),
        ],
      ),
    );
  }
}
