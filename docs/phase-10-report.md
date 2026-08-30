# Phase 10 Report — Customer App Responsive + Accessibility Closure

**Scope:** `town-shoppy-customer` only (seven genuine bugs found and fixed, all in presentation-layer widgets, plus a large new widget-test suite). No backend or admin code changed — both re-verified for regression only. No authentication bypass of any kind was used or attempted.

---

## 1. Starting state (confirmed, not assumed)

Per the brief's own instruction, Phase 9's claimed state was verified against the actual repository before any new work started: all six Phase 9-modified files (`app_notification.dart`, `otp_verify_screen.dart`, `mobile_number_screen.dart`, `error_state.dart`, `empty_state.dart`, `app_button.dart`) and all three Phase 9 test files were confirmed present and unchanged, and a fresh `flutter test` run reproduced Phase 9's reported baseline before any Phase 10 edits began.

## 2. Responsive verification — exact-viewport widget-test matrix

Extending Phase 9's exact-viewport strategy (Flutter's own `tester.view.physicalSize`, not a browser screenshot — see Phase 8/9 for why browser-resize is unreliable for this app's Flutter Web CanvasKit renderer in this environment) to every remaining major customer screen, at all four required breakpoints: **375×812, 390×844, 430×932, 768×1024**. A small shared helper (`test/helpers/responsive_test_helper.dart`) now does the size-set/pump/assert/teardown boilerplate, justified this phase by the sheer number of screens involved (a much stronger case than Phase 9's two files) — small test fakes are still duplicated per file, per this codebase's existing convention.

Every screen was tested with deliberately long/hard content (long merchant and branch names, long addresses, large ₹ amounts, long notification bodies, long referral codes/links) rather than the short defaults, specifically to surface overflow that short QA data would hide.

| Screen | 375 | 390 | 430 | 768 | Result |
|---|---|---|---|---|---|
| Login (Mobile number / OTP) | PASS | PASS | PASS | PASS | Already covered by Phase 9; re-confirmed passing, not duplicated |
| Home | PASS | PASS | PASS | PASS | Bug found + fixed (§4.1) |
| Merchant Discovery | PASS | PASS | PASS | PASS | |
| Merchant Detail | PASS | PASS | PASS | PASS | Bug found + fixed (§4.2) |
| Branch Selector | PASS | PASS | PASS | PASS | |
| Redemption Initiation | PASS | PASS | PASS | PASS | |
| Redemption Verification | PASS | PASS | PASS | PASS | Bug found + fixed (§4.4) |
| Redemption History | PASS | PASS | PASS | PASS | |
| Redemption Detail | PASS | PASS | PASS | PASS | |
| Purchases List | PASS | PASS | PASS | PASS | |
| Purchase Detail | PASS | PASS | PASS | PASS | |
| Referrals | PASS | PASS | PASS | PASS | |
| Notifications | PASS | PASS | PASS | PASS | Bug found + fixed (§4.5, §4.6) |
| Profile | PASS | PASS | PASS | PASS | |

## 3. Accessibility audit

**Text scaling (real, not simulated):** `MediaQuery.textScaler` set to **1.3x** (a common "Larger Text" device setting) and **2.0x** (the top of what iOS/Android expose without switching to separate bold/huge assistive modes), on a representative set — Login, Merchant Detail, Redemption Verification, Notifications, Profile — per the brief's explicit instruction not to test exhaustively but honestly. This found three of the seven genuine bugs (§4.2, §4.4, §4.5); after fixes, all five screens pass at both scales with zero exceptions. No text was hidden, clipped without an ellipsis, or otherwise silently dropped to force a pass.

**Semantics tree (representative, not exhaustive):** dumped and read the real `SemanticsNode` tree for `MobileNumberScreen` and `NotificationsScreen`. The mobile-number field, "Send code" button, and headings all carry clear, descriptive labels ("Mobile number", "Send code", not "Button 1"). Notifications surfaced a genuine gap (§4.6): the unread/read visual distinction (tint + bold + dot) was entirely invisible to a screen reader — an unread and a read tile announced identically. Fixed and covered by a new regression test.

