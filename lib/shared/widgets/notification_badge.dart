import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Small unread-count dot, stacked on top of [child] — used on the header's
/// notification bell.
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
          top: -AppSpacing.xs,
          right: -AppSpacing.sm,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs + 1, vertical: 1),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            decoration: BoxDecoration(
              color: AppColors.crimson,
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              border: Border.all(color: AppColors.surface, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              count > 9 ? '9+' : '$count',
              textAlign: TextAlign.center,
              style: AppTypography.overline.copyWith(color: AppColors.onCrimson, letterSpacing: 0),
            ),
          ),
        ),
      ],
    );
  }
}
