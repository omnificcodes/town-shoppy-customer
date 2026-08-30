# TownShoppy Flutter Customer App — Phase 1 Report

**Scope:** Architecture + Backend Contract Audit + Premium Foundation + OTP Authentication
**Date:** 2026-08-19
**Backend at time of audit:** Laravel 13.25.0 / PHP 8.5.9, Sanctum token auth, Domain-Driven structure (`town-shoppy-api`)

---

## 1. Backend Customer API Contract (as discovered, not invented)

All routes are prefixed `/api/v1`. Every response uses the `ApiResponse::success()/::error()` envelope. Auth is Sanctum bearer-token (`Authorization: Bearer <token>`), no refresh-token flow — a `401` always means "sign in again."

| Method & URL | Auth | Purpose | Notes |
|---|---|---|---|
| `POST /auth/otp/request` | Public | Request an OTP for a mobile number | Rate-limited per mobile/IP (`config/otp.php`); accepts bare 10-digit, `+<cc>`, `00<cc>`, or leading-`0` formats via `PhoneNumberNormalizer` |
| `POST /auth/otp/verify` | Public | Verify OTP, returns `{account, token, is_new_account}` | `name`/`referral_code` optional, used only on first registration |
| `GET /auth/me` | Sanctum | Current account + `customer_profile` | Used to restore session on app restart |
| `POST /auth/logout` | Sanctum | Revoke current token | Best-effort; app always clears local state regardless of response |
| `GET /notifications` | Sanctum | Cursor-paginated notification list | **Fixed this phase** — was missing pagination meta |
| `POST /notifications/{id}/read` | Sanctum | Mark one notification read | |
| `POST /notifications/read-all` | Sanctum | Mark all read | |
| `GET /notification-preferences` | Sanctum | Channel preferences | Not surfaced in UI this phase (no screen built) |
| `GET /town-coins/transactions` | Sanctum | Silver wallet balance + ledger | **Fixed this phase** — was missing pagination meta |
| `GET /purchases` | Sanctum | Customer's own purchase history | Used only for the Home "recent purchases" preview (3 items); full list screen deferred |
| `GET /referrals/me` | Sanctum | Own referral code + stats | Referral code shown read-only on Profile; registration flow not built |

Confirmed via Policy inspection but **not surfaced in Phase 1 UI** (in scope for a later milestone, not fabricated):
- `GET /redemptions`, `POST /redemptions` (customers can initiate redemptions)
- `GET /merchants`, `GET /merchants/nearby`, `GET /towns`, `GET /associations`, `GET /merchant-categories`, `GET /offers` (public, no auth required)

Confirmed **absent from the backend entirely** (empty `app/Domain/*` folders — reserved namespaces only, zero implementation): `LuckyDraw`, `Prize`, `Sponsorship`, `Voucher`, `TownCoin` (as a distinct rewards concept beyond the Silver wallet). No customer-facing rewards, lucky draw, or loyalty-point system exists on the backend. None of this was built or referenced in the Flutter app.

`POST /auth/login` (password-based) exists on the backend but was deliberately never wired into the Flutter app — the customer app is OTP-only per the brief.

## 2. Customer Permission Model

- `Account.activeRoles()` resolves `Role::Customer` purely from `customerProfile !== null` — there is no separate `role` column. An account can hold multiple roles simultaneously (e.g. a merchant owner account can also carry a customer profile).
- `CustomerProfile` fields are **only** `id, account_id, name, referral_code, status` — explicitly documented in the model's own docblock as "Slice 1 scope only." Address/DOB/gender/photo/preferences do not exist yet. **There is no update endpoint for `CustomerProfile` anywhere in `routes/api.php`** — this is why the Profile screen is read-only, not a Flutter limitation.
- Every customer-scoped endpoint (`/notifications`, `/town-coins/transactions`, `/purchases`, `/referrals/me`) scopes strictly to the authenticated account via policy/query constraints — confirmed independently via direct HTTP cross-account testing (Section 7).

