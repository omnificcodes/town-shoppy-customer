import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../merchants/application/featured_merchants_provider.dart';
import '../../../merchants/data/models/merchant.dart';
import '../../../merchants/presentation/merchant_logo.dart';

/// A grid of Super-Admin-curated merchants (`is_featured`), distinct from
/// [MerchantCard] (a full-width list row meant for `MerchantsListScreen`'s
/// long scroll) — this is a compact vertical tile suited to a 2-column
/// Home grid. Renders nothing at all (not even a section header) when the
/// list is empty, since "no merchant has been featured yet" is a normal,
/// expected state, not an error worth a placeholder for.
class FeaturedBusinessesSection extends ConsumerWidget {
  const FeaturedBusinessesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(featuredMerchantsProvider);

    return featured.when(
      loading: () => const SizedBox(height: 168, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 176,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) => _FeaturedMerchantTile(merchant: items[index]),
          ),
        );
      },
    );
  }
}

class _FeaturedMerchantTile extends StatelessWidget {
  const _FeaturedMerchantTile({required this.merchant});

  final Merchant merchant;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: merchant.name,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          onTap: () => context.push('/merchants/${merchant.id}'),
          child: Container(
            width: 136,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      child: SizedBox(
                        width: double.infinity,
                        height: 72,
                        child: MerchantLogo(url: merchant.logoUrl, merchantName: merchant.name, size: 72),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(999)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 11, color: AppColors.onYellow),
                            const SizedBox(width: 2),
                            Text(
                              'Featured',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: AppColors.onYellow, fontWeight: FontWeight.w700, fontSize: 9),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  merchant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (merchant.category != null)
                  Text(
                    merchant.category!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
