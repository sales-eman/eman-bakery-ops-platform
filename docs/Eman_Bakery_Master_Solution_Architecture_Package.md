# Eman Bakery  
# Master Solution Architecture Package

**Document Classification:** Internal – Source of Truth  
**Version:** 1.0  
**Date:** 28 October 2026  
**Status:** Authoritative for AI Agents, Engineering, and Stakeholders  
**System Name:** Eman Bakery Wholesale Distribution, Operational Ledger & ZATCA Phase 2 Invoicing Platform  

---

## Document Control

| Item | Value |
|------|-------|
| Business Owner | Eman Bakery (Jeddah, Saudi Arabia) |
| Primary Architect | Enterprise System Architect (this package) |
| Source of Truth Basis | Original operational discussions (AI-1), architectural iteration (AI-2), enterprise invariant review |
| Intended Consumers | AI coding agents, backend/frontend engineers, DevOps, finance/operations stakeholders |
| Change Control | Any material change to invariants, data model, or integration contracts requires formal revision of this package |

This single document is the authoritative source of truth. AI coding agents must treat every section as binding unless an explicit written exception is recorded.

---

# 01 — Executive Business Vision

## 1.1 Why the System Exists

Eman Bakery produces fresh bread daily in Jeddah and dispatches it the same day to approximately 85–90 wholesale distributors. There is no warehouse stock. Distributors make multiple pickups per day, each under a private price matrix, and resell to their own assigned B2B customers.

The current operational reality relies on fragmented processes that cannot reliably enforce:
- Quantity limits derived strictly from confirmed dispatches.
- Maximum resale prices set by the company.
- Correct VAT treatment between the company–distributor leg and the distributor–B2B-customer leg.
- Exactly-one legal ZATCA Phase 2 tax invoice per commercial sale under network failure and retry conditions.

The system exists to replace these manual and error-prone processes with a controlled, auditable, concurrency-safe operational platform that integrates with Odoo Online 19 as the sole legal accounting and ZATCA clearance engine.

## 1.2 Business Objectives

1. Eliminate overselling of dispatched quantities under concurrent cashier activity.
2. Enforce administrator-defined maximum resale prices server-side with zero bypass.
3. Issue every B2B tax invoice in the name of Eman Bakery, with the distributor margin included in the taxable base, under ZATCA Phase 2 clearance rules.
4. Keep the company–distributor commercial relationship as a non-VAT operational ledger settlement.
5. Provide complete daily cycle close, reconciliation, and operator visibility so that the quantity equation always balances or surfaces an explicit exception.
6. Enable AI coding agents and human engineers to implement the system with minimal ambiguity and near-enterprise consistency.

## 1.3 Expected Business Outcomes

- Zero quantity oversell incidents attributable to race conditions.
- Zero duplicate ZATCA tax invoices caused by timeouts or at-least-once delivery.
- Complete audit trail for every quantity and monetary movement.
- Daily reconciliation that can be reviewed by finance within a defined service window.
- Distributor self-service portal that cannot violate company rules.

## 1.4 Target Users

| User Group | Primary Interaction |
|------------|---------------------|
| Company Operations / Dispatch Staff | Create wholesale orders, confirm dispatches |
| Company Finance / Payment Staff | Record and allocate distributor payments, review reconciliation |
| Company Administrators | Manage products, distributors, price matrices, customer assignments, cycle close |
| Distributor Cashiers / Portal Users | Create B2B invoices for assigned customers only, view real-time status |
| Auditors / Read-only Reviewers | Inspect ledgers, audit logs, and reports |
| System Workers (automated) | Process outbox, call Odoo, reconcile ambiguous outcomes |

## 1.5 Success Criteria

- All seven business invariants (see Section 02 and 04) hold under concurrent load and network failure.
- Mandatory concurrency and timeout proof tests pass with recorded evidence.
- Live Odoo Online 19 integration demonstrated end-to-end in a non-production environment, including the ambiguous-timeout path.
- Daily reconciliation report is produced automatically and surfaces every discrepancy.
- No production tax invoice is issued until the residual blockers listed in this package are closed.

