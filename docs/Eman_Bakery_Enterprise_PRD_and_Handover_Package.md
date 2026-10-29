# Eman Bakery — Enterprise Product Requirements Document & Handover Package

**Document Type:** Production-Ready Enterprise Handover  
**Version:** 1.0  
**Date:** 28 October 2026  
**Status:** Ready for Engineering Implementation (after closure of residual blockers)  
**Classification:** Internal — Engineering & Architecture  

---

## Document Control

| Item | Value |
|------|-------|
| Source of Truth | AI-1 operational discussions + original handoff pack |
| Architectural Iteration | AI-2 (Odoo-verified addendum) |
| Enterprise Architect Review | Cross-checked against business invariants, concurrency patterns, ledger/VAT rules, and Odoo JSON-2 outbox requirements |
| Primary Business | Eman Bakery, Jeddah, Saudi Arabia — daily-fresh wholesale bread |
| Legal Invoice Engine | Odoo Online 19 + Saudi localization (ZATCA Phase 2) |
| Operational Database | Supabase Postgres (or equivalent) with Row-Level Security |

---

# Part 1 — Executive Summary & Architecture Verdict

## 1.1 Purpose
This document synthesizes the original business intent (AI-1), the refined architecture iteration (AI-2), and a rigorous enterprise architecture review into a single, authoritative Product Requirements Document (PRD) and implementation handover package. It is intended for direct use by engineering teams and AI coding agents.

## 1.2 Architecture Verdict
**Revise → Accept after targeted hardening.**

The architecture correctly preserves all core business invariants:
- No warehouse stock.
- Per-distributor price matrices and customer assignments.
- Server-side quantity caps under database row locks.
- Server-side maximum resale price enforcement.
- Strict segregation of VAT treatment between the two commercial legs.
- Odoo Online 19 as the sole legal book and ZATCA clearance engine.
- Transactional outbox + durable worker + explicit ambiguous state to prevent duplicate tax invoices.

Residual blockers that must be closed before production tax-invoice issuance:
1. Explicit handling of the first-balance-row creation race (advisory lock or create-on-dispatch-confirm).
2. Worker ownership of uniqueness because the searchable Odoo reference field is not guaranteed unique on Odoo Online.
3. Confirmation of exact Odoo field names, create payload shape, and ZATCA status values from the live instance `/doc` page.

## 1.3 Invariant Compliance Matrix

| # | Invariant | Status | Notes |
|---|-----------|--------|-------|
| 1 | No warehouse stock | Pass | Availability derived solely from confirmed dispatches on the current Riyadh cycle. Unsold quantity becomes explicit write-off. |
| 2 | Distributor matrix & assignments | Pass | 85–90 distributors, multiple daily pickups, private price matrices, assigned B2B customers only. |
| 3 | Quantity cap under lock | Pass (design) / Risk (first-row) | Must lock the balance row (or use advisory lock) inside the reservation transaction. |
| 4 | Max resale price, server-side | Pass | Enforced in the same transaction as quantity reservation. No invented floor price. |
| 5 | VAT legs segregated | Pass | Company→Distributor = non-VAT operational settlement. Distributor→B2B = single ZATCA Phase 2 tax invoice in Eman Bakery name, margin included. |
| 6 | Odoo is the legal book | Pass | Application owns commercial decision and outbox; Odoo owns posting, clearance, and legal artifacts. |
| 7 | No duplicate tax invoice | Pass (design) / Risk (uniqueness) | Transactional outbox + deterministic idempotency key + search-before-create + explicit ambiguous state. |

---

# Part 2 — Comprehensive Product Requirements Document (PRD)

## 2.1 Business Context

Eman Bakery produces fresh bread daily and dispatches it the same day to approximately 85–90 wholesale distributors. There is no warehouse stock to reconcile. Distributors make multiple pickups per day. Each distributor has:
- A private product price matrix (company transfer price).
- An administrator-defined maximum resale price per product.
- A private set of assigned B2B customers.

Distributors resell to their B2B customers. The customer-facing document is a ZATCA Phase 2 standard tax invoice issued in the name of Eman Bakery (seller of record and VAT registration). The taxable base includes the distributor’s margin. The commercial relationship between Eman Bakery and the distributor is settled through a separate non-VAT operational ledger.

