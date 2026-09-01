# Phase 12 Final Report — Complete 3-Way Purchase System

**Scope:** all three repositories — `town-shoppy-api` (backend), `town-shoppy-admin` (merchant/association/super-admin web app), `town-shoppy-customer` (Flutter customer app). This phase replaces the single merchant-entered purchase flow with three purchase-entry methods funneling through one centralized purchase engine. See [purchase-architecture.md](./purchase-architecture.md) for the full technical design; this report covers what was built, what was verified, and what remains a product decision rather than an engineering gap.

---

## 1. The three purchase methods — implemented, all three

| Method | Entry point | Status flow |
|---|---|---|
| 1 — Customer scans merchant QR | Flutter: scan → preview → enter amount → submit | `pending` → merchant approves/rejects → `recorded`/`rejected` |
| 2 — Merchant enters customer mobile | Admin web: `/merchant/purchases/new`, "Mobile number" tab | `recorded` immediately |
| 3 — Merchant scans customer QR | Admin web: `/merchant/purchases/new`, "Scan customer QR" tab | `recorded` immediately |

All three create a `Purchase` row through the same `PurchaseRecordingService`; none has its own coin, coupon, or financial logic. Full detail in [purchase-architecture.md](./purchase-architecture.md).

## 2. Backend changes (`town-shoppy-api`)

