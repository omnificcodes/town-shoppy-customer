# TownShoppy Flutter Customer App — Phase 2 Report

**Scope:** Purchases, Redemptions & Referral Code
**Date:** 2026-08-20
**Baseline:** Phase 1 (OTP auth, Home, Profile, Notifications) — complete and unmodified in architecture; extended, not rebuilt.

---

## 1. Features Implemented

| Feature | Status |
|---|---|
| Purchases — paginated list (pull-to-refresh, infinite scroll, empty/error states) | Complete |
| Purchase detail screen (merchant, branch, amount, coins, coupons, bill reference, date) | Complete |
| Redemptions — paginated list (same UX conventions as Purchases) | Complete |
| Redemption detail screen (merchant, branch, discount, coins debited, verification info, date) | Complete |
| Referral summary screen (code, shareable link, qualified/pending counts, milestone progress, history) | Complete |
| Referral-code entry | Complete, scoped to registration only (see Section 3) |
| Navigation entry points (Home "See all" links, Profile "Activity" section) | Complete |

Deliberately **not built** this phase: initiating a new redemption (`POST /redemptions`) — this requires choosing a merchant/branch, and merchant discovery is still out of scope (see Section 11). Redemption `cancel`/`verify` actions were likewise left out — the brief asked for list/detail only, matching Phase 1's own recommendation.

## 2. Backend Endpoints Used

`GET /purchases`, `GET /purchases/{id}`, `GET /redemptions`, `GET /redemptions/{id}`, `GET /referrals/me`, and an extended use of the existing `POST /auth/otp/verify` (see Section 3). All confirmed against the real running Sail backend via direct HTTP (Section 9), not mocks.

## 3. The Referral-Code-Entry Discovery (and a Registration Bug Found Along the Way)

Before writing any UI, the actual contract was read directly from `AuthController`, `AuthService`, `OtpService`, `OtpVerifyRequest`, and `ReferralRegistrationService`:

