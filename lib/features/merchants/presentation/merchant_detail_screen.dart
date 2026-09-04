import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../application/merchant_branches_provider.dart';
import '../application/merchant_detail_provider.dart';
import '../data/models/merchant.dart';
import '../data/models/merchant_branch_ref.dart';
import 'branch_selector.dart';
import 'category_visual.dart';
import 'merchant_logo.dart';

class MerchantDetailScreen extends ConsumerWidget {
  const MerchantDetailScreen({super.key, required this.merchantId});

  final int merchantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(merchantDetailProvider(merchantId));

    return Scaffold(
      appBar: AppBar(title: const Text('Merchant Details')),
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
        _HeroCard(merchant: merchant, locationLine: locationLine),

        // Redeem eligibility mirrors RedemptionCalculator::calculate()'s own
        // gate exactly (accepts_town_coin + a positive discount_rate) — the
        // backend re-checks both regardless, this only avoids offering a CTA
        // that would just 422.
        if (merchant.acceptsTownCoin && (merchant.discountRate ?? 0) > 0) ...[
          const SizedBox(height: AppSpacing.md),
          _RedeemCoinCta(onTap: () => context.push('/merchants/${merchant.id}/redeem')),
        ],

        if (merchant.description != null && merchant.description!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('About', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _AboutCard(merchant: merchant),
        ],

        const SizedBox(height: AppSpacing.lg),
        _BranchesSection(merchant: merchant),

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

        const SizedBox(height: AppSpacing.lg),
        const _WhyTownCoinStrip(),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.merchant, required this.locationLine});

  final Merchant merchant;
  final String locationLine;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.orange.withValues(alpha: 0.12), AppColors.yellow.withValues(alpha: 0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Stack(
        children: [
          // Purely decorative -- no illustration asset exists for this (same
          // stance as Home/Wallet's own icon-built motifs), so a single
          // large low-opacity icon stands in for the reference's leaf
          // flourish rather than adding an image asset.
          Positioned(
            right: -16,
            top: -8,
            child: Icon(Icons.eco_rounded, size: 110, color: AppColors.orange.withValues(alpha: 0.08)),
          ),
          const Positioned(right: 36, top: 12, child: Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.orange)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 76,
                height: 76,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  boxShadow: [BoxShadow(color: AppColors.deepMaroon.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: MerchantLogo(url: merchant.logoUrl, merchantName: merchant.name, size: 68),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(merchant.name, style: Theme.of(context).textTheme.headlineSmall),
                    if (merchant.category != null) ...[
                      const SizedBox(height: 2),
                      Text(merchant.category!.name, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                    if (locationLine.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(locationLine, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                    if (merchant.acceptsTownCoin) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(999)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.savings_rounded, size: 14, color: AppColors.success),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Accepts Town Coin',
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.success, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RedeemCoinCta extends StatelessWidget {
  const _RedeemCoinCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.orange,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
          child: Row(
            children: [
              const Icon(Icons.savings_rounded, color: Colors.white),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Redeem Town Coin', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                child: const Icon(Icons.chevron_right_rounded, color: AppColors.orange, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.merchant});

  final Merchant merchant;

  @override
  Widget build(BuildContext context) {
    final category = merchant.category;
    final visual = category != null ? CategoryVisual.forCategory(name: category.name, slug: category.slug) : CategoryVisual.fallback;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: visual.color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(visual.icon, color: visual.color, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (category != null) ...[
                  Text(category.name, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                ],
                Text(merchant.description!, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The full branch list (Phase 4) — replaces Phase 3's single embedded
/// `merchant.branch`. A failure here doesn't block the rest of the merchant
/// profile (same "don't let a secondary section break the page" policy as
/// the merchant list's category-chip row), but branch data matters more for
/// an eventual redemption flow than categories do, so this shows a
/// retryable error rather than silently collapsing to nothing.
///
/// Exactly one branch gets the reference design's richer card (address +
/// call + directions); zero or several branches fall back to the existing
/// [BranchSelector] list, since a single call/directions footer wouldn't
/// unambiguously belong to any one of several branches.
class _BranchesSection extends ConsumerWidget {
  const _BranchesSection({required this.merchant});

  final Merchant merchant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(merchantBranchesProvider(merchant.id));

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
            onRetry: () => ref.invalidate(merchantBranchesProvider(merchant.id)),
          ),
          data: (data) => data.length == 1
              ? _SingleBranchCard(branch: data.first, contactMobileNumber: merchant.contactMobileNumber)
              : BranchSelector(branches: data),
        ),
      ],
    );
  }
}

class _SingleBranchCard extends StatelessWidget {
  const _SingleBranchCard({required this.branch, required this.contactMobileNumber});

  final MerchantBranchRef branch;
  final String? contactMobileNumber;

  @override
  Widget build(BuildContext context) {
    final address = branch.formattedAddress;
    final hasContact = contactMobileNumber != null && contactMobileNumber!.trim().isNotEmpty;
    final hasCoordinates = branch.latitude != null && branch.longitude != null;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                  child: const Icon(Icons.storefront_rounded, color: AppColors.orange, size: 20),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(branch.name ?? 'Branch', style: Theme.of(context).textTheme.titleSmall),
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(address, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (hasContact || hasCoordinates) ...[
            const Divider(height: 1),
            Row(
              children: [
                if (hasContact)
                  Expanded(
                    child: _BranchActionButton(
                      icon: Icons.call_rounded,
                      label: contactMobileNumber!,
                      onTap: () => _launch(context, Uri(scheme: 'tel', path: contactMobileNumber)),
                    ),
                  ),
                if (hasContact && hasCoordinates)
                  const SizedBox(height: 32, child: VerticalDivider(width: 1)),
                if (hasCoordinates)
                  Expanded(
                    child: _BranchActionButton(
                      icon: Icons.near_me_rounded,
                      label: 'Get Directions',
                      onTap: () => _launch(
                        context,
                        Uri.parse('https://www.google.com/maps/search/?api=1&query=${branch.latitude},${branch.longitude}'),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _launch(BuildContext context, Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open this action on your device.')));
    }
  }
}

class _BranchActionButton extends StatelessWidget {
  const _BranchActionButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppColors.orange),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Generic, non-merchant-specific product education -- same honest-content
/// rule as everywhere else in this session's redesigns (Wallet's "How it
/// works" sheet): no fabricated per-merchant claims, just how Town Coin
/// itself works, same for every merchant page.
class _WhyTownCoinStrip extends StatelessWidget {
  const _WhyTownCoinStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        children: [
          Expanded(
            child: _WhyTownCoinItem(icon: Icons.savings_rounded, color: AppColors.orange, title: 'Pay with\nTown Coins', subtitle: 'Use your coins to get exciting offers'),
          ),
          Expanded(
            child: _WhyTownCoinItem(icon: Icons.card_giftcard_rounded, color: AppColors.crimson, title: 'Enjoy More\nRewards', subtitle: 'Unlock special discounts & deals'),
          ),
          Expanded(
            child: _WhyTownCoinItem(icon: Icons.percent_rounded, color: Color(0xFF6A1B9A), title: 'Save More\nEveryday', subtitle: 'The more you shop, the more you save'),
          ),
        ],
      ),
    );
  }
}

class _WhyTownCoinItem extends StatelessWidget {
  const _WhyTownCoinItem({required this.icon, required this.color, required this.title, required this.subtitle});

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 2),
        Text(subtitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall, maxLines: 3),
      ],
    );
  }
}
