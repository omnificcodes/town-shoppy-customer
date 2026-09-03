# Town Shoppy — Lucky Draw 2.0 Final Report

**Scope:** all three repositories — `town-shoppy-api` (Laravel backend), `town-shoppy-admin` (Next.js admin/merchant/association-admin app), `town-shoppy-customer` (Flutter customer app). This report covers the redesign of Lucky Draw from a scheduled-feeling, multi-step admin workflow into a manual, single-action "Run Lucky Draw" experience with business/prize curation, a premium command-center UI, and a presentational winner-reveal sequence — built on top of, and reusing, the Lucky Draw/Prize/Coupon engine from the prior pass (see [final-production-readiness-report.md](./final-production-readiness-report.md) for that engine's original build and audits).

---

## 1. New Lucky Draw architecture

No parallel or duplicate system was created. Lucky Draw 2.0 is the same `Draw`/`Prize`/`DrawWinner`/`Voucher` schema and the same `DrawService`/`PrizeService`/`VoucherService` engine from the original build, extended with:

- One new orchestration method, `DrawService::runDraw()`, that performs create → allocate prizes → lock pool → execute as a single call — the same four backend steps that already existed, now invoked together instead of as four separate admin actions.
- One new read-only method, `DrawService::previewEligibleCount()`, for the live "eligible coupons" number the management screen shows before any commitment.
- A real bug fix in the shared eligibility query: `scope=all` now correctly bounds to the draw's own association (previously unbounded — see §14).
- A new business-authorization rule at prize-allocation time (§4).

Every existing safeguard (row-lock+recheck state machine, one-coupon-wins-at-most-one-prize, at-most-one-unit-of-the-same-prize-per-customer, frozen eligibility snapshots) is unchanged and still enforced by the same code paths `runDraw()` calls into.

## 2. Manual draw workflow

The Association Admin can run a draw at any time — there is no schedule, no cron, no "next Monday" concept anywhere in the system. The single "Run Lucky Draw" button on the new management screen (`/association-admin/draws/new`) does the following, synchronously, in one request:

1. Validates cadence, businesses, and prizes (all server-side — see §14).
2. Creates the `Draw` row.
3. Allocates every selected prize to it.
4. Locks the eligibility pool (freezes exactly which coupons are in the running).
5. Executes — selects winners, issues vouchers, closes eligibility for the cadence just consumed.
6. Returns the fully complete (or `failed`, if the pool turned out empty) draw.

The frontend never waits for or drives any of this — by the time `POST /draws/run` resolves, the draw is already finished. What the admin sees afterward (§13) is a presentation of an already-decided result, not a live process.

## 3. Three-cadence eligibility model

Weekly, Monthly, and Mega are not schedules — they identify which of a coupon's three independent eligibility rows is being consumed. This was already true in the original Coupon/CouponEligibility design (one row per coupon per cadence) and is unchanged here. Running a Monthly draw closes only `cadence=monthly` eligibility rows for the coupons in its pool; a coupon's Weekly and Mega rows are untouched, exactly as the product rule requires. Verified directly (§18, Scenario A-equivalent test): a Monthly draw with 5 eligible coupons closes all 5 monthly rows (2 to `won`, 3 to `closed`) while every one of those same coupons' weekly and mega rows remain `active`.

## 4. Business filtering

`scope=all` or `scope=selected_merchants` (pre-existing `Draw.scope` column, unchanged) controls which merchants' coupons are pooled — enforced entirely server-side inside `DrawService`'s eligibility query, never trusted from the frontend. The management screen's business panel (search, select all/deselect all, individual checkboxes) is a pure UI convenience over the same `merchant_ids` parameter the backend re-validates independently.

**Fixed this pass:** `scope=all` previously had no association boundary at all — it pooled every eligible coupon platform-wide, regardless of which association's merchants generated it. It now correctly bounds to the draw's own association's merchants, matching the product requirement ("Eligible coupons come from all eligible businesses within the Association scope"). This was a real, silent bug in the original engine, not something introduced by this pass — caught and fixed while implementing the preview endpoint, with two existing tests' fixtures updated to reflect the corrected (correct) behavior and a new regression test added.

## 5. Prize filtering

New rule, additive to the existing engine: when a draw is scoped to selected businesses, a prize can only be allocated to it if the prize's sponsor merchant is one of those selected businesses (`PrizeService::allocateToDraw()`, enforced server-side, a 422 on violation). This is a draw-*setup*-time curation rule, distinct from — and does not alter — BR-19 (a *winning* coupon's purchase merchant is still independent of the prize's sponsor; that fairness guarantee is unchanged once a prize is legitimately allocated). `scope=all` carries no such restriction, matching prior behavior. The management screen's prize panel filters its choices the same way as a UX convenience, re-validated by the backend regardless.

## 6. Winner selection

Unchanged from the original engine and re-confirmed this pass: 100% server-side `random_int()`, inside a row-locked transaction, zero client-controllable input. One winner per selected prize (a prize's `quantity_remaining`, almost always 1 for a Lucky Draw 2.0 sponsored prize); a coupon can win at most one prize per draw; a customer can win at most one unit of the *same* prize per draw. All pre-existing guarantees, all still enforced by the same `selectOneWinner()`/`drawWinnersForPrize()` code `runDraw()` calls into unchanged.

## 7. Draw state machine

Unchanged: `open → pool_locked → executing → complete`, or `→ cancelled` (pre-lock) / `→ failed` (empty pool at lock). `runDraw()` drives a draw through this exact sequence in one call rather than four; it never introduces a new status or bypasses a transition. A `failed` result (empty pool) is a normal, tested outcome, not an error — surfaced to the admin plainly, not as a crash.

## 8. Coupon lifecycle

Unchanged. A coupon's three `CouponEligibility` rows (weekly/monthly/mega) are created identically at purchase time (see §3 of the prior report) and closed only for the cadence a draw actually consumes. Nothing about Lucky Draw 2.0 changes how coupons are issued, how many, or from which purchase amounts.

## 9. Notifications

Built this pass, reusing the existing `NotificationService`/`NotificationType`/channel architecture — no second notification system:

- **New: Email channel.** No email-sending capability existed anywhere in this codebase before this pass. Added `NotificationChannel::Email`, an `EmailNotificationChannel` using Laravel's built-in `Mail` facade (works correctly against the `log` driver in dev; a real provider is an `.env`/ops decision, not a code one), and Blade email templates for the winner and sponsor-merchant notifications.
- **New: `PrizeWon` notification type** — the merchant-sponsor-facing counterpart to the existing `DrawWon` (customer-facing). Fired from `DrawService::notifyWinners()` for the sponsor's active owner account, with a masked winner label (never the real name/mobile number), in-app + email + WhatsApp.
- **`DrawWon`** gained WhatsApp and email channels (previously in-app + SMS only).
- **Now genuinely wired (final closure pass):** `accounts.email` (nullable, unique, with `email_verified_at`) is the real recipient field the email channel resolves against — see §23. Email delivery for both the winner (`DrawWon`) and the sponsoring merchant owner (`PrizeWon`, falling back to `merchants.contact_email`) is exercised end-to-end by real HTTP/database tests, not a direct `deliver()` call.

## 10. Customer experience

No changes were needed. The customer-facing coupon eligibility display (per-cadence status: pending/won/closed, in the coupon detail screen) and the Lucky Draw results/voucher-claim UI (draws list, draw detail with masked winners, My Vouchers with claim QR) were already built in the prior pass and require no data-shape changes to correctly reflect Lucky Draw 2.0 — a manually-run draw looks identical, from the customer's side, to any other completed draw. Confirmed by reading the existing screens: they already key entirely off `Draw`/`DrawWinner`/`Voucher` records, which are structurally unchanged.

## 11. Merchant experience

**New this pass:** the merchant's sponsored-prize detail page (`/merchant/prizes/[id]`) now shows a "Congratulations" banner and a Winners section (masked winner name, claim status, claimed timestamp) once a sponsored prize has been won — previously this page showed no winner information at all. Prize proposal gained an optional monetary "value" field (`prizes.value`, new nullable column), shown on prize cards and the detail page.

## 12. Association Admin experience

**Rebuilt this pass.** The old "New draw" page (a bare cadence dropdown + scope radio + merchant checklist, requiring four more separate actions afterward to add prizes/lock/execute) is fully replaced by the "Lucky Draw Management" screen at the same route (`/association-admin/draws/new`):

- Cadence selector (three large cards, described as "which eligibility pool," never as a schedule).
- Two-panel layout: sponsored-prize cards (image, sponsor, value, quantity, status, checkbox) on the left, a searchable business picker (all/select-all/individual) on the right, each filtering the other.
- A live draw summary (type, prize count, business count, eligible-coupon count — the last one fetched from the backend in real time, never computed client-side).
- A rich confirmation dialog before the irreversible action.
- A ~2-minute, staged, presentational reveal sequence after confirming (preparing → shuffling → selecting → per-prize reveal → winner results), backed by an already-complete result — refreshing mid-animation re-fetches the same (already-finished) draw rather than re-running anything, verified live.
- The Draw History detail view gained "Created by" (the initiating admin's mobile number) and a "Businesses" section listing the scoped merchants by name — both previously entirely unexposed by the API.

## 13. Super Admin experience

Unchanged and re-confirmed: Super Admin already has unrestricted visibility across every association's draws/prizes/winners via the existing `hasRole(SuperAdmin)` bypass on every relevant Policy and query scope — nothing in this pass narrowed or altered that. No Association-Admin-only capability was extended to Super Admin beyond what already existed (Super Admin was always able to act on any association's behalf, per the original engine's design).

## 14. Security

- **Fixed:** `scope=all` unbounded-by-association gap (§4) — a real, exploitable-by-accident data-scoping bug (not a malicious-actor concern given the caller is already gated to their own association, but a real "wrong data pooled" defect) that predates this pass and was caught and closed here.
- **New rule enforced server-side:** prize-sponsor-within-selected-businesses (§5), rejecting a mismatched allocation with a 422 regardless of what the frontend sent.
- **New:** merchant-ids-belong-to-this-association and prize-ids-belong-to-this-association validation on `runDraw()` — both return a 422 with a clear message rather than silently succeeding or 500ing.
- **New:** an unrelated but real infrastructure issue was found and fixed during live verification — the local dev container's `auth-*.log` file for the current day had been created with `root` ownership (from an earlier `docker exec` run as root), causing every login to throw a permission-denied exception and fail with a 500. Fixed by restoring correct ownership; flagged here since it's the kind of issue that would also occur in a real deployment if any process ever writes to the app's log directory as a different user than the web server runs as.
- Every pre-existing security guarantee from the original Lucky Draw audit (server-side-only winner selection, `Gate::authorize()` on every write, no cross-association/cross-merchant leakage, no QR/voucher secret exposure) is unchanged and still enforced by the same code `runDraw()` calls into.

## 15. Concurrency protection

Unchanged from the original engine, and this is the reason `runDraw()` needed no new locking logic of its own: every step it calls (`lockPool()`, `execute()`, `PrizeService::allocateToDraw()`) already row-locks and re-checks its own state transition before proceeding, making duplicate execution structurally impossible regardless of how many callers race. **New:** `runDraw()` itself is additionally idempotency-keyed (`draws.idempotency_key`, new unique column) — a double-click or client retry of the exact same "Run Lucky Draw" submission returns the already-created draw instead of attempting to create a second one, mirroring the established Purchase/Redemption idempotency pattern exactly. Verified by a dedicated test: two identical requests with the same key produce exactly one `Draw` row.

## 16. Database changes

Two additive migrations, no destructive changes, no historical data altered:

- `draws.idempotency_key` (nullable, unique string) — backs §15.
- `prizes.value` (nullable decimal(12,2)) — purely informational display data, never used in any eligibility/selection calculation.
- **Final closure pass:** `accounts.email` (nullable, unique string) + `accounts.email_verified_at` (nullable timestamp) — see §23. `merchants.contact_email` (nullable string, no uniqueness constraint, mirrors `contact_mobile_number`) — see §23.

## 17. API changes

- `GET /draws/preview` (new) — count-only, no persistence, given `association_id`/`cadence`/`scope`/`merchant_ids`.
- `POST /draws/run` (new) — the single consolidated action (§2), requires an `Idempotency-Key` header.
- `POST /draws` (existing `store()`) — left in place, unused by the new UI but not removed, for API-level backward compatibility.
- `DrawResource` gained `merchant_scopes` (array of `{id, name}`) and `created_by` (initiating admin's mobile number), both manager-only, both newly eager-loaded by `index()`/`show()`.
- `PrizeResource` gained `value` and a conditional `winners` array (`{voucher_id, winner_label, claim_status, claimed_at}`, masked), eager-loaded by `PrizeController::show()`.
- **Fixed:** `GET /draws/{draw}/winners`, and the `confirmWinner`/`forfeitWinner` responses, were missing `prize.sponsorMerchant` in their eager-loads — every winner reveal was silently showing "Sponsored by —" instead of the real merchant name. Found during live browser verification of the new reveal screen, fixed, and covered by a new regression test.
- **Final closure pass:** `POST /auth/email` (new, authenticated) — sets/normalizes the caller's own account email, no-ops on resubmitting the current value, resets `email_verified_at` on a genuine change. `AccountResource` gained `email`/`email_verified_at` (self-view only — confirmed no other resource ever returns another account's `AccountResource`). `MerchantPrivateResource` gained `contact_email`, settable only at merchant registration (`RegisterMerchantRequest`), mirroring the existing `contact_mobile_number` convention. See §23.

## 18. Tests

New/updated backend Pest tests, all passing:

- `tests/Feature/LuckyDraw/RunDrawTest.php` (new, 13 tests): preview count correctness (both scope modes, including the association-boundary fix), the full run-a-draw happy path (Scenario-A-equivalent: all businesses, 2 prizes, 2 winners, cross-cadence isolation verified), a single-business-scoped run (Scenario-B-equivalent: excluded-business coupons never participate), rejecting an out-of-association business/prize, rejecting a prize whose sponsor is outside the selected scope, idempotency-key replay producing exactly one draw, missing-cadence/missing-prizes validation, missing-Idempotency-Key rejection, cross-association admin rejection, empty-pool-graceful-failure, and the sponsor-merchant-name regression (§17).
- `tests/Feature/LuckyDraw/DrawPoolAndExecutionTest.php` (updated): two tests' fixtures corrected to tie their coupons' merchants to the draw's own association — they were silently relying on the pre-fix unbounded `scope=all` behavior and would have passed trivially (0 == 0) had the fix not been made and the fixtures not been corrected alongside it.
- `tests/Feature/Notification/DrawWonNotificationTest.php` (final closure pass: 7 tests, up from 5): email delivery for the winner, the new `PrizeWon` notification to the sponsor, a graceful no-op when a recipient has no email on file, plus two new end-to-end tests added this pass — real winner+sponsor email delivery via the actual HTTP `execute()` endpoint using real `accounts.email` column values (replacing an earlier in-memory-only `setAttribute()` workaround now that the real column exists), and the `merchants.contact_email` fallback when the sponsor's owner account has none.
- `tests/Feature/Auth/UpdateEmailTest.php` (new, final closure pass, 7 tests): set-email-first-time, normalize-and-collide-on-uniqueness, reject-invalid-format, reset-`email_verified_at`-on-change, no-op-on-resubmitting-the-same-value, requires-authentication, and `GET /auth/me` exposing both new fields.

## 19. Build verification

| Check | Result |
|---|---|
| Backend — `php artisan test --parallel` | **834 passed, 0 failures** (2659 assertions) — up from 825, includes the new email-architecture tests |
| Flutter — `flutter analyze` | No issues found |
| Flutter — `flutter test` | **196/196 passed** |
| Flutter — `flutter build apk --release` | Succeeded (`app-release.apk`, 72.3MB) |
| Admin — `npx tsc --noEmit` | Clean |
| Admin — `npm run lint` | Clean |
| Admin — `npm run build` | Succeeded — all routes compiled, including the new `/association-admin/draws/[id]/reveal` route |

All seven checks above were re-run in full as part of the final closure pass (not just incrementally) and confirmed green together.

## 20. UI/UX changes

- New "Lucky Draw Management" screen (§12) replacing the old plain create form at the same route — no duplicate/dead route left behind.
- New "Draw reveal" screen and route (`/association-admin/draws/[id]/reveal`) — staged, ~2-minute presentational sequence with a skip-to-results affordance and refresh-safe recovery (localStorage-tracked, never re-triggers the draw).
- Prize cards (image, sponsor, value, quantity, status) replacing the old plain `<Select>` dropdown for prize allocation.
- Business picker (search, select-all/deselect-all, checkboxes) replacing the old plain merchant checklist.
- Live eligible-coupon-count summary, fetched from the backend on every selection change.
- Rich confirmation dialog before the irreversible action.
- Merchant prize-detail page gained a winner/claim-status section and a "Congratulations" banner (§11).
- Draw History detail gained "Created by" and "Businesses" (§12).
- Design language: white/neutral surfaces with restrained orange (a solid-orange CTA reserved for the one primary "Run Lucky Draw"/"Start Lucky Draw" action, matching the existing app-wide convention of reserving that treatment for genuinely primary actions), tinted section headers (amber/green) via new optional, backward-compatible `stepNumber`/`tone` props on the shared `FormSection` component — every other page using `FormSection` is visually unaffected.

Live-verified end-to-end in a real browser against the running dev backend: login → cadence/business/prize selection → live preview count → confirm → run → reveal animation → winner shown correctly with sponsor name → Draw History detail showing businesses/created-by/winners correctly → confirmed no duplicate draw is created by revisiting the reveal URL.

## 21. Removed feature flags

None removed *this* pass — the `lucky_draw` feature-flag gate was already fully removed from the codebase in the immediately preceding pass (all `featureFlags->enabled('lucky_draw')` checks deleted from every controller, the seed default flipped to `enabled: true`, and the legal-risk register entry marked as an accepted, owner-directed risk rather than a blocking one). Lucky Draw 2.0 was built and verified against that already-unblocked state; nothing in this pass reintroduced any gate, flag check, or "not yet enabled" condition anywhere in backend, admin, or Flutter code.

## 22. Final closure pass — email architecture, brand copy, and closing gaps

A separate, later pass closed out every item this report had previously listed as a genuine remaining gap, plus performed a full production-readiness sweep. Summary (full detail in [final-production-readiness-report.md](./final-production-readiness-report.md)):

- **Email architecture, built for real.** `accounts.email`/`accounts.email_verified_at` (nullable, unique) added — Account, not any role-profile table, per this codebase's own "Account is the one shared identity for every role" precedent (ADR-001), and per the same reasoning §9 already used to design the (until-now schema-less) email channel around. `merchants.contact_email` added as the secondary/fallback path for merchant-owner-targeted notifications (`PrizeWon`), mirroring the existing `contact_mobile_number` business-contact-field pattern. `EmailNotificationChannel::resolveRecipientEmail()` — previously reading a placeholder `$merchant->email` — now reads the real columns. `POST /auth/email` lets an authenticated account set/normalize its own email; `AccountResource`/`MerchantPrivateResource` expose the new fields where established view-scoping rules already allow it. No email-verification-send/confirm flow was built — deliberately out of scope (notifications don't require a verified address; see §23's Optional row).
- **Brand copy.** Repo-wide search for "Town Shopee" found and fixed the one live occurrence: `config/notifications.php`'s `DrawWon` email subject line. (Two other matches were already-correct historical citations in test/doc text, not live bugs.)
- **Merchant prize list value display.** `prizes-list-client.tsx` (the LOW item below) now shows a Value column, using the same shared `Money` component as every other prize interface — also applied to the merchant prize detail page and the association-admin prize approval queue, which had the identical gap, and replaced an ad hoc local `formatCurrency()` in `draw-management.tsx` with the same shared component for true consistency.
- **Obsolete-blocker sweep.** Found and fixed two stale doc comments (a migration docblock and a Flutter repository docblock) that still described Lucky Draw as "gated behind the `lucky_draw` feature flag, disabled pending legal review" — false since the flag was already removed and the risk was already accepted (see `docs/decisions/risk-register.md#r-2`, correctly left untouched as it documents a real, still-open *business/legal* question, not a code blocker). No actual blocking logic was found anywhere — the sweep only corrected documentation that no longer matched reality.
- **Full regression, re-run clean:** see the updated §19 table — 834 backend tests, 196 Flutter tests, `flutter analyze`/release build, and admin typecheck/lint/build all green together after every change above.
- **Live UI verification:** logged into the association-admin console against the running dev backend; Dashboard, Prizes (all filters), and Draws pages render cleanly with the corrected brand copy and the new Value column. Along the way, a real (pre-existing, unrelated to this pass's code changes) dev-environment bug was found and fixed: the current day's `auth-*.log` file had been created with `root` ownership by an earlier out-of-band `docker exec` command, which made every login throw a permission-denied exception and fail with a 500. This is an artifact of how commands were run against the dev container in this session, not a defect in the application code — flagged as awareness for anyone else running ad hoc root commands against the same container.

## 23. Remaining issues

| Item | Severity | Detail |
|---|---|---|
| No email-verification send/confirm flow | OPTIONAL | `email_verified_at` exists and resets correctly on change, but nothing sends a verification code. Deliberately out of scope — notifications are fire-and-forget, not an auth context, so a verified address isn't required for the feature to work. Build only if/when a product requirement needs a *confirmed* address (e.g. password-reset-via-email). |
| No customer/merchant-facing "add your email" UI screen | LOW | The backend (`POST /auth/email`) and API exposure are complete and tested; no Admin/Flutter settings screen was built to call it, since none was explicitly requested by name. Whoever owns email collection UX should scope a small settings-page addition when ready. |
| ~~No `email` column on any recipient-facing table~~ | RESOLVED | See §22 — `accounts.email` (+ `merchants.contact_email` fallback) now backs the email channel for real. |
| ~~Merchant prize list table doesn't show `value`~~ | RESOLVED | See §22 — fixed, and extended to every other prize interface with the same gap. |
| ~~Email/WhatsApp copy said "Town Shopee"~~ | RESOLVED | Was implemented literally per the exact subject-line copy originally given; corrected to "Town Shoppy" in the brand-copy closure pass, matching the rest of the product. |
| Local dev log-file permission issue | N/A — recurring dev-environment artifact, fixed again | See §14 and §22 — not a code defect. Recurs whenever a command is run against the dev container as `root` instead of `sail` on the day's first log write; worth a `chown` in the container's entrypoint or a documented convention if it keeps recurring across sessions. |
