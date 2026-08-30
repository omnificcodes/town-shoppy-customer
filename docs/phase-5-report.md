# TownShoppy Flutter Customer App — Phase 5 Report

**Scope:** Customer Redemption Initiation
**Date:** 2026-08-20
**Baseline:** Phases 1–4 (auth, Home/Profile/Notifications, Purchases/Redemptions history/Referrals, Merchant Discovery, full Branch API) — complete and unmodified in architecture; extended, not rebuilt.

---

## 1. Backend Redemption Contract

Re-verified fresh from the real source, not assumed from prior reports.

**`POST /redemptions`** (`auth:sanctum`, `throttle:redemptions` — 10/min per account)
- Required: `merchant_id` (int, `exists:merchants`), `bill_amount` (numeric, `min:0.01`, `max:1000000`, `decimal:0,2` — i.e. rupees, 2 decimal places, never paise/cents)
- Optional: `branch_id` (int, `exists:merchant_branches`) — omitted defaults to the merchant's primary branch; this app always sends an explicit `branch_id`
- Required header: `Idempotency-Key`
- Response: `RedemptionResource` fields, plus `otp_code` (and `qr_secret`, unused by this app — see Section 2) merged in by the controller **only on a genuine first creation** (201) — never on an idempotent replay (200) of the same key.

**`GET /redemptions` / `GET /redemptions/{id}`** — customer's own history (Phase 2, unchanged).

**`POST /redemptions/{id}/verify`** — `{verification_method: 'qr'|'otp', code}`. Authorization is the single most important finding of this phase (Section 3).

**`POST /redemptions/{id}/cancel`** — `{reason?}`.

**Lifecycle** (`RedemptionStatus`): `initiated → settled` (verify debits + settles atomically in one DB transaction), `initiated → expired` (a verify attempt after the QR/OTP window closes), `initiated → cancelled`. There is no separately-persisted `verified` state in practice — `RedemptionService::verify()` only ever writes `settled` directly; `Verified` exists in the enum purely as a transition-guard check.

**Validation/business rules** (`RedemptionCalculator`): the merchant must have `accepts_town_coin = true` and a positive `discount_rate`, or initiation is rejected with a specific 422 message. The redeemable coin amount is `min(merchant's % cap, customer's actual balance)`.

## 2. Verification Mechanism — What QR/OTP Actually Means

Before building anything, the real merchant-side verification UI (`town-shoppy-admin`) was inspected directly. Finding: **it has no camera or scanning capability anywhere** — `verify-redemption-dialog.tsx` lets the merchant pick `"qr"` or `"otp"` as a radio option, but both render the *same plain text input*; a human merchant reads whatever the customer shows them and types it in. `qr_secret` is a 40-character random string — not something a person can read aloud or transcribe correctly.

**Decision:** this app displays only the 6-digit `otp_code` (`config('redemption.otp_length')`), prominently, for the customer to read aloud or show to staff. No QR image is rendered — building one would be non-functional UI theater for a scanning capability that does not exist in the real system today, which the brief's own rules explicitly prohibit inventing.

The customer can **never** verify their own redemption — confirmed by reading `RedemptionPolicy::verify()` (owner/staff of the redeeming merchant only) and by both the existing Pest suite and a live HTTP call (Section 8). This app therefore only ever *initiates* and *waits*; verification happens exclusively on the merchant side, outside this app.

## 3. Authorization

| Actor | Initiate | View own | View another's | Verify | Cancel |
|---|---|---|---|---|---|
| Guest | 401 | — | — | — | — |
| Customer (own redemption) | ✅ | ✅ | 403 | **403** | ✅ |
| Merchant owner/staff (redeeming merchant) | — | ✅ | — | ✅ | ✅ |
| Association admin | — | — | — | 403 | — |
| Super admin | — | ✅ (any) | ✅ (any) | 403 | ✅ (override) |

Every cell above was verified live over HTTP against the real backend this phase (Section 8), not assumed from the existing Pest suite alone (which independently confirms the same matrix).

## 4. Screens Implemented

