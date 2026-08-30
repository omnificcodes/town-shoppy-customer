# TownShoppy Flutter Customer App — Phase 3 Report

**Scope:** Merchant Discovery + Merchant/Branch Selection Foundation
**Date:** 2026-08-20
**Baseline:** Phase 1 (OTP auth, Home, Profile, Notifications) + Phase 2 (Purchases, Redemptions, Referrals) — complete and unmodified in architecture; extended, not rebuilt.

---

## 1. Backend Contract Discovered

Before writing any UI, the actual customer-facing merchant/branch/category/town contract was read directly from the backend source — `MerchantController`, `MerchantPolicy`, `MerchantCategoryController`, `TownController`, `AssociationController`, and every relevant Resource — rather than assumed from the Admin platform's (privileged) merchant endpoints.

| Capability | Backend support | Notes |
|---|---|---|
| List merchants | `GET /merchants` | Offset-paginated (`{current_page, last_page, per_page, total}`), no `auth:sanctum` middleware required |
| Filter by category | `GET /merchants?category_id=` | Real, server-side |
| Filter by association | `GET /merchants?association_id=` | Real, server-side (not surfaced in UI — no customer-facing reason to filter by association directly) |
| Filter by town | Not available | No `town_id` parameter exists on `index()` |
| Text search | Not available | No search parameter exists on `index()` |
| Merchant detail | `GET /merchants/{id}` | Returns the same `MerchantPublicResource` shape as the list |
| Merchant categories | `GET /merchant-categories` | Public, unpaginated flat array |
| Merchant's branch list | **Backend capability not currently available** | `MerchantPublicResource.branch` returns only `$this->branches->firstWhere('is_primary', true)` — a single branch, never a list. No route anywhere returns a merchant's full branch set to a customer or guest caller. |
| Nearby search (geolocation) | `GET /merchants/nearby` | Exists, requires `lat`/`lng`; out of scope this phase (no location architecture yet) — see Section 11 |
| Opening hours | **Backend capability not currently available** | No such field exists on any Merchant/Branch resource |
| Town discovery | `GET /towns` | Read, but not surfaced as a filter since `/merchants` has no `town_id` parameter to pair it with |

Following the brief's instruction, every "not available" row above is a genuine finding from reading the controller/resource code and confirming it live over HTTP (Section 6) — nothing here was assumed or inferred from the Admin platform.

## 2. Authorization Model

`MerchantController::index()` computes `isPrivileged = $isSuperAdmin || $adminAssociationIds !== []` — a customer account and a merchant-owner/staff account are **never** privileged for this endpoint. Verified directly over HTTP with a three-way comparison of the exact same request (`GET /merchants`) sent unauthenticated, as a real seeded Customer A token, and as a real seeded Customer B token: all three returned byte-identical `MerchantPublicResource` payloads. The same comparison was repeated for `GET /merchants/{id}` and `GET /merchant-categories`.

This confirms merchant/category discovery is fully public, non-personalized data — the deliberate architectural consequence (Section 6) is that these providers do not participate in the `sessionEpochProvider` cache-isolation mechanism the rest of the app uses, because there is no cross-account data to isolate.

## 3. Screens Implemented

| Screen | Route | Status |
|---|---|---|
| Home "Discover merchants" entry card | `/home` (existing screen, new card) | Complete |
| Merchant list (search/browse) | `/merchants` | Complete — category filter, infinite scroll, pull-to-refresh |
| Merchant detail | `/merchants/:id` | Complete — hero header, about, branch, website |

Deliberately **not built** this phase: any form of redemption initiation, a multi-branch picker UI (the backend has no data to power one — see Section 11), a town filter, and a search box — all because the backend genuinely does not support them, not because they were deprioritized.

## 4. API Integration

| Endpoint | Method | Used by |
|---|---|---|
| `/merchants` | GET | `MerchantsRepository.list()` — `page`, `per_page`, optional `category_id` |
| `/merchants/{id}` | GET | `MerchantsRepository.show()` |
| `/merchant-categories` | GET | `MerchantCategoriesRepository.list()` |

All three were verified against the real running Sail backend via direct HTTP with a real Sanctum token (Section 6), not mocks, before any Flutter code consumed them.

## 5. Merchant Discovery UX

