# Prompt 01 — Scaffold only

Use @build-web-apps on the repository `sales-eman/eman-bakery-ops-platform`.

Read `AGENTS.md` and `docs/Eman_Bakery_Master_Solution_Architecture_Package.md` before editing. Obey them.

Build a Next.js App Router + TypeScript application shell only.

Include:

- A company-staff area with placeholder pages: Dispatch confirmation, Reconciliation.
- A distributor area with placeholder pages: Create B2B invoice, Invoice status.
- Navigation that keeps those two areas visually separate.
- No database writes.
- No Supabase service-role key.
- No Odoo client.
- No quantity or price calculations that pretend to be authoritative.

After the code is in place, run the local production build. Then use @vercel to deploy a **preview** (not production) and return the preview URL, the build command, and the files changed.

Stop. Do not start the schema.
