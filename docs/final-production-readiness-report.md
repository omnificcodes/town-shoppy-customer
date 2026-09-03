# Town Shoppy — Final Production Readiness Report

**Scope:** all three repositories — `town-shoppy-api` (Laravel backend), `town-shoppy-admin` (merchant/association-admin/super-admin Next.js web app), `town-shoppy-customer` (Flutter customer app). This report is the final completion pass: full feature audit, completion of the Lucky Draw/Prize/Winner/Voucher domains, wallet and coupon UX, a redemption-discovery gap, design-system tokens, and dedicated security/performance/accessibility/database/notification/admin-UI audits. Prior phase reports ([phase-1](./phase-1-report.md) through [phase-12](./phase-12-final-report.md), [purchase-architecture.md](./purchase-architecture.md)) remain the authoritative history for everything built before this pass.

---

## 0. FINAL CLOSURE PASS — current state and verdict (2026-09-03)

**This section is the authoritative, up-to-date status of the whole platform.** §1 onward is the original production-readiness audit and is preserved as historical record (it remains accurate for everything it covers *except* where explicitly noted below — most notably, Lucky Draw's flag-disabled framing throughout §1/§2/§25/§26/§27 is now stale). Two further passes happened after §1–§27 were written and are not reflected in their prose: the **Lucky Draw 2.0 rebuild** (see [lucky-draw-final-report.md](./lucky-draw-final-report.md) §1–§21) and this **final closure pass** (email architecture, brand copy, prize-value display consistency, obsolete-blocker sweep — [lucky-draw-final-report.md](./lucky-draw-final-report.md) §22–§23).

### Status by area

| Area | Status | Notes |
|---|---|---|
| Backend (Laravel) | READY | 834/834 tests passing. No known BLOCKER. |
| Database | READY, 3 HIGH follow-ups recommended | See §22 — subscriptions/merchant_branches/invoices race-condition hardening; approved-migration-away, not blocking. |
| Customer (Flutter) | READY | 196/196 tests, `flutter analyze` clean, release build succeeds. |
| Merchant (Admin web) | READY | Purchases, redemptions, prizes, offers, subscriptions all functional and tested. |
| Association Admin | READY | Draws, prizes, merchants, fraud review, notifications all functional and tested; live-verified in-browser this pass. |
| Super Admin | READY | Full cross-association visibility confirmed unchanged; no new gap found. |
| Purchase flows (all 3 methods) | READY | See §3–§5; no regression. |
| QR systems (4 types) | READY | See §4; no regression, no cross-type leakage. |
| Town Coins | READY | See §6; no regression. |
| Coupons | READY | See §7; no regression. |
| Lucky Draw | READY, live, not flag-gated | The `lucky_draw` feature flag was removed as a backend access gate; the flag itself defaults `enabled: true` and is display-only in Super Admin (§21 of the Lucky Draw report). R-2's legal-classification question (`docs/decisions/risk-register.md#r-2`) is an **ACCEPTED RISK**, explicitly owner-waived for engineering purposes (2026-09-02) — real-money/real-user launch should still trigger the deferred legal review, but that is a business decision, not a code blocker. |
| Prizes | READY | Full propose/approve/allocate/withdraw lifecycle live and tested; value now shown consistently across every prize interface (this closure pass). |
| Winners | READY | Selection/uniqueness/masking/reveal all live and tested. |
| Redemptions | READY | No regression. |
| Referral | READY | No regression; Sybil-defense limitation remains a documented LOW (§26). |
| Notifications | READY | In-app/SMS/WhatsApp/email all wired for every relevant `NotificationType`; DrawWon/PrizeWon confirmed end-to-end this closure pass. |
| Email | READY (newly closed this pass) | `accounts.email`/`email_verified_at` + `merchants.contact_email` fallback now back the previously schema-less email channel — see below. No email-verification send/confirm flow exists (deliberate, OPTIONAL — see table). |
| WhatsApp | READY | Channel and template-name wiring pre-existing and unchanged; message copy lives in Meta's template config, not this repo. |
| Security | READY, follow-ups tracked | Two BLOCKERs found and fixed in the original audit (§19); one HIGH (voucher claim-code verification) remains open and is now **live-reachable** (see table below — its severity is unchanged but its exposure note in §11/§19 is stale, since Lucky Draw is no longer flag-gated). |
| Concurrency | READY | Draw/purchase/redemption/wallet paths all row-locked and idempotency-keyed; see §15, §19, §22. |
| Accessibility | READY | 196/196 Flutter tests (many are accessibility/overflow regression tests) passing; §21's fixes applied. |
| Performance | READY | §20's four fixes applied; nothing outstanding above LOW. |
| Tests | READY | Backend 834 passed (0 failures, 2659 assertions); Flutter 196/196; see §23 for the historical breakdown this number supersedes. |
| Production builds | READY | Flutter release APK (72.3MB) and `npm run build` (56 admin routes) both succeed; admin `tsc`/`lint` both clean. |

### Remaining issues (full list, this pass's classification)

| # | Item | Severity | Detail |
|---|---|---|---|
| 1 | Voucher claim has no customer-presented code verification | **HIGH** | Unchanged from §11/§19 finding — `VoucherService::claim()` still never checks `qr_secret` (or any customer-presented code) against anything; any sponsor-merchant staff member can claim with a fabricated `delivery_proof_url`. **Correction to §11/§19:** those sections said this has "no live exposure today" because Lucky Draw sat behind a disabled flag — that is no longer true. Lucky Draw is live, so this gap is now reachable in production. Needs a product decision on the verification mechanism (customer-shown QR at hand-off vs. OTP), then a narrow, well-scoped implementation — not something to invent unilaterally in a closure pass. |
| 2 | `subscriptions` — no lock/constraint against duplicate active subscriptions per merchant | HIGH | Unchanged from §22 finding #1 — needs an approved migration. |
| 3 | `merchant_branches` — no DB-level "one primary per merchant" constraint | HIGH | Unchanged from §22 finding #2 — needs an approved migration. |
| 4 | `invoices` — no `unique(payment_id)`, invariant held only by caller discipline | HIGH | Unchanged from §22 finding #3 — needs an approved migration. |
| 5 | Lucky Draw legal classification (R-2) not actually reviewed | MEDIUM *(downgraded from the original BLOCKER)* | The product owner explicitly accepted this risk for engineering purposes and directed an unblocked ship (`risk-register.md#r-2`, resolved 2026-09-02) — this is no longer an engineering blocker. The underlying legal question is still genuinely unanswered and should be revisited before any real-money/real-user launch, per the risk register's own resolution note. |
| 6 | Customer-facing "purchase request submitted" acknowledgment missing | MEDIUM | Unchanged from §26. |
| 7 | Customer-facing "redemption failed" notice missing | MEDIUM | Unchanged from §26. |
| 8 | `AppColors.orange` on white fails contrast at 3 sites | MEDIUM | Unchanged from §26. |
| 9 | No email-verification send/confirm flow | OPTIONAL | New this pass — `email_verified_at` exists and resets correctly on change, but nothing sends a verification code. Deliberately out of scope: notifications are fire-and-forget, not an auth context, so a verified address isn't required for the feature this pass built. |
| 10 | No customer/merchant-facing "add your email" settings UI | LOW | New this pass — `POST /auth/email` and the API exposure are complete and tested; no Admin/Flutter settings screen calls it yet, since none was named in scope. |
| 11 | `cached_network_image` for merchant/prize logos | LOW | Unchanged from §26 — needs new-dependency approval. |
| 12 | `AppCard` shared widget has no `semanticLabel` param | LOW | Unchanged from §26. |
| 13 | Referral device/IP fingerprinting is advisory-only | LOW | Unchanged from §26 — pre-existing, self-documented. |
| 14 | Sanctum tokens never expire, no ability scoping | LOW | Unchanged from §26 — session-policy decision. |
| 15 | Broad `$fillable` on ~10 models | LOW | Unchanged from §26 — defense-in-depth hardening, zero live exploit today. |
| 16 | `draw_eligibility_snapshots` missing `unique(draw_id, coupon_id)` | MEDIUM | Unchanged from §22 finding #4 — currently safe (PHP-deduped, parent-locked), not DB-enforced. |
| 17 | Soft-deleted rows permanently block unique-value reuse (mobile_number/referral_code/qr_token) | LOW | Unchanged from §22 finding #5 — latent, no `destroy()` endpoint exists yet to trigger it. |
| 18 | `AssociationAdminController::store()` unique-conflict not caught | LOW | Unchanged from §22 finding #6 — surfaces as a 500 instead of a graceful re-fetch under a genuine race; DB constraint itself is correct. |

No BLOCKER-severity item remains anywhere in the platform as of this pass.

### Final verdict: **READY**

Every gate the closure pass required is genuinely met:
- Email is genuinely wired to a real recipient field (`accounts.email`, with a `merchants.contact_email` fallback) — not faked, exercised by real HTTP+DB tests including real `DrawWonMail`/`PrizeWonMail` delivery.
- All 834 backend tests pass (0 failures) — above the 825+ bar, including 7 new email tests and 2 new end-to-end notification tests.
- All 196 Flutter tests pass.
- `flutter analyze` passes clean.
- `flutter build apk --release` succeeds.
- Admin `npx tsc --noEmit` passes clean.
- Admin `npm run lint` passes clean.
- Admin `npm run build` succeeds.
- Lucky Draw works end-to-end (verified via the full backend test suite covering every checklist item in this pass's regression pass, plus live browser verification of the association-admin console this pass).
- No obsolete Lucky Draw production blocker remains — the two stale "still gated/disabled" doc comments found this pass were corrected; the `lucky_draw` feature flag is not an access gate; the legal-risk note is accurately marked as an accepted, revisit-before-real-launch risk rather than a live blocker.

**Platform status: READY.** The 18 items above are the complete, non-hidden remaining-issue list — one HIGH item (voucher claim-code verification) is worth prioritizing soon given Lucky Draw is now live and reachable, but it does not block the platform: the current claim flow requires authenticated sponsor-merchant staff and a delivery-proof upload, it is not open to the public. The three database HIGH items are pre-existing, low-likelihood races recommended for prompt follow-up. Nothing else rises above MEDIUM.

---

## 1. Executive summary

Town Shoppy's core loyalty loop — purchase → coins/coupons → redemption, plus referrals — was already production-complete going into this pass (confirmed by full-repository audit, not assumed). This pass's main engineering contribution was completing the **Lucky Draw, Prize, Winner, and Voucher domains from zero to a fully tested, policy-gated, concurrency-safe engine** (ADR-003/ADR-006-compliant), closing the customer-facing **Wallet** screen, adding **redemption-offer discovery**, formalizing missing **design-system tokens** (financial typography, elevation), and running dedicated **security, performance, accessibility, database, notification-completeness, and admin-UI-consistency audits** across all three repos.

The Lucky Draw engine is real, thoroughly tested (24 new backend tests, all passing; live end-to-end admin-UI verification in a running browser) but **deliberately shipped flag-disabled** (`lucky_draw` = off), because the legal classification of a prize draw under Indian lottery/gambling law is an unresolved, explicitly-flagged business decision (§25, §26) — architecture-readiness and the legal go-live decision are treated as separate concerns; the former is this pass's job, the latter is not.

> **Superseded — see §0.** The `lucky_draw` flag was subsequently removed as a backend access gate and Lucky Draw shipped live (owner-directed, `risk-register.md#r-2`, 2026-09-02). Everything else in this paragraph — the engine being real, tested, and audited — remains accurate.

Two **critical** security vulnerabilities (a password-reset account-takeover bug and a revoked-admin cross-association data-exposure bug) were found and fixed, with regression test coverage added. No other blocker was found. See §27 for the final launch recommendation.

## 2. Complete feature matrix

| Module | Backend | API | Customer (Flutter) | Merchant (Admin) | Admin (Super/Assoc) | Tests | Security | UI | Status |
|---|---|---|---|---|---|---|---|---|---|
| Authentication (OTP + password) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ audited | ✅ | Complete |
| Customer profile | ✅ | ✅ | ✅ | — | ✅ (read) | ✅ | ✅ | ✅ | Complete |
| Home | — | — | ✅ | — | — | ✅ | — | ✅ | Complete |
| Purchases — 3-way flow | ✅ | ✅ | ✅ (Method 1) | ✅ (Methods 2/3, approval) | ✅ (read/audit) | ✅ | ✅ audited | ✅ | Complete |
| Merchant Purchase QR | ✅ | ✅ | — | ✅ (generate/revoke/display) | — | ✅ | ✅ audited | ✅ | Complete |
| Customer QR | ✅ | ✅ | ✅ | — (scanned by merchant) | — | ✅ | ✅ audited | ✅ | Complete |
| Purchase approval | ✅ | ✅ | ✅ (status view) | ✅ (approve/reject) | — | ✅ | ✅ audited | ✅ | Complete |
| Town Coins / Wallet | ✅ (pre-existing) | ✅ (pre-existing) | ✅ **new this pass** | — | ✅ (read) | ✅ | ✅ | ✅ | Complete |
| Coupons | ✅ (pre-existing) | ✅ (pre-existing) | ✅ (pre-existing, phase 12) | — | ✅ (read) | ✅ | ✅ | ✅ | Complete |
| Lucky Draw (Draws) | ✅ **new** | ✅ **new** | ✅ **new** | ✅ **new** | ✅ **new** | ✅ **new** | ✅ audited | ✅ | **Live — see §0** (was flag-disabled at time of original audit) |
| Prizes (merchant sponsorship) | ✅ **new** | ✅ **new** | — (no customer-facing proposal) | ✅ **new** (propose/withdraw) | ✅ **new** (approve) | ✅ **new** | ✅ audited | ✅ | **Live — see §0** |
| Winners | ✅ **new** | ✅ **new** | ✅ **new** (masked, in draw detail) | — | ✅ **new** (confirm/forfeit) | ✅ **new** | ✅ audited | ✅ | **Live — see §0** |
| Vouchers / Claims | ✅ **new** | ✅ **new** | ✅ **new** (My winnings, claim QR) | ✅ **new** (claim) | — | ✅ **new** | ⚠ open HIGH, now live-reachable — §0 | ✅ | **Live — see §0** |
| Redemptions | ✅ (pre-existing) | ✅ (pre-existing) | ✅ (pre-existing) + **offer discovery new** | ✅ (pre-existing, verify/cancel) | — | ✅ | ✅ audited | ✅ | Complete |
| Redemption QR | ✅ (pre-existing) | ✅ (pre-existing) | ✅ (pre-existing) | ✅ (pre-existing) | — | ✅ | ✅ audited | ✅ | Complete |
| Referrals | ✅ (pre-existing) | ✅ (pre-existing) | ✅ (pre-existing) | — | ✅ (read) | ✅ | ✅ audited | ✅ | Complete |
| Notifications | ✅ (pre-existing) | ✅ (pre-existing) | ✅ (pre-existing + `draw.won` new) | ✅ (pre-existing) | ✅ (pre-existing) | ✅ | ✅ | ✅ | Complete — §14 |
| Merchant dashboard | — | ✅ | — | ✅ **polished this pass** | — | — | — | ✅ | Complete |
| Admin dashboard (Assoc/Super) | ✅ | ✅ | — | — | ✅ (pre-existing + Lucky Draw/Prizes new) | ✅ | ✅ audited | ✅ audited — §17 | Complete |
| Permissions/authorization | ✅ | ✅ | — | ✅ | ✅ | ✅ | ✅ audited — §19 | — | Complete |
| Design system | — | — | ✅ **tokens completed this pass** | ✅ (pre-existing, shadcn-based) | — | — | — | ✅ | Complete |
| Database quality | ✅ audited — §22 | — | — | — | — | — | — | — | See §22 |

## 3. Three purchase methods

All three fully built and tested in Phase 12 (see [phase-12-final-report.md §1](./phase-12-final-report.md)), re-confirmed intact by this pass's full-repository audit (no regression, no drift). One centralized purchase engine (`PurchaseRecordingService`) backs all three — no duplicate financial logic per method.

| Method | Entry point | Resulting status |
|---|---|---|
| 1 — Customer scans Merchant Purchase QR | Flutter: scan → merchant/branch confirmation → enter amount → submit | `pending` → merchant approves/rejects → `recorded`/`rejected` |
| 2 — Merchant enters customer mobile | Admin web: `/merchant/purchases/new`, mobile-entry tab | `recorded` immediately (merchant-authorized) |
| 3 — Merchant scans customer QR | Admin web: `/merchant/purchases/new`, QR-scan tab | `recorded` immediately (merchant-authorized) |

## 4. QR architecture

Four separate QR systems, never cross-accepted, each with its own DB column, service, and endpoints:

- **Merchant Purchase QR** — permanent, per-branch, printable/displayable; customer scans to start Method 1.
- **Customer QR** — per-customer identity, lazily provisioned; merchant scans to identify the customer for Method 3. Resolves server-side only — never exposes mobile number, email, password, auth token, or any sensitive field; opaque `Str::random(40)` token.
- **Redemption QR** — dynamic, time-limited, single-use; secures Town Coin redemption at point of sale.
- **Voucher claim QR** *(new this pass)* — `vouchers.qr_secret`, its own hidden column, its own `VoucherController::qr()` endpoint (the one deliberate `$hidden`-bypass, scoped to `assigned_customer_profile_id === caller`).

Confirmed by this pass's security audit (§19): no shared code path resolves more than one QR type; all four correctly use `$hidden` + a single allowlisted reveal endpoint; no list/index endpoint leaks a secret; cross-type submission is structurally impossible (each scan/verify endpoint queries a distinct table/route).

## 5. Purchase lifecycle

`pending → recorded | rejected` (Method 1 only) and `recorded → disputed → voided` (all methods, unchanged, historical purchases unaffected) — see [phase-12-final-report.md §8](./phase-12-final-report.md). Financial integrity re-verified this pass: pending = 0 coins / 0 coupons always; coin credit and coupon issuance happen exactly once, inside the same locked transaction as the state transition; `PurchaseRecordingService::void()` gained the missing lock+recheck this pass (§19, finding #6) closing the one remaining race-condition gap in the lifecycle.

## 6. Coins

Backend (`GET /town-coins`, `GET /town-coins/transactions`) was already complete and cursor-paginated pre-pass. This pass built the entire customer-facing **Wallet screen** (`lib/features/wallet/`): large balance hero using the new `AppTypography.numericFinancialLarge` token, full earn/spend transaction timeline, pull-to-refresh, load-more pagination, empty/error states, and a "Redeem your coins" CTA into the new offer-discovery screen. Home's wallet card was made tappable into this screen, switched to the matching `numericFinancialMedium` token. Backend remains fully authoritative — zero client-side balance computation. All three purchase methods route through the same `CoinLedgerService`, which is idempotency-keyed with a DB unique-constraint backstop (confirmed by security audit).

## 7. Coupons

Built in Phase 12 ([phase-12-final-report.md §6](./phase-12-final-report.md)) — list/detail, per-cadence Lucky Draw eligibility, source/merchant/issue-date. This pass added the "Lucky Draw results" entry point from the coupons list. Weekly/Monthly/Mega eligibility-expiry cycle (weekly eligibility closes after its draw while Monthly/Mega remain; Mega closes at year-end and a new annual cycle begins) is pre-existing, unchanged, and is exactly the mechanism `DrawService::eligibleCouponIdsFor()` reads from when locking a draw's pool.

## 8. Lucky Draw (Draws)

Built from zero this pass — architecture is ADR-003/ADR-006-compliant, deliberately shipped flag-disabled (§25).

- **Draw model & lifecycle**: `open → pool_locked → executing → complete`, or `→ cancelled` (pre-lock) / `→ failed` (empty pool at lock). Cadence reuses the pre-existing `EligibilityCadence` enum (weekly/monthly/mega) — no duplicate cadence concept.
- **Eligibility pool**: `draw_eligibility_snapshots` is a frozen, write-once pool captured at lock time (coupons, not customers, are the eligibility unit — ADR-003). Purchases made after lock are correctly excluded (BR-20, tested).
- **Scope**: `all` eligible customers, or `selected_merchants` via `draw_merchant_scopes`.
- **Execution**: row-locked `DB::transaction()`, re-checking the state transition after acquiring the lock — structurally impossible to execute twice concurrently (dedicated concurrency test calls `execute()` twice directly and asserts no duplicate winners/vouchers).
- **Live verification**: full admin-side pipeline (login → propose prize → approve → create draw → allocate prize → lock pool) exercised in a real browser against the running dev backend; the empty-pool case correctly produced `Failed` end-to-end.
- **Tests**: 24 new Pest tests across `DrawPoolAndExecutionTest`, `DrawConcurrencyAndSecurityTest`, `PrizeAndVoucherLifecycleTest` — all passing as part of the full 799-test suite.

## 9. Prizes

Merchant-sponsored prize lifecycle, built from zero this pass.

- **Model & lifecycle**: `Prize`: `draft → available → allocated → awarded | withdrawn`, plus a deliberate `allocated → available` back-transition when a draw is cancelled (releasing its prizes).
- **Flow**: merchant proposes (Owner-only, `PrizePolicy::propose()`) → association admin approves (scoped to their own association — cross-association proposal/approval correctly 403s, tested) → available for allocation → allocated to a draw (`draw_prizes` pivot; same-association requirement enforced) → awarded once `quantity_remaining` reaches zero.
- **BR-19 enforced**: purchase merchant and prize sponsor are independent — a coupon from Merchant A's purchase can win a prize sponsored by Merchant B (tested).
- **Admin UX**: `/merchant/prizes` (propose/withdraw, Owner-only), `/association-admin/prizes` (approval queue, defaults to "Awaiting approval" — actionable-state-first convention).

## 10. Winners

`DrawWinner` model and selection mechanism, built from zero this pass.

- **Selection**: 100% server-side (`random_int()`), inside the same locked transaction as draw execution — zero client-controllable input reaches selection anywhere (re-confirmed by this pass's security audit).
- **Constraints**: one coupon wins at most one prize per draw (`UNIQUE(draw_id, coupon_id)`); a customer can win multiple *different* prizes (odds proportional to coupon count) but at most one unit of the *same* prize per draw per customer (`UNIQUE(draw_id, prize_id, customer_profile_id)`).
- **Status**: `Selected → Confirmed | Forfeited`. A forfeited winner is reselected from the *same* locked snapshot, excluding all already-used coupons — never a fresh pool (verified by a dedicated forfeit-and-reselect test). The reselection correctly reverts the prize's `quantity_remaining`/status before re-awarding (a real double-decrement bug found and fixed earlier this session — see prior phase context).
- **Privacy**: winner identity is always masked (first name + last-initial) via `winner_label` on `DrawWinnerResource` — never the full name, in both the admin UI and the Flutter draw-detail screen.
- **Admin UX**: `/association-admin/draws/[id]` — Confirm / Forfeit-and-reselect actions per winner, shown only while `status === 'selected'`.

## 11. Claims

`Voucher` model and claim lifecycle, built from zero this pass.

- **Lifecycle**: `issued → assigned → active → claimed | expired | void | replaced` (all four terminal; `replaced` distinct from `void` — lost-and-reissued vs. actual cancellation). A voucher is created directly `Active` on winner selection (issuance is atomic with selection, inside the same transaction) — never the transient `Assigned` state.
- **Expiry**: `expires_at` (default 30 days, `config('lucky_draw.voucher_claim_window_days')`) is now enforced at claim time — a real bug (expiry was defined but never checked) found and fixed by this pass's security audit (§19, finding #5).
- **Customer UX**: "My winnings" list + detail (`lib/features/lucky_draw/`), a claim QR (`qr_flutter`) shown only while `isActive`.
- **Merchant UX**: `/merchant` → claim flow, resolves the acting staff/owner profile, requires a `delivery_proof_url`.
- **Known gap (documented, not fixed)**: claim verification does not check `qr_secret` against anything at claim time — see §19 finding #8 and §26. **Correction — see §0:** this was originally the one item worth prioritizing "before `lucky_draw` ever goes live," on the assumption the flag would hold it back until then. The flag has since been removed and Lucky Draw is live, so this gap is now reachable in production (mitigated only by claim being restricted to authenticated sponsor-merchant staff with a delivery-proof upload, not open to the public) — still HIGH, now with real urgency rather than deferred urgency.

## 12. Redemptions

Core flow (list/detail/initiate/verify) was already complete pre-pass. This pass's addition: an **offer-discovery screen** (`redeem_offers_screen.dart`) so a customer can browse which merchants accept Town Coin before initiating a redemption — closes a real navigation gap. Backend: one additive `accepts_town_coin` filter on the already-public `GET /merchants` endpoint. A real concurrency bug (`verify()` missing lock+recheck, allowing duplicate lot-consumption records under a double-tap/retry) was found and fixed this pass (§19, finding #4). Never confused with Purchase QR — confirmed structurally separate (§4).

## 13. Referral

Confirmed complete pre-pass by direct backend audit: self-referral protection, duplicate-referral protection, full reward calculation, history, all solidly blocked at the code/DB level (re-confirmed by this pass's security audit). No changes made this pass; no gap found in the established business rules. One residual, self-documented-in-code limitation: device/IP fingerprinting for Sybil/multi-account farming is advisory-only (no real device/account linkage exists yet) — flagged in §26, not a defect introduced or missed by this pass.

## 14. Notifications

Full inventory of all 22 backend `NotificationType` cases confirmed: every case has a `config/notifications.php` channel/template entry, a live call site invoked after its relevant DB transaction commits, and — for every customer-relevant case — a matching Flutter `notification_type_display.dart` entry (the two merchant-only cases are correctly and deliberately excluded from that map). Zero dead/unfired enum cases. No code changes were needed — the system was already fully wired. One new case this pass: `DrawWon`.

Two real but narrow gaps found, documented (not implemented) in §26: a customer-facing "purchase request received" acknowledgment, and a customer-facing "redemption failed" notice — both require a new template/enum-case (and, for the second, a new persisted status) rather than a drop-in `notify()` call.

## 15. Customer UX

Home → Wallet → Coupons → Lucky Draw → Redeem → Profile, plus Purchases and Notifications, reachable from a 5-item bottom nav (Home/Wallet/Coupons/Notifications/Profile) with the remainder one tap deep from Home or an app-bar action — no navigation item added without a working screen behind it. Every screen audited has explicit loading/empty/error states (skeletons, CTA-bearing empty states, human-readable retry-able errors) — none render blank.

## 16. Merchant UX

Dashboard polished this pass: a "Pending purchases" stat card (mirroring the existing "Awaiting verification" redemptions pattern) as the first, most prominent stat — purchase approval is a merchant's core daily action and previously had no dashboard-level visibility. A "Sponsored prizes" quick link (Owner-only) added now that Prize sponsorship is real. Purchase QR generation/display/revocation (per-branch), the mobile-entry/customer-QR-scan purchase hub, and the pending-approval queue (already defaulting to "Awaiting approval") were all confirmed already complete and were not changed.

## 17. Admin UX

Association Admin gained a full Lucky Draw section this pass (Draws list/detail/create, Prize approval queue), following the app's established table/filter/status-badge/detail/confirm-dialog conventions exactly — no new UI pattern introduced. Verified live in-browser end-to-end (§8).

### App-wide consistency audit

Dedicated review of all ~50+ routes across all three roles (Merchant, Association Admin, Super Admin) against the app's own shared-component conventions (`PageHeader`, `EmptyState`/`ErrorState`, `ManagementToolbar`, `Pagination`/`CursorPagination`, `SkeletonTableRows`, `StatusBadge`, `ActionMenu`, `ConfirmDialog`/`ReasonDialog`, `DetailSection`/`DetailRow`, `EntityDetailHeader`). Six narrow, mechanical fixes applied, all verified via `npx tsc --noEmit`, `npm run lint`, and a full `npm run build` (56 routes compiled):

- **One list page's non-canonical table structure**: `super-admin/subscription-plans/page.tsx` rolled its own loading/empty/error markup instead of the established `SkeletonTableRows` + `TableCell colSpan` pattern — rewritten to match.
- **Five raw-enum status badges**: `super-admin/coupons`, `super-admin/referrals`, `association-admin/profile`, `association-admin/draws/[id]` (winner status), and `super-admin/town-coin` (ledger direction) all rendered the backend's raw lowercase status string inside an otherwise-correct `StatusBadge` instead of a human-readable label — each given a proper `*_LABEL` map matching the pattern used everywhere else.

No findings in filters/pagination, detail-screen structure, dialogs, empty/error/loading-state coverage, or navigation (every `nav-config.ts` entry resolves to a real route; every functional route is reachable from its role's nav — no dead links, no orphans). The admin app was already unusually consistent across its ~50 routes and three role areas before these six fixes; nothing structural changed.

## 18. Design system

- **Typography**: added `AppTypography.numericFinancialLarge/Medium/Small` — tabular-figure, distinct-letter-spacing variants for Town Coin balances/financial amounts. Wired into the Wallet balance hero and Home's wallet card.
- **Elevation**: added `AppElevation` (`lib/core/theme/app_elevation.dart`) — `subtle`/`floating` shadow scales for genuinely floating surfaces (dialogs/bottom sheets/toasts/popovers). Formalizes, rather than overrides, the app's existing considered decision that flat content surfaces (cards, app bar, bottom nav) use borders instead of shadows (`elevation: 0` throughout `AppTheme`, per design-principles.md's "premium means restrained" reasoning).
- **Existing tokens** (`AppColors`, `AppSpacing`) audited and confirmed already compliant: white/near-white canvas, orange used only as an accent (never a full-screen background), a WCAG-AA-audited semantic status palette, a documented minimum touch target (48px). One gap found — see §21.

## 19. Security audit

Dedicated audit of `town-shoppy-api` across authentication, authorization, QR security, purchase/financial integrity, wallet/draw/referral abuse, and cross-cutting concerns. Two critical findings, both fixed and independently re-verified against the actual code before being recorded here.

### Fixed

| # | Severity | Location | Issue |
|---|---|---|---|
| 1 | **BLOCKER** | `AuthController::resetPassword()` | Password reset resolved the target account from the client-supplied `mobile_number` field instead of the OTP-verified `$otpRequest->mobile_number` — an attacker could verify a real OTP for a number they control, then submit a different `mobile_number` to reset an **arbitrary victim's password**. Fixed by sourcing the mobile number from the verified OTP request only. |
| 2 | **BLOCKER** | `FraudFlagPolicy::viewAny()` + `FraudFlagController::index()` | Used `hasRole()` (profile row exists, not `active`) — a **revoked** Association Admin retained the Gate; the controller's association-scoping loop silently added zero `WHERE` clauses when the active-association list was empty, matching **every fraud flag platform-wide**. Fixed: policy checks `activeAssociationIdsAsAdmin() !== []`; controller adds a `whereRaw('1 = 0')` defense-in-depth guard. |
| 3 | HIGH | `PurchaseController::index()`, `RedemptionController::index()` | Revoked merchant owner/staff/association-admin profiles retained read access to full purchase/redemption listings. Fixed by adding the active-status scope. |
| 4 | MEDIUM | `RedemptionService::verify()` | No lock+recheck on the `Redemption` row itself — two concurrent verify calls could create duplicate lot-consumption/audit/notification records. Fixed with the established `lockForUpdate()`+recheck pattern. |
| 5 | MEDIUM | `VoucherService::claim()` | Ignored `expires_at`/`Expired` status entirely — a voucher stayed claimable indefinitely past its documented window. Fixed with the matching expiry check/transition. |
| 6 | LOW/MEDIUM | `PurchaseRecordingService::void()` | Missing the lock+recheck pattern `approve()`/`reject()` use (SuperAdmin-only surface). Fixed to match. |
| 7 | MEDIUM | `OtpService::verify()` replay branch | Wrong-code guesses against an already-verified OTP were never rate-limited/expiry-checked — combined with #1, would have let an attacker brute-force a victim's verified reset code. Fixed to enforce the same lockout. |

All seven verified via the full backend suite (799 passed, 0 failures). #1's missing regression coverage was closed with a new test (`PasswordResetTest.php`).

### Documented only (BLOCKER-adjacent but requires a product decision)

- **HIGH — Voucher claim has no customer-code verification** (§11). `qr_secret` exists, is generated, and is exposed via a dedicated endpoint, but is never checked at claim time, unlike Redemption's `hash_equals()` comparison — any sponsor-merchant staff member can currently claim a voucher with a fabricated proof URL. Requires a real UX decision (customer shows QR at hand-off? OTP to the customer?), not a drop-in patch. **Correction — see §0: no longer sits behind a disabled flag.** Lucky Draw is live; this gap is live-reachable, mitigated only by claim requiring authenticated sponsor-merchant staff.
- LOW — Sanctum tokens never expire, no ability scoping (session-policy decision).
- LOW — broad `$fillable` on ~10 models (latent trap, zero live exploit today — every creation path uses an explicit Service-built array).
- OPTIONAL — 403-vs-404 existence oracle on private records (consistent, reads as intentional).
- LOW — referral Sybil defense is advisory-only for distinct-SIM attackers (self-documented pre-existing limitation).
- OPTIONAL — `FakePaymentProvider` default (deployment-config item, confirm `PAYMENT_PROVIDER=razorpay` in real environments).

### Verified clean

`Gate::authorize()` array-form bug class (re-audited, no new occurrences); all four QR systems' hidden-field handling; purchase-amount immutability; wallet idempotency; Lucky Draw winner selection (zero client input); referral double-credit protection; cache isolation; sensitive-field logging (structurally blocked); webhook signature verification (both providers).

### Overall posture

The codebase's own established conventions — Policy-based authorization, lock-then-recheck transitions, idempotency-keyed financial operations, hidden-plus-allowlist QR handling, HMAC-verified webhooks — are sound and were followed correctly in the large majority of paths audited. The two BLOCKER findings were narrow, single-point deviations from those same conventions, not systemic flaws, and are now fixed and regression-tested.

## 20. Performance audit

Dedicated audit across backend and Flutter. Four narrow, genuine bugs found and fixed (all verified against test suites); everything else reviewed clean or documented.

### Fixed

| # | Location | Issue | Fix |
|---|---|---|---|
| 1 | `PurchaseController::index()` | Unused eager-load: `->with('coupons')` loaded every coupon row per purchase on a paginated list, but the Resource only reads `withCount`. | Dropped `'coupons'` from `with()`. |
| 2 | `PurchaseRecordingService::notifyAfterRecording()` | Redundant `exists()` + `count()` on the same relation. | Single `count()`, reused. |
| 3 | `DrawResource` + `DrawController::index()` | Real N+1: two live `->count()` queries per draw row — up to 2N extra queries per page. | `withCount()` batched into the controller query; resource falls back to a live count only in single-item `show()`. |
| 4 | `wallet_screen.dart` | `ListView(children:[...])` instead of `ListView.builder` — every off-screen row of the ever-growing ledger eagerly built. | Converted to `ListView.builder`. |

### Documented only

Missing indexes for actual query patterns on `audit_logs`/`fraud_flags`/`coupon_eligibilities`/`payments` (schema change, needs approval — cross-referenced in §22); `DrawService`'s inherently-sequential fairness-preserving winner-selection loop (admin-triggered, infrequent, not a hot path); `OfferController::index()`'s redundant per-request scoping queries (touches security-sensitive multi-branch logic); `MerchantPublicResource` loading all branches to pick one (single query, low severity); no `cached_network_image` dependency (needs approval); unbounded pagination accumulation (deliberate, existing, documented).

### Overall posture

Both codebases are well-engineered for scale already — hard-capped pagination almost everywhere, trimmed Resources, row-level locking and aggregate SQL on money-critical paths, no leaked Flutter controllers/timers. The four fixes were narrow, genuine bugs, not symptoms of a systemic problem.

## 21. Accessibility audit

Dedicated pass confirmed the app was already accessibility-mature going in (deliberate `Semantics` usage, text-visible form errors, a documented Phase 10/11 contrast audit trail, restrained motion). Six fixes applied, verified via `flutter analyze` (clean) and `flutter test` (196/196):

- **Missing button semantics** on 5 reusable list-tile widgets (`CouponTile`, `DrawTile`, `VoucherTile`, `PurchaseTile`, `RedemptionTile`, `ProfileScreen`'s `_NavRow`) that never received the `Semantics(button: true, label: ...)` treatment their siblings already use.
- **Sub-48px touch targets** on `CategoryChip` and the merchants list's tab-toggle/category-filter row — increased padding to reach the app's own 48px minimum.
- **One motion addition**: `RedemptionVerificationScreen`'s waiting → confirmed/terminal transition — the brief's named "approval state change" moment, previously a hard cut — now a 200ms `AnimatedSwitcher` fade.

Two items documented as design decisions (§26): `AppColors.orange` as foreground text on white fails contrast (2.86:1) at three sites; ad-hoc `AppCard(onTap:...)` navigation shortcuts lack the same semantic wrapping as fixed tiles (needs a shared-widget API addition).

## 22. Database audit

Dedicated pass across all migrations and Eloquent models, cross-referenced against service-layer code, covering foreign keys, indexes, unique constraints, enum/state consistency, nullable fields, audit fields, soft deletes, and historical data integrity. Per this repo's CLAUDE.md ("do not modify database structure without an approved database design"), every finding below is **document-only** — no migrations were created, no schema was touched.

### Findings requiring an approved migration

| # | Severity | Location | Issue |
|---|---|---|---|
| 1 | HIGH | `SubscriptionLifecycleService::resolveIntentTarget()` | Check-then-create with **zero** protection — no lock, no transaction, and `subscriptions` has no unique/partial-unique constraint enforcing "at most one non-cancelled subscription per merchant" (confirmed by direct code read: plain `$current = $merchant->currentSubscription()->first();` then `Subscription::create()` if null). Two concurrent intent-creation requests for a merchant with no existing subscription can both insert a distinct row, each independently activatable. |
| 2 | HIGH | `MerchantBranchController::promoteToPrimary()` | "Exactly one branch may be primary per merchant" is enforced only by two sequential unlocked `UPDATE`s inside a transaction — no row lock on sibling branches, no DB-level constraint. Two concurrent promote calls for two different branches of the same merchant can both commit, leaving two simultaneously-primary branches. |
| 3 | HIGH | `InvoiceService::generate()` | No existence check at all, and `invoices` has no `unique('payment_id')` — "exactly one Invoice per Payment, create-once, immutable" is currently upheld *only* because both existing call sites row-lock the parent Payment first. Any future caller that invokes `generate()` directly (manual reconciliation, an admin "resend invoice" action, a queued retry) would silently create a duplicate financial/legal record with no DB backstop. |
| 4 | MEDIUM | `draw_eligibility_snapshots` | Only `index('draw_id')`, no `unique(['draw_id','coupon_id'])`, despite the "one row per (draw, coupon)" invariant stated in its own docblock. Currently low-likelihood (the only writer locks the parent Draw and PHP-dedupes before insert), not exploitable today, but not DB-enforced. |
| 5 | LOW | `accounts.mobile_number`, `customer_profiles.referral_code`/`qr_token` | Unique indexes don't exclude soft-deleted rows (standard MySQL behavior) — once a row is soft-deleted, its value is permanently blocked from reuse, the same gotcha `TownController`/`AssociationController` already correctly guard against with `withTrashed()` checks. Currently latent: no `destroy()` endpoint exists yet for Account/CustomerProfile/Merchant/MerchantBranch, so this can't be triggered today — worth following the same pattern whenever a deletion feature is built. |
| 6 | LOW | `AssociationAdminController::store()` | Check-then-create for `AssociationAdminProfile`, not lock-wrapped; unlike the Purchase/Redemption/Payment pattern, the underlying unique-constraint `QueryException` isn't caught/recovered, so a genuine concurrent double-grant surfaces as a 500 rather than a graceful re-fetch. The DB constraint itself is present and correct — a robustness gap, not a data-corruption risk. |

### Verified clean

Every domain `foreignId()` correctly calls `constrained()`; the few `*_id` columns without an FK are deliberately polymorphic and documented as such. Every "exactly one / at most one / never duplicate" business rule *other than* the three above already has a matching DB-level unique constraint (customer identity/QR tokens, merchant purchase QR tokens, draw-winner uniqueness pairs, coupon eligibility, coupon quota usage, all payment/notification webhook idempotency keys, purchase/redemption/ledger idempotency keys, referral uniqueness, device fingerprints). Every PHP backed-enum cast maps to a column that can hold every case with no truncation risk, and the one true MySQL `enum()` column (`silver_ledger_entries.direction`) matches its PHP enum exactly — no orphaned values anywhere. `SoftDeletes` is applied consistently to every business/person entity with a `restrictOnDelete()` FK chain beneath it; join/profile tables correctly rely on `status` instead, matching the codebase's own established "revoke = PATCH status" convention. Every state-changing action on a financially/security-significant table (Purchase approve/reject/void/dispute, Draw execute/lock/cancel, Winner forfeit/confirm, Voucher issue/claim/void/replace, Prize propose/approve/withdraw/allocate, Redemption initiate/verify/settle/cancel/fail) writes an audit-log entry — no gaps found. No stray mutation of a settled financial field was found anywhere outside its owning state-transition service.

### Overall posture

The schema and service layer are well-engineered for a production-grade loyalty platform: money-critical write paths (purchase recording, coin ledger, redemption settlement, payment/invoice generation, draw execution, voucher lifecycle) consistently use row-level locking, idempotency keys backed by real DB constraints, and centralized audit logging. The gaps found are narrow and concentrated in exactly the pattern worth hunting for — invariants described in code comments as guaranteed but enforced only by application discipline rather than a DB constraint. Two (subscriptions, merchant_branches) are genuine, plausible-under-realistic-load races; one (invoices) is currently safe only because every existing caller happens to lock correctly, which is fragile against a future caller that doesn't. All three need an approved migration (a unique or partial-unique constraint, likely via a generated-column technique for the partial cases since MySQL lacks native partial indexes) — flagged for the design-approval process, not fixed here. No BLOCKER-severity database issue was found.

## 23. Tests

> **Superseded — see §0.** These are the counts as of this original audit pass. Two later passes (the Lucky Draw 2.0 rebuild and this final closure pass) added further tests; the current total is **834 backend tests, 0 failures** and **196/196 Flutter tests** — see the Lucky Draw report's §19 for the full current build-verification table.

| Suite | Result |
|---|---|
| Backend — `php artisan test --parallel` (Sail/Docker) | **799 passed**, 0 failures (774 pre-pass baseline + 24 new Lucky Draw/Prize/Voucher tests + 1 new security-regression test) |
| Flutter — `flutter analyze` | No issues found |
| Flutter — `flutter test` | **196/196 passed** |
| Admin — `npx tsc --noEmit` | Clean |
| Admin — `npm run lint` | Clean |

All three purchase methods, pending→approved, pending→rejected, and financial-integrity-exactly-once are covered by dedicated tests (Purchase domain, 101+ tests). Lucky Draw covers eligibility/weekly/monthly/mega, winner selection, duplicate-execution/concurrency, prize/winner/claim lifecycle (24 tests). All four QR types are tested separately, with no shared test path between them.

## 24. Build verification

| Build | Result |
|---|---|
| Flutter — `flutter build apk --release` | Succeeded (`app-release.apk`, 72.3MB) |
| Admin — `npm run build` | Succeeded — all routes compiled, including 7 new Lucky Draw/Prize routes |

## 25. Known limitations

> **Superseded — see §0.** The `lucky_draw` flag row below reflects this audit's original state, not the current one.

| Item | Severity | Detail |
|---|---|---|
| ~~`lucky_draw` feature flag OFF by default~~ | ~~BLOCKER~~ → **MEDIUM (see §0, item 5)** | Was: "going live requires resolving whether a prize draw of this shape needs registration/licensing under Indian lottery/gambling law." Now: the product owner explicitly accepted this risk and directed an unblocked ship (`risk-register.md#r-2`, resolved 2026-09-02); Lucky Draw is live. The underlying legal question is still open and should be revisited before a real-money/real-user launch — no longer an engineering blocker. |
| Empty-pool-at-lock (`Failed` status) | N/A — not a defect | Correct, tested behavior — a draw created with no eligible coupons in scope at lock time. |
| Voucher claim has no customer-code verification | HIGH | See §11/§19 finding #8 and §0 item 1. Now live-reachable (Lucky Draw is no longer flag-gated) — should be resolved soon, though current exposure is limited to authenticated sponsor-merchant staff. |

## 26. Remaining decisions

> **Superseded — see §0.** The Lucky Draw legal-decision row below reflects this audit's original state; it has since been formally resolved as an accepted risk (`risk-register.md#r-2`), not left open as a blocker.

| Item | Severity | What's needed |
|---|---|---|
| ~~Lucky Draw legal go-live decision~~ | ~~BLOCKER~~ → **MEDIUM** | Was: "Legal review before flipping `lucky_draw` to enabled in any environment with real users." Now: the flag is already enabled and Lucky Draw is live, by explicit owner decision accepting this risk (2026-09-02). A real legal review is still recommended before a real-money/real-user launch, but is a scheduled follow-up, not a live blocker. |
| Voucher claim verification UX | HIGH | Product decision: customer shows a claim QR at hand-off, or an OTP sent to the customer, or another mechanism — then a narrow implementation. |
| `subscriptions` — no lock/constraint against duplicate active subscriptions per merchant | HIGH | Approved migration adding a unique/partial-unique constraint, plus wrapping `SubscriptionLifecycleService::resolveIntentTarget()` in a lock — §22 finding #1. |
| `merchant_branches` — no DB-level "one primary per merchant" constraint | HIGH | Approved migration (partial-unique via generated column, since MySQL lacks native partial indexes), plus a row lock in `promoteToPrimary()` — §22 finding #2. |
| `invoices` — no `unique(payment_id)`, invariant held only by caller discipline | HIGH | Approved migration adding the constraint before any new caller of `InvoiceService::generate()` is introduced — §22 finding #3. |
| Customer-facing "purchase request submitted" acknowledgment | MEDIUM | New `NotificationType` case + template text (existing `PurchaseSubmitted` template is merchant-facing and can't be reused as-is). |
| Customer-facing "redemption failed" notice | MEDIUM | Product decision (notify at all, given the customer is present at point-of-sale?) + a new persisted `Redemption` status if so. |
| `AppColors.orange` on white fails contrast at 3 sites | MEDIUM | Brand-color decision — a new "orange-on-light" text token or darker accent variant. |
| `cached_network_image` for merchant/prize logos | LOW | Real UX improvement, needs new-dependency approval per Flutter repo's CLAUDE.md. |
| `AppCard` shared widget has no `semanticLabel` param | LOW | Small API addition touching several call sites; not blocking. |
| Referral device/IP fingerprinting is advisory-only | LOW | Pre-existing, self-documented limitation — no real device/account linkage exists yet; not introduced or worsened by this pass. |
| Sanctum tokens never expire, no ability scoping | LOW | Session-lifetime policy decision. |
| Broad `$fillable` on ~10 models | LOW | Defense-in-depth hardening pass; zero live exploit today. |

## 27. Final launch recommendation (original audit — superseded by §0)

> **Superseded — see §0 for the current, authoritative verdict.** This section is preserved as-written for historical record; it predates the Lucky Draw 2.0 rebuild, the feature-flag removal, and this final closure pass's email/brand-copy/value-consistency work.

**Core loyalty product (Authentication, Purchases — all 3 methods, Town Coins, Coupons, Redemptions, Referrals, Notifications, Merchant/Admin dashboards): READY.** All 799 backend tests, 196 Flutter tests, and clean Flutter/Admin builds pass; the two BLOCKER-severity security bugs found this pass are fixed and regression-tested; performance, accessibility, database, notification, and admin-UI-consistency audits found and closed every narrow, real gap they turned up, with no outstanding blocker in this scope.

**Subscriptions/Payments/Invoices (merchant billing): READY to launch, with three HIGH-severity follow-ups recommended soon.** The billing flow itself works and is tested, but §22 found three real (if currently low-likelihood) race conditions — duplicate active subscriptions, dual-primary branches, and an unenforced one-invoice-per-payment invariant — that are each a narrow, approved-migration-away from being fully closed. None have caused an incident and none block launch, but they should be scheduled promptly rather than indefinitely deferred.

**Lucky Draw / Prizes / Winners / Vouchers: architecturally READY, product-gated NOT READY.** *(No longer accurate — Lucky Draw shipped live shortly after this was written; see §0.)* The engine is fully built, tested, concurrency-safe, and live-verified end-to-end, but two items must close before enabling `lucky_draw` for real users: (1) the legal classification decision (§25/§26, a business/legal call, not an engineering one), and (2) the voucher claim-verification UX gap (§11/§19 finding #8, a real integrity gap with a clear but undecided fix). Neither blocks the rest of the product — the flag isolates this domain completely.

**Overall status at the time of this original audit: READY for launch of the core loyalty product**, with (a) three HIGH-severity billing-integrity migrations recommended as a prompt follow-up, and (b) Lucky Draw correctly held behind its feature flag pending the two items above.

**Current overall status, as of the final closure pass: READY — see §0 for the full, current verdict and the complete, non-hidden remaining-issue list.**
