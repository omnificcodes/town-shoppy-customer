import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// The one card shape used across the app — white surface, soft border,
/// no elevation (design-principles.md's "premium means restrained" —
/// borders read calmer than shadows at this density).
///
/// [compact] tightens the inner padding for dense rows (list tiles);
/// [tinted] swaps the white surface for the brand's soft orange tint, the
/// only sanctioned way to give a card a warm accent.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.compact = false,
    this.tinted = false,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool compact;
  final bool tinted;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = padding ?? EdgeInsets.all(compact ? AppSpacing.smd : AppSpacing.md);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      side: BorderSide(color: borderColor ?? (tinted ? AppColors.orangeBorder : AppColors.border)),
    );

    // The InkWell lives INSIDE the card's Material so the ripple paints on
    // the card surface -- an InkWell wrapped around an opaque Card draws
    // its splash behind the card, where nobody ever sees it.
    return Material(
      color: tinted ? AppColors.orangeTint : AppColors.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: resolvedPadding, child: child),
      ),
    );
  }
}