---

# 02 — Product Requirements Document (PRD)

## 2.1 Scope

The system is an operational platform. It is not a general ERP. Odoo Online 19 remains the legal book of record and the ZATCA clearance engine. The application owns commercial decisions, quantity and price enforcement, the transactional outbox, and operator-facing workflows.

## 2.2 Core Business Invariants (Non-Negotiable)

1. **No warehouse stock.** Availability is derived solely from confirmed dispatches on the current Asia/Riyadh business cycle. Unsold quantity at cycle close becomes an explicit write-off; it is never carried forward.
2. **Distributor model.** Approximately 85–90 wholesale distributors. Multiple pickups per day accumulate into the same cycle balance. Each distributor has a private price matrix and a private set of assigned B2B customers.
3. **Quantity cap, server-side.** For every (distributor, product, cycle) the sum of sales that hold quantity cannot exceed confirmed dispatches. Enforcement occurs inside a database transaction that locks the balance row (or uses a transaction-scoped advisory lock).
4. **Maximum resale price, server-side.** An administrator sets a maximum unit price per product (and, where configured, per distributor). Any B2B invoice line exceeding that maximum is rejected inside the same transaction; no outbox row is written.
5. **VAT leg segregation.**  
   - Company → Distributor = non-VAT operational ledger settlement.  
   - Distributor → B2B Customer = single ZATCA Phase 2 standard tax invoice issued in the name of Eman Bakery; taxable base includes the distributor margin.
6. **Odoo is the legal book.** The application decides what to sell and reserves quantity. Odoo posts the legal invoice and performs ZATCA clearance. The application never overwrites Odoo as the source of legal truth.
7. **No duplicate tax invoice.** At-least-once delivery must never produce a second tax invoice. This is achieved by a transactional outbox, a deterministic unique idempotency key, search-before-create, and an explicit `ambiguous` state that continues to hold quantity.

## 2.3 Key User Stories

**US-1 Confirm Dispatch**  
As dispatch staff I confirm a distributor pickup so that the confirmed quantity becomes available for resale on the current Riyadh cycle and the operational ledger is charged at the transfer price.  
Acceptance: Confirmation is idempotent; repeated confirmation does not increase quantity or ledger impact a second time.

**US-2 Create B2B Invoice**  
As a distributor cashier I create an invoice for one of my assigned B2B customers.  
Acceptance: The system rejects the request if the customer is not assigned, if quantity is insufficient, or if any unit price exceeds the maximum. On acceptance, quantity is reserved and a durable outbox job is created atomically.

**US-3 Observe True Status**  
As a distributor user I see the real processing state of every invoice (Reserved, Submitted, Cleared, Rejected, Ambiguous, Manual Review). An unconfirmed outcome is never displayed as successful.

**US-4 Cycle Close**  
As operations staff (or a scheduled job) I close a Riyadh business day.  
Acceptance: No further sales are accepted on that cycle; remaining quantity is written off explicitly; ambiguous items remain visible for reconciliation.

**US-5 Reconcile**  
As finance or operations staff I obtain a daily (and on-demand) reconciliation that compares local reservations against Odoo moves by idempotency key and surfaces quantity-equation exceptions and multi-match references.

## 2.4 Functional Requirements (Selected)

