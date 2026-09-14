import 'package:flutter/material.dart';

/// TownShoppy customer-app brand palette.
///
/// Source of truth: `town-shoppy-api/docs/product/design-principles.md`.
/// That document specifies the three brand accents (orange/crimson/yellow)
/// and names "Dark Maroon / Deep Brown" as the primary text-on-white color
/// without picking an exact value — [deepMaroon] is that chosen value,
/// picked here for WCAG AA contrast against white (~13:1) and recorded back
/// in the design doc.
///
/// Core rule from that doc: white/near-white is the canvas, saturated
/// accent color is used only for CTAs, badges, active states, and reward
/// moments — never as a full-screen background behind body content.
class AppColors {
  AppColors._();

  // Brand accents.
  static const orange = Color(0xFFFF6B00); // primary accent / brand
  static const crimson = Color(0xFFE50914); // secondary accent / urgency
  static const yellow = Color(0xFFFFD600); // tertiary accent / reward moments
  static const deepMaroon = Color(0xFF3D1414); // text-on-white, dark contrast

  // Neutral surfaces.
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFFAF8F6);
  static const border = Color(0xFFEFE7E2);
  static const textPrimary = deepMaroon;
  static const textSecondary = Color(0xFF7A6B66);
  static const textDisabled = Color(0xFFBBAEA9);

  // `silver`/`silverLight`/`silverDark` remain the app's general neutral/
  // muted tone (AppTone.neutral below, plus several unrelated inactive-icon
  // call sites) — kept as-is for that role.
  static const silver = Color(0xFF8A94A6);
  static const silverLight = Color(0xFFEEF0F4);
  static const silverDark = Color(0xFF4B5468);

  // Town Coin gold — the coin's own visual identity (balance hero, coin
  // glyph, ledger amounts, TU tag). Note: design-principles.md's "Silver
  // vs. Gold" section reserves gold specifically for a future *merchant*
  // wallet and asks that it stay visually distinct from the customer
  // wallet; using gold here for the customer-facing Town Coin is a
  // deliberate, explicit deviation from that reservation, not an oversight.
  static const gold = Color(0xFFB8860B);
  static const goldLight = Color(0xFFFBF3D9);
  static const goldDark = Color(0xFF7D5F0C);

  // Semantic status colors — distinct from the three reserved brand accents
  // per the design doc ("neither wallet's UI should borrow the literal
  // accent colors... reserved for platform-brand moments").
  //
  // Phase 11: `success`/`pending` foregrounds and backgrounds, and `error`'s
  // foreground, were deliberately deepened/lightened from their original
  // values — a Phase 10 contrast audit found all three fell short of WCAG
  // AA's 4.5:1 for normal text at `StatusBadge`'s actual ~11sp size (which
  // doesn't qualify for the 3:1 large-text exception). Every value below is
  // chosen to clear 4.5:1 with a real safety margin (not the bare minimum)
  // while staying the same hue family — see design-principles.md's
  // "Semantic status colors" section for the full before/after contrast
  // table and the reasoning per token. `info` already passed and is
  // unchanged.
  static const success = Color(0xFF1B804A); // was 0xFF1F9254 — 3.55:1 -> 4.60:1 (paired with successBg below)
  static const successBg = Color(0xFFEEF9F3); // was 0xFFE7F6EE
  static const pending = Color(0xFF946600); // was 0xFFB07A00 — 3.33:1 -> 4.69:1 (paired with pendingBg below)
  static const pendingBg = Color(0xFFFDF6E7); // was 0xFFFCF1DA
  // `error` is deliberately its OWN value, no longer aliased to `crimson` —
  // `crimson` is the reserved brand accent (used for CTAs/gradients/badge
  // dots) and must not move; `error` is the status-semantic red (badges,
  // error text/icons/borders) and needed to deepen slightly to clear 4.5:1
  // against `errorBg`, which `crimson` at its brand value could not do
  // (4.08:1) without either moving the brand red itself or washing
  // `errorBg` out to nearly white. The two remain the same red family and
  // are visually indistinguishable side by side.
  static const error = Color(0xFFCE0812); // was crimson (0xFFE50914) — 4.08:1 -> 4.87:1
  static const errorBg = Color(0xFFFCE8E9);
  static const info = Color(0xFF3B5BA9);
  static const infoBg = Color(0xFFEAEFF9);

  // On-accent text: orange/yellow are mid-to-high luminance (design doc's
  // accessibility note) — deepMaroon reads reliably on both; white is only
  // used on crimson, which is dark enough for AA at normal text sizes.
  static const onOrange = deepMaroon;
  static const onYellow = deepMaroon;
  static const onCrimson = Color(0xFFFFFFFF);

  // Tinted accent surfaces — the ONLY way the brand accent appears behind
  // body content (design doc: saturated accent is for CTAs/badges, never a
  // background). Banners, tinted CTAs and icon badges all use these.
  static const orangeTint = Color(0xFFFFF0E3); // orange at ~8% on white
  static const orangeTintStrong = Color(0xFFFFE3CC); // orange at ~18%
  static const orangeBorder = Color(0xFFFFD2AE);

  /// The deep end of the brand orange (the Stitch redesign's `brand-700`).
  /// Two jobs [orange] can't do: carrying white text on a saturated
  /// surface (white on this is 5.2:1, white on [orange] only 2.9:1), and
  /// small orange text on white, such as "See all" links, at WCAG AA.
  static const orangeDeep = Color(0xFFC2410C);

  // Full-bleed dark surfaces (the QR scanner) and text on them.
  static const scrim = Color(0xFF000000);
  static const onScrim = Color(0xFFFFFFFF);
  static const onScrimMuted = Color(0xB3FFFFFF); // white at 70%

  // Business mode (the merchant-operator face of this app). The shell's
  // chrome -- app bar, bottom nav's active state, hero cards -- is anchored
  // on the brand's deep maroon rather than the customer mode's white/orange
  // so an owner always knows at a glance which mode they are in
  // (design-principles.md: customer and merchant surfaces must never be
  // confusable). Orange stays the CTA colour in both modes; gold is the
  // merchant wallet's identity per the same doc's "Silver vs. Gold" rule.
  static const businessInk = Color(0xFF4A1818); // hero/app-bar ground
  static const businessInkDeep = Color(0xFF2B0C0C); // gradient end, pressed states
  static const onBusinessInk = Color(0xFFFFFFFF);
  static const onBusinessInkMuted = Color(0xCCFFFFFF); // white at 80%
  static const businessTint = Color(0xFFF6EEEE); // maroon at ~6% on white
  static const businessTintStrong = Color(0xFFEBD9D9); // maroon at ~14%
  static const businessBorder = Color(0xFFE3CFCF);

  // Coupon tile's ticket-stub accent -- a deliberately bespoke navy.
  // Nothing else in the palette is navy-toned (silverDark is blue-gray, the
  // wrong hue, and used elsewhere as a neutral); scoped here rather than
  // repurposed so this one accent stays easy to find.
  static const luckyDrawNavy = Color(0xFF0B1E3F);

  /// Decorative accents for category tiles, offer tiles and coupon icons —
  /// one shared list so those screens stop each inventing their own hex.
  /// Purely visual variety (which tile is which), never a status meaning;
  /// every value clears 3:1 against white for icon use, and text is never
  /// set in these.
  static const decorativeAccents = <Color>[
    Color(0xFF2E7D32), // green
    Color(0xFFE64A19), // deep orange
    Color(0xFFD81B60), // pink
    Color(0xFF00897B), // teal
    Color(0xFF1E88E5), // blue
    Color(0xFF6A1B9A), // purple
    Color(0xFFAD1457), // magenta
    Color(0xFF6D4C41), // brown
    Color(0xFFC9A227), // gold
    Color(0xFF3949AB), // indigo
    Color(0xFFF4511E), // red-orange
    Color(0xFF8E24AA), // violet
    Color(0xFF558B2F), // olive
  ];
}

/// One semantic tone enum shared by every tinted surface (badges, info
/// boxes, inline notes) so "success" is the same pair of colors everywhere.
enum AppTone {
  info,
  success,
  pending,
  error,
  neutral;

  /// (background, foreground) for this tone.
  (Color, Color) get colors => switch (this) {
        AppTone.info => (AppColors.infoBg, AppColors.info),
        AppTone.success => (AppColors.successBg, AppColors.success),
        AppTone.pending => (AppColors.pendingBg, AppColors.pending),
        AppTone.error => (AppColors.errorBg, AppColors.error),
        AppTone.neutral => (AppColors.silverLight, AppColors.silverDark),
      };
}
