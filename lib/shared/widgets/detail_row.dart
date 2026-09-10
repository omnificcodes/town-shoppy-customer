import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// A label/value line inside a detail card ("Issued · 04/09/2026"). The
/// value can be a plain string or any widget (a [StatusBadge], a money
/// figure). Long values wrap on the right rather than squeezing the label.
class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, this.value, this.child, this.icon, this.emphasize = false})
      : assert(value != null || child != null, 'Provide value or child');

  final String label;
  final String? value;
  final Widget? child;
  final IconData? icon;

  /// Bold the value (the row that answers the screen's main question).
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppIconSize.md, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            flex: 2,
            child: Text(label, style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          ),
          const SizedBox(width: AppSpacing.smd),
          Flexible(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: child ??
                  Text(
                    value!,
                    textAlign: TextAlign.end,
                    style: textTheme.bodyMedium?.copyWith(fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
