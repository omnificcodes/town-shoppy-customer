import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// A single selectable category filter chip. Selected state is never
/// color-only — the label weight and a check icon both change too.
class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: selected ? '$label, selected' : label,
      child: Material(
        color: selected ? AppColors.orange : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          onTap: onTap,
          child: Padding(
            // Vertical padding deliberately larger than AppSpacing.sm --
            // AppSpacing.touchTarget (48) is this app's minimum tap-target
            // constant (applied to every AppButton via app_theme.dart), but
            // this chip's own rendered height was never checked against it
            // and came out to ~36px. Paired with the reduced ListView/Row
            // padding at each of this chip's two call sites (merchants list
            // filter row, tab toggle), this brings the tappable area up to
            // ~44-48px without changing the chip's outer allotted space.
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  const Icon(Icons.check_rounded, size: 16, color: AppColors.onOrange),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: selected ? AppColors.onOrange : AppColors.textPrimary,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
