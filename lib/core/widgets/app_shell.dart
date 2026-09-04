import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/purchases/presentation/scan_and_pay_sheet.dart';
import '../../shared/widgets/app_bottom_navigation.dart';

const _tabPaths = ['/home', '/wallet', '/coupons', '/profile'];

const _tabItems = [
  BottomNavItemData(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
  BottomNavItemData(icon: Icons.savings_outlined, activeIcon: Icons.savings_rounded, label: 'Wallet'),
  BottomNavItemData(
    icon: Icons.confirmation_number_outlined,
    activeIcon: Icons.confirmation_number_rounded,
    label: 'Coupons',
  ),
  BottomNavItemData(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
];

/// Shared shell for the four authenticated top-level destinations. Scan &
/// Pay is deliberately not a 5th tab -- it opens a picker sheet (My QR vs.
/// scan a merchant's), not a screen, so it's the floating center action
/// instead, docked in the bottom bar's notch. Notifications moved off the
/// tab bar entirely to the Home header's bell icon (see `HomeHeader`) once
/// Scan & Pay took the visually-central slot; `/notifications` is still a
/// real route, just a top-level push now rather than a shell tab.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  int get _currentIndex {
    final index = _tabPaths.indexWhere((path) => location.startsWith(path));
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: child,
      floatingActionButton: ScanAndPayFab(onTap: () => showScanAndPaySheet(context)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: _currentIndex,
        onTap: (index) => context.go(_tabPaths[index]),
        items: _tabItems,
      ),
    );
  }
}