- FR-Q1 Available quantity = Σ confirmed dispatch quantity − Σ quantity held by sales in {reserved, submitted, cleared, ambiguous}.
- FR-Q2 All quantity and price checks execute inside a single Postgres transaction that acquires the required lock before any mutation.
- FR-Q3 Unit price ≤ administrator maximum; violation causes full rollback and no outbox row.
- FR-Q4 Draft sales do not hold quantity; transition to reserved does.
- FR-Q5 Quantity is never released from a cleared identity except via an explicit credit-note document that carries its own idempotency key.
- FR-L1 Company→Distributor movements update only the operational ledger; no tax invoice is generated.
- FR-L2 Distributor→B2B produces exactly one ZATCA Phase 2 standard tax invoice in Eman Bakery’s name.
- FR-O1 Sale (status = reserved) and outbox row (deterministic unique idempotency key) are written in the same database transaction.
- FR-O2 The worker never calls Odoo while holding a database lock on the balance row.
- FR-O3 Before every create the worker searches Odoo for an existing move whose reference equals the idempotency key.
- FR-O4 Timeout or connection reset after the request has been sent moves the job to `ambiguous`; no further create is permitted until search proves absence.
- FR-C1 Business cycle = civil date in Asia/Riyadh.
- FR-A1 Every quantity or monetary movement records actor, UTC timestamp, before/after or delta, reason, and source document.
- FR-A2 Monetary amounts use exact numeric types; binary floating-point is forbidden.

---

# 03 — Functional Specification

## 3.1 Dispatch Confirmation Screen (Company Staff)

**Purpose:** Record that a distributor has physically taken product.

**Fields**
- Distributor (required, searchable)
- Cycle Date (default = today Asia/Riyadh, editable only by authorised role)
- Product lines: Product, Requested Qty, Confirmed Qty, Transfer Unit Price (snapshot)
- Notes / Reference

**Actions**
- Save as Draft
- Confirm Dispatch (idempotent)
- Cancel Draft

**Business Rules**
- Only confirmed quantity increases the cycle balance.
- Confirmation is atomic with the balance update and the operational ledger charge.
- Repeated confirmation of the same dispatch document is a no-op.

## 3.2 B2B Invoice Creation Screen (Distributor)

**Purpose:** Create a customer-facing tax invoice under company rules.

**Fields**
- B2B Customer (restricted to assigned customers only)
- Product lines: Product, Quantity, Unit Price
- Calculated: Line Total, VAT, Grand Total (display only; server recalculates)

**Actions**
- Save Draft
- Submit Invoice

**Business Rules (all server-side)**
- Customer must be assigned to the current distributor.
- For every line: available quantity ≥ requested quantity (under lock).
- For every line: unit price ≤ maximum resale price.
- On successful validation the system creates the sale in status `reserved` and the outbox row in one transaction.
- The UI never receives a success response until the database transaction has committed.

## 3.3 Invoice Status View (Distributor)

Displays for each invoice:
- Local status (Reserved / Submitted / Cleared / Rejected / Ambiguous / Manual Review)
- Odoo move reference (when known)
- ZATCA clearance status (when known)
- Quantity held indicator
- Timestamp of last state change

An Ambiguous or Manual Review status is never labelled “Completed”.

## 3.4 Cycle Close Screen / Scheduled Job

**Purpose:** Close a Riyadh business day.

**Actions**
- Preview remaining quantity per distributor/product
- Execute Close (writes explicit write-off documents, freezes the cycle)
- View exceptions (ambiguous sales, quantity equation mismatches)

**Rules**
- After close, no new sales are accepted on that cycle_date.
- Remaining quantity is written off; it is never transferred to the next cycle.
- Ambiguous rows are left for reconciliation.

## 3.5 Reconciliation Dashboard (Finance / Operations)

**Sections**
- Local sales by status (Reserved, Submitted, Cleared, Ambiguous, …)
- Odoo moves matched by idempotency key / reference
- Unmatched Odoo moves carrying the system’s reference prefix
- Quantity equation per (distributor, product, cycle)
- Settlement rows counted once per cleared line
- Exception queue with severity and owner assignment

---

# 04 — System Architecture Document

## 4.1 High-Level Component Diagram

```
Distributor / Company Users
        │
        ▼
   Web / PWA Frontend
        │
        ▼
   Authenticated Backend API
   (business rules, transactions, RLS enforcement)
        │
        ├──────────────────────────────┐
        ▼                              ▼
 Supabase Postgres                 Durable Queue
 (operational data,                (Cloud Tasks or
  outbox, audit, RLS)               equivalent)
        │                              │
        │                              ▼
        │                       Worker (Cloud Run
        │                       or equivalent)
        │                              │
        │                              ▼
        │                       Odoo Online 19
        │                       JSON-2 API
        │                       (legal invoices,
        │                        ZATCA clearance)
        ▼
   Operational Reports
   & Reconciliation
```

