import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// The maroon band every Business-mode tab root opens with -- the one
/// visual that tells an owner "you are in the business side of the app"
/// before they read a word. Pushed detail screens use a plain
/// [BusinessScaffold] app bar instead so the band stays a tab-root signal.
class BusinessPageHeader extends StatelessWidget {
  const BusinessPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.child,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  /// Optional content rendered inside the band under the title row (the
  /// dashboard's identity block).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.businessInk, AppColors.businessInkDeep],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.sm)],
                  const BusinessModeChip(),
                  const Spacer(),
                  ...actions,
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(title, style: textTheme.headlineMedium?.copyWith(color: AppColors.onBusinessInk)),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(subtitle!, style: textTheme.bodyMedium?.copyWith(color: AppColors.onBusinessInkMuted)),
              ],
              if (child != null) ...[const SizedBox(height: AppSpacing.md), child!],
            ],
          ),
        ),
      ),
    );
  }
}

/// "BUSINESS" eyebrow pill -- gold on maroon, the merchant identity from
/// design-principles.md's "Silver vs. Gold" rule.
class BusinessModeChip extends StatelessWidget {
  const BusinessModeChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.storefront_rounded, size: AppIconSize.xs, color: AppColors.yellow),
          const SizedBox(width: AppSpacing.xs),
          Text('BUSINESS', style: AppTypography.overline.copyWith(color: AppColors.yellow)),
        ],
      ),
    );
  }
}

/// Round icon button on the maroon band (bell, menu).
class BusinessHeaderIconButton extends StatelessWidget {
  const BusinessHeaderIconButton({super.key, required this.icon, required this.tooltip, required this.onTap, this.badge});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.onBusinessInk.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: AppSpacing.touchTarget,
          height: AppSpacing.touchTarget,
          child: Tooltip(
            message: tooltip,
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: AppColors.onBusinessInk, size: AppIconSize.lg),
                  if (badge != null) Positioned(top: -AppSpacing.xs, right: -AppSpacing.sm, child: badge!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// App bar + body for pushed (non-tab-root) Business screens. Same shape
/// as the customer `AppScaffold`, but the bar is tinted so a pushed
/// business page still reads as business.
class BusinessScaffold extends StatelessWidget {
  const BusinessScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.padded = true,
    this.bottomBar,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final bool padded;
  final Widget? bottomBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        backgroundColor: AppColors.businessInk,
        foregroundColor: AppColors.onBusinessInk,
        // The themed title style is maroon; on this maroon bar it needs its
        // own colour (a themed style ignores `foregroundColor`).
        titleTextStyle: AppTypography.sectionTitle.copyWith(color: AppColors.onBusinessInk),
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.onBusinessInk),
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomBar == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.md),
                child: bottomBar,
              ),
            ),
      body: SafeArea(
        bottom: bottomBar == null,
        child: padded ? Padding(padding: const EdgeInsets.all(AppSpacing.page), child: body) : body,
      ),
    );
  }
}