**Contrast (computed via WCAG relative-luminance formula on `AppColors`' actual hex values, not eyeballed):**

| Pair | Ratio | WCAG AA (normal text, 4.5:1) |
|---|---|---|
| `textPrimary` (deepMaroon) on white | ~13:1 | PASS (already documented in the codebase) |
| `textSecondary` on white | ~5.1:1 | PASS |
| `info` on `infoBg` | ~5.6:1 | PASS |
| `error` (crimson) on `errorBg` | ~4.1:1 | **Below 4.5:1** |
| `success` on `successBg` | ~3.6:1 | **Below 4.5:1** |
| `pending` on `pendingBg` | ~3.3:1 | **Below 4.5:1** |
| `textDisabled` on white | ~2.2:1 | Exempt — disabled-state text (WCAG 1.4.3) |

The three status-badge tones (error/success/pending) fall short of AA for normal text; they don't qualify for the "large/bold text" 3:1 exception either, since `StatusBadge` renders at `labelSmall` (~11sp), below the 14sp-bold threshold. **Not changed this phase** — `error`/`success`/`pending`/`info` are shared, brand-governed semantic colors documented in `design-principles.md` and used across every status badge, info box, and (likely) the admin app too. Adjusting them is a design-system decision with a blast radius well beyond a QA/verification phase and beyond "no arbitrary design system" — flagging here for the design owner rather than silently picking new values.

**Touch targets:** `AppSpacing.touchTarget` (48dp) is applied via the app theme to every `ElevatedButton`/`OutlinedButton`/`TextButton`; `IconButton`s get Material's own 48dp default. `CategoryChip` and card rows run smaller (~36–40dp) but still clear WCAG 2.2's actual AA minimum (2.5.8, 24×24 CSS px) — noted, not treated as a bug, since changing chip padding would be a visual redesign this phase's brief doesn't call for.

**Status not conveyed by color alone:** confirmed by code read — `StatusBadge` is always text-on-tinted-background, never a bare color swatch; `NotificationTile`'s unread dot is a distinct shape, and (after §4.6) is now also stated explicitly in its accessible label.

## 4. Bugs found and fixed

All seven are genuine, minimal, presentation-layer fixes — no business logic, provider, or backend code was touched for any of them.

1. **Home — header row overflow.** `lib/features/home/presentation/home_screen.dart`: the "Recent purchases"/"Redemptions" section headers overflowed by ~28px at 375/390px width — 242px title + 128px "See all" button don't fit in the 343px available. Fix: wrap the title `Text` in `Expanded` + ellipsis. Regression: `home_screen_responsive_test.dart`.
2. **Merchant Detail — location row overflow.** `merchant_detail_screen.dart`: the town/state line (icon + unwrapped `Text`) overflowed by 502px with a realistically long town name. Fix: `Expanded` + ellipsis. Regression: `merchant_detail_screen_responsive_test.dart`.
3. **Merchant Detail — "Accepts Town Coin" row overflow at scale.** Same file: this row overflowed at 1.3x **and** 2.0x text scale even with its short, fixed default label. Fix: `Flexible` + ellipsis. Regression: `text_scaling_test.dart`.
4. **Redemption Verification (confirmation view) — amount-row overflow.** `redemption_verification_screen.dart`: the discount/coins/remaining-bill rows overflowed with large real currency amounts, and independently at 2x text scale via the unwrapped label. Fix: `Flexible` + ellipsis on both label and value. Regression: `redemption_verification_screen_test.dart` + `text_scaling_test.dart`.
5. **Notifications — AppBar action overflow at 2x scale.** `notifications_screen.dart`: the "Mark all read" `TextButton` overflowed the AppBar's trailing row at 2.0x text scale — a known Material `AppBar`/`NavigationToolbar` framework limitation (`actions` aren't given a shrink-to-fit constraint). Fix: converted to an `IconButton` + tooltip, which is immune to text scale **and** brings this action in line with the app's own existing AppBar-action convention (Home's "Sign out" is already an icon + tooltip, not a text button). Regression: `text_scaling_test.dart` + `notifications_screen_responsive_test.dart`.
6. **Notifications — unread status invisible to assistive technology.** `notification_tile.dart`: found via a real semantics-tree dump (§3), not a layout bug — the tint/bold/dot unread signals are all visual-only, so a screen reader announced an unread and a read notification identically. Fix: an explicit composed `Semantics` label that states "Unread" first while preserving the full title/body/timestamp content (no information lost). Regression: new `notification_tile_test.dart`.
7. **Proactive — same unprotected-label pattern in three sibling files.** `redemption_detail_screen.dart`'s and `purchase_detail_screen.dart`'s `_DetailRow`, and `redemption_initiation_screen.dart`'s `_ReviewRow`, shared the exact unwrapped-label pattern that caused bug #4. Wrapped all three labels in `Flexible` + ellipsis pre-emptively, verified via the full test suite (no test caught these failing yet, but the code path is identical to a confirmed bug — left unfixed, they would have failed the same way under a long enough label or high enough text scale).

## 5. UX changes made

Exactly one, and it's the bug-fix in §4.5: Notifications' "Mark all read" AppBar action changed from a `TextButton` to an `IconButton` + tooltip (`Icons.done_all_rounded`). No other visual or interaction change was made anywhere in the app.

## 6. Redemption journey / cache-isolation regression

