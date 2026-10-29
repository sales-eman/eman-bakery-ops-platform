# Agent instructions — Eman Bakery

Read `docs/Eman_Bakery_Master_Solution_Architecture_Package.md` before changing anything. It overrides convenience.

## Scope control

Implement only the milestone named in the current prompt under `prompts/`. Do not start Odoo calls, Cloud Tasks, or production deployment because a later section of the architecture mentions them.

## Forbidden

- Calling Odoo, or any other network service, inside the transaction that locks `cycle_balance`.
- Creating a second invoice after a timeout. Search by the idempotency key first. If the outcome is unknown, set `ambiguous` and hold quantity.
- Treating requested (unconfirmed) pickups as available quantity.
- Carrying unsold quantity into the next business day.
- Issuing a tax invoice on the company-to-distributor leg.
- Putting the distributor’s name as the seller on the B2B tax invoice.
- Inventing Odoo model names, journal codes, or ZATCA element names. Mark them UNVERIFIED until read from the live database `/doc` page.
- Committing secrets.

## Required when quantity or price changes

One database transaction must:

1. Lock the balance row for `(distributor_id, product_id, cycle_date)`, or take a transaction-scoped advisory lock if that row does not exist yet.
2. Re-read the maximum resale price inside that transaction.
3. Reject the whole transaction if quantity is insufficient or price is above the maximum.
4. Insert the reserved sale and, once the outbox milestone is approved, the outbox row with a unique idempotency key.
5. Commit. Only then may a publisher enqueue work.

`cycle_date` is the civil date in `Asia/Riyadh`, not the UTC date of the database server.

## Money and quantity

Use exact numeric types. Never use binary floating point for money or quantity.