## 2.2 Goals

1. Enforce quantity and price invariants under concurrent access with zero overselling.
2. Guarantee at-most-one legal tax invoice per commercial sale, even under network timeouts and at-least-once queue delivery.
3. Maintain clean separation of the two commercial legs for VAT and accounting purposes.
4. Provide reliable daily cycle close, reconciliation, and operator visibility.
5. Keep the browser/PWA completely untrusted for any business-rule enforcement.

## 2.3 Non-Goals

- Replacement of Odoo as the legal accounting and ZATCA system.
- Warehouse inventory management or multi-day stock carrying.
- Client-side enforcement of quantity or price limits.
- Automatic creation of a second tax invoice on timeout or retry.
- Hand-rolled ZATCA XML signing (prefer Odoo Saudi localization unless a written exception exists).

## 2.4 User Roles

| Role | Primary Capabilities | Explicit Denials |
|------|----------------------|------------------|
| Super Admin / Admin | Full configuration, price matrices, assignments, cycle close, reconciliation override | — |
| Company Order / Dispatch Staff | Create wholesale orders, confirm dispatches | Cannot issue B2B invoices or alter ledgers arbitrarily |
| Payment Staff | Record and allocate distributor payments | Cannot confirm dispatches or create tax invoices |
| Distributor User | Create B2B invoices for assigned customers only, view own balances and status | Cannot see other distributors, change prices, confirm dispatches, or issue credit notes |
| Auditor (Read-Only) | View reports and audit trails | No write access |

All authorization is enforced server-side and via database RLS. UI hiding is never sufficient.

## 2.5 Core User Stories

**US-1 — Confirm Dispatch**  
As dispatch staff, I confirm a distributor pickup so that the confirmed quantity becomes available for resale on the current Riyadh business day and the operational ledger is charged at the transfer price.

**US-2 — Create B2B Invoice**  
As a distributor cashier, I create an invoice for one of my assigned B2B customers. The system must reject the request if quantity is insufficient or the unit price exceeds the maximum resale price. On acceptance, quantity is reserved and a durable outbox job is created atomically.

**US-3 — Observe Invoice Status**  
As a distributor user, I see the true processing state of every invoice (Reserved, Submitted, Cleared, Rejected, Ambiguous, Manual Review). An unconfirmed outcome is never shown as successful.

**US-4 — Cycle Close**  
As an operations user (or scheduled job), I close a Riyadh business day so that no further sales are accepted on that cycle, remaining quantity is written off explicitly, and ambiguous items remain visible for reconciliation.

**US-5 — Reconcile**  
As finance or operations staff, I run (or view the daily) reconciliation that compares local reservations against Odoo moves by idempotency key and surfaces quantity equation exceptions and multi-match references.

## 2.6 Functional Requirements

### Quantity & Price
- FR-Q1: Available quantity for (distributor, product, cycle) = Σ confirmed dispatch quantity − Σ quantity held by sales in statuses {reserved, submitted, cleared, ambiguous}.
- FR-Q2: All quantity and price checks occur inside a single database transaction that acquires a lock on the balance key before any mutation.
- FR-Q3: Unit price on a B2B invoice line must be ≤ the administrator-configured maximum resale price for that distributor and product. Violation causes full transaction rollback; no outbox row is written.
- FR-Q4: A sale whose status is draft does not hold quantity. Transition to reserved holds quantity.
- FR-Q5: Quantity is never released from a cleared identity except via an explicit credit-note document that carries its own idempotency key.

### Commercial Legs
- FR-L1: Company → Distributor movements update the operational ledger only. No tax invoice is generated.
- FR-L2: Distributor → B2B Customer produces exactly one ZATCA Phase 2 standard tax invoice whose seller is Eman Bakery and whose taxable amount is the price charged to the customer (margin included).
- FR-L3: Distributor margin settlement is derived from cleared invoice lines and is itself idempotent.

