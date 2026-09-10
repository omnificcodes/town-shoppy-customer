import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// The app's one button. Three visual weights ([AppButtonVariant]), three
/// heights ([AppButtonSize]), optional leading/trailing icon, and a
/// built-in loading state so every screen handles "submitting" the same
/// way instead of reinventing a spinner overlay per form (section 34:
/// loading is part of the feature).
///
/// Full-width by default (a screen's primary action spans the page);
/// pass `expand: false` for an inline button that hugs its label.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final disabled = isLoading || onPressed == null;
    final height = switch (size) {
      AppButtonSize.sm => AppSize.controlSm,
      AppButtonSize.md => AppSize.controlMd,
      AppButtonSize.lg => AppSize.controlLg,
    };
    final iconSize = size == AppButtonSize.sm ? AppIconSize.sm : AppIconSize.md;
    final spinnerColor = switch (variant) {
      AppButtonVariant.primary => Theme.of(context).colorScheme.onPrimary,
      AppButtonVariant.destructive => AppColors.onCrimson,
      _ => Theme.of(context).colorScheme.primary,
    };

    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(spinnerColor)),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: iconSize),
                const SizedBox(width: AppSpacing.sm),
              ],
              // Flexible, not a bare Text: mainAxisSize.min lets the button
              // hug short labels (the common case) without stretching, but
              // a long label in a narrow parent needs somewhere to give --
              // without this, the Row demands the text's full natural width
              // and throws a RenderFlex overflow instead of the button just
              // shrinking the text to fit.
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              if (trailingIcon != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(trailingIcon, size: iconSize),
              ],
            ],
          );

    // Minimum, not fixed, height: the button grows for a large system
    // text scale instead of clipping its own label.
    final minimumSize = Size(expand ? double.infinity : 0, height);
    final padding = EdgeInsets.symmetric(horizontal: size == AppButtonSize.sm ? AppSpacing.md : AppSpacing.lg);

    return switch (variant) {
      AppButtonVariant.primary => ElevatedButton(
          onPressed: disabled ? null : onPressed,
          style: ElevatedButton.styleFrom(minimumSize: minimumSize, padding: padding),
          child: child,
        ),
      AppButtonVariant.destructive => ElevatedButton(
          onPressed: disabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            minimumSize: minimumSize,
            padding: padding,
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.onCrimson,
            disabledBackgroundColor: AppColors.error.withValues(alpha: 0.35),
          ),
          child: child,
        ),
      AppButtonVariant.secondary => OutlinedButton(
          onPressed: disabled ? null : onPressed,
          style: OutlinedButton.styleFrom(minimumSize: minimumSize, padding: padding),
          child: child,
        ),
      AppButtonVariant.text => TextButton(
          onPressed: disabled ? null : onPressed,
          style: TextButton.styleFrom(minimumSize: Size(0, height), padding: padding),
          child: child,
        ),
    };
  }
}

enum AppButtonVariant { primary, secondary, text, destructive }

enum AppButtonSize { sm, md, lg }