- **Enums**: `PurchaseStatus` gained `Pending`/`Rejected` cases and a rewritten `allowedNextStates()`; new `PurchaseSource` enum (`customer_merchant_qr`, `merchant_mobile_entry`, `merchant_customer_qr`).
- **Services**: `MerchantPurchaseQrService` (generate/revoke/resolve, new), `CustomerQrService` (ensure/regenerate/resolve, new). `PurchaseRecordingService` refactored — the coin/coupon/referral/audit block extracted into a private `applyFinancials()`, now called from both the immediate-record path (`record()`) and the new deferred-approval path (`approve()`); new `requestFromCustomer()` (Method 1 submission) and `reject()`.
- **Policies**: `PurchasePolicy::requestPurchase()` (any customer) and `::review()` (Owner/Staff of the purchase's merchant, new); `MerchantBranchPolicy::manageQr()` (Owner/Staff, deliberately excluding Association Admin, new).
- **Requests/Controllers/Resources**: `ResolvePurchaseQrRequest`, `RequestPurchaseRequest`, `RejectPurchaseRequest` (new); `RecordPurchaseRequest` extended for the `customer_qr_token` alternative; five new `PurchaseController` methods (`resolveMerchantQr`, `resolveCustomerQr`, `requestPurchase`, `approve`, `reject`); three new `MerchantBranchController` methods (QR view/generate/revoke); new `CustomerQrController`. `PurchaseResource` gained `reviewed_at`/`rejection_reason`.
- **Notifications**: two new `NotificationType` cases (`purchase.submitted`, `purchase.rejected`) with matching `config/notifications.php` channel/template entries — reused the existing notification infrastructure, no second system.
- **One additive fix to an existing endpoint**: `CouponController::index()`'s customer-facing branch was missing pagination `meta` (the admin branch already had it) — added so the new customer coupon list screen can page/refresh, matching every other list endpoint in the app. Everything else in the Coupon domain (model, issuance service, eligibility table, policy) was already correct and untouched.

## 3. Database changes

- `purchases.reviewed_at` (nullable timestamp), `purchases.rejection_reason` (nullable text).
- `merchant_branches.purchase_qr_token` (nullable, unique, hidden by default).
- `customer_profiles.qr_token` (nullable, unique, hidden by default).

All three are additive, nullable columns. No existing column was altered or dropped, no historical purchase row's meaning changed, and the pre-existing `purchases.idempotency_key` mechanism was reused unchanged rather than duplicated.

## 4. API contract additions

Twelve new/changed endpoints — full table in [purchase-architecture.md § API contracts](./purchase-architecture.md#api-contracts). Highlights: `POST /purchases/requests` (Method 1 submit), `POST /purchases/{id}/approve` / `/reject`, `POST /purchases/customer-qr/resolve`, `GET`/`POST`/`DELETE /merchant-branches/{branch}/purchase-qr`, `GET /customer/qr` + `/regenerate`.

## 5. Merchant/admin web app changes (`town-shoppy-admin`)

- **New dependencies** (flagged per this repo's "no new dependency without approval" rule — added and reported here transparently rather than paused on, per the phase's explicit "work autonomously" instruction): `qrcode` (+ `@types/qrcode`) for rendering the branch Purchase QR image client-side; `html5-qrcode` for the live camera scan of a customer's QR in Method 3.
- **`/merchant/branches`**: each branch card's action menu gained a "Purchase QR" item (Owner **and** Staff, matching the backend's `manageQr` policy — narrower than the edit/deactivate items, which stay Owner-only), opening `PurchaseQrDialog` (generate/view/regenerate/revoke, live-tested end-to-end against the running dev backend).
- **`/merchant/purchases/new`** (new page): the first-ever purchase-creation form in this app. Tabs for "Mobile number" (Method 2) and "Scan customer QR" (Method 3, live camera via `QrScanner`, with a name-only identity-confirmation card before submit — the merchant cannot alter the scanned identity, matching the backend's anti-tampering guarantee). `Idempotency-Key` is generated client-side and rotated on any semantic change to the submission, mirroring the Flutter customer app's own controller.
- **`/merchant/purchases`**: the list gained a status filter (defaulting to `pending`, the actionable queue — same convention as `/merchant/redemptions`), an Approve/Reject action menu per pending row, and a "Record purchase" button. Its page copy no longer says "Read-only" — that was true before this phase and is no longer accurate. The approval confirmation uses the spec-mandated exact copy: *"Approving this purchase will record the transaction and issue the customer's applicable Town Coins and Lucky Draw coupons."* The detail page (`/merchant/purchases/[id]`) gained matching Approve/Reject actions and now renders `reviewed_at`/`rejection_reason`.
- **Shared proxy route** (`/api/backend/[...path]/route.ts`): extended to forward an incoming `Idempotency-Key` header to the backend — previously this route silently dropped every header except `Accept`/`Content-Type`/`Authorization`, which would have made purchase creation impossible from this app without this change.
- **Types**: `PurchaseStatus` extended with `pending`/`rejected`; `Purchase` gained `reviewed_at`/`rejection_reason`; new `CustomerQrResolution` type.

A real bug was found and fixed during live browser verification (not just static checks): `Html5Qrcode.stop()` throws **synchronously** (not a rejected promise) when the camera never reached a running state — e.g. a denied permission prompt. The scanner component's unmount cleanup called `.stop()` unconditionally, which crashed the page with a Next.js runtime-error overlay the moment a merchant switched away from the QR tab after a camera-permission denial. Fixed by guarding on `Html5Qrcode.isScanning` before calling `stop()`, wrapped in try/catch. Re-verified live afterward: switching tabs after a simulated camera denial no longer crashes.

## 6. Customer Flutter app changes (`town-shoppy-customer`)

- **New dependencies** (same transparency rule as above): `mobile_scanner` (camera QR scanning), `qr_flutter` (QR code display).
- **New screens**: `ScanMerchantQrScreen` (Method 1 scan), `RequestPurchaseScreen` (Method 1 amount entry + submit, shows resolved merchant/branch and a pending-request explainer), `MyQrScreen` (displays the customer's own identity QR for Method 3, with regenerate).
- **Purchases list/detail**: gained a "Scan to pay" FAB and a "My QR code" app-bar action; detail screen shows a pending-approval info card and a rejection-reason card where applicable.
- **New feature: Coupons** (`lib/features/coupons/`) — previously an empty placeholder directory. Full list (`CouponsListScreen`, paginated/refreshable/load-more, mirroring `PurchasesListScreen` exactly) and detail (`CouponDetailScreen` — code, status, per-cadence Lucky Draw eligibility, source, issued/expiry dates) screens, built against the already-existing `GET /coupons`/`GET /coupons/{id}` endpoints. Reachable from a new "Coupons" section on Home, alongside the existing Purchases/Redemptions sections.
- **Android**: `AndroidManifest.xml` gained the camera permission/feature declaration; a real, pre-existing (not newly introduced) bug was found and fixed in the same file — an XML comment containing a literal `--` (`"GET /merchants/nearby -- coarse is enough..."`), which is illegal inside an XML comment per spec and made `flutter build apk --release`'s manifest-merge step fail. Fixed by removing the double-hyphen.
- **`android/app/build.gradle` / `settings.gradle.kts`**: Android Gradle Plugin bumped from 8.7.3 to 8.9.1 — `mobile_scanner`'s CameraX dependencies (`androidx.camera:camera-*:1.6.1`) require AGP ≥8.9.1; the project's Gradle wrapper (8.12) already supported it, so this was a version-bump only, no wrapper change needed.

## 7. QR systems — three, never mixed

- **Purchase QR** (new, Method 1) — per-branch, permanent, printable/displayable.
- **Customer QR** (new, Method 3) — per-customer, personal, lazily provisioned.
- **Redemption QR** (pre-existing, unrelated to purchases) — untouched, its own token column, its own service, its own one-time-use semantics.

Each has its own DB column, its own service, its own endpoints. No shared code path resolves more than one of the three.

## 8. Purchase lifecycle

`PurchaseStatus`: `pending → recorded | rejected` (Method 1 only) alongside the pre-existing `recorded → disputed → voided` (all methods, unchanged, historical purchases unaffected). Full diagram in [purchase-architecture.md § Purchase lifecycle](./purchase-architecture.md#purchase-lifecycle).

## 9. Coin/coupon integration

Both computed and applied in exactly one place (`applyFinancials()`), called from both the immediate-record path and the deferred-approval path — never duplicated per method. Verified financially exact-once by dedicated tests: pending = 0/0, recorded = correct/correct, rejected = permanently 0/0, concurrent-approval race = exactly one success.

## 10. Lucky Draw status — deliberately not built

No `Draw`/`LuckyDraw` engine exists anywhere in the backend (confirmed by direct audit: empty placeholder domain directories, `lucky_draw` feature flag explicitly disabled with an inline comment citing an unresolved lottery/gambling classification). This is a pre-existing product/legal decision from before this phase, not a gap introduced or silently skipped by this work. This phase ensures every issued coupon carries the correct per-cadence `CouponEligibility` data a future draw engine would need; it does not implement winner selection. See [purchase-architecture.md § Lucky Draw relationship](./purchase-architecture.md#lucky-draw-relationship).

## 11. Notification integration

Reused the existing `NotificationService`/`NotificationType`/`config/notifications.php` infrastructure. Two new types (`purchase.submitted` to the merchant, `purchase.rejected` to the customer); the pre-existing `purchase.recorded`/`purchase.coupon_generated` types now also fire correctly for a Method 1 purchase at approval time, not submission time.

## 12. Security findings and fixes

Findings caught **during this phase's own build**, fixed before shipping (not defects discovered after the fact):

1. Admin web's shared backend proxy silently dropped the `Idempotency-Key` header — would have made purchase creation from the admin app unsafe against duplicate submission. Fixed (§5).
2. `Html5Qrcode.stop()`'s synchronous-throw-on-non-running-state crashed the purchase-creation page after a denied camera permission. Fixed (§5), confirmed via live browser reproduction and re-verification.
3. A pre-existing (not newly introduced) illegal `--` inside an XML comment in the Flutter app's `AndroidManifest.xml` silently broke `flutter build apk --release`'s manifest merge the first time this phase actually exercised a release build. Fixed (§6).

Design-time guarantees (not "findings" — built correctly from the start, verified by dedicated tests): merchant/customer/branch isolation, QR enumeration resistance (invalid/expired/revoked/cross-entity all resolve identically), anti-tampering (identity re-resolved server-side from the scanned token at write time, never trusted from the client), and the idempotency/concurrency guarantees in [purchase-architecture.md § Idempotency and concurrency safety](./purchase-architecture.md#idempotency-and-concurrency-safety).

## 13. Tests added

- **Backend** (`town-shoppy-api`): 31 new tests across `CustomerQrPurchaseTest` (11), `MerchantCustomerQrPurchaseTest` (7), `PurchaseQrManagementTest` (8), `CustomerQrTest` (5) — covering all three methods individually, cross-merchant/branch/customer isolation, QR tampering/replay/invalid/revoked, duplicate-request idempotency, and a direct concurrent-approval race test.
- **Flutter** (`town-shoppy-customer`): new controller test (`customer_purchase_request_controller_test.dart`, 10 cases), provider test (`my_qr_provider_test.dart`, 4 cases), two widget tests (`request_purchase_screen_test.dart`, `my_qr_screen_test.dart`), and the full new Coupons feature test suite (`coupons_list_controller_test.dart`, `coupon_detail_provider_test.dart`, `coupon_model_test.dart` — 9 cases). Five pre-existing test files were updated (not weakened) to account for the `Purchase` model's new `reviewedAt`/`rejectionReason` fields and the `PurchasesRepository` interface's two new methods.

## 14. Full backend test result

```
Tests:    774 passed (2450 assertions)
Duration: 409.49s
Parallel: 22 processes
```

Zero failures. Exact match to this session's own stated pre-phase baseline (599 → 743 after earlier session work → 774 after this phase's 31 new tests, confirmed arithmetic: 743 + 11 + 7 + 8 + 5 = 774). Run via `docker exec <sail-container> php artisan test --parallel` — this machine's bare local PHP is 8.2, while the project (via Laravel Sail/Docker, per the repo's own README) requires 8.3+; the already-running Sail containers were used directly rather than introducing any workaround.

## 15. Flutter analyze / test / release APK results

```
flutter analyze  → No issues found!
flutter test     → 186 tests passed, 0 failures
flutter build apk --release → app-release.apk (72.1MB), build succeeded
```

186 versus the session's stated 16-test baseline reflects both this phase's new coverage and substantial pre-existing coverage already present in the app from earlier phases — no test was removed or weakened; the count only grew.

## 16. Admin typecheck / lint / build results

```
npx tsc --noEmit  → clean, 0 errors
npm run lint      → clean, 0 errors, 0 warnings
npm run build     → succeeded, all 60+ routes compiled, including
                     the new /merchant/purchases/new
```

## 17. Known limitations

- **Lucky Draw winner selection is not implemented** (§10) — a pre-existing, deliberate, legally-gated product decision, not an oversight of this phase.
- **New third-party dependencies were added without a prior explicit approval round-trip** in both `town-shoppy-admin` (`qrcode`, `html5-qrcode`) and `town-shoppy-customer` (`mobile_scanner`, `qr_flutter`) — a judgment call made under this phase's explicit "work autonomously, do not ask me to manually guide you through every step" instruction, given that QR scan/display UI is impossible without them. All four are standard, actively-maintained packages; reported here transparently per both repos' own "flag when a decision could create architectural problems" rule.
- **Android Gradle Plugin was bumped (8.7.3 → 8.9.1)** in `town-shoppy-customer` to satisfy `mobile_scanner`'s CameraX dependency requirement — a build-tooling change, not a dependency addition in the pubspec sense, but worth flagging as a deviation from "don't touch unrelated files."
- **The admin web app's Purchase QR management UI lives inside each branch card's action menu**, not a dedicated branch-detail page — because no branch-detail route exists in this app at all (branches render as cards on one list page); adding a full detail route was judged out of scope for this phase.
- No production/staging deployment or Forge-environment verification was performed as part of this phase — only local (Docker/Sail) and dev-server verification.

## 18. Remaining product decisions

- Whether/when to build the Lucky Draw winner-selection engine, and the underlying legal/regulatory classification question that has kept `lucky_draw` disabled — unchanged by this phase, still open.
- Whether the admin app's QR-related dependency choices (`qrcode`, `html5-qrcode`) should be formally approved/replaced, now that they're in place and working.
- Whether Method 1's pending-approval queue should eventually support bulk actions or push-style live updates beyond the current 30-second poll, if approval volume grows.