### Outbox & Worker
- FR-O1: The sale record (status = reserved) and the outbox row (with deterministic unique idempotency key) are inserted in the same database transaction.
- FR-O2: The worker never calls Odoo while holding a database lock on the balance row.
- FR-O3: Before every create attempt the worker searches Odoo for an existing move whose reference equals the idempotency key.
- FR-O4: On timeout or connection reset after the request has been sent, the job moves to state `ambiguous`. No further create is permitted until search proves absence.
- FR-O5: Multi-match on the reference field is a hard manual-review exception.

### Cycle & Time
- FR-C1: Business cycle is the civil date in `Asia/Riyadh`.
- FR-C2: Close-of-cycle job refuses new sales, writes an explicit write-off for any remaining quantity, and leaves ambiguous rows untouched.
- FR-C3: Unsold quantity is never carried forward as opening stock.

### Audit & Money
- FR-A1: Every quantity or monetary movement records actor, UTC timestamp, before/after or delta, reason, and source document.
- FR-A2: Monetary amounts use exact numeric types; binary floating-point is forbidden.
- FR-A3: Ledger entries are append-only. Corrections are compensating entries.

## 2.7 Non-Functional Requirements

- Correctness under concurrency is a hard requirement; throughput is secondary.
- All privileged business rules execute server-side.
- Secrets never appear in client bundles, logs, repository, or chat.
- Observability must include: job_id, correlation_id, attempt number, state transitions, queue age, ambiguous count, and reconciliation discrepancy counts.
- Backup and restore of the operational database must be rehearsed before production.
- Riyadh local time is used for all business-day calculations and UI display; storage remains UTC.

## 2.8 Data Model (Logical)

**Master Data**  
products, distributors, b2b_customers, distributor_customer_assignments, user_profiles, roles/permissions, distributor_product_prices (transfer), distributor_resale_price_rules (maximum).

**Operational Documents**  
wholesale_orders / wholesale_order_lines, dispatches / dispatch_lines (only confirmed lines affect balance).

**Quantity Projection**  
cycle_balance (distributor_id, product_id, cycle_date, available_qty, max_resale_price, version or updated_at) — the row that is locked.

**Sales & Outbox**  
resale_invoice_requests / resale_invoice_lines (status machine), outbox / invoice_jobs (idempotency_key UNIQUE, state, lease_owner, leased_until, payload, odoo_move_id, attempts, last_error).

**Financial**  
distributor_ledger_entries (append-only), payments, payment_allocations.

**Control & Observability**  
audit_logs, reconciliation_runs, reconciliation_discrepancies, invoice_status_events.

**Quantity Holding Rule**

| Sale Status | Holds Quantity? |
|-------------|-----------------|
| draft | No |
| reserved | Yes |
| submitted / cleared | Yes |
| ambiguous | Yes |
| rejected_never_accepted / void_before_submit | No (released once) |
| cleared then credit-noted | Released only by the credit-note document |

## 2.9 State Machines

**Invoice / Job State Machine (simplified)**  
```
draft → reserved → (queued) → processing → submitted → cleared
                ↘               ↘           ↘
                 void_before_submit   failed_terminal   rejected_never_accepted
                                    ↘
                                     ambiguous → (reconcile by search) → one of the terminal states
```

**Outbox / Worker States**  
pending → leased → succeeded | failed_retryable | failed_terminal | ambiguous

## 2.10 Failure Modes That Must Be Proven Safe

- Two concurrent cashiers sell the last unit → exactly one succeeds.
- Odoo create times out after commit → job becomes ambiguous; quantity held; no second create.
- Cloud Tasks delivers the same outbox row twice → second delivery is idempotent.
- Balance row does not yet exist on first sale of a product/distributor/cycle → advisory lock or pre-creation on dispatch prevents double insert.
- ZATCA rejects after Odoo create → quantity release only if the identity was never accepted; otherwise credit-note path.
- Close-of-cycle runs while a sale transaction holds the lock → close waits or retries.

---

# Part 3 — Critical Architecture Review (CPO Lens)

## 3.1 Scores

| Dimension | Score (0–10) | Commentary |
|-----------|--------------|------------|
| Completeness of happy path | 9 | All major workflows are covered. |
| Edge-case & concurrency coverage | 7 | First-row race and multi-line lock ordering need explicit treatment. |
| Failure handling & recoverability | 8 | Ambiguous state and search-before-create are correct; uniqueness ownership must be hardened. |
| Operational readiness | 7 | Reconciliation, alerting, and runbooks are present but require concrete ownership. |
| Readiness for coding agents | 7.5 | Rises to ≥9 after the two blockers and live `/doc` verification. |

