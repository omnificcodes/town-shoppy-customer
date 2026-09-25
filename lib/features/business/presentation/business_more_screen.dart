import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_mode/app_mode.dart';
import '../../../core/app_mode/app_mode_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../merchants/presentation/merchant_logo.dart';
import '../../notifications/application/unread_count_provider.dart';
import '../application/business_context.dart';
import 'business_routes.dart';
import 'widgets/business_page_header.dart';

/// The full merchant menu, following the Google Stitch redesign -- every
/// destination the web sidebar has, in the same groups, with the same
/// Owner/Staff visibility and the same lock icon on package-gated entries.
/// Also where an owner switches back to the Customer app and signs out.
class BusinessMoreScreen extends ConsumerWidget {
  const BusinessMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final account = auth is AuthAuthenticated ? auth.account : null;
    final isLoggingOut = auth is AuthAuthenticated && auth.isLoggingOut;
    final isOwner = ref.watch(isBusinessOwnerProvider);
    final hasPackage = ref.watch(merchantEntitlementProvider).value?.hasPackage ?? true;
    final pendingPurchases = ref.watch(dashboardPendingPurchasesCountProvider).value ?? 0;
    final offerPage = ref.watch(dashboardPendingOfferRedemptionsProvider).value;
    final pendingOffers = offerPage?.items.length ?? 0;
    final morePendingOffers = offerPage?.hasMore ?? false;

    final visible = BusinessDestination.all.where((d) => d.path != BusinessRoutes.root && (isOwner || !d.ownerOnly));

    Future<void> switchToCustomer() async {
      await ref.read(appModeControllerProvider.notifier).select(AppMode.customer);
      if (context.mounted) context.go('/home');
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Hero(isOwner: isOwner, mobileNumber: account?.mobileNumber, onSwitch: switchToCustomer),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.lg,
              AppSpacing.page,
              AppSpacing.xxl + AppSize.fab,
            ),
            sliver: SliverList.list(
              children: [
                for (final group in BusinessDestination.groupOrder)
                  if (visible.any((d) => d.group == group)) ...[
                    _GroupLabel(title: group, trailing: _servicesLabel(visible.where((d) => d.group == group).length)),
                    _MenuCard(
                      children: [
                        for (final d in visible.where((d) => d.group == group))
                          _MenuRow(
                            icon: d.icon,
                            title: d.label,
                            subtitle: d.subtitle,
                            locked: d.gated && !hasPackage,
                            badge: d.gated && !hasPackage
                                ? null
                                : d.path == BusinessRoutes.purchases && pendingPurchases > 0
                                ? '$pendingPurchases pending'
                                : d.path == BusinessRoutes.offerRedemptions && pendingOffers > 0
                                ? '$pendingOffers${morePendingOffers ? '+' : ''} pending'
                                : null,
                            onTap: () =>
                                BusinessRoutes.tabs.contains(d.path) ? context.go(d.path) : context.push(d.path),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.section),
                  ],
                const _GroupLabel(title: 'Support & settings'),
                _MenuCard(
                  compact: true,
                  children: [
                    _SettingsRow(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & merchant support',
                      onTap: () => ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('Support contact is coming soon.'))),
                    ),
                    _SettingsRow(
                      icon: isLoggingOut ? Icons.hourglass_top_rounded : Icons.logout_rounded,
                      title: isLoggingOut ? 'Signing out…' : 'Sign out',
                      destructive: true,
                      // Always tappable so the row keeps its InkWell padding;
                      // the guard is inside AuthController.logout anyway.
                      onTap: () {
                        if (!isLoggingOut) ref.read(authControllerProvider.notifier).logout();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _servicesLabel(int count) => count == 1 ? '1 service' : '$count services';
}

/// "+91 66666 44444" for an Indian mobile; anything else is shown as stored.
String _formatMobile(String mobile) {
  final digits = mobile.replaceAll(RegExp(r'[^0-9]'), '');
  final local = digits.length == 12 && digits.startsWith('91') ? digits.substring(2) : digits;
  if (local.length != 10) return mobile;
  return '+91 ${local.substring(0, 5)} ${local.substring(5)}';
}

/// The deep espresso header: Business chip, notifications, the title with
/// the business name and role, and the signed-in card with Switch.
class _Hero extends ConsumerWidget {
  const _Hero({required this.isOwner, required this.mobileNumber, required this.onSwitch});

  final bool isOwner;
  final String? mobileNumber;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchant = ref.watch(myMerchantProvider).value;
    final unread = ref.watch(unreadNotificationCountProvider).value ?? 0;
    final textTheme = Theme.of(context).textTheme;
    final mobile = mobileNumber;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.businessInk, AppColors.businessInkDeep],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -AppSpacing.xxl,
            top: -AppSpacing.xxl,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.12), shape: BoxShape.circle),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const BusinessModeChip(),
                      const Spacer(),
                      _BellButton(unread: unread),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    header: true,
                    child: Text(
                      'More',
                      style: textTheme.headlineMedium?.copyWith(
                        color: AppColors.onBusinessInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (merchant != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: merchant.name,
                            style: const TextStyle(color: AppColors.onBusinessInk, fontWeight: FontWeight.w600),
                          ),
                          const TextSpan(text: '  ·  '),
                          TextSpan(text: isOwner ? 'Owner' : 'Staff'),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(color: AppColors.onBusinessInkMuted),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.onBusinessInk.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      border: Border.all(color: AppColors.onBusinessInk.withValues(alpha: 0.15)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.smd),
                      child: Row(
                        children: [
                          _StoreAvatar(logoUrl: merchant?.logoUrl, name: merchant?.name),
                          const SizedBox(width: AppSpacing.smd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SIGNED IN AS',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.overline.copyWith(
                                    color: AppColors.onBusinessInkMuted,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    mobile == null ? '—' : _formatMobile(mobile),
                                    style: AppTypography.numericFinancialInline.copyWith(
                                      color: AppColors.onBusinessInk,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Tooltip(
                            message: 'Switch to Customer app',
                            child: Material(
                              color: AppColors.onBusinessInk.withValues(alpha: 0.12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                                side: BorderSide(color: AppColors.onBusinessInk.withValues(alpha: 0.15)),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                                onTap: onSwitch,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(minHeight: AppSize.controlSm),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd),
                                    child: Center(
                                      widthFactor: 1,
                                      child: Text(
                                        'Switch',
                                        style: textTheme.labelLarge?.copyWith(
                                          color: AppColors.onBusinessInk,
                                          fontWeight: FontWeight.w700,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The business logo when there is one, otherwise an orange store tile.
class _StoreAvatar extends StatelessWidget {
  const _StoreAvatar({required this.logoUrl, required this.name});

  final String? logoUrl;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final url = logoUrl;
    final merchantName = name;
    final radius = BorderRadius.circular(AppSpacing.radiusMd);

    if (url != null && url.isNotEmpty && merchantName != null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: radius),
        child: MerchantLogo(url: url, merchantName: merchantName, size: AppSize.avatarMd),
      );
    }
    return Container(
      width: AppSize.avatarMd + AppSpacing.xs,
      height: AppSize.avatarMd + AppSpacing.xs,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [AppColors.orangeDeep, AppColors.orange],
        ),
        borderRadius: radius,
        border: Border.all(color: AppColors.onBusinessInk.withValues(alpha: 0.25)),
      ),
      child: const Icon(Icons.storefront_rounded, color: AppColors.onCrimson, size: AppIconSize.lg),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
      child: Material(
        color: AppColors.onBusinessInk.withValues(alpha: 0.12),
        shape: CircleBorder(side: BorderSide(color: AppColors.onBusinessInk.withValues(alpha: 0.15))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => context.push(BusinessRoutes.notifications),
          child: SizedBox.square(
            dimension: AppSpacing.touchTarget,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.notifications_outlined, color: AppColors.onBusinessInk, size: AppIconSize.lg),
                if (unread > 0)
                  Positioned(
                    top: AppSpacing.smd,
                    right: AppSpacing.smd,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.businessInk, width: 2),
                      ),
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

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final shownTrailing = trailing;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xs, 0, AppSpacing.xs, AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title.toUpperCase(),
                style: AppTypography.overline.copyWith(color: AppColors.textSecondary, letterSpacing: 1.2),
              ),
            ),
          ),
          if (shownTrailing != null) Text(shownTrailing, style: AppTypography.caption),
        ],
      ),
    );
  }
}

/// A white rounded card whose rows are split by hairlines.
class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children, this.compact = false});

  final List<Widget> children;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(compact ? AppSpacing.radiusLg : AppSpacing.xl);

    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: AppElevation.card),
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: AppColors.border),
        ),
        child: Column(
          children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.border),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.locked,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool locked;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final shownSubtitle = subtitle;
    final shownBadge = badge;

