# Eman Bakery operational platform

Private source repository for the Jeddah wholesale bread system: daily dispatch, distributor price matrices, server-side quantity and maximum resale-price caps, a non-VAT company-to-distributor ledger, and ZATCA Phase 2 tax invoices issued in Eman Bakery’s name through Odoo Online 19.

This repository currently holds the source-of-truth documentation and the ordered Codex prompts. Application code is not started yet. Do not treat an empty preview as a working ledger.

## Read first

1. [docs/Eman_Bakery_Master_Solution_Architecture_Package.md](docs/Eman_Bakery_Master_Solution_Architecture_Package.md) — binding source of truth.
2. [docs/STACK_DECISION.md](docs/STACK_DECISION.md) — what is hosted where, and why Vercel is not optional for the web app.
3. [docs/CODEX_SEQUENCE.md](docs/CODEX_SEQUENCE.md) — what Codex may implement, and what it must not implement yet.
4. [prompts/](prompts/) — one prompt per milestone. Send only the current prompt.

## What is already done

- GitHub repository created and kept private.
- Architecture package and enterprise PRD committed.
- Stack decision recorded.
- Codex prompt sequence committed so the agent is not given the whole system at once.

## What a person still has to create

These cannot be created from this repository alone:

- A Supabase project (development first, then staging and production).
- A Vercel project linked to this repository, used for preview deployments only until a later go-live decision.
- An Odoo Online 19 non-production database and a least-privilege API key, stored in a secret manager, never in git.
- A Cloud Tasks queue and Cloud Run worker when the outbox milestone starts. That worker is not a Vercel function.

## Non-negotiable rules

- No warehouse stock. Availability comes only from confirmed dispatches on the Asia/Riyadh cycle.
- Quantity and maximum resale price are enforced inside one database transaction that locks the balance.
- Company to distributor is a non-VAT ledger settlement. The only tax invoice is the B2B invoice in Eman Bakery’s name, margin included.
- A timeout must never create a second Odoo invoice. Search first. Timeouts stay ambiguous and continue to hold quantity.
- Do not call Odoo while a balance-row lock is held.
