# Purchase Architecture — 3-Way Purchase System

## Principle

There is **one** purchase engine. Three different entry points create a `Purchase` row, but every financial consequence of a purchase — Town Coin credit, coupon issuance, referral qualification, audit logging — runs through exactly one code path (`PurchaseRecordingService::applyFinancials()`), regardless of which method created the row. No method has its own coin/coupon logic, its own table, or its own notification pipeline. This document describes that engine, the three entry points into it, and the security/idempotency guarantees that make it safe for a merchant's own client (Flutter or the admin web app) to never be trusted with financial state.

## The three purchase methods

| # | Name | Who acts | Initial status | Identity source |
|---|---|---|---|---|
| 1 | Customer scans merchant QR | Customer | `pending` → `recorded`/`rejected` after merchant review | Customer scans; merchant reviews |
| 2 | Merchant enters customer mobile | Merchant (Owner/Staff) | `recorded` immediately | Merchant types a mobile number |
| 3 | Merchant scans customer QR | Merchant (Owner/Staff) | `recorded` immediately | Merchant scans; backend resolves identity |

`Purchase.source` records which method created the row (`customer_merchant_qr`, `merchant_mobile_entry`, `merchant_customer_qr`), purely for audit/reporting — it never changes which code path processes the row's financials.

### Method 1 — customer scans merchant/branch Purchase QR

