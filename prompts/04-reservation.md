# Prompt 04 — Local reservation

Implement B2B invoice submission up to local reservation only.

Inside one database transaction:

- Reject a customer who is not assigned to the distributor.
- Lock `cycle_balance` for each line, in a stable product order.
- If the balance row does not exist, do not pretend `FOR UPDATE` locked it. Use the dispatch-created row or a transaction-scoped advisory lock.
- Reject when quantity exceeds availability or unit price exceeds the maximum stored for that row.
- Insert the sale with status `reserved`.
- Do not insert an outbox row yet.
- Do not call Odoo.
- Do not hold the lock across any network call.

Add a test or script note showing two concurrent reservations of the last unit cannot both commit. Run the build, redeploy the preview, and stop.
