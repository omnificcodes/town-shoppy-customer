import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../application/merchant_branches_provider.dart';
import '../application/merchant_detail_provider.dart';
import '../data/models/merchant.dart';
import 'branch_selector.dart';
import 'merchant_logo.dart';

class MerchantDetailScreen extends ConsumerWidget {
  const MerchantDetailScreen({super.key, required this.merchantId});

  final int merchantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(merchantDetailProvider(merchantId));

    return Scaffold(
      appBar: AppBar(title: const Text('Merchant')),
      body: SafeArea(
        child: detail.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(children: [LoadingSkeletonCard(), SizedBox(height: AppSpacing.sm), LoadingSkeletonCard()]),
          ),
          error: (error, _) => ErrorState(
            error: error is AppException ? error : const UnknownAppException(),
            onRetry: () => ref.invalidate(merchantDetailProvider(merchantId)),
          ),
          data: (merchant) => _MerchantDetailBody(merchant: merchant),
        ),
      ),
    );
  }
}

class _MerchantDetailBody extends ConsumerWidget {
  const _MerchantDetailBody({required this.merchant});

  final Merchant merchant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationLine = [merchant.town?.name, merchant.town?.stateRegion].whereType<String>().where((p) => p.isNotEmpty).join(', ');

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Hero header.
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.orange.withValues(alpha: 0.10), AppColors.yellow.withValues(alpha: 0.10)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MerchantLogo(url: merchant.logoUrl, merchantName: merchant.name, size: 72),
              const SizedBox(height: AppSpacing.md),
              Text(merchant.name, style: Theme.of(context).textTheme.headlineSmall),
              if (merchant.category != null) ...[
                const SizedBox(height: 4),
                Text(merchant.category!.name, style: Theme.of(context).textTheme.bodyMedium),
              ],
              if (locationLine.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        locationLine,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (merchant.acceptsTownCoin) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(Icons.savings_rounded, size: 16, color: AppColors.silverDark),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Accepts Town Coin',
                        style: Theme.of(context).textTheme.labelMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Redeem eligibility mirrors RedemptionCalculator::calculate()'s own
        // gate exactly (accepts_town_coin + a positive discount_rate) — the
        // backend re-checks both regardless, this only avoids offering a CTA
        // that would just 422.
        if (merchant.acceptsTownCoin && (merchant.discountRate ?? 0) > 0) ...[
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Redeem Town Coin',
            icon: Icons.savings_rounded,
            onPressed: () => context.push('/merchants/${merchant.id}/redeem'),
          ),
        ],

        if (merchant.description != null && merchant.description!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('About', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          AppCard(child: Text(merchant.description!, style: Theme.of(context).textTheme.bodyMedium)),
        ],

        const SizedBox(height: AppSpacing.lg),
        _BranchesSection(merchantId: merchant.id),

        if (merchant.websiteUrl != null && merchant.websiteUrl!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Website', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Row(
              children: [
                const Icon(Icons.public_rounded, color: AppColors.info),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(merchant.websiteUrl!, style: Theme.of(context).textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The full branch list (Phase 4) — replaces Phase 3's single embedded
/// `merchant.branch`. A failure here doesn't block the rest of the merchant
/// profile (same "don't let a secondary section break the page" policy as
/// the merchant list's category-chip row), but branch data matters more for
/// an eventual redemption flow than categories do, so this shows a
/// retryable error rather than silently collapsing to nothing.
class _BranchesSection extends ConsumerWidget {
  const _BranchesSection({required this.merchantId});

  final int merchantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(merchantBranchesProvider(merchantId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          branches.value != null && branches.value!.length > 1 ? 'Branches' : 'Branch',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        branches.when(
          loading: () => const LoadingSkeletonCard(),
          error: (error, _) => ErrorState(
            error: error is AppException ? error : const UnknownAppException(),
            onRetry: () => ref.invalidate(merchantBranchesProvider(merchantId)),
          ),
          data: (data) => BranchSelector(branches: data),
        ),
      ],
    );
  }
}
