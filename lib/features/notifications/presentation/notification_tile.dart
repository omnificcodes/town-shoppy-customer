import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/relative_time.dart';
import '../data/models/app_notification.dart';
import 'notification_type_display.dart';

/// Section 24/54: unread gets a soft tint + bold title + a dot indicator —
/// never color-only, the dot itself is a shape, not just a hue.
class NotificationTile extends StatelessWidget {
  const NotificationTile({super.key, required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final display = NotificationTypeDisplay.forType(notification.type);
    final unread = notification.isUnread;
    final title = notification.title ?? 'Notification';
    final timeLabel = notification.createdAt != null ? relativeTime(notification.createdAt!) : '';

    // The tint/bold-weight/dot are all visual-only -- a screen reader gets
    // none of them for free from the descendant Text widgets, so unread
    // status must be stated explicitly here too (section 24/54's "never
    // color-only" applies to assistive tech, not just sighted users).
    // `excludeSemantics` replaces the descendant Text widgets' own merged
    // announcement with this hand-composed one, so title/body/time are
    // spelled out here rather than lost.
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: [
        if (unread) 'Unread',
        title,
        if (notification.body != null) notification.body!,
        timeLabel,
      ].join(', '),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          color: unread ? AppColors.infoBg.withValues(alpha: 0.5) : Colors.transparent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: display.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(display.icon, color: display.color, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                          ),
                    ),
                    if (notification.body != null) ...[
                      const SizedBox(height: 2),
                      Text(notification.body!, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 4),
                    Text(timeLabel, style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
              if (unread)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm, top: 6),
                  child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
