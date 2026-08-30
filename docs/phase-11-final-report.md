# Phase 11 Final Report — Design System Contrast Closure + Final Accessibility Polish

**Scope:** `town-shoppy-customer` only (three semantic color tokens adjusted, one documentation update, one new regression-test file). No backend, no admin, and no authentication code was touched.

---

## 1. Objective

Phase 10 found that three of the customer app's four semantic status tones — `error`, `success`, `pending` — fell short of WCAG AA's 4.5:1 contrast requirement for normal text at `StatusBadge`'s actual rendered size (~11sp/bold, which does not qualify for the 3:1 "large text" exception). Phase 10 deliberately did not fix this, since `AppColors` is a shared, brand-governed palette and a QA phase guessing new values wasn't appropriate. Phase 11's objective was to resolve that gap with the smallest, most brand-safe adjustment possible, add regression coverage so it can't silently regress again, and confirm the fix doesn't destabilize anything else.

## 2. Before/after contrast table

Computed via the standard WCAG 2.x relative-luminance formula against the real hex values (cross-checked two independent ways — a standalone Node script and a Flutter widget test reading `Color.r/g/b` directly — both agree):

| Token | Before | After | Requirement | Result |
|---|---:|---:|---:|---|
| `error` on `errorBg` | 4.08:1 | **4.87:1** | 4.5 | PASS |
| `success` on `successBg` | 3.55:1 | **4.60:1** | 4.5 | PASS |
| `pending` on `pendingBg` | 3.33:1 | **4.69:1** | 4.5 | PASS |
| `info` on `infoBg` | 5.59:1 | 5.59:1 (unchanged) | 4.5 | PASS |

Also re-verified while auditing (all already passed, left unchanged):

| Pair | Ratio | Result |
|---|---:|---|
| `textPrimary` on white | ~13:1 | PASS |
| `textSecondary` on white | ~5.1:1 | PASS |
| `textDisabled` on white | ~2.2:1 | Exempt (disabled-state text, WCAG 1.4.3) |

Exact new values (`town-shoppy-customer/lib/core/theme/app_colors.dart`):

| Token | Old hex | New hex |
|---|---|---|
| `success` | `#1F9254` | `#1B804A` |
| `successBg` | `#E7F6EE` | `#EEF9F3` |
| `pending` | `#B07A00` | `#946600` |
| `pendingBg` | `#FCF1DA` | `#FDF6E7` |
| `error` | `#E50914` (aliased to `crimson`) | `#CE0812` (own value) |
| `errorBg` | `#FCE8E9` | `#FCE8E9` (unchanged) |

## 3. Design decision

**Inspection first (per the brief's own instruction, before any value was touched):** confirmed the four semantic tokens live only in `AppColors` (Dart), are used exclusively by `StatusBadge`, `InfoBox`, and status icons (`notification_type_display.dart`), and are explicitly documented as "distinct from the three reserved brand accents" (orange/crimson/yellow) — i.e. they were always meant to be independently tunable. Also confirmed the admin app (`town-shoppy-admin`) maintains a **completely separate** token system (OKLCH-based CSS custom properties in `globals.css`, with light/dark variants) — not shared with the Flutter app at all, and its own `warning` token already went through an identical contrast fix in the past (its code comment explicitly notes the raw `--warning` value failed contrast as badge text and was replaced with a `-foreground` accessible pair). This confirms the "architecture already supports separate themes" condition, so no admin changes were needed or made.

**`success`/`pending` — combined foreground+background adjustment (Option C), not foreground-only (Option A):** a foreground-only fix needed to darken `success` by roughly 15–20% and `pending` by a similar margin to clear 4.5:1 against their *current* backgrounds. A background-only fix (Option B) was tested and proven mathematically insufficient on its own — even lightening `successBg`/`pendingBg` all the way to pure white only reaches ~3.96:1 / ~3.73:1, still short of 4.5:1, because the original foregrounds weren't dark enough to begin with. A **combined** adjustment (deepen the foreground ~12–16%, lighten the background ~30–35%) reaches the same target contrast with roughly half the foreground shift a foreground-only fix would need, keeping both colors closer to their originals and the backgrounds still visibly (not washed-out) tinted.

**`error` — un-aliased from the literal brand `crimson`, not deepened as one color.** `error` was previously declared as `= crimson`, meaning the "error" semantic and the reserved Crimson Red brand accent (used for CTAs, gradients, and the notification-badge dot) were the exact same value. Deepening it in place would have moved the brand accent itself — a real branding violation. Lightening only `errorBg` was evaluated too, but reaching 4.5:1 against the *unmoved* crimson foreground requires a background luminance so high (≥0.935, vs. the current 0.843) that the tint becomes nearly indistinguishable from white — visually inconsistent with the still-clearly-tinted `successBg`/`pendingBg`/`infoBg` next to it. The chosen fix instead gives `error` its **own** value, a few percent darker than `crimson`, while `crimson` itself (and every non-status usage of it) is completely untouched. The two are the same red family and read as identical at a glance.

## 4. Visual impact

**Customer app:** every change is a same-hue-family shift of a few percentage points — visually a very subtle deepening of green/amber/red and a very subtle lightening of their tinted backgrounds. No new color was introduced, no gradient or reserved brand accent (orange/crimson/yellow) moved, and no component was restructured. Affected screens (all inspected at the code level; a live-browser pixel check was attempted but blocked — see §8): Home (recent-purchases status badges), Purchases List/Detail, Redemptions List/Detail, Notifications (status icons via `notification_type_display.dart`), Profile (`InfoBox` account-status card).

**Merchant Admin / Association Admin / Super Admin:** **no changes made or needed.** Confirmed via inspection (§3) that these apps' status/severity/payment/subscription badges (`status-badge.tsx`, `severity-badge.tsx`, `payment-status-badge.tsx`, `subscription-status-badge.tsx`) run on an entirely independent, OKLCH-based token system in `town-shoppy-admin/src/app/globals.css`, unrelated to the Flutter `AppColors` file this phase touched. The admin `success`/`info`/`destructive` badge tones were not re-audited for contrast in this phase — the codebase already shows evidence of a deliberate, per-token contrast-aware convention there (the `warning`/`warning-foreground` pair), but auditing three more admin-side OKLCH tokens is a distinct, separate-codebase piece of work outside this phase's explicit Customer-app scope; noted as a possible future item, not started.

## 5. Accessibility

- **Contrast:** all four status tones now clear WCAG AA's 4.5:1 for normal text, with real safety margin (4.60–5.59:1), not the bare minimum — verified twice independently (§2) and locked in by a new automated test (§6/§11).
- **Status semantics:** `purchaseStatusTone`/`redemptionStatusTone` (the functions mapping backend status strings to `success`/`pending`/`error`/`neutral`) were not touched — `recorded`→success, `disputed`→pending, `voided`→error, `settled`/`verified`→success, `initiated`→pending, `expired`/`cancelled`→error, all unchanged and confirmed by reading both files directly.
- **Notification semantics:** the Phase 10 fix making unread notifications announce "Unread" to assistive technology is a `Semantics` label composition, entirely independent of color — re-confirmed still passing via `notification_tile_test.dart` (unchanged, part of the full green suite).
- **Text scaling:** the full Phase 10 `text_scaling_test.dart` suite (1.3x/2.0x on Login, Merchant Detail, Redemption Verification, Notifications, Profile) re-ran unchanged and green — color values don't affect layout, and no typography was touched this phase (confirming the brief's preference: the palette-adjustment route was sufficient, no text-size change was needed).

