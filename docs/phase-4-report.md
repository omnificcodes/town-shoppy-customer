# TownShoppy Flutter Customer App — Phase 4 Report

**Scope:** Full Merchant Branches API + Customer Branch Integration
**Date:** 2026-08-20
**Baseline:** Phase 1 (auth, Home, Profile, Notifications) + Phase 2 (Purchases, Redemptions, Referrals) + Phase 3 (Merchant Discovery) — complete and unmodified in architecture; extended, not rebuilt.

---

## 1. Backend Contract

**New endpoint:** `GET /merchants/{merchant}/branches`

Public, no `auth:sanctum` middleware required — same optional-auth pattern as `GET /merchants/{merchant}`. Returns every **active** branch belonging to the given merchant, ordered primary-first (`is_primary DESC, id ASC`), as a plain array under `{success, data: [...]}` — no pagination meta, since a merchant's branch count is expected to stay small (Section 9 of the brief: "keep the API simple," matching how `GET /merchant-categories` is also an unpaginated flat array).

Visibility of the *merchant itself* follows the exact same rule `show()` already used: a non-active merchant (`pending`/`rejected`/`suspended`/`inactive`) 404s for any caller who can't pass `Gate::forUser($account)->allows('viewPrivate', $merchant)` — so this route cannot be used to enumerate branches of a merchant a caller isn't otherwise allowed to see. Confirmed live: a guest gets `404` for a `pending` merchant's branches; that same merchant's own owner gets `200`.

## 2. Authorization

Unlike `GET /merchants`, where a privileged caller (Super Admin / Association Admin) escalates from `MerchantPublicResource` to `MerchantPrivateResource`, the branch endpoint has **no privileged variant at all** — `MerchantBranchResource` has never carried any owner/financial/audit field, so every caller (guest, customer, merchant owner/staff, association admin, super admin) receives the identical public shape. Verified live with real accounts of every role against the same merchant: guest, customer, owner, staff, association admin, and super admin all returned byte-identical JSON.

## 3. Resource

