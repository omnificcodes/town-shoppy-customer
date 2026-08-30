import 'package:flutter/material.dart';

/// Primary/secondary button with a built-in loading state so every screen
/// handles "submitting" the same way instead of reinventing a spinner
/// overlay per form (section 34: loading is part of the feature).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final disabled = isLoading || onPressed == null;
    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(
                variant == AppButtonVariant.primary
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              // Flexible, not a bare Text: mainAxisSize.min lets the button
              // hug short labels (the common case) without stretching, but
              // a long label (e.g. "Use a different number") in a narrow
              // parent needs somewhere to give -- without this, the Row
              // demands the text's full natural width and throws a
              // RenderFlex overflow instead of the button just shrinking
              // the text to fit.
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    return switch (variant) {
      AppButtonVariant.primary => ElevatedButton(
        onPressed: disabled ? null : onPressed,
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: disabled ? null : onPressed,
        child: child,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: disabled ? null : onPressed,
        child: child,
      ),
    };
  }
}

enum AppButtonVariant { primary, secondary, text }