- **List**: `MerchantsListScreen` — a horizontally-scrolling category-chip filter row above a card list, infinite scroll triggered 200px before the bottom, pull-to-refresh, and a `MerchantsListController` (`AsyncNotifier`) mirroring Phase 2's `PurchasesListController`/`RedemptionsListController` shape adapted for the same `OffsetPage<T>` contract `/purchases` and `/redemptions` already use — no new pagination model was needed.
- **Cards**: `MerchantCard` shows only fields the resource actually returns — logo (with fallback, Section 5 below), name, category, town/state (via `association.town`), and a discount badge that only renders when `discount_rate` is non-null.
- **Categories**: a horizontal chip row (`CategoryChip`, with an "All" chip first) sourced from `GET /merchant-categories`; tapping a chip calls `filterByCategory`, which resets to page 1 and re-requests with the new `category_id` (no-op if the same category is re-tapped).
- **Town filter**: not built — no `town_id` parameter exists on `/merchants` to pair it with (Section 1).
- **Search**: not built — no search parameter exists on `/merchants` (Section 1); documented here as a future backend enhancement rather than faked with client-side filtering, which the brief explicitly prohibited.
- **Detail**: `MerchantDetailScreen` — a gradient hero header (logo, name, category, town/state, an "Accepts Town Coin" badge when true), an "About" section only when `description` is non-empty, a "Branch" section, and a "Website" section only when `website_url` is non-empty.
- **Branch section**: renders via the shared `BranchSelector` widget in its non-interactive (`onSelected: null`) mode, showing the merchant's one available branch (name + `formattedAddress`) with **no opening-hours field**, since none exists in the resource. `BranchSelector` is built genuinely list- and selection-capable (`onSelected: ValueChanged<int>?`, a `selected` radio state) specifically so a future redemption-initiation branch picker can reuse it without rework — but it is not wired into any redemption-submission flow this phase.
- **Image loading**: `MerchantLogo` shows a shimmer skeleton while loading, a graceful storefront-icon placeholder on missing/null `logo_url` or a network failure, and never a broken-image icon.
- **Empty/error states**: the list screen distinguishes "no merchants exist yet" from "no merchants in this category" (offering a "Clear filter" action only in the latter case), and both list and detail screens use the shared `ErrorState` widget (friendly copy + retry, never raw Laravel/HTTP details) on failure.

## 6. Security

- **Public/private boundary**: `Merchant`, `MerchantBranchRef`, `AssociationRef`, `TownRef`, and `MerchantCategory` were modeled to mirror `MerchantPublicResource`/`MerchantBranchResource`/etc. field-for-field. None of `owner_name`, `contact_mobile_number`, `gst_number`, `verified_at`, `rejection_reason`, or `duplicate_flag_notes` (all `MerchantPrivateResource`-only fields) are ever requested or parsed — the app structurally cannot reach `MerchantPrivateResource`, since `MerchantController::index()`/`show()` never return it to a non-privileged caller.
- **Customer isolation**: not a concern for this data — Section 2's three-way comparison confirms merchant/category data is identical across accounts and for guests.
- **Cache isolation (Phase 1/2 regression check)**: re-verified that `sessionEpochProvider` (bumped on login/logout) is still correctly watched first by every *customer-scoped* provider from Phases 1–2 (Purchases, Redemptions, Referrals, Profile, Notifications) — unchanged, unregressed. The three new Phase 3 providers (`merchantCategoriesProvider`, `MerchantsListController`, `merchantDetailProvider`) deliberately do **not** watch it, with the reasoning documented inline in each file's own docblock — the first deliberate exception to that pattern, justified by Section 2's live verification rather than assumption.
- **Performance**: `merchant-categories` (small, effectively-static reference data) is fetched once per app session via `FutureProvider` and reused across the filter row and any future screen that needs it; the merchant list only ever requests the next page on scroll or explicit filter change — no duplicate or speculative requests.

## 7. Responsive QA

Verified live in the Browser pane at **375px width** (iPhone SE class): the merchant list, category chip row, merchant cards, and merchant detail screen (including the branch address, which wraps correctly across lines) all rendered with no horizontal overflow.

