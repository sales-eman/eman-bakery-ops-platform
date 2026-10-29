# Prompt 05 — Transactional outbox, no Odoo

Extend the reservation transaction so the same commit inserts an outbox row.

- `idempotency_key` is deterministic and unique in Postgres.
- If the reservation rolls back, no outbox row remains.
- A publisher may run only after commit.
- The worker may log or mark `pending`. It must not call Odoo.
- Timeouts are not implemented against Odoo yet. Do not add a second-create path.

Run the build, redeploy the preview, and stop. The next milestone requires a non-production Odoo database and is not authorised by this prompt.