- There is **no standalone "apply a referral code" endpoint**. A code is only ever accepted as an optional `referral_code` field on `POST /auth/otp/verify`, and only takes effect the **one time** a genuinely new account is created (`AuthService::completeOtpAuthentication` — an existing account short-circuits before the field is even read).
- `OtpService::verify()` is explicitly idempotent for a caller who still presents the correct code, so resubmitting the same `otp_request_id`/`code` — this time with a name and optional referral code — is safe and does not consume a second OTP.
- An unrecognized referral code is a **silent no-op** by design (`ReferralRegistrationService`'s own docblock: distinguishing a valid from an invalid code would be a referral-code enumeration oracle, the same class of protection Slice 1's OTP flow already uses for account existence). The UI therefore never claims "invalid code" — it shows a neutral success confirmation regardless, and never promises a specific reward amount, since qualification is asynchronous (`Referral.status = pending` until the referred customer's first qualifying purchase).

While confirming this, a second thing came to light: `AuthService::completeOtpAuthentication` requires a `name` for any genuinely new account, but **Phase 1's `OtpVerifyScreen` never collected one** — new-customer registration would have failed with a 422 the first time a real new number tried to sign up. This was only invisible in Phase 1 because all live testing used pre-seeded existing accounts. This is the same code path referral-code entry has to hook into, so both were fixed together:

- Added `AuthProfileRequired` to `AuthState` — reached when `verifyOtp` gets back a 422 with a `name` field error, i.e. "this is a new account."
- Added `AuthController.completeRegistration({name, referralCode})`, which resubmits the same idempotent OTP verification with the collected name and optional code. A `current.isSubmitting` guard makes a second tap while the first request is in flight a no-op — real duplicate-submission prevention, not just a disabled button.
- Added `CompleteProfileScreen` (`/complete-profile`) — Name (required) + Referral code (optional, 32-char cap matching the backend's own validation), shown exactly once, only on this path, never seen again by a returning customer.

## 4. Architecture Decisions

- **`OffsetPage<T>`** (`lib/core/networking/offset_page.dart`) — a second pagination model alongside Phase 1's `CursorPage<T>`, because `PurchaseController`/`RedemptionController` use classic `{current_page, last_page, per_page, total}` page-number pagination, not the `{next_cursor, prev_cursor}` shape Notifications/Wallet use. Verified directly against the real backend, not assumed.
- `PurchasesListController` / `RedemptionsListController` mirror Phase 1's `NotificationsController` shape (`AsyncNotifier` + `loadMore()`/`refresh()`), adapted for offset pagination — deliberately two small, near-identical classes rather than a shared generic base, matching the existing codebase's own preference for concrete, readable controllers over premature abstraction.
- `purchaseDetailProvider(id)` / `redemptionDetailProvider(id)` are `FutureProvider.family`, watching `sessionEpochProvider` first (Phase 1's cache-isolation mechanism), so a logout/login cycle correctly clears any cached detail view for the previous account.
- All new list/detail/referral screens reuse Phase 1's exact shared widgets (`AppCard`, `StatusBadge`, `EmptyState`, `ErrorState`, `LoadingSkeletonCard`) and theme tokens — no new design-system components were introduced, and `home_screen.dart`'s previously-duplicated purchase-status-tone logic was extracted into a shared `purchase_status.dart` helper reused by both Home and the new Purchases screens.

## 5. Backend Changes (Minimal, Contract-Driven)

Two changes, both additive and precedented:

1. **`PurchaseResource` now includes `merchant`/`branch` nested objects** (`{id, name}`), mirroring `RedemptionResource`'s already-existing identical pattern for the same underlying `Merchant`/`MerchantBranch` `belongsTo` relations. Previously a purchase only exposed `merchant_id`, which would have forced the UI to show a bare numeric ID — a real customer-facing regression, not a hypothetical one. `PurchaseController::index()`/`show()` now eager-load `merchant`/`branch`.
2. No other backend routes, migrations, or validation rules were touched.

## 6. Security Considerations

- No new backend-authorization logic was added; all customer scoping (`customer_profile_id === own`) was already enforced server-side and is unchanged.
- The referral-code enumeration protection (Section 3) was preserved end-to-end — the Flutter UI never surfaces a distinct "valid"/"invalid" signal for a submitted code.
- `CompleteProfileScreen`'s `isSubmitting` guard prevents a duplicate `POST /auth/otp/verify` call, which matters because a second concurrent call would otherwise redundantly attempt the same registration (harmless given the backend's own idempotency, but wasteful and worth guarding client-side regardless).
- No new token handling, storage, or logging paths were introduced — all new repositories reuse the existing `ApiClient`/`SecureStorageService` exactly as Phase 1 established them.

## 7. UX Decisions

- Purchases/Redemptions lists show merchant name, amount/coins, relative date, and a status badge — consistent tile shape, consistent `StatusBadge` tone mapping per domain (`purchase_status.dart` / `redemption_status.dart`).
- Detail screens show every customer-relevant field the resource actually returns and nothing invented; a "Merchant #<id>" fallback exists purely as defense-in-depth in case a relation is ever unloaded, not as an expected UI state.
- The Referral screen shows stats and history using cards consistent with the rest of the app, with copy-to-clipboard for the code/link (matching Phase 1's existing copy-icon pattern) and an explicit qualified-vs-pending distinction using icon + color + text (never color alone).
- `CompleteProfileScreen` explains in one sentence why the user is seeing it ("This is your first time signing in with +91 ...") rather than presenting an unexplained extra step.

## 8. Tests Added

Flutter test count grew from 16 (end of Phase 1) to **44**, all passing:

- `purchase_model_test.dart` / `redemption_model_test.dart` / `referral_summary_model_test.dart` — JSON parsing, including missing-relation fallback behavior.
- `purchases_list_controller_test.dart` / `redemptions_list_controller_test.dart` — successful load, empty list, backend error, `loadMore` pagination, a `loadMore` failure preserving already-loaded items, `refresh`.
- `purchase_detail_provider_test.dart` / `redemption_detail_provider_test.dart` / `referral_summary_provider_test.dart` — successful load and a 404/backend-error case.
- `auth_controller_test.dart` (new) — the full referral/registration-completion flow: routed to `AuthProfileRequired` on a new-account signal, a referral code passed through correctly, a submission with no code sends `null`, a backend validation error on resubmit keeps the state with the error attached, and the in-flight submitting state genuinely blocks a duplicate submission.

One backend Pest test was added (`PurchaseRecordingTest.php`) asserting the new `merchant`/`branch` fields on both `GET /purchases` and `GET /purchases/{id}`.

**A version-specific test-infrastructure note, not a production concern:** Riverpod 3.3.2 auto-retries a failed provider `build()` with backoff rather than settling into a plain `AsyncError`, so tests assert failures via `AsyncValue.hasError`/`.error` (set on both the retrying-loading and settled-error variants) rather than waiting for a specific `AsyncError` instance. This only affects how the test suite observes failure state — the app's own error UI (`ErrorState` widget, retry button) is unaffected, since it already branches on `state.hasError`-equivalent logic via `AsyncValue.when()`.

## 9. Build & Regression Verification

- `flutter analyze`: **No issues found.**
- `flutter test`: **44/44 passing.**
- `flutter build apk --release`: **succeeded** (48.9MB).
- Backend Pest (Docker Sail, 22 parallel processes): **600 passed, 1905 assertions, 0 failures** — up from the 599/1898 baseline at the start of this phase (the +1 test / +7 assertions is the new merchant/branch regression test).
- Next.js admin app: `tsc --noEmit` clean, `eslint` clean, `next build` succeeded across all routes — confirms the one backend resource change did not regress the admin platform.
- Direct-HTTP verification against the real backend (bypassing the Flutter UI, using a real seeded customer account's Sanctum token): `GET /purchases`, `GET /redemptions`, and `GET /referrals/me` all returned exactly the shapes the new Flutter models parse — `{data: [], meta: {current_page, last_page, per_page, total}}` for the empty-history case, and the full referral-summary object for `/referrals/me`.

## 10. Known Limitation — Honestly Reported

Live, pixel-level browser verification of the new screens (checking for overflow, spacing, responsive layout at multiple widths, and visually confirming loading/empty/error states) **could not be completed this session**: the Browser pane's screenshot/compositing path was unavailable throughout (`the Browser pane is not displayed, so the page is not compositing frames`), a session-side tooling limitation distinct from Phase 1's pull-to-refresh gesture gap. What *was* confirmed instead:

- The dev server compiles and serves the app cleanly (after clearing a stale service-worker cache — the same benign artifact Phase 1 encountered and diagnosed, not a real defect).
- The mobile-number entry `TextField` is genuinely present and interactive (confirmed by typing into it via the browser automation and reading back the entered value).
- No console errors after the cache was cleared.
- Every new backend contract was verified directly over HTTP with a real token (Section 9), which is what the new screens' repositories parse.
- The full Flutter widget/unit test suite exercises the actual production screens' state logic (loading/empty/error/data branches) directly.

This is a real verification gap, not a claim that the UI is broken — but visual/responsive QA of the Purchases, Redemptions, and Referral screens should get one more pass (e.g. on a physical device/emulator or a session where the Browser pane renders) before this is called fully proven, exactly as Phase 1 flagged its own live-interceptor gap rather than glossing over it.

## 11. Backend Limitations (confirmed, not assumed)

- Initiating a new redemption (`POST /redemptions`) requires selecting a merchant and branch; merchant discovery (`GET /merchants/nearby`) was not integrated this phase, so this action was not built. The read-only history endpoints (`GET /redemptions`, `GET /redemptions/{id}`) are fully covered.
- Referral-code application remains a one-time, registration-only capability by backend design — there is still no route for an existing customer to apply a code after the fact, and an unknown code is silently ignored rather than reported, both confirmed as deliberate anti-enumeration design, not gaps to fix.
- `GET /notification-preferences` exists on the backend but has no customer-facing UI in either phase.

## 12. Recommended Next Milestone (recommend only, not started)

Build **merchant discovery** (`GET /merchants/nearby`, `GET /merchants`, `GET /merchants/{id}`) as its own milestone — every backend endpoint for it already exists and is public/optional-auth. This unlocks two things at once: a genuine "browse nearby shops" experience, and the merchant/branch picker that redemption-initiation (`POST /redemptions`) needs, since that flow is otherwise unbuildable without it. Notification-preferences UI is a smaller, independent follow-up after that.
