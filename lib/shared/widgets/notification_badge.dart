import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Small unread-count dot, stacked on top of [child] — used on the bottom
/// nav's Notifications icon.
class NotificationBadge extends StatelessWidget {
  const NotificationBadge({super.key, required this.child, required this.count});

  final Widget child;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -4,
          right: -8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 16),
            decoration: const BoxDecoration(color: AppColors.crimson, shape: BoxShape.circle),
            child: Text(
              count > 9 ? '9+' : '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
