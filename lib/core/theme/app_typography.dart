import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale for the customer app.
///
/// Deliberately uses Flutter's platform default (Roboto) rather than adding
/// a `google_fonts` dependency to match the admin web app's Geist font —
/// design-principles.md leaves typography undecided for a reason ("the
/// brief didn't specify them"), and a zero-dependency system font keeps
/// this foundation phase from pulling in network-loaded font assets for a
/// choice that isn't load-bearing yet. Revisit if a specific typeface is
/// later approved.
///
/// Sizes intentionally never drop below 13sp (design-principles.md +
/// section 18's "avoid overly small text"), and line heights are generous
/// for comfortable extended reading (financial/activity history is a
/// primary use case, not just glanceable cards).
class AppTypography {
  AppTypography._();

  static const _base = TextStyle(color: AppColors.textPrimary, height: 1.35);

  static TextTheme get textTheme => TextTheme(
        displaySmall: _base.copyWith(fontSize: 32, fontWeight: FontWeight.w700, height: 1.2),
        headlineLarge: _base.copyWith(fontSize: 26, fontWeight: FontWeight.w700, height: 1.25),
        headlineMedium: _base.copyWith(fontSize: 22, fontWeight: FontWeight.w700, height: 1.25),
        headlineSmall: _base.copyWith(fontSize: 19, fontWeight: FontWeight.w600, height: 1.3),
        titleLarge: _base.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
        titleMedium: _base.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        titleSmall: _base.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
        bodyLarge: _base.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
        bodyMedium: _base.copyWith(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
        bodySmall: _base.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          height: 1.4,
          color: AppColors.textSecondary,
        ),
        labelLarge: _base.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        labelMedium: _base.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
        labelSmall: _base.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      );

  /// Numeric/financial display variant — Town Coin balances, purchase and
  /// redemption amounts. Tabular figures so digits don't jitter width as a
  /// balance updates, and a distinct letter-spacing from prose headings so a
  /// number reads as data, not as a heading that happens to be a number.
  static const numericFinancialLarge = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -0.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const numericFinancialMedium = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.25,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const numericFinancialSmall = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
