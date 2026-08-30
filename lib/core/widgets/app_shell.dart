import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/notifications/application/unread_count_provider.dart';
import '../../shared/widgets/app_bottom_navigation.dart';
import '../../shared/widgets/notification_badge.dart';

const _tabPaths = ['/home', '/notifications', '/profile'];

/// Shared shell for the three authenticated top-level destinations
/// (section 31/32) — a single, compact bottom nav rather than a
/// per-feature navigation pattern.
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
