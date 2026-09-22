import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../offers/application/merchant_offers_provider.dart';
import '../../offers/data/models/offer.dart';
import '../../offers/presentation/offer_labels.dart';
import '../../products/application/products_list_controller.dart';
import '../../products/application/products_query.dart';
import '../../products/presentation/product_card.dart';
import '../../wallet/application/wallet_controller.dart';
import '../application/merchant_branches_provider.dart';
import '../application/merchant_detail_provider.dart';
import '../data/models/merchant.dart';
import '../data/models/merchant_branch_ref.dart';
import 'category_visual.dart';
import 'favorite_button.dart';
import 'merchant_card.dart';
import 'merchant_logo.dart';

/// One merchant's page, following the Google Stitch redesign: a cover with
/// whether the shop is open, the profile card, the Town Coin saving with
/// the customer's balance, call / WhatsApp / directions, about, the shop's
/// running offers, its branches and products, and a pay bar.
///
/// Every figure is real: the merchant resource, `GET /merchants/{id}/branches`,
/// `GET /offers?merchant_id=`, the product catalog and the wallet. Stitch's
/// star rating, review count, verified tick, amenity chips, per-branch
/// opening hours, "Max benefit" and share button are absent on purpose:
/// the backend records none of them, and there is no share integration.
class MerchantDetailScreen extends ConsumerWidget {
  const MerchantDetailScreen({super.key, required this.merchantId});

  final int merchantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(merchantDetailProvider(merchantId));
    final merchant = detail.value;

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      bottomNavigationBar: merchant == null ? null : _PayBar(merchant: merchant),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(merchantId: merchantId, merchantName: merchant?.name),
            Expanded(
              child: detail.when(
                loading: () => const LoadingSkeletonList(count: 3),
                error: (error, _) => ErrorState(
                  error: error is AppException ? error : const UnknownAppException(),
                  onRetry: () => ref.invalidate(merchantDetailProvider(merchantId)),
                ),
                data: (merchant) => _MerchantDetailBody(merchant: merchant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.merchantId, required this.merchantName});

  final int merchantId;
  final String? merchantName;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final name = merchantName;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox.square(
            dimension: AppSpacing.touchTarget,
            child: canPop
                ? IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                    onPressed: () => Navigator.of(context).maybePop(),
                  )
                : null,
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                'Merchant Details',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.sectionTitle,
              ),
            ),
          ),
          SizedBox.square(
            dimension: AppSpacing.touchTarget,
            child: name == null ? null : FavoriteButton(merchantId: merchantId, merchantName: name),
          ),
        ],
      ),
    );
  }
}

class _MerchantDetailBody extends ConsumerWidget {
  const _MerchantDetailBody({required this.merchant});

  final Merchant merchant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Redeem eligibility mirrors RedemptionCalculator::calculate()'s own
    // gate exactly (accepts_town_coin + a positive discount_rate) — the
    // backend re-checks both regardless, this only avoids offering a CTA
    // that would just 422.
    final canRedeem = merchant.acceptsTownCoin && (merchant.discountRate ?? 0) > 0;
    final hasAbout =
        (merchant.description?.trim().isNotEmpty ?? false) ||
        (merchant.tagline?.trim().isNotEmpty ?? false) ||
        (merchant.websiteUrl?.trim().isNotEmpty ?? false);

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        _CoverAndProfile(merchant: merchant),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (canRedeem) ...[const SizedBox(height: AppSpacing.md), _RedeemBanner(merchant: merchant)],
              const SizedBox(height: AppSpacing.md),
              _QuickActions(merchant: merchant),
              if (hasAbout) ...[
                const SizedBox(height: AppSpacing.section),
                const _SectionLabel(label: 'ABOUT'),
                const SizedBox(height: AppSpacing.sm),
                _AboutCard(merchant: merchant),
              ],
              _OffersSection(merchantId: merchant.id),
              const SizedBox(height: AppSpacing.section),
              _BranchesSection(merchant: merchant),
              _ProductsSection(merchant: merchant),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _launch(BuildContext context, Uri uri) async {
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open this action on your device.')));
  }
}

String _percent(double value) => value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);

String _rupees(double amount) =>
    amount.truncateToDouble() == amount ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);

