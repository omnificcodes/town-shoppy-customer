import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../notifications/application/unread_count_provider.dart';
import '../../application/home_location_controller.dart';

/// Home's top bar, following the Stitch redesign: menu and location on the
/// left, the Town Shoppy wordmark centred, notifications on the right, on the
/// page's own cream ground with a hairline underneath.
///
/// Not a Material [AppBar]: the centred logo between two unequal side groups
/// is exactly what AppBar's title slot can't hold. The circular buttons draw
/// at 40dp to match the design but keep a 48dp touch target.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  static const _logoHeight = 40.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider).value ?? 0;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surfaceMuted,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page - AppSpacing.xs, vertical: AppSpacing.xs),
        child: Row(
          children: [
            _CircleIconButton(
              icon: Icons.menu_rounded,
              label: 'Menu',
              onTap: () => Scaffold.of(context).openDrawer(),
            ),
            const Flexible(child: _LocationPill()),
            Expanded(
              child: Center(
                child: Semantics(
                  label: 'Town Shoppy',
                  image: true,
                  child: Image.asset(
                    'assets/images/townshoppy_logo.png',
                    height: _logoHeight,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
            _CircleIconButton(
              icon: Icons.notifications_none_rounded,
              label: unreadCount > 0 ? 'Notifications, $unreadCount unread' : 'Notifications',
              showDot: unreadCount > 0,
              onTap: () => context.push('/notifications'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationPill extends ConsumerWidget {
  const _LocationPill();

  static const _maxWidth = 168.0;

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
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: Material(
          color: AppColors.surface,
          shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => ref.read(homeLocationControllerProvider.notifier).retry(),
            child: SizedBox(
              height: AppSize.controlSm,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_rounded, size: AppIconSize.sm, color: AppColors.orange),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: AppIconSize.sm, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.label, required this.onTap, this.showDot = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Stitch marks unread notifications with a dot, not a count; the count
  /// still reaches screen readers through [label].
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: AppSpacing.touchTarget / 2,
        child: SizedBox(
          width: AppSpacing.touchTarget,
          height: AppSpacing.touchTarget,
          child: Center(
            child: Container(
              width: AppSize.controlSm,
              height: AppSize.controlSm,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
                boxShadow: AppElevation.card,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, size: AppIconSize.md, color: AppColors.textPrimary),
                  if (showDot)
                    Positioned(
                      top: AppSpacing.sm,
                      right: AppSpacing.sm,
                      child: Container(
                        width: AppSpacing.sm + AppSpacing.xxs,
                        height: AppSpacing.sm + AppSpacing.xxs,
                        decoration: BoxDecoration(
                          color: AppColors.orange,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surface, width: AppSpacing.xxs),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