## 3. Flutter Architecture

Extended the existing scaffold (Riverpod 3.3.2, Dio, GoRouter, `flutter_secure_storage` — already the correct stack, not replaced):

```
lib/
  core/
    config/env.dart            — API_BASE_URL via --dart-define, no hardcoded prod URL
    constants/app_constants.dart
    errors/app_exception.dart  — sealed exception hierarchy (Network/Unauthenticated/Forbidden/NotFound/Conflict/Validation/RateLimited/Server/Unknown)
    networking/api_client.dart — single Dio instance, interceptors, onUnauthorized hook
    networking/api_error_mapper.dart, api_envelope.dart, cursor_page.dart
    routing/app_router.dart    — GoRouter + Riverpod-driven redirect guard
    storage/secure_storage_service.dart — flutter_secure_storage wrapper (pre-existing, reused)
    theme/                     — app_colors, app_spacing, app_typography, app_theme
    utils/relative_time.dart   — hand-rolled, avoids a timeago dependency
    widgets/app_shell.dart     — authenticated shell + bottom navigation
  features/
    auth/{data,application,presentation}
    home/presentation
    profile/presentation
    notifications/{data,application,presentation}
    wallet/{data,application}
    purchases/{data,application}
  shared/widgets/               — AppButton, AppTextField, AppCard, InfoBox, StatusBadge,
                                   LoadingSkeleton, EmptyState, ErrorState, NotificationBadge,
                                   AppBottomNavigation, AppScaffold
```

Each feature follows `data` (models + repository talking to the shared `ApiClient`) → `application` (Riverpod controllers/state) → `presentation` (widgets only, no direct HTTP calls). No raw `dynamic` maps reach the UI layer — every API response is parsed into a typed model.

## 4. Authentication

OTP-only, matching the brief's hard requirement (never password auth, despite `/auth/login` existing on the backend):

1. **Mobile number entry** (`MobileNumberScreen`) → client-side length check (UX only; backend `ValidMobileNumber` remains authoritative) → `POST /auth/otp/request`.
2. **OTP verify** (`OtpVerifyScreen`) → `POST /auth/otp/verify` → on success, receives `{account, token, is_new_account}`.
3. Token is written to `flutter_secure_storage` immediately — **never** SharedPreferences, never logged, never included in analytics/crash payloads.
4. Explicit, non-boolean auth states (`auth_state.dart`): `AuthUnauthenticated` (with `isRequestingOtp`/`error`), `AuthOtpSent`, `AuthVerifying`, `AuthAuthenticated`, `AuthLoggingOut`, `AuthSessionExpired`, `AuthError` — the router's `redirect` callback and every screen branch on these explicitly, never on a raw boolean `isLoggedIn`.
5. On app restart, `AuthController.build()` attempts `_restoreSession()` via `GET /auth/me` using the stored token; a `401` here clears the token and lands on the login screen with the "session expired" message.
6. `ApiClient.onUnauthorized` is wired once by `AuthController` so a `401` from **any** endpoint, at any point in the app, triggers the same session-clear + redirect path (see Section 7 for the one verification gap on this path).

## 5. Screens Implemented (Phase 1 scope only)

| Screen | Data source | Notes |
|---|---|---|
| Mobile number entry | `POST /auth/otp/request` | |
| OTP verify | `POST /auth/otp/verify` | |
| Authenticated shell + bottom nav | — | 3 destinations: Home, Notifications, Profile |
| Home | `GET /auth/me`, `GET /town-coins/transactions`, `GET /purchases` (3 most recent) | Greeting, Silver wallet balance card, recent-purchases preview — all real data, no placeholders |
| Profile | `GET /auth/me` | Read-only (name, mobile, referral code) — no edit UI, because no update endpoint exists |
| Notifications | `GET /notifications`, `POST /notifications/{id}/read`, `POST /notifications/read-all` | Cursor-paginated list, unread badge, all 17 real `NotificationType` values mapped to display copy/icons |