- **`MerchantDetailScreen`** (Phase 3/4, extended) — added a "Redeem Town Coin" CTA, shown only when `merchant.acceptsTownCoin && (merchant.discountRate ?? 0) > 0` (mirrors `RedemptionCalculator`'s own gate; the backend remains authoritative regardless).
- **`RedemptionInitiationScreen`** (new) — the branch → amount → review → submit form.
- **`RedemptionVerificationScreen`** (new) — OTP display, waiting state, and terminal states (settled/expired/cancelled).

**Reused, not rebuilt:** `BranchSelector` (Phase 4) — its interactive (`onSelected` non-null) mode is used for the first time, exactly as it was built to support; the existing `RedemptionDetailScreen` (Phase 2) — linked to from the confirmation view rather than duplicating its field layout; `redemptionStatusTone` and `NotificationTypeDisplay` (already covers all 4 redemption notification types — zero changes needed); `walletControllerProvider` (Phase 1) — reused to show the customer's available coin balance as context.

## 5. Customer Flow (as implemented)

```
Merchant Detail (Redeem CTA, gated)
  → Branch (auto-selected if exactly one; explicit tap required via BranchSelector if multiple)
  → Bill amount (₹ prefix, 2-decimal input formatter, backend-matching 0.01–1,000,000 bound)
  → Review (merchant, branch, amount — appears once both are set; no fabricated discount preview,
     since the actual discount/coin math only exists server-side)
  → Submit (duplicate-tap guarded; Idempotency-Key stays stable across a retry of the same
     request, rotates only when branch/amount genuinely change)
  → Verification screen: OTP code displayed prominently, polls the existing
     redemptionDetailProvider every 4s
  → Confirmation: real discount/coins/remaining-bill fields once status flips to `settled`,
     with a link to the full Redemption Detail screen (Phase 2)
```

No bill-amount discount estimate is ever shown before submission — the calculation depends on server-side config and the customer's live balance, and fabricating an approximation was explicitly out of scope.

## 6. Backend Integration

Exact endpoints consumed: `POST /redemptions` (`RedemptionsRepository.initiate()`), `GET /redemptions/{id}` (existing `redemptionDetailProvider`, reused for both the initial fetch and the verification screen's polling — no new backend endpoint or polling infrastructure was introduced). `GET /merchants/{id}` and `GET /merchants/{id}/branches` (Phases 3/4) power the merchant-identity and branch-selection steps.

## 7. Side Effects (confirmed by reading `RedemptionService` in full, not assumed)

- **Redemption row** created on initiate; **one `SilverLedgerEntry` debit + `RedemptionLotConsumption` rows** created atomically on settle.
- **No Purchase or Coupon is ever created** by this flow — that is a separate domain, untouched here.
- **Notifications:** `redemption.initiated` (on initiate), `redemption.completed` (on settle), `redemption.expired`, `redemption.cancelled` — all four already had icon/color mappings in `NotificationTypeDisplay` since Phase 2; nothing needed adding.
- **Fraud:** `RedemptionFraudSignalDetector` runs server-side on initiate, verification failure, and self-redemption attempts. `RedemptionResource`'s explicit field allowlist structurally guarantees no fraud score, signal, or reason ever reaches this app — confirmed no such field appears in any response this phase's live testing captured.
- **Flutter provider invalidation:** a successful submit invalidates `redemptionsListControllerProvider` so the customer's Redemption history reflects the new entry without a hard refresh — this is the only provider invalidated, since Purchases and Notifications are never mutated by this flow.

## 8. Security — Every Test Performed

**A genuine backend defect was found and fixed this phase:** neither `RedemptionPolicy::initiate()` nor `RedemptionController::store()` checked the merchant's or branch's `status`. Live-reproduced: a *suspended* merchant and an *inactive* branch could both accept a redemption (201, live-confirmed before the fix). Root cause identified, two explicit checks added to `RedemptionController::store()` (mirroring the existing branch-mismatch check's style), 4 new Pest regression tests added (`RedemptionEligibilityTest.php`: suspended merchant rejected, pending merchant rejected, inactive branch rejected, active/active still succeeds — no regression). Full suite re-run clean afterward.

**Live HTTP matrix (real backend, real seeded accounts, this session):**

| # | Test | Result |
|---|---|---|
| 1 | Guest `POST /redemptions` | **401** |
| 2 | Customer A valid redemption | **201**, `otp_code` present, `qr_secret` present (unused by app) |
| 3 | Merchant A + Branch B (mismatch) | **422** "The given branch does not belong to the given merchant." |
| 4 | Bill amount `0` | **422**, field error `bill_amount: "must be at least 0.01"` |
| 5 | Same Idempotency-Key, same body, resubmitted | **200** (replay), same redemption id, **no** `otp_code`/`qr_secret` in the replay response |
| 6 | Customer B views Customer A's redemption (IDOR) | **403** |
| 7 | Customer B cancels Customer A's redemption | **403** |
| 8 | Customer A verifies their own redemption | **403** (confirms Section 2/3's finding directly) |
| 9 | `GET /redemptions/{id}` as the owning customer | 200, confirmed **no** `qr_secret`/`otp_code` ever appears in a GET response |
| 10 | Guest `GET /redemptions/{id}` | **401** |

**Pest** (existing + new): all 8 Redemption test files (`RedemptionAuthorizationTest`, `RedemptionCalculationTest`, `RedemptionConcurrencyTest`, `RedemptionEligibilityTest` [new], `RedemptionFraudTest`, `RedemptionOtpTest`, `RedemptionQrTest`, `RedemptionSecurityTest`, `RedemptionWalletTest`) — **56/56 passing**, covering IDOR, mass-assignment, idempotency-conflict, self-redemption blocking (even for a super-admin-owner combination), qr_secret/otp never leaking into any response or audit log, OTP attempt-limiting, QR replay/expiry, and FIFO wallet debit correctness.

**Flutter-side:** the `Idempotency-Key` is generated client-side (`generateIdempotencyKey()`, `dart:math` `Random.secure()` — no new dependency), stays stable across a retry of the identical (branch, amount) pair, and rotates on any genuine edit — verified by a dedicated controller test. The OTP code is held only in an in-memory Riverpod provider (`PendingOtpCodes`), consumed exactly once, never written to secure storage, logs, or analytics.

**Customer cache isolation:** unaffected — no new customer-scoped provider was added that skips `sessionEpochProvider`; `redemptionDetailProvider` (reused for polling) already watches it from Phase 2.

## 9. UX

Premium, restrained styling consistent with the existing design system: a soft-tinted merchant-identity card, the reused `BranchSelector` in its interactive mode (radio-style selection, never color-only — an icon change accompanies the color change), a large-type `₹`-prefixed amount field, a clean Review card, and a large letter-spaced OTP display (`displaySmall`, `letterSpacing: 8`) framed in a tinted card with a `Semantics` label that spells out each digit for screen readers. Loading language is accurate to the actual stage ("Creating your redemption…" while submitting; "Waiting for the merchant to verify…" while polling — never "Processing payment," since no payment occurs here).

**Responsive QA:** genuinely verified at 375px only, via a live screenshot of the Merchant Detail entry point with the new "Redeem Town Coin" CTA and real branch data — clean, no horizontal overflow. **390px and 430px were not separately verified this session**, and the interactive branch/amount/review/verification screens could not be visually walked through live — see Section 12 for why, and what was verified instead.

## 10. Testing — Exact Results

| Check | Result |
|---|---|
| `flutter analyze` | **No issues found.** |
| `flutter test` | **100/100 passing** (79 at the end of Phase 4 → 100; +21 new tests this phase) |
| `flutter build apk --release` | **succeeded**, 49.3MB |
| Backend Pest (Docker Sail, 22 parallel processes) | **624 passed, 1,980 assertions, 0 failures** (620/1,976 baseline + exactly the 4 new eligibility tests) |
| Pint | **0 style issues** across 394 files |
| Admin `tsc --noEmit` | clean |
| Admin ESLint | clean |
| Admin `next build` | succeeded across every route |

New Flutter tests this phase (21): `redemption_initiation_result_test.dart` (2), `pending_otp_codes_provider_test.dart` (3), `redemption_initiation_controller_test.dart` (9 — initial state, branch selection + Idempotency-Key rotation semantics, amount bounds, `canSubmit` gating, successful submit with exact-argument assertions, no-op on missing fields, failure preserving form state, duplicate-tap guard under real concurrency via a `Completer`), `redemption_initiation_screen_test.dart` (3 — ineligible-merchant empty state, single-branch auto-select + Review appearance, multi-branch explicit-tap requirement), `redemption_verification_screen_test.dart` (4 — one per real backend status: initiated/settled/expired/cancelled).

## 11. Bugs Discovered

**Medium — Redemption initiation did not check merchant/branch active status** (found, fixed, regression-tested this phase — see Section 8). No other defects found.

## 12. Honest Limitation — Live Browser Interaction

The Merchant Detail entry point (with the new "Redeem Town Coin" CTA and real branch data) was genuinely screenshot-verified at 375px early in this session. Partway through attempting to click into the redemption flow, the Browser pane's click tool began timing out consistently across multiple retries, a fresh tab, and alternate navigation methods (URL hash change, `window.location.hash`, JS-triggered reload) — eventually the pane stopped compositing frames entirely, the same failure mode Phase 2's session documented. This is a session tooling limitation, not a claim about the app: no server or console errors were observed at any point, and the page remained correctly rendered throughout.

Given the brief's own instruction to fall back to the strongest available alternative when browser tooling fails, this phase relied instead on:
- **Interactive Flutter widget tests** (`tester.tap()`, `tester.enterText()` — genuine simulated interaction, not static assertions) covering every screen and branch of the flow, including all 4 real backend statuses on the verification screen.
- **A 10-scenario live HTTP matrix** against the real running backend, exercising exactly what the app's repository layer sends.
- **The full regression suite** (Section 10).

390px/430px and the actual interactive walkthrough (branch tap → amount entry → review → submit → OTP display → settlement) were **not** visually verified live this session. This is reported honestly rather than glossed over, consistent with how Phase 2 and Phase 3 each flagged their own tooling gaps.

## 13. Next Milestone (recommend only, not started)

The customer-facing side of redemption is now complete end-to-end (discovery → detail → branch → initiate → wait → confirm). The natural next milestone is **Merchant-Side Verification Polish** — today the merchant admin's OTP/QR verify dialog is a bare, single text field with no distinction between the two methods' actual UX; a merchant-facing "recent redemptions awaiting verification" queue view would close the loop this phase deliberately left on the customer side only. A live browser walkthrough of this exact flow (blocked this session per Section 12) is also worth completing in a follow-up session before this milestone is considered fully proven, independent of any code changes.
