import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

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
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({super.key, required this.currentIndex, required this.onTap, required this.items});

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavItemData> items;

  @override
  Widget build(BuildContext context) {
    assert(items.length == 4, 'AppBottomNavigation expects exactly 4 items either side of the notch.');

    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      padding: EdgeInsets.zero,
      color: AppColors.surface,
      elevation: 8,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            Expanded(child: _tab(context, 0)),
            Expanded(child: _tab(context, 1)),
            const SizedBox(width: 56),
            Expanded(child: _tab(context, 2)),
            Expanded(child: _tab(context, 3)),
          ],
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, int index) {
    final item = items[index];
    final selected = index == currentIndex;
    final color = selected ? AppColors.orange : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? item.activeIcon : item.icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: selected ? FontWeight.w700 : null),
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
  const ScanAndPayFab({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Scan & Pay',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.orange, AppColors.crimson],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(color: AppColors.crimson.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
            ],
            border: Border.all(color: AppColors.surface, width: 3),
          ),
          child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}
