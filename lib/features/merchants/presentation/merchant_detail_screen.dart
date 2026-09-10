import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';
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

    return AppScaffold(
      title: 'Merchant Details',
      padded: false,
      body: detail.when(
        loading: () => const LoadingSkeletonList(count: 2),
        error: (error, _) => ErrorState(
          error: error is AppException ? error : const UnknownAppException(),
          onRetry: () => ref.invalidate(merchantDetailProvider(merchantId)),
        ),
        data: (merchant) => _MerchantDetailBody(merchant: merchant),
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
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        _HeroCard(merchant: merchant, locationLine: locationLine),

        // Redeem eligibility mirrors RedemptionCalculator::calculate()'s own
        // gate exactly (accepts_town_coin + a positive discount_rate) — the
        // backend re-checks both regardless, this only avoids offering a CTA
        // that would just 422.
        if (merchant.acceptsTownCoin && (merchant.discountRate ?? 0) > 0) ...[
          const SizedBox(height: AppSpacing.md),
          _RedeemCoinCta(
            discountRate: merchant.discountRate!,
            onTap: () => context.push('/merchants/${merchant.id}/redeem'),
          ),
        ],

        if (merchant.description != null && merchant.description!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'About'),
          const SizedBox(height: AppSpacing.sm),
          _AboutCard(merchant: merchant),
        ],

        const SizedBox(height: AppSpacing.section),
        _BranchesSection(merchant: merchant),

        if (merchant.websiteUrl != null && merchant.websiteUrl!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'Website'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Row(
              children: [
                const Icon(Icons.public_rounded, size: AppIconSize.lg, color: AppColors.info),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(merchant.websiteUrl!, style: Theme.of(context).textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.section),
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
        color: AppColors.orangeTint,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.orangeBorder),
      ),
      child: Stack(
        children: [
          // Purely decorative -- no illustration asset exists for this (same
          // stance as Home/Wallet's own icon-built motifs), so a single
          // large low-opacity storefront stands in for an illustration
          // rather than adding an image asset.
          Positioned(
            right: 0,
            top: 0,
            child: ExcludeSemantics(
              child: Icon(Icons.storefront_rounded, size: AppIconSize.hero, color: AppColors.orange.withValues(alpha: 0.08)),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.orangeBorder),
                ),
                child: MerchantLogo(url: merchant.logoUrl, merchantName: merchant.name, size: AppSize.avatarLg),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(merchant.name, style: Theme.of(context).textTheme.headlineSmall),
                    if (merchant.category != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(merchant.category!.name, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                    if (locationLine.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: AppIconSize.sm, color: AppColors.textSecondary),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(locationLine, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                    if (merchant.acceptsTownCoin) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const StatusBadge(
                        label: 'Accepts Town Coin',
                        tone: AppTone.success,
                        icon: Icons.savings_rounded,
                        large: true,
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

/// The page's one primary action, on a tinted card so it reads as the
/// reward moment without painting saturated orange behind body text.
class _RedeemCoinCta extends StatelessWidget {
  const _RedeemCoinCta({required this.discountRate, required this.onTap});

  final double discountRate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rate = discountRate.toStringAsFixed(discountRate.truncateToDouble() == discountRate ? 0 : 1);

    return AppCard(
      tinted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            // The rate is the merchant's own configured discount_rate, the
            // same figure RedemptionCalculator applies — not a marketing
            // estimate.
            'Save $rate% when you pay with Town Coin here.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.smd),
          AppButton(
            label: 'Redeem Town Coin',
            size: AppButtonSize.lg,
            icon: Icons.savings_rounded,
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed: onTap,
          ),
        ],
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
            width: AppSize.avatarMd,
            height: AppSize.avatarMd,
            decoration: BoxDecoration(color: visual.color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(visual.icon, color: visual.color, size: AppIconSize.md),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (category != null) ...[
                  Text(category.name, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
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
        SectionHeader(title: branches.value != null && branches.value!.length > 1 ? 'Branches' : 'Branch'),
        const SizedBox(height: AppSpacing.sm),
        branches.when(
          loading: () => const LoadingSkeletonCard(),
          error: (error, _) => ErrorState(
            error: error is AppException ? error : const UnknownAppException(),
            compact: true,
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
                  width: AppSize.avatarMd,
                  height: AppSize.avatarMd,
                  decoration: BoxDecoration(color: AppColors.orangeTint, borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                  child: const Icon(Icons.storefront_rounded, color: AppColors.orange, size: AppIconSize.md),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(branch.name ?? 'Branch', style: Theme.of(context).textTheme.titleSmall),
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
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
                  const SizedBox(height: AppSpacing.xl, child: VerticalDivider(width: 1)),
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
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: AppSpacing.touchTarget,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: AppIconSize.sm, color: AppColors.orange),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Generic, non-merchant-specific product education -- same honest-content
/// rule as everywhere else in this session's redesigns (Wallet's "How it
/// works" sheet): no fabricated per-merchant claims, just how Town Coin
/// itself works, same for every merchant page. Three stacked rows rather
/// than three squeezed columns, so each label wraps naturally at any width
/// or text scale instead of relying on a hard line break.
class _WhyTownCoinStrip extends StatelessWidget {
  const _WhyTownCoinStrip();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Why pay with Town Coin'),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              const _WhyTownCoinItem(
                icon: Icons.savings_rounded,
                color: AppColors.orange,
                title: 'Pay with Town Coins',
                subtitle: 'Use your coins towards purchases at participating merchants.',
              ),
              const SizedBox(height: AppSpacing.smd),
              const _WhyTownCoinItem(
                icon: Icons.card_giftcard_rounded,
                color: AppColors.crimson,
                title: 'Enjoy more rewards',
                subtitle: 'Unlock merchant discounts and lucky draw entries.',
              ),
              const SizedBox(height: AppSpacing.smd),
              _WhyTownCoinItem(
                icon: Icons.percent_rounded,
                color: AppColors.decorativeAccents[5],
                title: 'Save more every day',
                subtitle: 'The more you shop locally, the more you save.',
              ),
            ],
          ),
        ),
      ],
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: AppSize.avatarMd,
          height: AppSize.avatarMd,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: AppIconSize.md),
        ),
        const SizedBox(width: AppSpacing.smd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xxs),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
