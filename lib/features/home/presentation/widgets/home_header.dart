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
/// reference layout this was built from. White/cream, not a saturated
/// banner -- this app's own "white canvas, accent reserved for CTAs" rule
/// (`AppColors`'s docblock).
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider).value ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.sm),
      child: Column(
        children: [
          Text(
            'Town Shoppy',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.orange, fontWeight: FontWeight.w700),
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

    return Semantics(
      button: true,
      label: 'Location: $label. Tap to refresh',
      child: Material(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          onTap: () => ref.read(homeLocationControllerProvider.notifier).retry(),
          child: Container(
            constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on_rounded, color: AppColors.orange, size: AppIconSize.md),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge),
                ),
                const SizedBox(width: AppSpacing.xxs),
                const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: AppIconSize.md),
              ],
            ),
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
        child: SizedBox(
          width: AppSpacing.touchTarget,
          height: AppSpacing.touchTarget,
          child: Tooltip(
            message: tooltip,
            child: Center(
              child: NotificationBadge(count: badgeCount, child: Icon(icon, color: AppColors.textPrimary, size: AppIconSize.lg)),
            ),
          ),
        ),
      ),
    );
  }
}
