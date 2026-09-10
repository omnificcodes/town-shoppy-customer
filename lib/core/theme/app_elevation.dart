import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Elevation scale for the customer app.
///
/// This app's flat content surfaces (cards, app bar) deliberately use
/// `elevation: 0` plus a hairline border instead of a shadow — see
/// [AppTheme]'s `cardTheme` and design-principles.md's "premium means
/// restrained" — borders read calmer than shadows at this density, and that
/// choice stays in place here.
///
/// Elevation still has a real job on this app's *floating* surfaces — the
/// ones that sit above other content and need a visual cue separating them
/// from what's behind (nav bar, FAB, dialogs, bottom sheets, toasts). The
/// numeric levels feed Material `elevation:` parameters; [subtle] and
/// [floating] are the equivalent `BoxShadow`s for hand-built containers,
/// so both kinds of surface share one restrained scale.
class AppElevation {
  AppElevation._();

  /// Flat: border only. Cards, tiles, the app bar at rest.
  static const double level0 = 0;

  /// The app bar once content has scrolled under it.
  static const double level1 = 1;

  /// The bottom nav bar and sticky headers.
  static const double level2 = 3;

  /// The docked Scan & Pay action.
  static const double level3 = 8;

  /// Dialogs and bottom sheets.
  static const double level4 = 16;

  /// For content that sits just above the page — e.g. a popover menu.
  static List<BoxShadow> get subtle => [
        BoxShadow(
          color: AppColors.deepMaroon.withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// For genuinely floating surfaces — dialogs, bottom sheets, toasts.
  static List<BoxShadow> get floating => [
        BoxShadow(
          color: AppColors.deepMaroon.withValues(alpha: 0.10),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}
