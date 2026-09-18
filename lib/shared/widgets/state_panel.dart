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

  static const double _maxMeasure = 340;

  @override
  Widget build(BuildContext context) {
    // The glyph sits in a soft disc of its own colour rather than floating
    // bare on the page. A lone grey icon above two lines of text is what a
    // framework default looks like; the disc gives the state a deliberate
    // focal point, and it is the same tinted-icon-badge idiom the rest of the
    // app already uses for its nav links and stat tiles. Decorative only --
    // the title and message carry the meaning.
    final discSize = compact ? AppSize.avatarMd : AppIconSize.hero + AppSpacing.sm;
    final glyph = ExcludeSemantics(
      child: Container(
        width: discSize,
        height: discSize,
        decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.10), shape: BoxShape.circle),
        child: Icon(icon, size: compact ? AppIconSize.md : AppIconSize.xl, color: iconColor),
      ),
    );

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        glyph,
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

    // Capped measure: on the hosted web build (and tablets) an uncapped
    // centred paragraph ran edge to edge as one long line, which is harder
    // to read than the same copy wrapped to a phone-width column.
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl, horizontal: AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: _maxMeasure), child: column),
      ),
    );
  }
}