## 4.2 Component Responsibilities

| Component | Purpose | Technology | Owner | Security Notes |
|-----------|---------|------------|-------|----------------|
| Frontend (Web/PWA) | User interface only | Existing repository stack (or approved equivalent) | Frontend team | Never trusted for business rules; no secrets |
| Backend API | Authentication, authorisation, all business-rule validation, transactional writes | Server-side service | Backend team | Service-role keys stay server-side |
| Supabase Postgres | Operational source of truth for quantities, reservations, outbox, ledgers, audit | Postgres + RLS | Data team | RLS on every exposed table; deny-by-default |
| Durable Queue | At-least-once delivery of outbox jobs | Cloud Tasks (or verified equivalent) | Platform team | Task name = idempotency key for deduplication |
| Worker | Lease outbox, search Odoo, create/post, reconcile, update local state | Cloud Run (or verified equivalent) | Backend / Platform | Bounded concurrency; no long-held DB locks |
| Odoo Online 19 | Legal invoice posting, Saudi localisation, ZATCA Phase 2 clearance | Odoo Online JSON-2 | Finance / Integration | API key in secret store; least-privilege integration user |

## 4.3 Trust Boundaries

- Browser → Backend API: authenticated, rate-limited, input-validated.
- Backend API → Postgres: uses service credentials; all business writes go through validated transactions.
- Worker → Odoo: TLS, bearer token, host allow-list, timeouts, structured error classification.
- No component treats Odoo and the operational database as a single atomic transaction.

## 4.4 Deployment Shape (Target)

- Frontend: existing hosting target (e.g. Vercel) if it meets requirements.
- Backend API & Worker: Cloud Run or equivalent durable compute.
- Queue: Cloud Tasks.
- Database: Supabase Postgres (or equivalent) with separate development, staging, and production projects.
- Secrets: platform secret manager; never in source control or client bundles.
- Observability: structured logs, metrics (queue age, ambiguous count, discrepancy count), alerts.

---

# 05 — Data Architecture

## 5.1 Core Entities

- products  
- distributors  
- b2b_customers  
- distributor_customer_assignments  
- user_profiles / roles / permissions  
- distributor_product_prices (transfer price + effective dates)  
- distributor_resale_price_rules (maximum resale price + effective dates)  
- wholesale_orders / wholesale_order_lines  
- dispatches / dispatch_lines  
- cycle_balance (projection locked for concurrency)  
- resale_invoice_requests / resale_invoice_lines  
- outbox / invoice_jobs  
- distributor_ledger_entries (append-only)  
- payments / payment_allocations  
- audit_logs  
- reconciliation_runs / reconciliation_discrepancies  
- invoice_status_events  

## 5.2 Key Relationships

```
Distributor 1──* Distributor_Customer_Assignment *──1 B2B_Customer
Distributor 1──* Dispatch_Line *──1 Product
Distributor + Product + Cycle_Date 1──1 Cycle_Balance
Cycle_Balance 1──* Resale_Invoice_Line (holding quantity)
Resale_Invoice_Request 1──1 Outbox_Job (idempotency_key)
Outbox_Job 0..1──1 Odoo account.move (by reference)
```

## 5.3 Quantity Equation (Authoritative)

```
available_qty(distributor, product, cycle) =
    Σ confirmed_dispatch_qty
  − Σ qty of sales whose status ∈ {reserved, submitted, cleared, ambiguous}
```

A sale holds quantity while it is in one of the listed statuses. Draft does not hold quantity. Release occurs only under explicitly defined safe transitions.

## 5.4 Data Dictionary (Selected Critical Fields)