## 3.2 Evaluation of Specific Mechanisms

**Transactional Outbox**  
Correctly placed inside the same transaction as the quantity reservation. Publisher runs after commit. Sweeper required for stranded pending rows. Both publisher and sweeper must treat “task already exists” as success.

**Worker Resilience**  
Lease + state machine is sound. Concurrency must be bounded. Retry only transport / 5xx failures with jittered exponential backoff. Business and ZATCA rejections are terminal or manual-review.

**Idempotency Keys**  
Deterministic and unique in Postgres. Used as Cloud Tasks task name. Because Odoo Online cannot guarantee uniqueness of the searchable reference, the worker must treat search results as the source of truth and never create when any match exists.

**Network Timeout Handling**  
Explicit `ambiguous` state that continues to hold quantity is the correct design. The residual risk is an incomplete search or a non-unique reference leading to a second create; this is called out as a blocker.

**Row-Level Locking**  
Design is correct. Implementation must:
- Lock in a stable order when an invoice contains multiple product lines.
- Guarantee the balance row exists or is created under protection before the first sale.
- Never hold the lock across the Odoo HTTP call.

## 3.3 Residual Risks (Ordered by Severity)

1. **Blocker** — Second tax invoice created under timeout + non-unique reference.  
2. **Blocker** — First-sale race on non-existent balance row.  
3. **Risk** — ZATCA status field names/values differ from assumptions.  
4. **Risk** — Close-of-cycle and sales transactions deadlock or race.  
5. **Gap** — Concrete ownership and runbook for the daily reconciliation exception queue.

---

# Part 4 — Implementation Guidance for Engineering & AI Agents

## 4.1 Milestone Order (Do Not Skip)

1. Invariants, Riyadh cycle clock, threat model, and role matrix.  
2. Master data (distributors, products, assignments, price matrices) + confirmed dispatch documents.  
3. Cycle balance ledger with row locks + local reserved invoice (no Odoo calls).  
4. Transactional outbox + durable worker against a non-production Odoo, including the full timeout/ambiguous/reconciliation path.  
5. ZATCA clearance states via Odoo’s Saudi localization.  
6. Company→Distributor non-VAT settlement journals.  
7. Close-of-cycle job + daily reconciliation report + operator exception queue.

## 4.2 Ready-to-Use Agent Context Prompt

```text
SYSTEM PROMPT FOR CODING AGENT

You are implementing the Eman Bakery operational platform (Jeddah wholesale bread).

NON-NEGOTIABLE INVARIANTS:
1. No warehouse stock. Availability = confirmed dispatches on the current Asia/Riyadh cycle only.
2. ~85–90 distributors, multiple pickups per day, private price matrix, private B2B customer assignments.
3. Quantity cap enforced inside a Postgres transaction that locks the balance row (or takes an advisory lock) on (distributor_id, product_id, cycle_date).
4. Maximum resale price enforced in the same transaction. No invented floor price.
5. Company → Distributor = non-VAT operational ledger settlement only. Distributor → B2B = single ZATCA Phase 2 standard tax invoice issued in Eman Bakery’s name; taxable base includes distributor margin.
6. Odoo Online 19 is the sole legal book and clearance engine. The application owns the commercial decision and the outbox.
7. At-least-once delivery must never produce a second tax invoice. Always search-before-create. Timeouts become explicit “ambiguous” state that continues to hold quantity.

SCHEMA RULES:
- Create the cycle_balance row on first confirmed dispatch or protect first-sale insert with a transaction-scoped advisory lock.
- Sale (status=reserved) + outbox row (deterministic UNIQUE idempotency_key) written in the same transaction.
- Money and quantity columns use exact numeric types.
- Timestamps stored in UTC; business day calculations use Asia/Riyadh.
- Ledger and audit tables are append-only.

WORKER RULES:
- Lease the outbox row.
- Search Odoo by the chosen reference field = idempotency_key before any create.
- Match found → repair local pointer, mark succeeded, do not create.
- No match and state permits → single create (prefer header + lines in one call).
- Timeout / connection reset after send → mark ambiguous; never create again until search proves absence.
- Multiple matches → hard manual-review exception.
- Never hold a database lock across the HTTP call to Odoo.

MILESTONE DISCIPLINE:
Implement only the currently approved milestone. Produce tests that prove the concurrency and timeout invariants before proceeding. All Odoo model, field, and method names remain UNVERIFIED until confirmed on the live instance /doc page.
```

