import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Soft-tinted info surface — the customer-app equivalent of the admin
/// web's 5-tone `InfoBox` system, using this app's own semantic palette
/// (never the reserved brand accents — design-principles.md's own rule).
class InfoBox extends StatelessWidget {
  const InfoBox({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.tone = InfoBoxTone.info,
  });

  final IconData icon;
  final String title;
  final String message;
  final InfoBoxTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      InfoBoxTone.info => (AppColors.infoBg, AppColors.info),
      InfoBoxTone.success => (AppColors.successBg, AppColors.success),
      InfoBoxTone.pending => (AppColors.pendingBg, AppColors.pending),
      InfoBoxTone.error => (AppColors.errorBg, AppColors.error),
      InfoBoxTone.silver => (AppColors.silverLight, AppColors.silverDark),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: fg)),
                const SizedBox(height: 2),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum InfoBoxTone { info, success, pending, error, silver }
