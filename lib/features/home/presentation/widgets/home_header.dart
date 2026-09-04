import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../notifications/application/unread_count_provider.dart';
import '../../../../shared/widgets/notification_badge.dart';
import '../../application/home_location_controller.dart';

/// Home's own top section -- brand wordmark, then a row of hamburger (opens
/// [HomeDrawer]) / current-location pill / notification bell. Deliberately
/// not a Material [AppBar]: nothing here needs `AppBar`'s single-row
/// constraint, and the two-row brand-then-utility-row shape matches the
/// reference layout this was built from. White/cream, not the navy banner
/// treatment `town-shoppy-admin` uses -- that is a different app with its
/// own established "white canvas, saturated accent reserved for CTAs"
/// design system (`design-principles.md`), which this header stays inside.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider).value ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      child: Column(
        children: [
          Text(
            'Town Shoppy',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.orange, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _CircleIconButton(
                icon: Icons.menu_rounded,
                tooltip: 'Menu',
                onTap: () => Scaffold.of(context).openDrawer(),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(child: _LocationPill()),
              const SizedBox(width: AppSpacing.sm),
              _CircleIconButton(
                icon: Icons.notifications_outlined,
                tooltip: 'Notifications',
                badgeCount: unreadCount,
                onTap: () => context.push('/notifications'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocationPill extends ConsumerWidget {
  const _LocationPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(homeLocationControllerProvider);

    final String label = switch (location) {
      AsyncData(:final value) when value is HomeLocationReady => value.label,
      AsyncData() => 'Set your location',
      AsyncError() => 'Set your location',
      _ => 'Locating…',
    };

    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => ref.read(homeLocationControllerProvider.notifier).retry(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.border)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on_rounded, color: AppColors.orange, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.tooltip, required this.onTap, this.badgeCount = 0});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Tooltip(
            message: tooltip,
            child: NotificationBadge(count: badgeCount, child: Icon(icon, color: AppColors.textPrimary, size: 22)),
          ),
        ),
      ),
    );
  }
}