Deliberately **not built** this phase (explicitly out of scope per the brief, not overlooked): full Purchases/Redemptions list screens, referral registration UI, merchant discovery, rewards/lucky draw (backend doesn't support it), notification-preferences UI.

## 6. Backend Endpoints Integrated

`POST /auth/otp/request`, `POST /auth/otp/verify`, `GET /auth/me`, `POST /auth/logout`, `GET /notifications`, `POST /notifications/{id}/read`, `POST /notifications/read-all`, `GET /town-coins/transactions`, `GET /purchases` (limited, recent-only usage). All verified against the real running Sail backend, not mocks, for integration-level checks.

## 7. Security Report

- **Token handling:** stored only in `flutter_secure_storage`; never appears in logs, URLs, or error payloads (confirmed by reading every interceptor/log call site).
- **Cross-account cache isolation (UI):** logged in as Customer A (id 2), confirmed name/wallet/referral code, logged out, logged in as Customer B (id 3) in the **same tab without a hard refresh** — Home/Profile/Notifications correctly showed only Customer B's data. This is driven by the `sessionEpochProvider` pattern (a `Notifier<int>` bumped on login/logout that every customer-scoped provider watches as the first line of its `build()`), the Riverpod-idiomatic equivalent of the admin app's earlier `queryClient.clear()` fix for the same class of bug.
- **Cross-account isolation (direct HTTP):** independently requested/verified OTP via `curl` for both accounts (bypassing the Flutter UI entirely), obtained two real Sanctum tokens, and confirmed Account A's token cannot read Account B's notifications/wallet/purchases — rejected/scoped correctly at the backend policy layer.
- **401 handling:** clears secure token + all customer-scoped Riverpod state, redirects to login with "Your session expired. Please sign in again." Confirmed via the app-restart path (`_restoreSession()` failing with an invalid/expired token).
- **403 handling:** does not force logout (verified by code inspection of `ApiErrorMapper`/`ApiClient` — a `ForbiddenException` is surfaced as an inline error, `onUnauthorized` is only invoked for 401).
- **Known verification gap, reported honestly:** the *live, in-session* `ApiClient.onUnauthorized` interceptor path (as opposed to the app-restart `_restoreSession()` path) was not exercised end-to-end in this session — the pull-to-refresh gesture used to try to trigger a live authenticated request did not register reliably in the Browser-pane automation tooling. The 401-clears-state logic is shared code between both paths (same `_clearSessionAndCustomerState()` call), and the app-restart path was fully verified, but the live-interceptor path specifically should get one more manual pass (e.g. on a physical device or emulator) before this is called fully proven.
- No backend changes were made to accommodate the Flutter app that weren't genuine, independently-justified bug fixes (Section 10).

## 8. UI/UX Report

- Design system implemented from `docs/product/design-principles.md` (the actual approved consumer brand spec, not the admin platform's palette): Vibrant Orange `#FF6B00` (primary/CTA), Crimson Red `#E50914` (secondary/urgency), Bright Yellow `#FFD600` (tertiary/reward), white/near-white canvas — saturated color reserved for CTAs/badges/active states, never full-bleed backgrounds.
- Silver (customer) wallet card uses a distinct cool/neutral-metallic tone family, deliberately not borrowing the warm brand accents, so it stays visually distinct from any future Gold/merchant wallet treatment.
- Skeletons mirror final layout (no generic spinners); the wallet balance never blanks during a background refresh — a prior cached value stays visible with a small inline "refreshing" indicator (`walletRefreshingProvider`), working around Riverpod 3.3.2 marking `AsyncValue.copyWithPrevious` as `@internal`.
- The real supplied logo (`townshoppe-logo.png`) was copied into `assets/images/townshoppy_logo.png` and registered in `pubspec.yaml` — not referenced externally.
- Verified responsively via the Browser pane at mobile widths; verified the light-only Material 3 theme renders correctly.

## 9. Tests Report

- `flutter analyze`: **No issues found.**
- `flutter test`: **16/16 passing** —
  - `test/core/api_error_mapper_test.dart` (10 tests): every Dio failure mode maps to the correct typed exception, including that a 500 never leaks the raw server message.
  - `test/features/auth/account_test.dart` (3 tests): `Account.fromJson` parsing, including the null-`customer_profile` edge case.
  - `test/widget_test.dart` (3 tests, rewritten from the failing default boilerplate): `MobileNumberScreen` rendering, client-side validation blocking a short number, and a successful OTP request with the correct trimmed number — using a `FakeAuthRepository` and a minimal in-test `GoRouter`, so these tests never touch the network.
- `flutter build apk --release`: **succeeded** (48.7MB, built via Gradle `assembleRelease`) — the production-build verification requirement is satisfied.
- Backend regression (Laravel Pest, run via Docker Sail, 22 parallel processes): **599 passed, 1898 assertions, 0 failures** — up from the 598/1890 baseline at the start of this phase, reflecting the two new regression tests added for the pagination-meta fixes (Section 10).
- Next.js admin app re-verified after the backend changes: `tsc --noEmit` clean, `eslint` clean, `next build` succeeded across all routes (Super Admin/Association Admin/Merchant Admin) — confirms no regression from the two backend edits.

## 10. Bugs Discovered

**Medium — found and fixed:**
1. `GET /notifications` returned no pagination meta at all (`next_cursor`/`prev_cursor` missing from the response), even though the endpoint uses `cursorPaginate()`. Root cause: `NotificationResource::collection(...)` was passed directly to `ApiResponse::success()` without extracting cursor metadata — a nested `ResourceCollection` does not auto-attach pagination meta the way a directly-returned Laravel paginator response would. Fixed in `NotificationController.php` to match the existing correct pattern in `AuditLogController`. Added a regression test asserting the `meta.next_cursor`/`meta.prev_cursor` structure.
2. `GET /town-coins/transactions` had the identical bug. Fixed identically in `WalletController.php`; extended the existing `TownCoinsTest.php` assertion to check the meta structure.

Both fixes follow the mandated process: reproduced, root-caused against the known-correct reference implementation, confirmed minimal blast radius (pagination meta only, no behavior change to the data itself), added regression tests, ran the full Pest suite (599/1898/0 failures), and are documented here.

**No Critical, High, or Low severity findings** in this phase's scope.

## 11. Backend Limitations (confirmed, not assumed)

- `LuckyDraw`, `Prize`, `Sponsorship`, `Voucher`, and `TownCoin`-as-a-rewards-concept are empty, unimplemented namespaces — no lucky draw, prize, sponsorship, voucher, or points-reward system exists on the backend today.
- `CustomerProfile` has no update endpoint — address/DOB/gender/photo/preferences are documented in the model's own docblock as a later slice, not available now. This is why Profile is read-only.
- No merchant-discovery-with-geolocation UI was built this phase (the backend's `/merchants/nearby` endpoint exists but integrating it, including any location-permission UX, was out of scope for Phase 1).
- Purchases and Redemptions each have a real, working backend endpoint, but no full list/detail screen was built in Flutter this phase — Home only shows a 3-item recent-purchases preview.
- Referral registration (applying a referral code at signup) is supported by `verifyOtp`'s optional `referral_code` param on the backend, but no dedicated referral-entry UI beyond the read-only code display on Profile was built this phase.

## 12. Next-Milestone Recommendation

Recommend (not started) as the logical next phase: build the full **Purchases** and **Redemptions** list/detail screens (both backend endpoints already exist and are policy-scoped correctly), plus a proper **referral-code entry step** in the OTP-verify/registration flow, since the backend already accepts `referral_code` on `POST /auth/otp/verify` and only the UI is missing. Merchant discovery (`/merchants/nearby`) and notification-preferences UI are reasonable follow-ups after that. Any rewards/lucky-draw UI should stay blocked until the corresponding backend domains are actually implemented — building against the current empty namespaces would mean fabricating a feature the backend cannot serve.