**Honestly reported gap**: 390px and 430px were not separately verified this session, nor was a physical device or emulator used — only the 375px browser-pane check above and the full widget-test suite (which exercises the same layout code at its default test-harness size) were completed. Given the layout uses relative/flexible widgets throughout (no fixed pixel widths beyond icon sizes), a regression at the wider breakpoints is unlikely but not proven. This is flagged the same way Phase 2 flagged its own unfinished visual-QA pass rather than being glossed over.

## 8. Accessibility

- `BranchSelector`'s tiles carry an explicit `Semantics(button:, selected:, label:)` wrapping the branch name and formatted address into one accessible label, and selection state is conveyed via icon (filled vs. outlined radio) plus color, never color alone.
- `MerchantCard` and `CategoryChip` use standard tappable Material widgets (`InkWell`/`ChoiceChip`-equivalent) sized to the existing design system's touch-target minimums, consistent with Phases 1–2.
- `MerchantLogo`'s placeholder/loading/error states all render through standard `Image`/`Icon` widgets with no custom semantics suppression, so screen readers announce the merchant name (via the surrounding card's semantics) regardless of image-load outcome.
- Not separately tested this session with a real screen reader (TalkBack/VoiceOver) — verified structurally via the widget tree and `Semantics` assertions in `branch_selector_test.dart`, consistent with how accessibility was verified in Phases 1–2.

## 9. Build & Regression Verification

- `flutter analyze`: **No issues found.**
- `flutter test`: **71/71 passing** (up from 44 at the end of Phase 2 — 27 new tests this phase).
- `flutter build apk --release`: **succeeded** (49.2MB / 51,545,212 bytes).
- Backend Pest (Docker Sail, 22 parallel processes): **600 passed, 1,905 assertions, 0 failures** — unchanged from the Phase 2 baseline, confirming zero regressions and, since no backend code was touched this phase (Section 11), zero new backend tests were needed either.
- Pint: **0 style issues** across 392 files.
- Next.js admin app: `tsc --noEmit` clean, `eslint` clean, `next build` succeeded across every route — confirms this phase's (zero) backend changes did not regress the admin platform, as expected.

## 10. Bugs Found

**None.** Unlike Phases 1 and 2, no backend defect was discovered or fixed this phase — the Pest count stayed at exactly 600/1,905/0 throughout, and the only backend "finding" (Section 1's `nearby()` pagination-meta gap) was deliberately left unfixed since it sits entirely outside this phase's milestone (see Section 11).

## 11. Backend Limitations (confirmed, not assumed)

- **Headline gap — no full branch-list endpoint for customers.** `MerchantPublicResource.branch` exposes only the merchant's single primary branch; there is no `GET /merchants/{id}/branches` (or equivalent) route anywhere in `routes/api.php`. This is the single largest blocker for the eventual redemption-initiation flow, which needs the customer to choose from potentially multiple branches before submitting `POST /redemptions`. `BranchSelector` was deliberately built list- and selection-capable so no rework is needed once this endpoint exists — only its data source needs to change.
- **`GET /merchants/nearby` has its own undiagnosed pagination-meta gap** — `MerchantController::nearby()` serializes its cached response via `json_decode(json_encode(NearbyMerchantResource::collection($paginated)))` rather than `->response()`, so it never emits `{meta: {...}}` at all. Noted but deliberately not fixed this phase: `nearby` requires device geolocation, and no location-permission/architecture exists yet in the Flutter app, putting it out of scope for this milestone regardless of the pagination gap.
- No `town_id` filter and no text-search parameter exist on `GET /merchants` — both would need new backend query support before a town filter or search box could be built as anything more than a UI stub.

## 12. Recommended Next Milestone (recommend only, not started)

Add the missing `GET /merchants/{id}/branches` endpoint (or extend `MerchantPublicResource` to include the full branch collection) as its own small, backend-first milestone — it is the one concrete gap directly blocking **redemption-initiation** (`POST /redemptions`), which otherwise now has everything else it needs: merchant discovery, merchant detail, and a branch-picker component already built and ready to receive real multi-branch data. Once that endpoint exists, redemption-initiation itself (branch selection → bill amount → verification code/QR flow) is the natural following milestone. `nearby()`'s pagination-meta gap and a town/search-capable `/merchants` endpoint are smaller, independent backend follow-ups after that.
