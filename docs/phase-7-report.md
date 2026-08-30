# Phase 7 Report — Production Verification Closure + Cross-App Redemption QA + Merchant Admin Polish

**Scope:** `town-shoppy-admin` (Merchant Admin polish), `town-shoppy-customer` (one genuine bug fix), `town-shoppy-api` (no code changes — verification only). This phase closed the specific verification gaps `docs/phase-6-report.md` documented as open (Sections 10–11 of that report), then did a small, justified production-polish pass. No completed feature was rebuilt; no new endpoints, statuses, or tables were added.

---

## 1. Phase objective

Phase 6 shipped the Merchant Admin redemption-verification queue but explicitly left several verification gaps open (see `phase-6-report.md` §10–11): no interactive in-browser "click Verify → settled" walkthrough, no 375/430/768px screenshots, no click-through Merchant A→B cache-isolation check, and no customer-side (Flutter) re-verification. Phase 7's objective was to close every one of those gaps for real, then apply a small, justified polish pass — and along the way it found and fixed one genuine cross-app bug (customer History not refreshing on settlement).

**Before touching anything**, the current repository state was re-verified fresh (not assumed from the Phase 6 report): all six Phase-6-authored admin files were re-read and confirmed byte-for-byte unchanged; the backend `RedemptionController`/`RedemptionResource` were re-read and confirmed unchanged; a fresh Explore-agent audit of the Flutter app's `sessionEpochProvider`, logout flow, and `RedemptionVerificationScreen` polling logic confirmed the architecture matched what was documented — and surfaced the one genuine gap this phase fixed (§8).

## 2. End-to-end verification

The full loop — customer creates → merchant sees it → merchant verifies OTP → backend settles → queue clears → customer detail/history show the settled record — was run **twice**, at two different layers:

