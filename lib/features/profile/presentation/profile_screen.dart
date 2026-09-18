import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_mode/app_mode.dart';
import '../../../core/app_mode/app_mode_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../auth/data/models/account.dart';
import '../../business/presentation/business_routes.dart';
import '../../coupons/application/coupons_list_controller.dart';
import '../../wallet/application/wallet_controller.dart';

/// The Profile tab, following the Google Stitch redesign: a warm profile
/// card, the customer's coins and coupons, their activity, business access,
/// account status, a nudge to shop locally, and sign out.
///
/// Stitch's VIP tier, avatar upload, "Verified" chip and Help & Support row
/// are absent on purpose: the backend has no tiers, avatars, verification
/// or support channel, and "24/7 assistance" would be an unbacked promise.
/// The Business section and Sign out are not in Stitch but stay, since
/// removing them would strand merchants and signed-in customers.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final account = authState is AuthAuthenticated ? authState.account : null;
    final isLoggingOut = authState is AuthAuthenticated && authState.isLoggingOut;

    if (account == null) {
      // Only reachable for the frame(s) while the session is still resolving
      // (the router redirects away otherwise) -- a skeleton, never a blank
      // screen.
      return const Scaffold(
        backgroundColor: AppColors.surfaceMuted,
        body: SafeArea(child: LoadingSkeletonList(count: 4)),
      );
    }

    final status = account.customerProfile?.status ?? account.status;
    final hasReferralCode = account.customerProfile?.referralCode != null;

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(couponCountsProvider);
            await ref.read(walletControllerProvider.notifier).refresh();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.xxl * 2),
            children: [
              const _TopBar(),
              const SizedBox(height: AppSpacing.md),
              _ProfileCard(account: account, status: status),
              const SizedBox(height: AppSpacing.md),
              const _RewardsCard(),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'My Activity', subtitle: 'Track your shopping, rewards and more'),
              const SizedBox(height: AppSpacing.smd),
              _LinkGroup(
                children: [
                  _LinkRow(
                    icon: Icons.receipt_long_rounded,
                    tint: AppColors.orangeDeep,
                    title: 'Purchases',
                    subtitle: 'Bills recorded at participating merchants',
                    onTap: () => context.push('/purchases'),
                  ),
                  _LinkRow(
                    icon: Icons.qr_code_2_rounded,
                    tint: AppColors.goldDark,
                    title: 'Redemptions',
                    subtitle: 'Town Coins you have spent',
                    onTap: () => context.push('/redemptions'),
                  ),
                  if (hasReferralCode)
                    _LinkRow(
                      icon: Icons.card_giftcard_rounded,
                      tint: AppColors.decorativeAccents[2],
                      title: 'Referrals',
                      subtitle: 'Invite friends with your code',
                      badge: 'Earn coins',
                      onTap: () => context.push('/referrals'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Business', subtitle: 'Run your shop on Town Shoppy'),
              const SizedBox(height: AppSpacing.smd),
              _LinkGroup(
                children: [
                  if (account.hasMerchantAccess)
                    _LinkRow(
                      icon: Icons.storefront_rounded,
                      tint: AppColors.businessInk,
                      title: 'Switch to Business app',
                      subtitle: 'Counter, offers, redemptions and your shop profile',
                      onTap: () async {
                        await ref.read(appModeControllerProvider.notifier).select(AppMode.business);
                        if (context.mounted) context.go(BusinessRoutes.root);
                      },
                    )
                  else
                    _LinkRow(
                      icon: Icons.storefront_outlined,
                      tint: AppColors.businessInk,
                      title: 'Register your business',
                      subtitle: 'Join Town Shoppy as a merchant',
                      onTap: () => context.push('/register-merchant'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(title: 'Account', subtitle: 'Your details and account status'),
              const SizedBox(height: AppSpacing.smd),
              _LinkGroup(
                children: [
                  _StatusRow(status: status),
                  _LinkRow(
                    icon: Icons.settings_outlined,
                    tint: AppColors.silverDark,
                    title: 'Edit profile',
                    subtitle: 'Update your name, dates and social links',
                    onTap: () => context.push('/profile/edit'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.section),
              const _ShopLocalBanner(),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Sign out',
                variant: AppButtonVariant.secondary,
                isLoading: isLoggingOut,
                onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                icon: Icons.logout_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _humanize(String status) {
  final words = status.replaceAll('_', ' ');
  return words.isEmpty ? words : words[0].toUpperCase() + words.substring(1);
}

String _initials(String? name, String mobile) {
  if (name != null && name.trim().isNotEmpty) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
  return mobile.isNotEmpty ? mobile.substring(mobile.length - 2) : '?';
}

/// "+91 99900 03001" for an Indian number, stored with or without the
/// country code; anything else is shown as stored.
String _formatMobile(String mobile) {
  final digits = mobile.replaceAll(RegExp(r'[^0-9]'), '');
  final local = digits.length == 12 && digits.startsWith('91') ? digits.substring(2) : digits;
  if (local.length != 10) return mobile;
  return '+91 ${local.substring(0, 5)} ${local.substring(5)}';
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.goldLight,
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd, vertical: AppSpacing.xs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        'Shop Local. Win Local.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.badgeLabel.copyWith(color: AppColors.goldDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Material(
          color: AppColors.surface,
          shape: const CircleBorder(side: BorderSide(color: AppColors.orangeBorder)),
          child: IconButton(
            tooltip: 'Edit profile',
            icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
            onPressed: () => context.push('/profile/edit'),
          ),
        ),
      ],
    );
  }
}

/// The warm hero card. Its ground runs from the business maroon to the
/// deep brand orange, both dark enough for white text at AA.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.account, required this.status});

  final Account account;
  final String status;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusLg);
    final isActive = status == 'active';
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.businessInk, AppColors.orangeDeep],
        ),
        boxShadow: AppElevation.floating,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              right: -AppSpacing.lg,
              top: -AppSpacing.lg,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(color: AppColors.yellow.withValues(alpha: 0.12), shape: BoxShape.circle),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                'My Profile',
                                style: AppTypography.greeting.copyWith(color: AppColors.onScrim),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              'Manage your account and activity',
                              style: AppTypography.caption.copyWith(color: AppColors.onScrimMuted),
                            ),
                          ],
                        ),
                      ),
                      if (account.isCustomer) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.goldLight,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                              child: Text(
                                'Town Member',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.badgeLabel.copyWith(color: AppColors.goldDark),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.smd),
                    child: Divider(height: 1, color: AppColors.onScrim.withValues(alpha: 0.18)),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    onTap: () => context.push('/profile/edit'),
                    child: Row(
                      children: [
                        Container(
                          width: AppSize.avatarLg + AppSpacing.sm,
                          height: AppSize.avatarLg + AppSpacing.sm,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: AppGradients.warmWash,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.goldLight, width: 2),
                          ),
                          child: Text(
                            _initials(account.customerProfile?.name, account.mobileNumber),
                            style: textTheme.titleLarge?.copyWith(
                              color: AppColors.orangeDeep,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.smd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.displayName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleLarge?.copyWith(
                                  color: AppColors.onScrim,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                _formatMobile(account.mobileNumber),
                                style: textTheme.bodySmall?.copyWith(color: AppColors.onScrimMuted),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.onScrim.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                                  border: Border.all(color: AppColors.onScrim.withValues(alpha: 0.25)),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: AppSpacing.xxs,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: isActive ? AppColors.successBg : AppColors.pendingBg,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Flexible(
                                        child: Text(
                                          isActive ? 'Active member' : _humanize(status),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.badgeLabel.copyWith(color: AppColors.onScrim),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: AppColors.onScrim.withValues(alpha: 0.7)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Town Coins and active coupons side by side, each with its way in.
class _RewardsCard extends ConsumerWidget {
  const _RewardsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletControllerProvider);
    final coupons = ref.watch(couponCountsProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.orangeBorder),
        boxShadow: AppElevation.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.smd),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _RewardHalf(
                  icon: Icons.toll_rounded,
                  tint: AppColors.gold,
                  title: 'Town Coins',
                  value: switch (wallet) {
                    AsyncData(:final value) => '${value.balance}',
                    AsyncError() => '—',
                    _ => null,
                  },
                  unit: 'coins',
                  unitColor: AppColors.goldDark,
                  actionLabel: 'View wallet',
                  actionBackground: AppColors.goldLight,
                  actionForeground: AppColors.goldDark,
                  onTap: () => context.push('/wallet'),
                ),
              ),
              const VerticalDivider(width: AppSpacing.lg, color: AppColors.border),
              Expanded(
                child: _RewardHalf(
                  icon: Icons.confirmation_number_rounded,
                  tint: AppColors.decorativeAccents[2],
                  title: 'Coupons',
                  value: switch (coupons) {
                    AsyncData(:final value) => '${value.active}',
                    AsyncError() => '—',
                    _ => null,
                  },
                  unit: 'active',
                  unitColor: AppColors.error,
                  actionLabel: 'View coupons',
                  actionBackground: AppColors.errorBg,
                  actionForeground: AppColors.error,
                  onTap: () => context.go('/coupons'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardHalf extends StatelessWidget {
  const _RewardHalf({
    required this.icon,
    required this.tint,
    required this.title,
    required this.value,
    required this.unit,
    required this.unitColor,
    required this.actionLabel,
    required this.actionBackground,
    required this.actionForeground,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String? value;
  final String unit;
  final Color unitColor;
  final String actionLabel;
  final Color actionBackground;
  final Color actionForeground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shown = value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: AppIconSize.lg,
              height: AppIconSize.lg,
              decoration: BoxDecoration(color: tint.withValues(alpha: 0.14), shape: BoxShape.circle),
              child: Icon(icon, size: AppIconSize.sm, color: tint),
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (shown == null)
          const LoadingSkeleton(width: 56, height: 24)
        else
          Semantics(
            label: '$title: $shown $unit',
            excludeSemantics: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(shown, style: AppTypography.numericFinancialMedium.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    unit,
                    style: AppTypography.caption.copyWith(color: unitColor, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        const Spacer(),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          button: true,
          label: actionLabel,
          excludeSemantics: true,
          child: Material(
            color: actionBackground,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSize.controlSm - AppSpacing.xs),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          actionLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.badgeLabel.copyWith(color: actionForeground),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: AppIconSize.sm, color: actionForeground),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A white card holding rows separated by hairlines.
class _LinkGroup extends StatelessWidget {
  const _LinkGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusMd);

    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: AppElevation.card),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                const Divider(height: 1, indent: AppSpacing.md, endIndent: AppSpacing.md, color: AppColors.border),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _RowIcon extends StatelessWidget {
  const _RowIcon({required this.icon, required this.tint});

  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSize.avatarMd,
      height: AppSize.avatarMd,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
        border: Border.all(color: tint.withValues(alpha: 0.16)),
      ),
      child: Icon(icon, color: tint, size: AppIconSize.md),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shownBadge = badge;

    return Semantics(
      button: true,
      label: '$title, $subtitle',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.smd),
            child: Row(
              children: [
                _RowIcon(icon: icon, tint: tint),
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
                            title,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (shownBadge != null)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.errorBg,
                                borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs + AppSpacing.xxs,
                                  vertical: 1,
                                ),
                                child: Text(shownBadge, style: AppTypography.overline.copyWith(color: AppColors.error)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.caption),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: AppIconSize.md),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'active';
    final (Color background, Color foreground) = isActive
        ? (AppColors.successBg, AppColors.success)
        : (AppColors.pendingBg, AppColors.pending);

    return Semantics(
      label: isActive ? 'Account status: active' : 'Account status: ${_humanize(status)}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.smd),
        child: Row(
          children: [
            _RowIcon(icon: isActive ? Icons.verified_user_outlined : Icons.hourglass_top_rounded, tint: foreground),
            const SizedBox(width: AppSpacing.smd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account status',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    isActive
                        ? 'Active — earn and redeem Town Coin'
                        : 'Some features may be unavailable until this changes',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              flex: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppSpacing.radiusXs)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                  child: Text(
                    isActive ? 'Active' : _humanize(status),
                    style: AppTypography.badgeLabel.copyWith(color: foreground),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A closing nudge toward the shops themselves.
class _ShopLocalBanner extends StatelessWidget {
  const _ShopLocalBanner();

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusLg);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(colors: [AppColors.businessInk, AppColors.orangeDeep]),
        boxShadow: AppElevation.floating,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(
              right: -AppSpacing.sm,
              bottom: -AppSpacing.md,
              child: Icon(Icons.shopping_bag_rounded, size: 110, color: AppColors.onScrim.withValues(alpha: 0.1)),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storefront_rounded, size: AppIconSize.md, color: AppColors.yellow),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          'Shop at local stores',
                          style: Theme.of(
                            context,
                          ).textTheme.titleSmall?.copyWith(color: AppColors.onScrim, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Earn Town Coins · Unlock offers · Support local shops',
                    style: AppTypography.caption.copyWith(color: AppColors.onScrimMuted),
                  ),
                  const SizedBox(height: AppSpacing.smd),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.onScrim.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd, vertical: AppSpacing.xs),
                          child: Text(
                            'Local shops, stronger communities',
                            style: AppTypography.badgeLabel.copyWith(color: AppColors.onScrim),
                          ),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Explore shops',
                        excludeSemantics: true,
                        child: Material(
                          color: AppColors.surface,
                          shape: const StadiumBorder(),
                          child: InkWell(
                            customBorder: const StadiumBorder(),
                            onTap: () => context.push('/merchants'),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: AppSize.controlSm),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Explore',
                                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                        color: AppColors.orangeDeep,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: AppIconSize.sm,
                                      color: AppColors.orangeDeep,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
