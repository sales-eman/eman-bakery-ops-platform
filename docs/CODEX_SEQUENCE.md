# Codex sequence

Use one prompt at a time from `prompts/`. Attach or point Codex at this repository. Require a preview URL only after the local build succeeds. Do not ask for a production deployment.

## Already completed without Codex

| Step | Status |
|---|---|
| Private GitHub repository | Done: `sales-eman/eman-bakery-ops-platform` |
| Architecture package in the repository | Done: `docs/` |
| Stack decision | Done: `docs/STACK_DECISION.md` |
| Agent rules so later sessions do not skip invariants | Done: `AGENTS.md` |

## Still required from the owner before Codex writes the database

1. Create a **development** Supabase project. Do not paste the service-role key into chat. Add it later as a Vercel/Supabase secret.
2. Create a Vercel project and import this GitHub repository. Leave production deployment off.
3. In Codex, connect the repository and enable the Build Web Apps and Vercel plugins.

## Then send prompts in this order

| Order | File | Codex may do | Codex must not do |
|---|---|---|---|
| 1 | `prompts/01-scaffold.md` | Next.js app shell, roles as UI only, navigation | Business writes, Odoo, secrets |
| 2 | `prompts/02-schema.md` | Migrations matching the architecture, RLS | Odoo columns as if verified |
| 3 | `prompts/03-dispatch.md` | Idempotent confirmed dispatch and balance increase | Resale invoices |
| 4 | `prompts/04-reservation.md` | Locked reservation, max price, assigned customer | Outbox, Odoo |
| 5 | `prompts/05-outbox.md` | Outbox row in the same transaction | Live Odoo calls |
| 6 | Later, not written yet | Non-production Odoo worker on Cloud Run | Production tax invoices |

Stop after each prompt. Review the diff before sending the next one.

## Hosting reminder

Codex deploys the **website preview** with Vercel. ChatGPT has no separate host that replaces Vercel, Supabase, or the Cloud Run worker. See `docs/STACK_DECISION.md`.
