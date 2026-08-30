import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// The one card shape used across the app — white surface, soft border,
/// no elevation (design-principles.md's "premium means restrained" —
/// borders read calmer than shadows at this density).
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding, this.onTap});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppSpacing.md),
        child: child,
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: card,
      ),
    );
  }
}