1. Merchant/branch displays a permanent QR (see [Merchant Purchase QR](#merchant-purchase-qr) below).
2. Customer scans it in the Flutter app (`ScanMerchantQrScreen`), which calls `POST /purchases/qr/resolve` to preview the merchant/branch name before committing to anything.
3. Customer enters a bill amount and submits via `POST /purchases/requests`. The **same scanned token** — never a merchant/branch id — travels in this request; the backend re-resolves the branch from the token itself, so the customer has no way to submit against a different merchant/branch than the one they actually scanned.
4. The `Purchase` is created `pending`, with `coins_awarded = 0` and no coupons issued. Nothing financial happens yet.
5. The merchant (Owner or Staff of that merchant, regardless of which branch they normally work at — see [Security model](#security-model)) sees the request in their pending-approvals queue and either:
   - **Approves** (`POST /purchases/{id}/approve`) — the purchase transitions to `recorded`, and `applyFinancials()` runs: coins are credited and coupons issued for the first and only time.
   - **Rejects** (`POST /purchases/{id}/reject`, optional reason) — the purchase transitions to `rejected`. No financial side effects ever occur for a rejected purchase.

### Method 2 — merchant enters customer mobile number

Merchant (Owner or Staff) opens "Record a purchase," enters the customer's mobile number and a bill amount, and submits via `POST /purchases` with `customer_mobile_number`. The purchase is created `recorded` immediately — `applyFinancials()` runs in the same request. No second approval step exists: `PurchasePolicy::create()` already restricts this action to Owner/Staff, so the merchant's own authenticated action *is* the authorization. Introducing a second approval would duplicate a check the policy layer already performs.

### Method 3 — merchant scans customer QR

Merchant scans the customer's personal identity QR (see [Customer QR](#customer-qr) below) instead of typing a mobile number, then enters a bill amount and submits via the same `POST /purchases` endpoint with `customer_qr_token` in place of `customer_mobile_number`. The backend resolves the token to a `CustomerProfile` server-side; the merchant's client never sends a customer id it could substitute — only the raw scanned token — so the merchant cannot alter the identity the QR represents after scanning, even by tampering with the request body.

`customer_mobile_number` and `customer_qr_token` are mutually exclusive-but-either-satisfies (`required_without_all`): exactly one must be present.

## Merchant Purchase QR

A permanent, per-branch, opaque token (`merchant_branches.purchase_qr_token`, `Str::random(40)`, hidden from every response except its own dedicated endpoints). Managed via:

- `GET /merchant-branches/{branch}/purchase-qr` — view the current token (or `null`).
- `POST /merchant-branches/{branch}/purchase-qr` — generate (first time) or regenerate (invalidates the old token immediately — there is no grace period).
- `DELETE /merchant-branches/{branch}/purchase-qr` — revoke. A revoked/regenerated-away token resolves to a 404 identical to one that never existed, so a customer scanning a stale printed code cannot distinguish "revoked" from "never valid" — no information leak either way.

`MerchantBranchPolicy::manageQr()` gates all three to Owner or Staff of that merchant — deliberately narrower than the branch's general `update()` ability, which also allows Association Admin. An Association Admin has no operational reason to hold a branch's live, repeatedly-displayable QR secret.

Resolution (`POST /purchases/qr/resolve`, and internally at submission time) is handled by `MerchantPurchaseQrService::resolve()`, which looks up an **active** branch by token only — an inactive branch's QR does not resolve even if the token itself is technically still stored.

## Customer QR

Every customer has one personal, opaque identity token (`customer_profiles.qr_token`, same `Str::random(40)` mechanism, hidden by default). Unlike the merchant QR, there is no separate "generate" step — `GET /customer/qr` lazily provisions a token on first call, since every customer implicitly has this capability the moment they have a profile. `POST /customer/qr/regenerate` always issues a fresh token (no revoke-without-replacement state, since a customer QR with no value at all would make Method 3 impossible for that customer).

Resolving a customer QR (`POST /purchases/customer-qr/resolve`, used by both the admin web app's preview-before-submit UI and internally at record time) returns **name only** — `{customer_profile_id, name}` — never a mobile number, email, or auth token. This is a deliberate privacy rule: a merchant scanning a QR should be able to confirm they scanned the right person by name, without the QR (or its resolution response) ever exposing contact details a merchant shouldn't have outside the purchase flow itself.

## Purchase lifecycle

```
                    ┌─────────┐
   Method 1 ───────►│ pending │
                    └────┬────┘
                         │
              ┌──────────┼──────────┐
              ▼                     ▼
          ┌─────────┐         ┌──────────┐
          │recorded │         │ rejected │  (terminal)
          └────┬────┘         └──────────┘
               │
   Methods 2/3 ┘  (create directly here, skipping pending)
               │
        ┌──────┴──────┐
        ▼             │
   ┌─────────┐         │
   │disputed │         │
   └────┬────┘         │
        │               │
        ▼               │
   ┌─────────┐          │
   │ voided  │◄─────────┘  (terminal; historical dispute/void
   └─────────┘             flow, unchanged by this phase)
```

`PurchaseStatus::allowedNextStates()` is the single source of truth for legal transitions, enforced server-side on every mutation (`approve()`/`reject()` both re-check it after acquiring a row lock, not just before). `pending`/`rejected` exist **only** for Method 1's genuine pre-authorization gap — they are not a general reintroduction of a pending-by-default purchase model. Methods 2 and 3 still go straight to `recorded`, exactly as the pre-existing single-method system did.

## Approval rules

- Only Method 1 purchases ever have anything to approve — `review` ability (Owner/Staff of the merchant that owns the purchase) gates both `approve()` and `reject()`.
- A merchant cannot approve/reject a purchase belonging to a different merchant (cross-merchant isolation, enforced by the `review` Policy, not by trusting the client to only show relevant rows).
- A customer cannot approve or reject their own request — there is no such endpoint reachable by a customer account at all.
- An already-approved or already-rejected purchase cannot be acted on again — `canTransitionTo()` is re-checked *after* a row lock is acquired inside the transaction, so two concurrent approval attempts can never both succeed (see [Idempotency and concurrency safety](#idempotency-and-concurrency-safety)).

## Coin issuance

Coins are computed and credited in exactly one place: `PurchaseRecordingService::applyFinancials()`. For Methods 2/3 this runs inside `record()`'s transaction, immediately. For Method 1 it runs inside `approve()`'s transaction, at approval time — **not** at request time. The coupon rule and coin amount are resolved fresh at the moment of actual recording (whichever moment that is), never from a stale snapshot taken when the customer first submitted the request. A pending purchase always shows `coins_awarded: 0`; a rejected purchase permanently stays at `coins_awarded: 0`.

## Coupon issuance

Unchanged in its own lifecycle — `CouponIssuanceService::issueForPurchase()` is called from inside the same `applyFinancials()` block as the coin credit, so a purchase's coin credit and its coupon issuance are atomic with each other (both happen, or — if the transaction rolls back — neither does). Each issued coupon gets one `CouponEligibility` row per draw cadence (`weekly`/`monthly`/`mega`), all `active` at issuance; cadence narrowing (a coupon closing out of the weekly draw while staying eligible for monthly/mega) is a downstream concern of the draw engine described in [Lucky Draw relationship](#lucky-draw-relationship), not something this phase changed.

The customer-facing "my coupons" list/detail UI (`GET /coupons`, `GET /coupons/{coupon}`) already existed and required no new backend endpoint — only a Flutter UI layer (`lib/features/coupons/`) and one additive fix: the customer-facing branch of `CouponController::index()` was missing pagination `meta` (the admin branch already had it), added so the customer list screen can page/refresh consistently with every other list in the app.

## Idempotency and concurrency safety

Two distinct mechanisms cover the two distinct risk shapes:

- **Fresh submission (Methods 1, 2, 3 all create a NEW row)**: an `Idempotency-Key` header is required on every purchase-creating request (`requestFromCustomer()`/`record()`). The key is checked against a DB-unique-constrained column *before* insert; a reused key with an identical request body replays the original result; a reused key with a *different* body throws a 409 conflict rather than silently doing the wrong thing. A network retry of a genuinely failed request is therefore always safe — it can never create two purchases, two coin credits, or two coupon sets.
- **Approving an EXISTING row (Method 1 only)**: there is no fresh insert to key against, so `approve()`/`reject()` instead take a row lock (`lockForUpdate()`) inside a DB transaction and re-check `canTransitionTo()` after acquiring it. Two concurrent approval attempts on the same purchase — a genuine race, e.g. Owner and Staff both tapping "Approve" within the same second — result in exactly one succeeding and the second throwing a 409, verified by a dedicated concurrency test that calls `approve()` twice directly at the service layer.

In both cases, financial correctness is exact-once by construction, not by convention: **pending = 0 coins / 0 coupons, always; recorded = correct coins / correct coupons, exactly once; rejected = 0 coins / 0 coupons, permanently.**

## Security model

Trust boundaries follow one rule: **the client is never trusted for anything financial or identity-bearing.** Concretely:

- **Merchant isolation** — every purchase-affecting endpoint scopes to the merchant(s) the caller's Owner/Staff profile(s) actually belong to; cross-merchant access attempts return 403/404, verified by dedicated tests.
- **Customer isolation** — a customer can only ever see and request against their own account; they cannot view or act on another customer's pending requests.
- **QR security** — an invalid token, an expired/revoked token, and a token belonging to a different (but real) branch/customer all resolve identically from the outside (a plain 404 or "invalid" response), preventing enumeration. Both QR systems are mutually exclusive with the pre-existing Redemption QR system (separate token columns, separate services, separate endpoints) — the three QR systems are never mixed.
- **Anti-tampering** — both scan flows carry only an opaque token through to the final write; the merchant/branch or customer identity is *re-resolved from that token* at the moment of writing, server-side, every time. Neither Flutter nor the admin web app ever gets a chance to substitute a different merchant, branch, or customer id into the request.
- **Never trust the client for**: coin calculation, coupon calculation, purchase ownership, merchant identity, customer identity, or approval state. All five are computed or verified server-side on every request that touches them.

## API contracts

| Method | Path | Purpose |
|---|---|---|
| GET | `/merchant-branches/{branch}/purchase-qr` | View a branch's current Purchase QR token |
| POST | `/merchant-branches/{branch}/purchase-qr` | Generate/regenerate a branch's Purchase QR |
| DELETE | `/merchant-branches/{branch}/purchase-qr` | Revoke a branch's Purchase QR |
| GET | `/customer/qr` | View (lazily provisioning) the caller's own Customer QR |
| POST | `/customer/qr/regenerate` | Regenerate the caller's own Customer QR |
| POST | `/purchases/qr/resolve` | Resolve a scanned merchant/branch QR token (Method 1, step 1) |
| POST | `/purchases/customer-qr/resolve` | Resolve a scanned customer QR token to `{customer_profile_id, name}` (Method 3 preview) |
| POST | `/purchases/requests` | Submit a Method 1 purchase request (`pending`), requires `Idempotency-Key` |
| POST | `/purchases` | Record a Method 2/3 purchase (`recorded` immediately), requires `Idempotency-Key` |
| POST | `/purchases/{purchase}/approve` | Approve a pending purchase — records it, credits coins/coupons |
| POST | `/purchases/{purchase}/reject` | Reject a pending purchase — no financial side effects |
| GET | `/purchases?status=pending` | List purchases, optionally filtered by status (doubles as the pending-approval queue) |
| GET | `/purchases/{purchase}` | Purchase detail |
| GET | `/coupons`, `/coupons/{coupon}` | Customer's own coupons — unchanged endpoints, now with pagination `meta` on the list |

## Database changes

- `purchases.reviewed_at` (nullable timestamp), `purchases.rejection_reason` (nullable text) — Method 1 approval metadata.
- `merchant_branches.purchase_qr_token` (nullable, unique) — hidden by default.
- `customer_profiles.qr_token` (nullable, unique) — hidden by default.
- `purchases.idempotency_key` (pre-existing, reused unchanged) — the same column and unique-constraint mechanism `record()` already used, now shared by `requestFromCustomer()` too.

No table was duplicated, no historical purchase record was altered in shape, and every purchase created before this phase (`source: 'merchant_app'` on legacy rows, a literal never enum-constrained at the DB level) continues to read exactly as it did — the new `PurchaseSource` enum values are additive, not a migration of old data.

## Notifications

Reuses the existing `NotificationService`/`NotificationType` infrastructure — no second notification system. Two new types were added, each with a `config/notifications.php` channel/template entry, the same three-part pattern every existing type follows:

- `purchase.submitted` — to the merchant's active owner, when a customer submits a Method 1 request.
- `purchase.rejected` — to the customer, when their Method 1 request is rejected.

The pre-existing `purchase.recorded`/`purchase.coupon_generated` types fire for every method once a purchase actually reaches `recorded` — including a Method 1 purchase at the moment it's approved, not at the moment it was originally submitted.

## Lucky Draw relationship

**No draw-execution engine exists, and this phase deliberately did not build one.** Confirmed by direct audit: no `Draw`/`LuckyDraw` model, controller, service, or route exists anywhere in the backend; `app/Domain/LuckyDraw` and `app/Domain/Prize` are empty placeholder directories; the `lucky_draw` feature flag is explicitly disabled with an inline comment citing an unresolved lottery/gambling classification question. This is a pre-existing, deliberate product decision from before this phase, not something newly discovered or newly skipped.

What this phase *does* guarantee, so a future draw engine has correct data to work from: every issued coupon gets one `CouponEligibility` row per cadence (`weekly`/`monthly`/`mega`), each independently `active`/`closed`/`won`. Winner selection — when built — must be server-side, auditable, transaction-safe, protected against duplicate execution, and based only on coupons/eligibilities in an `active` state. None of that exists yet; it is out of scope for this phase and remains a documented product/legal decision, not an engineering gap.

## Migration strategy

Every change in this phase is additive:

- New nullable columns, never a destructive `ALTER` on an existing non-nullable field.
- Two new `PurchaseStatus` cases (`pending`, `rejected`) added to an existing enum — every pre-existing status and its transitions are untouched.
- A new `PurchaseSource` enum for auditing new purchases going forward; the historical `'merchant_app'` string literal on old rows is left as-is rather than backfilled, since the column was never enum-constrained at the database level and no behavior depends on old rows matching the new enum's cases.
- Both new QR token columns are nullable and start `null` for every existing branch/customer — nothing is generated proactively; a QR simply doesn't exist until someone asks for one, exactly the lazy/on-demand shape both features were designed around.

No existing purchase, coupon, coin transaction, or notification changes shape or meaning as a result of this phase.
