import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_elevation.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// TownShoppy customer-app theme. Light theme only for this foundation
/// phase — design-principles.md names Dark Maroon as "the likely dark-mode
/// surface candidate" but does not specify a full dark palette, and section
/// 68 of this phase's brief is explicit: focus on an excellent light theme
/// first rather than inventing an unapproved dark theme.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.orange,
      brightness: Brightness.light,
      primary: AppColors.orange,
      onPrimary: AppColors.onOrange,
      secondary: AppColors.crimson,
      onSecondary: AppColors.onCrimson,
      tertiary: AppColors.yellow,
      onTertiary: AppColors.onYellow,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
      onError: AppColors.onCrimson,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTypography.fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surfaceMuted,
      textTheme: AppTypography.textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        // The page-title style the Stitch-era screens draw by hand in their
        // own top bars. Left unset, Material fell back to `titleLarge` --
        // same size, two weights lighter -- so every screen on AppScaffold
        // titled itself more quietly than Wallet or Merchant Details did.
        //
        // A themed title style carries its own colour and does NOT pick up
        // an AppBar's `foregroundColor`, so any bar on a dark ground
        // (BusinessScaffold, the two QR scanners) sets its own.
        titleTextStyle: AppTypography.sectionTitle,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.onOrange,
          disabledBackgroundColor: AppColors.orange.withValues(alpha: 0.35),
          disabledForegroundColor: AppColors.onOrange.withValues(alpha: 0.6),
          minimumSize: const Size.fromHeight(AppSpacing.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusControl)),
          textStyle: AppTypography.textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size.fromHeight(AppSpacing.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusControl)),
          textStyle: AppTypography.textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.orange,
          minimumSize: const Size(0, AppSpacing.touchTarget),
          textStyle: AppTypography.textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        // Pointer devices only (the hosted web build). Material's default
        // hover overlay is a flat grey that makes a white field look
        // disabled the moment the cursor crosses it; the page's own cream is
        // enough to acknowledge the hover.
        hoverColor: AppColors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
          borderSide: const BorderSide(color: AppColors.orange, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textDisabled),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.orange,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.orange),
      dividerColor: AppColors.border,
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: AppElevation.level4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
        titleTextStyle: AppTypography.textTheme.headlineSmall,
        contentTextStyle: AppTypography.textTheme.bodyMedium,
      ),
      // Material 3 tints every surface it isn't told about with the seed
      // colour: left unthemed, the menu drawer, the date/time pickers and
      // popup menus all came out a pinkish off-white that matches nothing
      // else in the app. They are plain white surfaces like the dialogs and
      // sheets beside them.
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.level4,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.level3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
          side: const BorderSide(color: AppColors.border),
        ),
        textStyle: AppTypography.textTheme.bodyMedium,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        elevation: AppElevation.level4,
        showDragHandle: true,
        dragHandleColor: AppColors.border,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.deepMaroon,
        contentTextStyle: AppTypography.textTheme.bodyMedium?.copyWith(color: AppColors.surface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusControl)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceMuted,
        side: const BorderSide(color: AppColors.border),
        labelStyle: AppTypography.textTheme.labelMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusPill)),
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
