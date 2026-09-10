import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'app_card.dart';

/// A tappable "go somewhere" row: tinted icon badge, title, optional
/// subtitle, chevron. Used by Home's "More" group and Profile's activity
/// links so both look and behave identically.
class NavLinkCard extends StatelessWidget {
  const NavLinkCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconColor = AppColors.orange,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: subtitle == null ? title : '$title, $subtitle',
      child: AppCard(
        onTap: onTap,
        compact: true,
        child: NavLinkRow(icon: icon, title: title, subtitle: subtitle, iconColor: iconColor, trailing: trailing),
      ),
    );
  }
}

/// The row inside [NavLinkCard], exposed so several links can share one
/// card separated by dividers (Home's "More" group).
class NavLinkRow extends StatelessWidget {
  const NavLinkRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor = AppColors.orange,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Container(
          width: AppSize.avatarMd,
          height: AppSize.avatarMd,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Icon(icon, color: iconColor, size: AppIconSize.md),
        ),
        const SizedBox(width: AppSpacing.smd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: AppIconSize.lg),
      ],
    );

    if (onTap == null) return row;

    return InkWell(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd, vertical: AppSpacing.smd), child: row),
    );
  }
}
