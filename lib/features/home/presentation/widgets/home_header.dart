import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/location/location_result.dart';
import '../../../../core/location/location_service.dart';
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
            _CircleIconButton(icon: Icons.menu_rounded, label: 'Menu', onTap: () => _openMenu(context)),
            // 3:2 against the logo slot, not an even split. The wordmark
            // needs ~70dp; the town name needs every dp it can get. Shared
            // equally, the pill was squeezed to ~127dp and cut its own
            // resting label down to "Set you…".
            const Flexible(flex: 3, child: _LocationPill()),
            Expanded(
              flex: 2,
              child: Center(
                child: Semantics(
                  label: 'Town Shoppy',
                  image: true,
                  // The logo PNG has an opaque white ground (no alpha
                  // channel). Multiplying this header's own cream into it
                  // dissolves that box (white x cream = cream) and leaves
                  // the lettering intact -- the same treatment the splash
                  // and auth screens already give this asset.
                  child: Image.asset(
                    'assets/images/townshoppy_logo.png',
                    height: _logoHeight,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                    color: AppColors.surfaceMuted,
                    colorBlendMode: BlendMode.multiply,
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

/// Opens the menu, which AppShell hosts on ITS Scaffold (so the drawer covers
/// the bottom bar) rather than on HomeScreen's. `Scaffold.of` finds the
/// nearest Scaffold -- HomeScreen's, which has no drawer -- so this walks one
/// level further out to the one that does. Falls back to the nearest for any
/// host that gives Home a drawer of its own.
void _openMenu(BuildContext context) {
  final nearest = Scaffold.of(context);
  final shell = nearest.context.findAncestorStateOfType<ScaffoldState>();
  (shell != null && shell.hasDrawer ? shell : nearest).openDrawer();
}

class _LocationPill extends ConsumerWidget {
  const _LocationPill();

  static const _maxWidth = 168.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(homeLocationControllerProvider);

    // "Set location", matching Discover Merchants' own pill -- the two are
    // the same control and said different things.
    final String label = switch (location) {
      AsyncData(:final value) when value is HomeLocationReady => value.label,
      AsyncData() => 'Set location',
      AsyncError() => 'Set location',
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
            onTap: () => _refresh(context, ref),
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

/// Re-asks for the location, then says what to do when there still isn't
/// one -- a tap that silently changes nothing reads as a broken button.
Future<void> _refresh(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  await ref.read(homeLocationControllerProvider.notifier).retry();

  final state = ref.read(homeLocationControllerProvider).value;
  if (state is! HomeLocationUnavailable) return;

  final service = ref.read(locationServiceProvider);
  final (message, settings) = switch (state.reason) {
    LocationServiceDisabled() => (
      'Location services are off. Turn them on to see your town and nearby shops.',
      kIsWeb ? null : service.openLocationSettings,
    ),
    LocationPermissionDeniedForever() => (
      'Location is blocked for Town Shoppy. Allow it in settings to see nearby shops.',
      kIsWeb ? null : service.openAppSettings,
    ),
    _ => ('Allow location to see your town and the shops around you.', null),
  };

  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      action: settings == null ? null : SnackBarAction(label: 'Settings', onPressed: settings),
    ),
  );
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
