import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_navigation.dart';
import 'business_routes.dart';
import 'widgets/counter_action_sheet.dart';

const _tabItems = [
  BottomNavItemData(icon: Icons.space_dashboard_outlined, activeIcon: Icons.space_dashboard_rounded, label: 'Home'),
  BottomNavItemData(icon: Icons.shopping_bag_outlined, activeIcon: Icons.shopping_bag_rounded, label: 'Sales'),
  BottomNavItemData(icon: Icons.campaign_outlined, activeIcon: Icons.campaign_rounded, label: 'Offers'),
  BottomNavItemData(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded, label: 'More'),
];

/// Business mode's shell: the four destinations an owner reaches for all
/// day (Home, Sales, Offers, More) around a docked "Counter" action that
/// opens Direct POS -- the merchant's equivalent of the customer shell's
/// Scan & Pay. Deliberately a separate widget from `AppShell`, not a
/// parameterised one: the two modes must never be one accidental flag
/// away from looking alike.
class BusinessShell extends StatelessWidget {
  const BusinessShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  int get _currentIndex {
    // Longest-prefix match so `/business/purchases` is "Sales", not "Home".
    var best = -1;
    var bestLength = -1;
    for (var i = 0; i < BusinessRoutes.tabs.length; i++) {
      final path = BusinessRoutes.tabs[i];
      if ((location == path || location.startsWith('$path/')) && path.length > bestLength) {
        best = i;
        bestLength = path.length;
      }
    }
    return best == -1 ? 0 : best;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      floatingActionButton: ScanAndPayFab(
        semanticLabel: 'Counter — My QR or My POS',
        icon: Icons.point_of_sale_rounded,
        color: AppColors.orange,
        foregroundColor: AppColors.onOrange,
        onTap: () => showCounterActionSheet(context),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: _currentIndex,
        onTap: (index) => context.go(BusinessRoutes.tabs[index]),
        items: _tabItems,
        activeColor: AppColors.businessInk,
        activeTint: AppColors.businessTint,
      ),
    );
  }
}
