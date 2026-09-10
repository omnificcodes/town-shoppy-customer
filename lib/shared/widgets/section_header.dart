import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// A section title with an optional subtitle and an optional trailing
/// action ("See all"). One shape for every "heading above a group of
/// content" in the app, so section rhythm is identical screen to screen.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.subtitle, this.actionLabel, this.onAction, this.icon});

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Icon(icon, size: AppIconSize.md, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: AppSpacing.sm),
          // Negative vertical margin keeps the 48dp target without pushing
          // the header taller than its title line.
          SizedBox(
            height: AppSpacing.touchTarget,
            child: TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm)),
              child: Text(actionLabel!),
            ),
          ),
        ],
      ],
    );
  }
}
