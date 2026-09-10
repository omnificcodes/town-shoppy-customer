import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Kept as an alias so existing `InfoBoxTone.info` call sites keep
/// compiling; the shared enum is [AppTone] (`silver` became `neutral`).
typedef InfoBoxTone = AppTone;

/// Soft-tinted info surface — the customer-app equivalent of the admin
/// web's tone system, using this app's own semantic palette (never the
/// reserved brand accents — design-principles.md's own rule). Use it for
/// every "note to the user" (a pending explanation, a rejection reason, a
/// safety warning) instead of a plain [AppCard], so the tone tells the user
/// how to feel about the note before they read it.
class InfoBox extends StatelessWidget {
  const InfoBox({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.tone = AppTone.info,
    this.action,
  });

  final IconData icon;
  final String? title;
  final String message;
  final AppTone tone;

  /// An optional inline action (e.g. "Try again"), rendered under the text.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = tone.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: AppIconSize.md),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title!, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: fg)),
                  const SizedBox(height: AppSpacing.xxs),
                ],
                Text(message, style: Theme.of(context).textTheme.bodySmall),
                if (action != null) ...[const SizedBox(height: AppSpacing.sm), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
