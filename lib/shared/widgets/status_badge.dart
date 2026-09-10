import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Kept as an alias so the many existing `StatusTone.success` call sites
/// keep compiling; new code should say [AppTone].
typedef StatusTone = AppTone;

/// A text-labeled status pill — never color-only (section 24/43: status
/// must not be communicated by color alone). Optional [icon] for the
/// states where a glyph adds meaning (a check for "verified", a clock for
/// "waiting"); it is decorative and the label always carries the meaning.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.tone, this.icon, this.large = false});

  final String label;
  final AppTone tone;
  final IconData? icon;

  /// A slightly taller pill for a screen's headline status (a detail
  /// page's hero), not for rows.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = tone.colors;
    final style = large
        ? AppTypography.textTheme.labelMedium!.copyWith(color: fg, fontWeight: FontWeight.w700)
        : AppTypography.badgeLabel.copyWith(color: fg);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? AppSpacing.smd : AppSpacing.sm,
        vertical: large ? AppSpacing.xs + 2 : AppSpacing.xs,
      ),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppSpacing.radiusPill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: large ? AppIconSize.sm : AppIconSize.xs, color: fg),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(child: Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