/// A small uppercase heading with a brand-orange dot, and an optional
/// trailing chip or link.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: AppColors.orangeDeep, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(label, style: AppTypography.sectionTitle.copyWith(letterSpacing: 0.8)),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// The shop's cover photo (or its category colours when it has none) with
/// the profile card overlapping its lower edge.
class _CoverAndProfile extends StatelessWidget {
  const _CoverAndProfile({required this.merchant});

  final Merchant merchant;

  static const _coverHeight = 200.0;
  static const _overlap = 56.0;

  @override
  Widget build(BuildContext context) {
    final category = merchant.category;
    final visual = category == null
        ? CategoryVisual.fallback
        : CategoryVisual.forCategory(name: category.name, slug: category.slug);
    final coverUrl = merchant.coverImageUrl;
    final status = merchant.businessHours?.statusAt(DateTime.now());
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.warmWash),
      child: Center(
        child: Icon(visual.icon, size: AppIconSize.hero * 1.5, color: visual.color.withValues(alpha: 0.25)),
      ),
    );

    return Stack(
      children: [
        SizedBox(
          height: _coverHeight,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (coverUrl == null)
                fallback
              else
                Image.network(
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.scrim.withValues(alpha: 0.25),
                      AppColors.scrim.withValues(alpha: 0),
                      AppColors.surfaceMuted,
                    ],
                    stops: const [0, 0.5, 1],
                  ),
                ),
              ),
              if (status != null)
                Positioned(
                  top: AppSpacing.smd,
                  right: AppSpacing.page,
                  child: _StatusPill(isOpen: status.isOpen, label: status.label),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, _coverHeight - _overlap, AppSpacing.page, 0),
          child: _ProfileCard(merchant: merchant),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isOpen, required this.label});

  final bool isOpen;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isOpen ? AppColors.success : AppColors.silverDark,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        boxShadow: AppElevation.card,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd, vertical: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(color: AppColors.onCrimson, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(label, style: AppTypography.badgeLabel.copyWith(color: AppColors.onCrimson)),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.merchant});

  final Merchant merchant;

  @override
  Widget build(BuildContext context) {
    final locationLine = [
      merchant.branch?.locality,
      merchant.town?.name,
      merchant.town?.stateRegion,
    ].whereType<String>().where((p) => p.trim().isNotEmpty).join(', ');
    final subtitle = [
      merchant.category?.name,
      merchant.tagline,
    ].whereType<String>().where((p) => p.trim().isNotEmpty).join(' · ');
    final association = merchant.association;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.floating,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.orangeBorder),
                    boxShadow: AppElevation.card,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                    child: MerchantLogo(url: merchant.logoUrl, merchantName: merchant.name, size: AppSize.avatarLg),
                  ),
                ),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        merchant.name,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.caption),
                      ],
                      if (locationLine.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(
                                Icons.location_on_outlined,
                                size: AppIconSize.sm,
                                color: AppColors.orangeDeep,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xxs),
                            Expanded(
                              child: Text(
                                locationLine,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (merchant.acceptsTownCoin || association != null) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.smd),
                child: Divider(height: 1, color: AppColors.border),
              ),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (merchant.acceptsTownCoin)
                    const _Chip(
                      icon: Icons.savings_rounded,
                      label: 'Accepts Town Coin',
                      background: AppColors.successBg,
                      foreground: AppColors.success,
                    ),
                  if (association != null)
                    _Chip(
                      icon: Icons.groups_rounded,
                      label: association.name,
                      background: AppColors.orangeTint,
                      foreground: AppColors.orangeDeep,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.background, required this.foreground});

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: foreground.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd, vertical: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppIconSize.sm, color: foreground),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.badgeLabel.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The page's one primary action. The rate is the merchant's own configured
/// discount_rate, the same figure RedemptionCalculator applies — not a
/// marketing estimate — and the balance is the customer's live wallet.
class _RedeemBanner extends ConsumerWidget {
  const _RedeemBanner({required this.merchant});

