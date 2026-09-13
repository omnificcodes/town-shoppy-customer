import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// A KPI tile ("Pending purchases · 3"). Tone follows the same semantic
/// palette as the rest of the app: pending work is amber, all-clear is
/// green, informational is blue.
class DashboardStatTile extends StatelessWidget {
  const DashboardStatTile({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.tone,
    this.description,
    this.descriptionWidget,
    this.onTap,
    this.isLoading = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final AppTone tone;
  final String? description;
  final Widget? descriptionWidget;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = tone.colors;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: onTap != null,
      label: '$title: $value${description != null ? ', $description' : ''}',
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: AppSize.avatarSm,
                      height: AppSize.avatarSm,
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Icon(icon, size: AppIconSize.sm, color: fg),
                    ),
                    const Spacer(),
                    if (onTap != null) Icon(Icons.chevron_right_rounded, size: AppIconSize.md, color: fg),
                  ],
                ),
                const SizedBox(height: AppSpacing.smd),
                Text(title, style: AppTypography.caption.copyWith(color: fg), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpacing.xxs),
                if (isLoading)
                  const _Pulse(width: 48, height: 22)
                else
                  Text(
                    value,
                    style: AppTypography.numericFinancialMedium.copyWith(color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (descriptionWidget != null) ...[const SizedBox(height: AppSpacing.xs), descriptionWidget!]
                else if (description != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(description!, style: textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The "take action now" tiles under Quick actions.
class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.tone,
    required this.onTap,
    this.locked = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final AppTone tone;
  final VoidCallback onTap;

  /// Draws a small lock (the web app's greyed-label + lock treatment) --
  /// still tappable so the user lands on the package screen.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = tone.colors;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: '$title, $description${locked ? ', select a package' : ''}',
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: AppSize.avatarSm + AppSpacing.xs,
                      height: AppSize.avatarSm + AppSpacing.xs,
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Icon(icon, size: AppIconSize.md, color: fg),
                    ),
                    const Spacer(),
                    Icon(locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded, size: AppIconSize.sm, color: AppColors.textSecondary),
                  ],
                ),
                const SizedBox(height: AppSpacing.smd),
                Text(title, style: textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpacing.xxs),
                Text(description, style: textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pulse extends StatelessWidget {
  const _Pulse({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
      ),
    );
  }
}
