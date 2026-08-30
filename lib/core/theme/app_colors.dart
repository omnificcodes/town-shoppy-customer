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

  // Silver wallet — deliberately outside the warm brand palette so a coin
  // balance never visually competes with a promotional badge (per the
  // design doc's "Silver vs. Gold" section). Cool, calm, metallic-gray.
  static const silver = Color(0xFF8A94A6);
  static const silverLight = Color(0xFFEEF0F4);
  static const silverDark = Color(0xFF4B5468);

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
}