`MerchantBranchResource` was extended with one new field — `is_primary` (boolean, always present, never `null`) — needed for the "Primary" label in a multi-branch UI (Section 24/section 3's own instruction: "If `is_primary` exists, use it"). No new resource class was created; the existing one already represented exactly the right public data.

Final field set: `id`, `name`, `is_primary`, `address_line`, `locality`, `city`, `state`, `postal_code`, `country`, `latitude`, `longitude`, `distance_km` (present only when the resource wraps a `nearby`-search row — absent here). Confirmed absent from every response: `status`, `merchant_id`, `deleted_at`, `created_at`, `updated_at`, and anything from `MerchantPrivateResource`.

## 4. Implementation (Backend Files Changed)

- `app/Domain/Merchant/Http/Resources/MerchantBranchResource.php` — added `is_primary`.
- `app/Domain/Merchant/Http/Controllers/MerchantController.php` — added `branches()`; extended `forgetPublicCache()` to also `Cache::forget("merchants:{id}:branches")` (fires on the same update/approve/reject/suspend/reinstate/deactivate/activate paths that already invalidate the merchant's public-detail cache).
- `routes/api.php` — added `Route::get('/merchants/{merchant}/branches', ...)` after the existing `show` route. No conflict with `/merchants/nearby` or `/merchants/{merchant}`: Laravel route parameters match exactly one URI segment by default, so the three-segment `/merchants/{id}/branches` never competes with either two-segment route regardless of registration order — confirmed live and via a dedicated Pest regression test.
- **Caching**: follows the exact convention `show()` already established — `Cache::remember("merchants:{id}:branches", 15 min, ...)`, the same TTL `docs/architecture/caching-strategy.md` documents for merchant-profile data, and the same `json_decode(json_encode(...))` round-trip that avoids the documented Redis `__PHP_Incomplete_Class` corruption bug. No new caching framework was introduced.
- **Branch filtering/ordering**: only `status = 'active'` branches are returned (matching the existing domain convention already used by `NearbyMerchantSearchService` and `Offer::isPubliclyVisible()` — never invented fresh for this endpoint), ordered primary-first. Soft-deleted branches are excluded automatically (`SoftDeletes` on the model).

No migration, model, or policy changes were needed — the `is_primary` and `status` columns already existed on `merchant_branches`.

## 5. Flutter Integration

Phase 3's existing architecture was extended, not rebuilt:

- `lib/features/merchants/data/models/merchant_branch_ref.dart` — added `isPrimary` (defaults `false` if the field is ever absent).
- `lib/features/merchants/data/merchants_repository.dart` — added `getBranches(int merchantId)`, calling `GET /merchants/{merchantId}/branches` through the same `Dio`/`ApiEnvelope` pattern `list()`/`show()` already use. No new repository class — one dedicated method on the existing repository was the minimal fit.
- `lib/features/merchants/application/merchant_branches_provider.dart` (new) — `merchantBranchesProvider = FutureProvider.family<List<MerchantBranchRef>, int>`, deliberately not watching `sessionEpochProvider` (same public-data reasoning as `merchantDetailProvider`/`merchantCategoriesProvider` from Phase 3).
- `lib/features/merchants/presentation/merchant_detail_screen.dart` — replaced the old `merchant.branch != null ? [merchant.branch!] : []` single-branch list with a new `_BranchesSection` that watches `merchantBranchesProvider(merchant.id)` directly and handles its own loading/error/data states.
- `lib/features/merchants/presentation/branch_selector.dart` — extended (not rebuilt) to show a small "Primary" label on the primary branch's tile, but **only when there's more than one branch** — a lone branch still displays exactly as it did in Phase 3, with no label.

## 6. Merchant Detail UX

- **One branch**: displays plainly, heading reads "Branch" (singular), no "Primary" label — unchanged from Phase 3's behavior.
- **Multiple branches**: heading reads "Branches" (plural), the primary branch carries a small orange "Primary" label above its name, every branch shows its name and formatted address, no opening hours anywhere (none exist in the resource).
- **Zero branches**: the existing `BranchSelector` empty state — "No branch information available." / "This merchant has not published a branch location yet." — reused as-is; no new empty-state copy was needed since Phase 3 already wrote exactly this message.
- **Branch-section failure**: does not take down the rest of the merchant profile — a compact retryable `ErrorState` renders in place of just that section, mirroring how Phase 3 already isolated the category-chip row's own failure from the merchant list.

`BranchSelector` remains genuinely reusable in its interactive (`onSelected` non-null) mode for a future redemption picker — this phase only ever passes `onSelected: null` in `MerchantDetailScreen`, per the explicit "keep it informational, don't wire redemption" instruction.

## 7. Security

- **Merchant scoping**: `GET /merchants/10/branches` can never return Merchant 11's branches — enforced by Eloquent route-model binding plus an explicit `$merchant->branches()` relation query (never a raw `MerchantBranch::all()`/global scope). Verified by both a dedicated Pest test and a live two-merchant HTTP comparison.
- **Private-field protection**: `MerchantBranchResource`'s explicit allowlist (`array_filter` over a fixed key set) makes it structurally impossible to leak `merchant_id`, `status`, `deleted_at`, or any timestamp — confirmed by a Pest assertion checking the *absence* of those keys, not just the presence of the expected ones.
- **Cache isolation**: the new `merchants:{id}:branches` cache key is per-merchant by construction; a dedicated Pest test warms both Merchant A's and Merchant B's cache entries and asserts neither response ever contains the other's branch names. A second test confirms a merchant `PATCH` invalidates its own cached branch list.
- **No regression to customer-scoped cache isolation**: `sessionEpochProvider`-watching providers from Phases 1–3 (Profile, Purchases, Redemptions, Referrals, Notifications) are untouched. The two new Phase 4 providers (`merchantBranchesProvider`) deliberately don't watch it, for the same reason `merchantDetailProvider` doesn't — verified live: Customer, guest, owner, staff, association admin, and super admin all received byte-identical branch data for the same merchant.

## 8. Testing

**Backend (Pest):**
`tests/Feature/Merchant/MerchantBranchDiscoveryTest.php` (new, 20 tests) — the full authorization matrix (guest/customer/owner-staff/association-admin/super-admin, all confirmed identical to guest; a pending merchant 404s for a guest but 200s for its own owner), merchant scoping (A never leaks into B; an invalid ID 404s), dataset sizes (zero/one/multiple branches, primary-first ordering), an inactive branch excluded, a soft-deleted branch excluded, resource-field presence/absence, three route-regression tests (`/merchants/nearby` and `/merchants/{id}` still resolve; the new route resolves distinctly), and two cache-regression tests (per-merchant isolation; invalidation on merchant update).

**Flutter:**
- `merchant_branch_ref_test.dart` — 2 new tests for `isPrimary` parsing (true/false, and defaulting to `false` when absent).
- `merchant_branches_provider_test.dart` (new) — loaded list, empty-list-vs-failure distinction, backend-error propagation (via the established `hasError`-polling pattern for Riverpod 3.3.2's auto-retry), and independent caching per merchant ID.
- `branch_selector_test.dart` — 2 new tests: the "Primary" label appears when there's more than one branch, and does **not** appear for a lone branch even when `is_primary` is `true`.

## 9. Exact Results

| Check | Result |
|---|---|
| `flutter analyze` | **No issues found.** |
| `flutter test` | **79/79 passing** (71 at the end of Phase 3 → 79; +8 new tests) |
| `flutter build apk --release` | **succeeded**, 49.2MB (51,545,217 bytes) |
| Backend Pest (Docker Sail, 22 parallel processes) | **620 passed, 1,976 assertions, 0 failures** (600/1,905 baseline + exactly the 20 tests/71 assertions this phase added — zero regressions) |
| Pint | **0 style issues** across 393 files (one import-style issue in the new test file was auto-fixed before the final run) |
| Admin `tsc --noEmit` | clean |
| Admin ESLint | clean |
| Admin `next build` | succeeded across every route |

## 10. QA

Verified live in the Browser pane against the real running backend (not mocks) at **375px, 390px, and 430px**:
- A merchant with two branches: "Branches" heading, orange "Primary" label on the first tile only, both full addresses, no opening hours, no horizontal overflow at any of the three widths.
- A merchant with zero branches: the polished "No branch information available" empty state, no overflow.
- A merchant with exactly one branch: "Branch" heading (singular), no "Primary" label — confirming the label is suppressed for a lone branch even though its `is_primary` value is `true`.
- Network tab confirmed the real `GET http://localhost:8000/api/v1/merchants/{id}/branches` call (200 OK) on every load — not stubbed data.

Two harmless `MIME type`/`Refused to execute script` console errors appeared during the very first page reload after a fresh dev-server restart — the same benign Flutter-web hot-reload/service-worker race documented in Phase 2's report, unrelated to this feature; the app loaded and rendered correctly on every subsequent navigation and reload.

## 11. Bugs Discovered

**None.** No backend defect was found or fixed this phase — the two new fields (`is_primary` on the resource, and the endpoint itself) were additive extensions of an already-correct domain, not fixes to a broken one.

## 12. Remaining Limitations (unchanged from Phase 3, confirmed still accurate)

- **Search**: `GET /merchants` still has no text-search parameter — not touched this phase, out of scope.
- **Town filter**: `GET /merchants` still has no `town_id` parameter — not touched this phase, out of scope.
- **Nearby/location**: `GET /merchants/nearby` still requires client-supplied GPS coordinates and its own pagination-meta gap (noted in Phase 3) remains unfixed — no location architecture exists yet in the Flutter app, and this phase deliberately left `nearby` untouched (confirmed via regression tests that it still works exactly as before).
- **Redemption**: `POST /redemptions` was not built. With this phase's branch endpoint in place, the last concrete backend gap blocking it is now closed — a customer can discover a merchant, view its full branch list, and (per `RedemptionController::store()`, read in Section on the redemption contract) supply a `branch_id` from that real list to `POST /redemptions`. Building the initiation flow itself is the next milestone.

## 13. Next Milestone (recommend only, not started)

**Redemption Initiation** — branch selection (via the now-genuinely-reusable interactive `BranchSelector`) → bill amount entry → the verification/QR flow `RedemptionController::store()` already returns (`qr_secret`, `otp_code`) → `POST /redemptions` → confirmation screen. This is the natural next step now that every backend piece it depends on (merchant discovery, merchant detail, full branch list) is proven and in place — but per this phase's own scope boundary, it was not started.
