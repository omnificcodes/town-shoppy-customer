import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_elevation.dart';
import '../../core/theme/app_spacing.dart';

/// The one card shape used across the app — white surface, hairline border,
/// and the same barely-there lift ([AppElevation.card]) the Stitch-era
/// screens draw by hand. The border still does the separating; the lift
/// only stops a white card from looking printed onto the cream page.
/// Without it, the screens built on this widget (purchases, redemptions,
/// Lucky Draw, billing, customers…) read as a flatter, older product than
/// Home, Wallet and the dashboard sitting one tap away.
///
/// [compact] tightens the inner padding for dense rows (list tiles);
/// [tinted] swaps the white surface for the brand's soft orange tint, the
/// only sanctioned way to give a card a warm accent. A tinted card stays
/// flat on purpose: it is an informational surface, not a raised one, and a
/// shadow under a tint muddies the tint.
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
    final card = Material(
      color: tinted ? AppColors.orangeTint : AppColors.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: resolvedPadding, child: child),
      ),
    );

    if (tinted) return card;

    // The shadow sits on a DecoratedBox OUTSIDE the Material: the Material
    // clips to its shape (so the ripple stays inside the rounded corners),
    // and would clip its own shadow away with it.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: AppElevation.card,
      ),
      child: card,
    );
  }
}
