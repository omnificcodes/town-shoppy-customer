import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale for the customer app.
///
/// Set in Plus Jakarta Sans, the typeface the Google Stitch redesign uses,
/// bundled as font assets (see pubspec.yaml) rather than loaded through a
/// `google_fonts` dependency, so text never waits on the network and no new
/// package was needed. Every style below names the family explicitly, and
/// [AppTheme] sets it app-wide, so a style built outside this file still
/// lands in the same face.
///
/// Sizes intentionally never drop below 12sp except [overline] (design-
/// principles.md + section 18's "avoid overly small text"). Stitch sets some
/// labels at 10-11px; those are raised to this floor on purpose. Line
/// heights stay generous for comfortable extended reading (financial and
/// activity history is a primary use case, not just glanceable cards).
class AppTypography {
  AppTypography._();

  static const fontFamily = 'PlusJakartaSans';

  static const _base = TextStyle(fontFamily: fontFamily, color: AppColors.textPrimary, height: 1.35);

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

  /// The screen-opening greeting ("Good evening, Sudheer") -- Stitch's
  /// extra-bold display line with tight tracking.
  static const greeting = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.3,
  );

  /// A section heading above a group of content ("Browse by Category").
  /// [SectionHeader] uses it, so every section title shares one weight.
  static const sectionTitle = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    fontSize: 17,
    fontWeight: FontWeight.w800,
    height: 1.25,
    letterSpacing: -0.2,
  );

  /// Secondary metadata under a title (timestamps, "Valid till …", helper
  /// lines). Sits between `labelSmall` and `bodySmall` so those two stop
  /// being pressed into caption duty.
  static const caption = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// Tiny tracked uppercase label above a group ("SHOP · SAVE · WIN",
  /// eyebrow text). The only style allowed below 12sp, and only in caps
  /// with tracking, which is what keeps it legible at that size.
  static const overline = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 1.2,
  );

  /// Text inside a [StatusBadge]/chip — bold so it survives the tinted
  /// background, never smaller than 12.
  static const badgeLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.1,
  );

  /// Numeric/financial display variant — Town Coin balances, purchase and
  /// redemption amounts. Tabular figures so digits don't jitter width as a
  /// balance updates, and a distinct letter-spacing from prose headings so a
  /// number reads as data, not as a heading that happens to be a number.
  static const numericFinancialLarge = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -0.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const numericFinancialMedium = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.25,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const numericFinancialSmall = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// A coin/amount inside a sentence or tile trailing slot ("+120 coins").
  static const numericFinancialInline = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