    return Semantics(
      button: true,
      label: [title, ?shownBadge, ?shownSubtitle, if (locked) 'locked, select a package'].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.smd),
            child: Row(
              children: [
                Container(
                  width: AppSize.controlSm + AppSpacing.xs,
                  height: AppSize.controlSm + AppSpacing.xs,
                  decoration: BoxDecoration(
                    color: locked ? AppColors.surfaceMuted : AppColors.businessTint,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Icon(
                    icon,
                    size: AppIconSize.md,
                    color: locked ? AppColors.textSecondary : AppColors.businessInk,
                  ),
                ),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xxs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            title,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: locked ? AppColors.textSecondary : AppColors.textPrimary,
                            ),
                          ),
                          if (shownBadge != null)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.pendingBg,
                                borderRadius: BorderRadius.circular(AppSpacing.xs),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs + 2, vertical: 1),
                                child: Text(
                                  shownBadge,
                                  style: AppTypography.badgeLabel.copyWith(
                                    color: AppColors.pending,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (shownSubtitle != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          shownSubtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (locked)
                  const Tooltip(
                    message: 'Select a package',
                    child: Icon(Icons.lock_outline_rounded, color: AppColors.textSecondary, size: AppIconSize.md),
                  )
                else
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: AppIconSize.md),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.icon, required this.title, required this.onTap, this.destructive = false});

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : AppColors.textPrimary;

    return Semantics(
      button: true,
      label: title,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget + AppSpacing.xs),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.smd),
            child: Row(
              children: [
                Icon(icon, size: AppIconSize.md, color: destructive ? AppColors.error : AppColors.textSecondary),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
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