  final Merchant merchant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rate = _percent(merchant.discountRate!);
    final wallet = ref.watch(walletControllerProvider).value;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGradients.warmWash,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.orangeBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.orangeTintStrong,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                          child: Text(
                            'SAVE WITH TOWN COIN',
                            style: AppTypography.overline.copyWith(color: AppColors.orangeDeep),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Save $rate% when you pay with Town Coin here.',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  width: AppSize.controlSm,
                  height: AppSize.controlSm,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                    border: Border.all(color: AppColors.orangeBorder),
                  ),
                  child: const Icon(Icons.toll_rounded, color: AppColors.orangeDeep, size: AppIconSize.md),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Redeem Town Coin',
              size: AppButtonSize.lg,
              icon: Icons.savings_rounded,
              trailingIcon: Icons.arrow_forward_rounded,
              onPressed: () => context.push('/merchants/${merchant.id}/redeem'),
            ),
            if (wallet != null) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.smd),
                child: Divider(height: 1, color: AppColors.orangeBorder),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Your balance: '),
                    TextSpan(
                      text: '${wallet.balance} coins (₹${_rupees(wallet.balanceInrEquivalent)})',
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                style: AppTypography.caption,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Call, WhatsApp and directions. Each tile is live only when the data
/// behind it exists: a dialable published number, and a branch with map
/// coordinates.
class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.merchant});

  final Merchant merchant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = dialableIndianMobile(merchant.contactMobileNumber);
    final branches = ref.watch(merchantBranchesProvider(merchant.id)).value ?? const <MerchantBranchRef>[];
    final located = [
      ...branches.where((b) => b.isPrimary),
      ...branches.where((b) => !b.isPrimary),
      ?merchant.branch,
    ].where((b) => b.latitude != null && b.longitude != null).firstOrNull;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ActionTile(
              icon: Icons.phone_rounded,
              tint: AppColors.orangeDeep,
              label: 'Call store',
              hint: phone == null ? 'No number listed' : 'Tap to call',
              onTap: phone == null ? null : () => _launch(context, Uri.parse('tel:+91$phone')),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _ActionTile(
              icon: Icons.chat_rounded,
              tint: AppColors.success,
              label: 'WhatsApp',
              hint: phone == null ? 'No number listed' : 'Message the shop',
              onTap: phone == null ? null : () => _launch(context, Uri.parse('https://wa.me/91$phone')),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _ActionTile(
              icon: Icons.map_outlined,
              tint: AppColors.info,
              label: 'Directions',
              hint: located == null ? 'No location yet' : 'Open in Maps',
              onTap: located == null
                  ? null
                  : () => _launch(
                      context,
                      Uri.parse(
                        'https://www.google.com/maps/search/?api=1&query=${located.latitude},${located.longitude}',
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.tint,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String label;
  final String hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = enabled ? tint : AppColors.textDisabled;
    final radius = BorderRadius.circular(AppSpacing.radiusMd);

    return Semantics(
      button: enabled,
      enabled: enabled,
      label: '$label, $hint',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.smd),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: AppSize.controlSm,
                  height: AppSize.controlSm,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Icon(icon, color: color, size: AppIconSize.md),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  hint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption,
                ),
              ],
            ),
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
    final visual = category != null
        ? CategoryVisual.forCategory(name: category.name, slug: category.slug)
        : CategoryVisual.fallback;
    final description = merchant.description?.trim();
    final tagline = merchant.tagline?.trim();
    final website = merchant.websiteUrl?.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: AppSize.avatarMd,
                  height: AppSize.avatarMd,
                  decoration: BoxDecoration(
                    color: visual.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                  ),
                  child: Icon(visual.icon, color: visual.color, size: AppIconSize.md),
                ),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category?.name ?? merchant.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (tagline != null && tagline.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(tagline, style: AppTypography.caption.copyWith(fontStyle: FontStyle.italic)),
                      ],
                      if (description != null && description.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(description, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (website != null && website.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.smd),
                child: Divider(height: 1, color: AppColors.border),
              ),
              Semantics(
                button: true,
                label: 'Website, $website',
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  onTap: () {
                    final uri = Uri.tryParse(website);
                    if (uri != null) _launch(context, uri);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        const Icon(Icons.public_rounded, size: AppIconSize.md, color: AppColors.info),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            website,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.info),
                          ),
                        ),
                        const Icon(Icons.open_in_new_rounded, size: AppIconSize.sm, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// This shop's running offers. Hidden while loading, on error, or when the
/// shop has none -- an optional section, not a core one.
class _OffersSection extends ConsumerWidget {
  const _OffersSection({required this.merchantId});

  final int merchantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(merchantOffersProvider(merchantId)).value;
    if (offers == null || offers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.section),
        _SectionLabel(
          label: 'OFFERS',
          trailing: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.orangeTint,
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              border: Border.all(color: AppColors.orangeBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
              child: Text(
                '${offers.length} available',
                style: AppTypography.badgeLabel.copyWith(color: AppColors.orangeDeep),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < offers.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _OfferRow(offer: offers[i], alternate: i.isOdd),
        ],
      ],
    );
  }
}

class _OfferRow extends StatelessWidget {
  const _OfferRow({required this.offer, required this.alternate});

  final Offer offer;
  final bool alternate;

  @override
  Widget build(BuildContext context) {
    final discount = offerDiscountLabel(offer);
    final detail = offer.applicableItem ?? offer.description;
    final badgeColor = alternate ? AppColors.crimson : AppColors.orangeDeep;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        gradient: LinearGradient(colors: [badgeColor.withValues(alpha: 0.06), AppColors.surface]),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.smd),
        child: Row(
          children: [
            Container(
              width: AppSize.controlLg,
              height: AppSize.controlLg,
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  discount?.replaceAll(' OFF', '\nOFF') ?? 'DEAL',
                  textAlign: TextAlign.center,
                  style: AppTypography.badgeLabel.copyWith(color: AppColors.onCrimson, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.smd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (detail != null && detail.trim().isNotEmpty)
                    Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: AppIconSize.xs, color: AppColors.pending),
                      const SizedBox(width: AppSpacing.xxs),
                      Flexible(
                        child: Text(
                          offerEndsInLabel(offer.endsAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(color: AppColors.pending, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Only a coin-redeemable offer has a claim flow to open.
            if (offer.isCoinRedeemable) ...[
              const SizedBox(width: AppSpacing.sm),
              Material(
                color: AppColors.orangeDeep,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusControl)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                  onTap: () => context.push('/offers/${offer.id}/redeem'),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: AppSize.controlSm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          'Claim',
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(color: AppColors.onCrimson, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Every active branch (`GET /merchants/{id}/branches`), numbered, primary
/// first. A failure here doesn't block the rest of the profile but shows a
/// retry, since branch data matters for finding the shop.
class _BranchesSection extends ConsumerWidget {
  const _BranchesSection({required this.merchant});

  final Merchant merchant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(merchantBranchesProvider(merchant.id));
    final count = branches.value?.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(label: count > 1 ? 'BRANCH LOCATIONS' : 'BRANCH LOCATION'),
        const SizedBox(height: AppSpacing.sm),
        branches.when(
          loading: () => const LoadingSkeletonCard(),
          error: (error, _) => ErrorState(
            error: error is AppException ? error : const UnknownAppException(),
            compact: true,
            onRetry: () => ref.invalidate(merchantBranchesProvider(merchant.id)),
          ),
          data: (data) {
            if (data.isEmpty) {
              return Text('This merchant has not published a branch location yet.', style: AppTypography.caption);
            }

            final ordered = [...data.where((b) => b.isPrimary), ...data.where((b) => !b.isPrimary)];
            return Column(
              children: [
                for (var i = 0; i < ordered.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  _BranchCard(branch: ordered[i], number: i + 1, showPrimary: ordered.length > 1),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({required this.branch, required this.number, required this.showPrimary});

  final MerchantBranchRef branch;
  final int number;
  final bool showPrimary;

  @override
  Widget build(BuildContext context) {
    final address = branch.formattedAddress;
    final hasCoordinates = branch.latitude != null && branch.longitude != null;
    final highlighted = branch.isPrimary;
    final distance = branch.distanceKm;
    final radius = BorderRadius.circular(AppSpacing.radiusMd);

    return Semantics(
      button: hasCoordinates,
      label: [
        if (showPrimary && branch.isPrimary) 'Primary branch',
        branch.name ?? 'Branch',
        if (address.isNotEmpty) address,
        if (hasCoordinates) 'opens directions',
      ].join(', '),
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: highlighted ? AppColors.orangeBorder : AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: hasCoordinates
              ? () => _launch(
                  context,
                  Uri.parse('https://www.google.com/maps/search/?api=1&query=${branch.latitude},${branch.longitude}'),
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.smd),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: AppSize.avatarSm,
                  height: AppSize.avatarSm,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: highlighted ? AppColors.orangeTint : AppColors.silverLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: highlighted ? AppColors.orangeBorder : AppColors.border),
                  ),
                  child: Text(
                    '$number',
                    style: AppTypography.badgeLabel.copyWith(
                      color: highlighted ? AppColors.orangeDeep : AppColors.silverDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xxs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            branch.name ?? 'Branch',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (showPrimary && branch.isPrimary)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.orangeTint,
                                borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                                border: Border.all(color: AppColors.orangeBorder),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs + AppSpacing.xxs),
                                child: Text(
                                  'Primary',
                                  style: AppTypography.badgeLabel.copyWith(color: AppColors.orangeDeep),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(address, style: AppTypography.caption),
                      ],
                      if (distance != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${distance < 1 ? '${(distance * 1000).round()} m' : '${distance.toStringAsFixed(1)} km'} away',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (hasCoordinates) ...[
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(Icons.directions_rounded, color: AppColors.orangeDeep, size: AppIconSize.md),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A preview of this merchant's product catalog -- up to the first page,
/// same "a failure here doesn't block the rest of the profile" policy as
/// [_BranchesSection]. Collapses to nothing (not an empty-state) when the
/// merchant simply has no products yet, since this is an optional
/// enhancement to the profile, not a core section every merchant needs.
class _ProductsSection extends ConsumerWidget {
  const _ProductsSection({required this.merchant});

  final Merchant merchant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsListControllerProvider(ProductsQuery(merchantId: merchant.id))).value;
    if (products == null || products.items.isEmpty) return const SizedBox.shrink();

    final preview = products.items.take(4).toList();
    final hasMore = products.items.length > preview.length || products.hasMore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.section),
        _SectionLabel(
          label: 'PRODUCTS',
          trailing: hasMore
              ? TextButton(
                  onPressed: () => context.push('/shopping', extra: (merchant.id, merchant.name)),
                  style: TextButton.styleFrom(foregroundColor: AppColors.orangeDeep),
                  child: const Text('See all'),
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.smd,
            crossAxisSpacing: AppSpacing.smd,
            childAspectRatio: 0.58,
          ),
          itemCount: preview.length,
          itemBuilder: (context, index) {
            final product = preview[index];
            return ProductCard(
              product: product,
              showMerchantName: false,
              onTap: () => context.push('/products/${product.id}'),
            );
          },
        ),
      ],
    );
  }
}

/// The pinned bottom bar: scan the counter QR, or pay with coins here.
class _PayBar extends StatelessWidget {
  const _PayBar({required this.merchant});

  final Merchant merchant;

  @override
  Widget build(BuildContext context) {
    final rate = merchant.discountRate;
    final canRedeem = merchant.acceptsTownCoin && rate != null && rate > 0;
    final radius = BorderRadius.circular(AppSpacing.radiusMd);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.smd, AppSpacing.page, AppSpacing.smd),
          child: Row(
            children: [
              Material(
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: radius,
                  side: const BorderSide(color: AppColors.border),
                ),
                child: IconButton(
                  tooltip: 'Scan the shop QR',
                  icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.textPrimary),
                  onPressed: () => context.push('/purchases/scan'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Semantics(
                  button: true,
                  label: canRedeem ? 'Pay bill with coins, save ${_percent(rate)} percent' : 'Scan QR to pay',
                  excludeSemantics: true,
                  child: DecoratedBox(
                    decoration: BoxDecoration(borderRadius: radius, boxShadow: AppElevation.floating),
                    child: Material(
                      borderRadius: radius,
                      clipBehavior: Clip.antiAlias,
                      child: Ink(
                        decoration: const BoxDecoration(gradient: AppGradients.promoHero),
                        child: InkWell(
                          onTap: () => context.push(canRedeem ? '/merchants/${merchant.id}/redeem' : '/purchases/scan'),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                              child: Row(
                                children: [
                                  const Icon(Icons.account_balance_wallet_rounded, color: AppColors.onCrimson),
                                  const SizedBox(width: AppSpacing.sm),
                                  // Two parts of the width to the label, one to
                                  // the chip, so both fit at normal text sizes
                                  // and both give way at large ones.
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      canRedeem ? 'Pay bill with coins' : 'Scan QR to pay',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                        color: AppColors.onCrimson,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (canRedeem) ...[
                                    const SizedBox(width: AppSpacing.xs),
                                    // Shrinks with the label at large text
                                    // scales instead of pushing the row wide.
                                    Flexible(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.sm,
                                            vertical: AppSpacing.xxs,
                                          ),
                                          child: Text(
                                            'Save ${_percent(rate)}%',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.badgeLabel.copyWith(color: AppColors.orangeDeep),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
