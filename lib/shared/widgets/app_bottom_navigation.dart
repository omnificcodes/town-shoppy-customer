import 'package:flutter/material.dart';

/// Bottom navigation destinations, kept intentionally compact (section 31:
/// 3-5 primary destinations, only for modules that actually exist in this
/// phase — Home, Notifications, Profile).
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({super.key, required this.currentIndex, required this.onTap, required this.items});

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavigationBarItem> items;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: items,
    );
  }
}