## 6. Bugs discovered

None beyond the contrast gap this phase was scoped to close (which was already known going in, not newly discovered). No unrelated cosmetic changes were made.

## 7. Regression

| Suite | Result |
|---|---|
| Pest | **627 passed**, **1995 assertions**, 0 failures (unchanged — no backend code touched) |
| Pint | Clean — 395 files, 0 issues |
| Flutter analyze | 0 issues |
| Flutter test | **147 passed**, 0 failed (141 Phase 10 baseline + 6 new contrast-regression tests) |
| Flutter release APK | Built successfully, **49.4 MB** (unchanged — no layout/asset change) |
| Flutter Web build | Built successfully, zero errors |
| Admin `tsc --noEmit` | 0 errors |
| Admin ESLint | 0 errors/warnings |
| Admin `next build` | Succeeded — **35 routes**, unchanged from baseline |

## 8. Remaining limitations

- **A live, authenticated, in-browser visual check of the new colors was attempted but blocked** — the same Flutter-Web/CanvasKit environment issue documented in Phase 8/10 was present again this session, and this time extended beyond keyboard input to mouse-click form submission not registering either, confirmed across a fresh page reload. Per standing instructions, no bypass was attempted; the app's real Login screen was confirmed rendering correctly, and the color-correctness evidence instead rests on the WCAG math (verified two independent ways) plus the full widget-test suite exercising every screen that renders these colors.
- **Admin's own `success`/`info`/`destructive` badge tones were not contrast-audited this phase** (§4) — confirmed independent from the customer app and out of this phase's scope, not verified pass/fail.
- **Live redemption-journey and cache-isolation re-verification (§16/§17 of the brief) relied entirely on existing automated evidence**, not a fresh live walkthrough — blocked by the same tooling issue above. The relevant widget tests (`redemption_verification_screen_test.dart`'s settled/initiated/expired/cancelled states and history-invalidation test, `redemptions_list_controller_test.dart`, `auth_controller_test.dart`'s session-epoch behavior) all render the exact `StatusBadge` code paths this phase changed and all pass unchanged.

## 9. Overall readiness

**READY.** All four semantic status tones now meet WCAG AA with real margin, the fix is the smallest brand-safe change available (no reserved brand accent moved, no new color introduced, no component redesigned), a deterministic regression test now guards against silent future regressions, and the complete three-app regression suite is green and unchanged everywhere it should be. The one honest gap is the same live-browser verification limitation carried over from Phase 10 — a tooling issue, not a code defect, and not something this phase's changes could plausibly have caused or worsened.

## 10. Next milestone (recommendation only — not started)

The one clear next step, directly following from §4/§8: **a short, separate admin-focused pass auditing `success`/`info`/`destructive` badge contrast in `town-shoppy-admin`'s own OKLCH token system**, following the same pattern already used for `warning` there. This is genuinely separate work (different codebase, different color space, different token architecture) and was explicitly out of scope for this Customer-app-focused phase. Not started this phase.

---

**Not auto-started**, per the brief's explicit instruction.
