# Prompt 03 — Confirm dispatch

Continue in the same repository. Implement dispatch confirmation only.

Rules:

- A dispatch increases availability only when it is confirmed.
- Confirmation is idempotent: repeating it does not add quantity or a ledger charge twice.
- The balance update and the operational ledger charge commit in one database transaction.
- `cycle_date` is the Asia/Riyadh civil date.
- Requested but unconfirmed pickups do not increase availability.

Do not implement B2B invoices. Run the build, redeploy the preview, and stop.
