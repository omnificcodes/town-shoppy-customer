/// Consistent spacing scale — comfortable mobile spacing, not cramped
/// enterprise density (design-principles.md's "premium means restrained,
/// not decorated" — generous white space is part of that, not a bonus).
///
/// Every padding/gap in the app should be one of these. `xxs` and `smd`
/// exist because 2 and 12 kept appearing as literals (hairline gaps between
/// a title and its caption; the gap between a card's rows); naming them is
/// what stops 3, 5, 6, 7, 10 and 14 from creeping in next to them.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double smd = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Horizontal page margin — every scrolling screen uses this on both
  /// sides so content edges line up screen to screen.
  static const double page = md;

  /// Vertical gap between two sections of a screen (a heading + its
  /// content counts as one section).
  static const double section = lg;

  // Radius scale. Cards/tiles use [radiusMd]; controls (buttons, inputs)
  // use [radiusControl]; only chips, avatars and segmented toggles are
  // fully round via [radiusPill].
  static const double radiusXs = 6;
  static const double radiusSm = 10;
  static const double radiusControl = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double radiusXl = 28;
  static const double radiusPill = 999;

  static const double touchTarget = 48;
}

/// Fixed sizes for controls and chrome, so a "large button" or "the nav
/// bar" is the same height everywhere instead of 44/48/52/56/58 by screen.
class AppSize {
  AppSize._();

  static const double controlSm = 40;
  static const double controlMd = AppSpacing.touchTarget;
  static const double controlLg = 56;

  static const double field = 56;
  static const double navBar = 64;
  static const double fab = 60;

  /// Width reserved in the bottom bar for the docked [fab] plus its border
  /// and notch margin, so the FAB never sits over a tab's label.
  static const double fabSlot = 76;

  static const double avatarSm = 32;
  static const double avatarMd = 40;
  static const double avatarLg = 56;
}

/// Icon size scale — seven sizes instead of the twenty-six the app had
/// accumulated. [lg] (24) is the default interactive icon size.
class AppIconSize {
  AppIconSize._();

  static const double xs = 14;
  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 28;
  static const double display = 40;
  static const double hero = 64;
}