| Entity | Field | Type | Required | Description |
|--------|-------|------|----------|-------------|
| cycle_balance | distributor_id | uuid | Yes | |
| cycle_balance | product_id | uuid | Yes | |
| cycle_balance | cycle_date | date | Yes | Asia/Riyadh civil date |
| cycle_balance | available_qty | numeric | Yes | Projection under lock |
| cycle_balance | max_resale_price | numeric | Yes | Snapshot of current rule |
| resale_invoice_requests | idempotency_key | text | Yes | Deterministic, UNIQUE |
| resale_invoice_requests | status | text | Yes | See state machine |
| outbox | idempotency_key | text | Yes | UNIQUE, used as queue task name |
| outbox | state | text | Yes | pending / leased / succeeded / failed_* / ambiguous |
| outbox | odoo_move_id | text | No | Populated after successful create or reconciliation |
| distributor_ledger_entries | entry_type | text | Yes | charge / payment / adjustment / write_off |
| distributor_ledger_entries | amount | numeric | Yes | Exact decimal |

All monetary and quantity columns use exact numeric types. Timestamps are stored in UTC; business-day logic uses Asia/Riyadh.

## 5.5 Concurrency Design

- Balance row is locked with `SELECT … FOR UPDATE` (or protected by a transaction-scoped advisory lock when the row does not yet exist).
- Multi-line invoices lock products in a stable order to avoid deadlock.
- The first balance row for a (distributor, product, cycle) is created either on dispatch confirmation or under advisory-lock protection.
- Odoo HTTP calls never occur while a balance lock is held.

---

# 06 — Security Architecture

## 6.1 Roles

| Role | Capabilities | Explicit Denials |
|------|--------------|------------------|
| Super Admin / Admin | Full configuration, price matrices, assignments, cycle close, reconciliation override | — |
| Company Order / Dispatch Staff | Create orders, confirm dispatches | Cannot issue B2B invoices or alter ledgers arbitrarily |
| Payment Staff | Record and allocate payments | Cannot confirm dispatches or create tax invoices |
| Distributor User | Create B2B invoices for assigned customers, view own data and status | Cannot see other distributors, change prices, confirm dispatches, issue credit notes |
| Auditor (Read-only) | View reports and audit trails | No write access |

## 6.2 Permission Model

- Deny by default.
- Every privileged action is authorised server-side.
- Database Row-Level Security (RLS) is enabled on every table exposed through the API.
- Distributor users can only see rows belonging to their own distributor_id.
- Service-role credentials never leave the server-side environment.

## 6.3 Additional Controls

- Multi-factor authentication for company staff accounts (where the identity provider supports it).
- Session expiry and immediate revocation on role change or user deactivation.
- Encryption in transit (TLS) and at rest (platform default).
- Complete audit log for every quantity or monetary mutation (actor, timestamp, before/after or delta, reason, source).
- Secrets stored only in the platform secret manager; never in source control, client bundles, logs, or chat.
- Structured logging that redacts credentials and sensitive payload fields.

---

# 07 — Integration Architecture

## 7.1 Primary Integration: Odoo Online 19

| Attribute | Value |
|-----------|-------|
| Protocol | HTTPS JSON-2 (`POST /json/2/<model>/<method>`) |
| Authentication | Bearer API key (dedicated integration user, least privilege) |
| Direction | Worker → Odoo (outbound only) |
| Frequency | On-demand per outbox job + scheduled reconciliation |
| Owner | Integration / Backend team |
| Error Handling | Classification into retryable (transport/5xx), terminal (4xx business), ambiguous (timeout after send) |
| Idempotency | Search by deterministic reference before every create; never create from ambiguous state |
| Uniqueness | Worker-owned; Odoo Online does not guarantee a unique constraint on the searchable reference field |

## 7.2 Supporting Integrations

| Integration | Protocol | Purpose | Notes |
|-------------|----------|---------|-------|
| Cloud Tasks (or equivalent) | Platform API | Durable at-least-once delivery of outbox jobs | Task name = idempotency key |
| Supabase Auth | Platform | User authentication and JWT | RLS relies on authenticated claims |
| Observability stack | Platform | Logs, metrics, alerts | Queue age, ambiguous count, discrepancy count |

