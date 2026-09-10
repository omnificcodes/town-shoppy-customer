import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// The shared layout behind [EmptyState] and [ErrorState]: a centered
/// icon, title, message and up to two actions. Scrolls itself because
/// callers drop it straight into a screen body with no scroll wrapper of
/// their own, so a short viewport or large system text scale must not
/// overflow. [compact] is the in-card density (e.g. a section on Home that
/// failed to load) — no vertical breathing room, small icon.
class StatePanel extends StatelessWidget {
  const StatePanel({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.message,
    this.title,
    this.action,
    this.secondaryAction,
    this.compact = false,
  });

  final IconData icon;
  final Color iconColor;
  final String? title;
  final String message;
  final Widget? action;
  final Widget? secondaryAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: compact ? AppIconSize.xl : AppIconSize.display, color: iconColor),
        SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
        if (title != null) ...[
          Text(title!, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
        ],
        Text(message, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
        if (action != null) ...[SizedBox(height: compact ? AppSpacing.smd : AppSpacing.md), action!],
        if (secondaryAction != null) ...[const SizedBox(height: AppSpacing.sm), secondaryAction!],
      ],
    );

    if (compact) return Padding(padding: const EdgeInsets.all(AppSpacing.md), child: column);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl, horizontal: AppSpacing.lg),
      child: column,
    );
  }
}
