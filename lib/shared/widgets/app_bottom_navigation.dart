import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_elevation.dart';
import '../../core/theme/app_spacing.dart';

class BottomNavItemData {
  const BottomNavItemData({required this.icon, required this.activeIcon, required this.label});

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// The 4 real bottom-nav destinations, notched around a floating center
/// action (Scan & Pay -- see [AppShell]) rather than a 5th tab item, since
/// that action opens a picker sheet, not a screen of its own, and deserves
/// the same visually-elevated treatment reference consumer apps in this
/// category use for their primary action.
///
/// The active tab is marked by a tinted pill behind its icon as well as
/// color/weight -- the app's own "never color alone" rule applies to
/// navigation state too. The bar grows with the system text scale (capped)
/// and respects the bottom safe area on gesture-nav devices.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.activeColor = AppColors.orange,
    this.activeTint = AppColors.orangeTint,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavItemData> items;

  /// The selected tab's icon/label colour and the pill behind its icon.
  /// Customer mode keeps the brand orange; Business mode passes its own
  /// maroon identity so the two shells never look alike.
  final Color activeColor;
  final Color activeTint;

  @override
  Widget build(BuildContext context) {
    assert(items.length == 4, 'AppBottomNavigation expects exactly 4 items either side of the notch.');

    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4);
    final height = AppSize.navBar + (textScale - 1) * 24;

    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: AppSpacing.sm,
      padding: EdgeInsets.zero,
      color: AppColors.surface,
      elevation: AppElevation.level2,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              Expanded(child: _tab(context, 0)),
              Expanded(child: _tab(context, 1)),
              const SizedBox(width: AppSize.fabSlot),
              Expanded(child: _tab(context, 2)),
              Expanded(child: _tab(context, 3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, int index) {
    final item = items[index];
    final selected = index == currentIndex;
    final color = selected ? activeColor : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: selected ? activeTint : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              ),
              child: Icon(selected ? item.activeIcon : item.icon, color: color, size: AppIconSize.lg),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The raised circular Scan & Pay action docked in the bottom nav's notch —
/// [AppShell] supplies this as the [Scaffold.floatingActionButton].
class ScanAndPayFab extends StatelessWidget {
  const ScanAndPayFab({
    super.key,
    required this.onTap,
    this.semanticLabel = 'Scan & Pay',
    this.icon = Icons.qr_code_scanner_rounded,
    this.color = AppColors.crimson,
    this.foregroundColor = AppColors.onCrimson,
  });

  final VoidCallback onTap;

  /// Business mode reuses this docked action as its "Counter" (Direct POS)
  /// button with its own label/icon/colour.
  final String semanticLabel;
  final IconData icon;
  final Color color;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: AppSize.fab,
            height: AppSize.fab,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: AppElevation.glow(color),
              border: Border.all(color: AppColors.surface, width: 3),
            ),
            child: Icon(icon, color: foregroundColor, size: AppIconSize.xl),
          ),
        ),
      ),
    );
  }
}
