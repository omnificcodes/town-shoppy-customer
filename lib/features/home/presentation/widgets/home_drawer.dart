import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_mode/app_mode.dart';
import '../../../../core/app_mode/app_mode_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/application/auth_state.dart';
import '../../../business/presentation/business_routes.dart';

/// Opened from [HomeHeader]'s hamburger icon -- a quick-nav shortcut list,
/// not a duplicate of [ProfileScreen] (which stays the full account
/// destination, still reachable as its own bottom-nav tab). Every
/// destination here is already a real route; nothing new is introduced.
class HomeDrawer extends ConsumerWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final account = authState is AuthAuthenticated ? authState.account : null;
    final isLoggingOut = authState is AuthAuthenticated && authState.isLoggingOut;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: AppSize.avatarLg / 2,
                    backgroundColor: AppColors.orangeTintStrong,
                    child: Text(
                      _initials(account?.customerProfile?.name, account?.mobileNumber ?? ''),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.orange),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(account?.displayName ?? 'Town Shoppy', style: Theme.of(context).textTheme.titleMedium),
                        // `displayName` already falls back to the mobile
                        // number for an account with no name; printing the
                        // number under it again just repeats the line above.
                        if (account != null && account.displayName != account.mobileNumber) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(account.mobileNumber, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                children: [
                  _DrawerItem(icon: Icons.person_outline_rounded, label: 'Profile', route: '/profile'),
                  _DrawerItem(icon: Icons.savings_outlined, label: 'Wallet', route: '/wallet'),
                  _DrawerItem(icon: Icons.storefront_outlined, label: 'Discover merchants', route: '/merchants'),
                  _DrawerItem(icon: Icons.shopping_bag_outlined, label: 'Shopping', route: '/shopping'),
                  _DrawerItem(icon: Icons.favorite_border_rounded, label: 'Favorites', route: '/favorites'),
                  _DrawerItem(icon: Icons.receipt_long_outlined, label: 'Purchases', route: '/purchases'),
                  _DrawerItem(icon: Icons.confirmation_number_outlined, label: 'Coupons & Lucky Draw', route: '/coupons'),
                  _DrawerItem(icon: Icons.qr_code_2_outlined, label: 'Redemptions', route: '/redemptions'),
                  if (account?.customerProfile?.referralCode != null)
                    _DrawerItem(icon: Icons.card_giftcard_outlined, label: 'Refer & earn', route: '/referrals'),
                  _DrawerItem(icon: Icons.notifications_outlined, label: 'Notifications', route: '/notifications'),
                  if (account?.hasMerchantAccess == true) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.storefront_rounded, color: AppColors.businessInk),
                      title: const Text('Switch to Business app'),
                      subtitle: const Text('Manage your shop'),
                      onTap: () async {
                        Navigator.of(context).pop();
                        await ref.read(appModeControllerProvider.notifier).select(AppMode.business);
                        if (context.mounted) context.go(BusinessRoutes.root);
                      },
                    ),
                  ] else ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.storefront_outlined, color: AppColors.textPrimary),
                      title: const Text('Register your business'),
                      subtitle: const Text('Join Town Shoppy as a merchant'),
                      onTap: () {
                        Navigator.of(context).pop();
                        // `go`, not `push` -- see the Login screen's
                        // "Register as a merchant" for why a push here
                        // loses the applicant mid-registration.
                        context.go('/register-merchant');
                      },
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: ListTile(
                leading: isLoggingOut
                    ? const SizedBox(
                        width: AppIconSize.lg,
                        height: AppIconSize.lg,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout_rounded, color: AppColors.error),
                title: Text(
                  'Sign out',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isLoggingOut ? AppColors.textDisabled : AppColors.error,
                      ),
                ),
                onTap: isLoggingOut ? null : () => ref.read(authControllerProvider.notifier).logout(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String? name, String mobile) {
    if (name != null && name.trim().isNotEmpty) {
      final parts = name.trim().split(RegExp(r'\s+'));
      return parts.take(2).map((p) => p[0].toUpperCase()).join();
    }
    return mobile.isNotEmpty ? mobile.substring(mobile.length - 2) : '?';
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({required this.icon, required this.label, required this.route});

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrimary),
      title: Text(label),
      onTap: () {
        Navigator.of(context).pop();
        context.push(route);
      },
    );
  }
}