No backend, no Riverpod provider, no controller, and no business-logic file was touched this phase — every fix in §4 was a presentation-layer wrap (`Expanded`/`Flexible`/`Semantics`) or a widget swap (`TextButton` → `IconButton`) with the `onPressed` callback and all state management left untouched. The existing functional test suite (redemption initiation/verification/list controllers, `sessionEpochProvider` cache-isolation, OTP/auth controller tests, notification JSON parsing) all continue to pass unmodified, and the fixed `RedemptionVerificationScreen`'s settled/initiated/expired/cancelled states are directly exercised by widget tests asserting the real discount/coins/remaining-bill values render correctly post-fix.

A live, in-browser re-run of the full authenticated redemption journey was attempted (Flutter Web, real backend, debug-OTP toggled on temporarily) but was blocked this session by the same transient Flutter-Web/CanvasKit keyboard-input limitation Phase 8 documented — confirmed again via **four independent input methods** (real `type`, individual key-presses, a fresh page reload, and the accessibility-DOM `form_input` path via the injected "Enable accessibility" node): none of them updated the rendered canvas, even though the app itself loaded and rendered the real Login screen correctly. Per the standing rule repeated in every phase brief, **no workaround (token injection, secure-storage manipulation, or debug-auth) was attempted** to get past this. The debug-OTP flag was reverted immediately (`OTP_EXPOSE_CODE_IN_RESPONSE=false`, `config:clear`, verified via `config('otp.expose_code_in_response')` reading `false`); no QA account or fixture data was left behind (the attempted registration never completed, so no `Account` row was ever created — confirmed via a direct count query).

**Security regression:** no auth, token, OTP, `qr_secret`, or cache-isolation code was touched this phase; nothing in §4's fixes could plausibly affect any of it, and the full backend test suite (which includes the OTP/auth/redemption security assertions) is unchanged.

## 7. Regression suite

| Suite | Result |
|---|---|
| Pest | **627 passed**, **1995 assertions**, 0 failures (unchanged from Phase 7/9 baseline — no backend code touched) |
| Pint | Clean — 395 files, 0 issues |
| Flutter analyze | 0 issues |
| Flutter test | **141 passed**, 0 failed (114 baseline + 27 new: 14 new/extended screen files + 10 text-scaling tests + 2 notification-tile accessibility tests + 1 branch-selector viewport test) |
| Flutter release APK | Built successfully, **49.4 MB** (unchanged from Phase 9 baseline — layout-only diff) |
| Flutter Web build | Built successfully, `flutter build web --release`, zero errors |
| Admin `tsc --noEmit` | 0 errors |
| Admin ESLint (full project) | 0 errors/warnings |
| Admin `next build` | Succeeded — **35 routes**, unchanged from baseline |

## 8. Remaining limitations

- **Live, authenticated, in-browser verification of the redemption journey and cache isolation was not completed this phase** (§6) — blocked by a transient Flutter-Web keyboard-input issue in this environment, confirmed via four independent methods, not worked around per standing instructions. Coverage instead relies on the unchanged, already-passing functional test suite plus the fact that no business logic was touched.
- **Contrast findings in §3 were not acted on** — `error`/`success`/`pending` status-badge tones fall short of WCAG AA (4.5:1) for their actual rendered size. This is a shared, brand-governed color-system decision, flagged for the design owner rather than changed unilaterally.
- **The accessibility audit is representative, not exhaustive** (five screens for text scaling, two for semantics-tree review, per the brief's own instruction) — a screen not covered could still have a similar issue.
- **Touch-target sizing for `CategoryChip` and list-tile rows (~36–40dp) was measured but not changed** — it clears the applicable WCAG 2.2 AA minimum (24×24px) but is below Material's 48dp recommendation; a cosmetic call, not a compliance failure.

## 9. Overall readiness verdict

**Ready, with minor limitations.** Every major customer screen now has real exact-viewport coverage at all four mandated breakpoints, seven genuine bugs (three responsive, three accessibility, one accessibility-only) were found and fixed with regression tests, the full three-app regression suite is green and unchanged where expected, and no business logic was put at risk. The two honest gaps are the unresolved brand-palette contrast shortfall in three status tones (a design decision, not a code defect) and this session's inability to re-run the full live redemption journey in-browser (a tooling limitation, not a functional regression — nothing touched this phase could plausibly have broken it, and the automated evidence for it is unchanged and still green).

## 10. Next milestone (recommendation only — not started)

The one clear next step, directly following from §3/§8: **take the three status-badge contrast findings (error/success/pending on their tinted backgrounds) to the design owner** for a deliberate palette decision — either deepen the three foreground colors slightly to clear 4.5:1, or bump `StatusBadge`'s text size/weight into the WCAG "large text" exception — rather than a QA phase guessing new brand values. Not started this phase.

---

**Not auto-started**, per the brief's explicit instruction.