## 7.3 Explicit Non-Integrations

- No direct browser-to-Odoo calls.
- No custom Python modules on Odoo Online (not supported).
- No hand-rolled ZATCA XML signer unless a written exception is recorded; prefer Odoo’s Saudi localisation.

---

# 08 — UX / UI Specification

## 8.1 Design Principles

- Clarity of status over visual decoration.
- Distributor users must never be able to see or act on another distributor’s data.
- Every destructive or irreversible action requires explicit confirmation.
- Mobile-responsive layout for cashier use on tablets and phones.
- Loading and error states must never imply success when the outcome is still ambiguous.

## 8.2 Key Screens (Logical Wireframe Description)

**Dispatcher Confirmation**  
Header (user, cycle date) → Distributor selector → Product grid (requested / confirmed qty) → Confirm / Cancel actions → Success or validation error banner.

**Distributor Invoice Creation**  
Header → Customer selector (assigned only) → Product lines with live remaining quantity and max price indicator → Totals (server-calculated) → Submit → Clear success / rejection message.

**Invoice Status List**  
Filterable table: Date, Customer, Amount, Local Status, ZATCA Status, Actions (view detail). Ambiguous and Manual Review rows visually distinct.

**Reconciliation Dashboard**  
Summary cards (open reserved, ambiguous, discrepancies) → Exception table with severity and assignee → Drill-down to quantity equation and matched/unmatched Odoo moves.

## 8.3 Branding & Accessibility

- Follow existing Eman Bakery visual identity where already defined.
- Sufficient colour contrast for status indicators.
- All critical actions reachable by keyboard.
- Arabic and English labels supported where the business requires them (implementation detail left to the frontend team).

---

# 09 — Non-Functional Requirements

## 9.1 Performance

- Interactive API responses for validation and reservation: target < 2 seconds under normal load.
- Worker processing of a single outbox job: bounded; long-running Odoo calls must not block other jobs beyond configured concurrency limits.

## 9.2 Availability & Resilience

- Operational database and API designed for high availability within the chosen platform’s SLA.
- Worker and queue designed so that a single instance failure does not lose jobs (durable outbox + at-least-once delivery + lease).
- Explicit pause switch that stops new invoice writes without deleting existing jobs.

## 9.3 Scalability

- Designed for the current scale of ~85–90 distributors and multiple daily pickups, with headroom for growth in distributors and concurrent cashiers.
- Concurrency limits on the worker protect both the database and the Odoo API.

## 9.4 Data Retention & Backup

- Operational database: daily backups, retention period defined with the business owner (recommended minimum 180 days for financial records).
- Backup restore must be rehearsed in a non-production environment before go-live.
- Audit logs retained according to Saudi commercial and tax record-keeping requirements (confirm with advisor).

## 9.5 Observability

- Structured logs containing job_id, correlation_id, distributor_id (where appropriate), attempt number, and state transition.
- Metrics: queue depth/age, ambiguous job count, reconciliation discrepancy count, worker error rate.
- Alerts on backlog growth, rising ambiguous count, and multi-match references.

## 9.6 Compliance & Audit

- Complete audit trail for every quantity and monetary movement.
- Ability to reconstruct the quantity equation for any historical cycle.
- Support for finance and external audit requests without granting unnecessary write access.

---

# 10 — Test Strategy

## 10.1 Mandatory Proof Tests (Must Pass Before Production)

**Concurrency**
- Two concurrent transactions attempt to reserve the final unit → exactly one commits.
- Multi-line invoice locks products in stable order; no deadlock under parallel load.
- First sale of a new (distributor, product, cycle) is safe under concurrency.

**Idempotency & Timeout**
- Simulated timeout after Odoo has committed → job becomes ambiguous; quantity held; subsequent search finds the move and repairs the pointer; no second create.
- Duplicate queue delivery of the same outbox row is a no-op.
- Multi-match on reference → job moves to manual review; no automatic action.