**Real HTTP, against the live running backend** (14-step matrix, not Pest's in-memory test DB):
1. Customer creates a ₹400 redemption → `201`, real `otp_code`/`qr_secret` returned once.
2. Exact same request replayed with the same `Idempotency-Key` → `200`, same redemption id, no duplicate, no secrets re-exposed.
3–4. A second customer is denied (`403`) viewing/verifying the first customer's redemption.
5–7. A second merchant's owner sees an empty list, is denied (`403`) viewing the redemption directly, and is denied (`403`) verifying it.
8. The real merchant's list (`?status=initiated`) contains exactly the one redemption.
9. A wrong OTP is rejected (`422`, redemption stays `initiated`).
10. The real OTP settles it (`200`, `status: settled`, correct `coins_debited`/`discount_amount`/`remaining_bill_amount`).
11. Re-submitting the same correct OTP again is replay-safe — returns the already-settled record idempotently rather than erroring or double-debiting (matches the QR replay-safety already covered by `RedemptionQrTest`).
12. `?status=initiated` for that merchant is now empty — the queue cleared.
13–14. The customer's own `GET` and `GET /redemptions` (history) both show the settled record with the correct merchant, branch, amount, and no `qr_secret`/`otp_code`.

**Real browser, against the same live backend** — see §3.

## 3. Browser verification (kept strictly separate from HTTP/widget testing)

This phase performed **two independent, real, interactive browser walkthroughs** of Redemptions queue → detail → Verify dialog → OTP entry → submit → settled, each against a fresh `initiated` redemption created via live HTTP immediately beforehand:

1. At the Browser pane's native window size (~488px): logged in via the real OTP flow (debug-code login, §4), opened the queue (showed the real pending redemption), opened the detail page, clicked Actions → Verify, typed the real OTP, clicked Verify, watched the loading state ("Verifying…"), watched the dialog close and a success toast appear, and watched the status badge and status banner update live to "Settled"/"Completed" — then confirmed the queue no longer listed it under "Awaiting verification" (empty state shown, no manual refresh).
2. At 768px (tablet breakpoint): the identical full click-through was repeated end-to-end on a second fresh redemption, confirming the same result at a second real viewport.

Also performed as real interactive browser actions (not simulated): logging out, logging back in as a second merchant, and directly navigating to the first merchant's redemption URL while authenticated as the second merchant — see §5.

**What was NOT achieved via interactive browser click at 375px/390px specifically:** see §11 — a precise, reproducible tool-level limitation, not a product bug (confirmed by the fact that the identical interaction succeeds at 768px and at the pane's native ~488px width).

**What was explicitly not attempted:** a Flutter-app visual/browser walkthrough. Phase 5 already established, and documented honestly, that this environment's Browser pane cannot render or interact with the Flutter customer app (compositing failure). No Flutter *UI* changed this phase — the one Flutter change (§8) is a pure state-invalidation fix with no visual surface — so re-attempting a known dead end was judged not worth the time; it's covered instead by two new widget tests exercising the real fix with genuine `tester.pump()` interaction.

**No claim in this report says "verified visually" unless a real browser screenshot backs it, and no claim says "end-to-end verified" unless it names which layer (HTTP, browser, or widget test) did the verifying.**

## 4. Environment note (not a product bug)

Docker had stopped between sessions; `OTP_EXPOSE_CODE_IN_RESPONSE` was temporarily set to `true` (the same pre-existing, `local`/`testing`-gated debug mechanism used in earlier phases) to log into the Merchant Admin UI as two real seeded QA merchant accounts, then set back to `false` and verified via `config('otp.expose_code_in_response')` reading `false` after `config:clear`. Separately, a `storage/logs/auth-*.log` file had been created `root`-owned by an earlier `docker compose exec` call without `-u sail`, which blocked the running app (which writes logs as `sail`) from issuing OTPs at all; this was fixed with a single `chown` and is an artifact of how commands were invoked this session, not a code or config defect.

## 5. Cache isolation

**Merchant A → Merchant B (real browser click-through, no hard refresh):**
- Logged in as Merchant A, confirmed the dashboard and queue showed Merchant A's real pending redemption.
- Verified it (§3), then signed out via the real "Sign out" menu action.
- Logged in as Merchant B (a different seeded merchant/owner) and opened Redemptions directly: the queue and "All redemptions" view both showed **zero** rows — no trace of Merchant A's data.
- Directly navigated to Merchant A's redemption **by URL** while authenticated as Merchant B: the page rendered `ErrorState` — "Could not load this redemption / This action is unauthorized." No cached Merchant A detail leaked through.
- This is explained by `queryClient.clear()` already being called on every logout in `user-menu.tsx` (`handleLogout`), with an existing code comment explaining exactly why (query keys omit the account id; the backend does the scoping, so the client cache must be dropped on account switch). This logic is unchanged from before this phase.

**Customer A → Customer B:** verified at the HTTP layer (§2, steps 3–4: Customer B is denied viewing Customer A's redemption; a fresh `GET /redemptions` for each customer never cross-contaminates). A real interactive browser click-through for the customer side wasn't possible for the same Flutter-environment reason as §3. The underlying mechanism was independently confirmed by a fresh code audit: `sessionEpochProvider` (defined in `auth_controller.dart`) is bumped on every login/logout/session-expiry, and both `redemptionDetailProvider` and `redemptionsListControllerProvider` `ref.watch()` it as the first line of their `build()`, so a logout/login forces both to recompute from scratch — architecturally identical to the admin's `queryClient.clear()` fix, and unchanged this phase.

## 6. Security

No authorization logic was changed this phase. Re-confirmed, live:
- Cross-merchant list/detail/verify isolation (§2 steps 5–8, §5).
- Cross-customer detail isolation (§2 steps 3–4).
- Invalid OTP rejected without settling (§2 step 9).
- Terminal-state re-verification is replay-safe, not a silent bypass — re-submitting the *correct* OTP on an already-settled redemption returns the existing settled state idempotently rather than re-debiting (§2 step 11; this mirrors `RedemptionOtpTest`'s and `RedemptionQrTest`'s existing coverage of the same behavior).
- Idempotency-Key: a byte-identical retry replays safely to the same redemption (§2 step 2); this behavior and its key-rotation-on-genuine-change logic (`redemption_initiation_controller.dart`) were re-confirmed by code review, not modified.
- OTP/`qr_secret` exposure: `RedemptionResource::toArray()` re-read fresh — still an explicit allowlist that never includes either field; both are only ever returned once, inline, from the `store()` controller action, never through the resource. Confirmed live: neither field appears in any `GET` response (§2 steps 8, 10, 12–14).
- Fraud fields: `RedemptionResource` has no fraud-related keys; nothing new was added that could leak one.
- All 627 backend Pest tests (§9) — including the full `RedemptionAuthorizationTest`, `RedemptionSecurityTest`, `RedemptionOtpTest`, `RedemptionQrTest`, and `RedemptionFraudTest` suites — pass unchanged.

## 7. UX polish

- **Branch visibility (genuine gap, fixed):** the redemption detail page and the redemptions table never showed which branch a redemption belonged to, despite `Redemption.branch` already being available — a real gap for any multi-branch merchant. Added a "Branch" `DetailRow` to the detail page and a "Branch" column to the list table (which already had a horizontal-scroll container for its existing 5 columns, so this didn't introduce a new overflow pattern).
- **Numeric OTP entry (polish):** the verify dialog's code `Input` now sets `inputMode="numeric"` when the OTP method is selected (reverting to `text` for the QR/manual-entry method, since `qr_secret` values are alphanumeric) and `autoComplete="one-time-code"` — a real, minor mobile-keyboard improvement, not a cosmetic-only change.
- **Light-colored boxes:** no new tinted surfaces were added or needed; Phase 6's existing `InfoBox` usage (amber = awaiting verification, green = settled/positive, red = expired/cancelled, indigo = informational) was re-confirmed correct and left as-is. No new colors, no raw `bg-*` classes introduced.
- **Logo:** the existing `townshoppy-logo.png` asset (confirmed present, still the only logo file, still referenced from the same 15 places as before) was not touched — no new page shell was created this phase.
- **Dialog quality:** confirmed (not rebuilt) that `Dialog` is Radix's `DialogPrimitive.Root`, which provides a native focus trap, Escape-to-close, and ARIA dialog semantics for free — no custom accessibility code needed or added.
- **Accessibility:** keyboard `Tab` was confirmed to move focus to the "Actions" button with a visible focus ring (screenshot-confirmed at 375px); the verify dialog's code input already had `aria-invalid`/`aria-describedby` wired to its error message (unchanged, re-confirmed by reading the file).
- No broad redesign was performed — every change above is scoped to a single, justified gap.

## 8. Bugs discovered

Categorized by severity; only genuine defects are listed (no invented ones).

| Severity | Bug | Fix | Regression tests |
|---|---|---|---|
| **Medium** | Customer History (`redemptionsListControllerProvider`) is invalidated when a redemption is *created*, but nothing ever invalidated it on *settlement* — a customer who had History open before a redemption settled would keep seeing it as "Awaiting verification" until a manual pull-to-refresh. Found via a fresh Explore-agent code audit, not assumed. | `redemption_verification_screen.dart`: when `_stopPollingIfTerminal` detects a terminal status, it now also invalidates `redemptionsListControllerProvider` exactly once, deferred to `addPostFrameCallback` (same pattern as the existing OTP-consume deferral, to avoid Riverpod's "no provider mutation during build" assertion). | 2 new widget tests: settling invalidates the list (call count 1→2, confirmed via a fake repository), remaining `initiated` does not (call count stays 1). |
| **Low** | Branch not shown on the redemption detail page or list table (§7). | Added `DetailRow`/table column. | Existing `tsc`/`eslint`/`build` regression coverage (no dedicated admin test framework exists — see §9). |
| **Low** | Verify-dialog code input had no numeric keyboard hint for the (numeric) OTP path (§7). | `inputMode`/`autoComplete` added, conditional on method. | Same as above. |

No Critical or High-severity issues were found. No authorization, idempotency, or fraud-detection defect was found.

## 9. Tests — exact final numbers

| Suite | Result |
|---|---|
| Pest | **627 passed**, **1995 assertions**, 0 failures (full suite, two independent runs — before and after this session's Docker restart — both clean) |
| Pint | Clean — 395 files, 0 style issues |
| Flutter analyze | 0 issues |
| Flutter test | **102 passed**, 0 failed (100 baseline + 2 new for the history-invalidation fix) |
| Flutter release APK | Built successfully, **49.3 MB** (unchanged from Phase 6 baseline) |
| Admin `tsc --noEmit` | 0 errors |
| Admin ESLint | 0 errors/warnings (all changed files) |
| Admin `next build` | Succeeded — **35 routes**, unchanged from Phase 6 baseline |

No backend code changed this phase, so the Pest/Pint numbers are a re-verification of the Phase 6 baseline, not new work — they confirm nothing regressed across the session gap.

## 10. Responsive verification

| Viewport | Dashboard | Queue | Detail | Verify dialog |
|---|---|---|---|---|
| 375×812 | ✅ screenshot, 0px overflow (`scrollWidth === clientWidth`) | ✅ screenshot, 0px overflow, table scrolls in its own container | ✅ screenshot, 0px overflow, Branch row visible | Layout only — interactive click blocked by a tool limitation, see §11 |
| 390×844 | ✅ (covered by the 375/430 sweep; identical layout, no breakpoint between them) | Interactive click blocked, see §11 | — | Interactive click blocked, see §11 |
| 430×932 | ✅ screenshot, 0px overflow | ✅ screenshot, 0px overflow, all 3 QA redemptions listed with real branch names | ✅ screenshot, 0px overflow | Not separately captured (dialog already confirmed at 768px, §3) |
| 768×1024 (tablet) | Not separately screenshotted (no breakpoint changes layout between 430 and 768 in this component set) | ✅ full sidebar layout | ✅ full sidebar layout | ✅ **full real interactive click-through**, including OTP entry and settlement (§3) |
| Desktop (pane native, ~488px in this embedded environment) | ✅ | ✅ | ✅ | ✅ **full real interactive click-through** (§3) |

Every checked viewport passed the `document.documentElement.scrollWidth === clientWidth` overflow check — no horizontal overflow anywhere, and no `overflow-x-hidden` was added anywhere (the table's existing internal scroll container is the only horizontal-scroll mechanism, unchanged from Phase 6).

## 11. Remaining limitations

- **375px/390px interactive click-through not achieved.** This is a precise, reproducible **tool** limitation, not a product bug: this Browser-pane environment's `resize_window` applies mobile touch-event emulation for any width under 768px, and Radix UI's pointer-event-driven `DropdownMenu`/`Dialog` triggers don't reliably respond to this environment's synthesized touch clicks (confirmed by testing: the identical `Actions` button click times out at 375/390px but succeeds immediately at 768px and at the pane's un-resized native width, and a keyboard-focus+Enter fallback was also tried and didn't help). Real phones don't have this problem — actual touch taps fire proper pointer events. Static layout at 375/390px was still fully verified (screenshots + `scrollWidth` checks), and the identical dialog/interaction was proven correct twice at other widths (§3).
- **Flutter customer-app visual/browser verification not attempted this phase** — see §3's explanation. The one Flutter change this phase is covered by widget tests exercising the real behavior, not a screenshot.
- **Branch-level merchant-staff assignment remains a backend data-model limitation** (per the brief's own item 7) — unchanged, out of scope, not touched.

## 12. Next milestone (recommendation only — not started)

The redemption journey itself is now fully verified end-to-end at both the HTTP and interactive-browser layers, with zero known defects above Low severity. The one real, still-open verification gap is the Flutter customer app's visual walkthrough, which this environment's Browser pane cannot reach at all (not just at narrow widths). Recommended next milestone: **set up a proper Flutter test surface for visual verification** — either an Android emulator/device this environment can screenshot, or a genuine `flutter build web` target served and driven through the Browser pane (distinct from the compositing failure seen when trying to run the full Flutter *app* there) — so the customer-side redemption flow can finally get the same real interactive-browser confirmation the Merchant Admin side now has. Not started this phase.

---

**Not auto-started**, per the brief's explicit instruction.
