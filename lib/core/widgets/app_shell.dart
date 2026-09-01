import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/notifications/application/unread_count_provider.dart';
import '../../shared/widgets/app_bottom_navigation.dart';
import '../../shared/widgets/notification_badge.dart';

const _tabPaths = ['/home', '/wallet', '/coupons', '/notifications', '/profile'];

/// Shared shell for the five authenticated top-level destinations -- Wallet
/// and Coupons (which also fronts Lucky Draw) were promoted from
/// Home-only links to first-class tabs once both grew into full screens of
/// their own, matching how central "my coins" and "my Lucky Draw entries"
/// are to the product; Purchases/Redemptions/Referrals stay reachable from
/// Home/Profile rather than adding a 6th/7th tab.
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
    final unreadCount = ref.watch(unreadNotificationCountProvider).value ?? 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: _currentIndex,
        onTap: (index) => context.go(_tabPaths[index]),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          const BottomNavigationBarItem(icon: Icon(Icons.savings_rounded), label: 'Wallet'),
          const BottomNavigationBarItem(icon: Icon(Icons.confirmation_number_rounded), label: 'Coupons'),
          BottomNavigationBarItem(
            icon: NotificationBadge(count: unreadCount, child: const Icon(Icons.notifications_rounded)),
            label: 'Notifications',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