## 4.3 Required Proof Tests (Must Pass Before Production)

**Concurrency**
- Two concurrent transactions attempt to reserve the final unit → exactly one commits.
- Multi-line invoice locks products in stable order; no deadlock under parallel load.
- First sale of a new (distributor, product, cycle) is safe under concurrency.

**Idempotency & Timeout**
- Simulated timeout after Odoo has committed → job becomes ambiguous; quantity held; subsequent search finds the move and repairs the pointer; no second create.
- Duplicate Cloud Tasks delivery of the same outbox row is a no-op.
- Multi-match on reference → job moves to manual review; no automatic action.

**Business Rules**
- Unit price = max accepted; max + 0.01 rejected inside the transaction; no outbox written.
- Unassigned customer rejected even when quantity remains.
- Requested (unconfirmed) dispatch does not increase availability.
- Void of reserved (never submitted) restores quantity once. Cleared identity requires credit note.

**Cycle**
- Close-of-cycle refuses new sales, writes explicit write-off, leaves ambiguous rows.
- 23:30 and 00:30 Riyadh correctly assign cycle_date.

**Security**
- Distributor A cannot read or mutate Distributor B’s data via any API path.
- Service-role and Odoo credentials never appear in client bundles or logs.

---

# Part 5 — Final Handover Structure

The engineering team should maintain the following document set (already largely present in the AI-1 / AI-2 folders, now unified and hardened by this review):

```
Eman_Bakery_Enterprise_Handover/
├── 00_READ_FIRST_EXECUTION_GUIDE.md
├── 01_SYSTEM_ARCHITECTURE_AND_SCOPE.md
├── 02_DATA_MODEL_AND_BUSINESS_INVARIANTS.md
├── 03_ODOO_ADAPTER_AND_DURABLE_WORKER.md
├── 04_SECURITY_TESTING_AND_ACCEPTANCE.md
├── 05_ENVIRONMENT_AND_PLATFORM_SETUP.md
├── 06_RELEASE_RUNBOOK_AND_AGENT_PROMPTS.md
├── 07_ODOO_BACKEND_VERIFICATION_EVIDENCE.md          (to be completed with live /doc results)
├── 08_ENTERPRISE_ARCHITECT_REVIEW_AND_PRD.md         (this document)
└── 09_AGENT_CONTEXT_PROMPTS.md                       (extract of Section 4.2 + milestone prompts)
```

## 5.1 Immediate Next Actions

1. Close the two blockers in the schema and worker design (first-row lock + uniqueness ownership).  
2. Perform live inspection of the Odoo Online 19 `/doc` page and record:
   - Exact field chosen for the searchable external reference.
   - Shape of the create call that includes invoice lines.
   - Official ZATCA / l10n_sa status field names and values.
3. Obtain tax-advisor confirmation of the non-VAT settlement journal treatment.  
4. Only then authorize a coding agent to begin Milestone 1.

## 5.2 Success Criteria for Production Readiness

- All critical concurrency and timeout tests pass with evidence.
- Live Odoo workflow (create → post → clearance status) demonstrated in a non-production database.
- Reconciliation runbook exercised, including multi-match and ambiguous cases.
- RLS and server-side authorization tests pass for every role.
- Database backup/restore rehearsed.
- Monitoring and alert ownership assigned.
- Finance / business owner sign-off on quantity equation, price rules, and ledger semantics.
- Documented rollback plan and stop-switch for invoice issuance.

---

**End of Document**

This package is the authoritative synthesis of the original business intent, the architectural iteration, and the enterprise-grade review. All core invariants are preserved. Residual risks are explicitly listed and must be closed before any tax invoice is issued in production.