**Business Rules**
- Unit price = maximum accepted; maximum + 0.01 rejected inside the transaction; no outbox written.
- Unassigned customer rejected even when quantity remains.
- Requested (unconfirmed) dispatch does not increase availability.
- Void of reserved (never submitted) restores quantity once. Cleared identity requires credit note.

**Cycle**
- Close-of-cycle refuses new sales, writes explicit write-off, leaves ambiguous rows.
- 23:30 and 00:30 Riyadh correctly assign cycle_date.

**Security**
- Distributor A cannot read or mutate Distributor B’s data via any API path.
- Service-role and Odoo credentials never appear in client bundles or logs.

## 10.2 Release Gates

Do not declare the system production-ready until:
- All critical tests above pass with recorded evidence.
- Live Odoo workflow (create → status → clearance) is demonstrated in a non-production database, including the timeout-after-create path.
- Reconciliation and manual-review runbooks are exercised.
- RLS and server-side authorisation tests pass for every role.
- Database backup and restore are rehearsed.
- Monitoring and alert ownership are assigned.
- Finance / business owner has signed off on quantity equation, price rules, and ledger semantics.
- A documented rollback plan and invoice-issuance stop-switch exist.

---

# 11 — Deployment Strategy

## 11.1 Environments

- Development  
- Staging (with non-production Odoo database or controlled test method)  
- Production  

## 11.2 Milestone Order (Binding)

1. Invariants, Riyadh cycle clock, threat model, role matrix.  
2. Master data + confirmed dispatch documents.  
3. Cycle balance ledger with locks + local reserved invoice (no Odoo).  
4. Transactional outbox + durable worker against non-production Odoo, including full ambiguous path.  
5. ZATCA clearance states via Odoo Saudi localisation.  
6. Company→Distributor non-VAT settlement.  
7. Close-of-cycle job + daily reconciliation + operator exception queue.

Later milestones may be stubbed; earlier ones may not be skipped.

## 11.3 Rollout Approach

- Pilot with a limited set of distributors after all proof tests pass.
- Invoice-issuance stop-switch available at all times.
- Full production cut-over only after pilot stability and finance sign-off.

---

# 12 — AI Agent Development Instructions

## 12.1 Binding Rules for Every Coding Agent

1. Treat this Master Solution Architecture Package as the single source of truth.  
2. Never weaken any of the seven business invariants.  
3. Never call Odoo inside a database transaction that holds a balance lock.  
4. Never create a second Odoo invoice because of a timeout; always search first.  
5. Never release quantity from an ambiguous or cleared identity except through the explicitly defined safe paths.  
6. All Odoo model, field, and method names remain UNVERIFIED until confirmed on the live instance `/doc` page.  
7. Implement only the currently approved milestone. Produce the required proof tests before requesting approval to proceed.  
8. Report exact files changed, migration impact, test results, and remaining blockers after every change set.  
9. Do not invent account codes, journal configurations, or ZATCA element names.  
10. Do not place secrets in source control, client code, logs, or chat.

## 12.2 Recommended Agent Context Prompt (Copy-Paste Ready)

```text
SYSTEM: You are implementing the Eman Bakery operational platform (Jeddah wholesale bread).

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

## 12.3 Residual Blockers (Must Be Closed Before Tax-Invoice Issuance)

1. Explicit handling of the first-balance-row creation race (advisory lock or create-on-dispatch-confirm).  
2. Worker ownership of uniqueness because the searchable Odoo reference field is not guaranteed unique on Odoo Online.  
3. Confirmation of exact Odoo field names, create payload shape, and ZATCA status values from the live instance `/doc` page.  
4. Tax-advisor sign-off on the non-VAT settlement journal treatment.

---

**End of Master Solution Architecture Package**

This document is the complete, world-class source of truth for the Eman Bakery system. It is intentionally structured so that AI coding agents, human engineers, and business stakeholders can work from a single coherent description with minimal ambiguity and maximum consistency with the original business intent and enterprise invariants.
