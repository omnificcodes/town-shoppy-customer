import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// A text-labeled status pill — never color-only (section 24/43: status
/// must not be communicated by color alone).
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.tone});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      StatusTone.success => (AppColors.successBg, AppColors.success),
      StatusTone.pending => (AppColors.pendingBg, AppColors.pending),
      StatusTone.error => (AppColors.errorBg, AppColors.error),
      StatusTone.neutral => (AppColors.silverLight, AppColors.silverDark),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}

enum StatusTone { success, pending, error, neutral }
