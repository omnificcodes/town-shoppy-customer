import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Elevation scale for the customer app.
///
/// This app's flat content surfaces (cards, app bar, bottom nav) deliberately
/// use `elevation: 0` plus a hairline border instead of a shadow — see
/// [AppTheme]'s `cardTheme` and design-principles.md's "premium means
/// restrained" — borders read calmer than shadows at this density, and that
/// choice stays in place here.
///
/// Elevation still has a real job on this app's *floating* surfaces — the
/// ones that sit above other content and need a visual cue separating them
/// from what's behind (dialogs, bottom sheets, toasts/snackbars, popover
/// menus). [subtle] and [floating] give those surfaces one consistent,
/// restrained shadow instead of each call site inventing its own or relying
/// on Material's default per-widget elevation values.
class AppElevation {
  AppElevation._();

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
