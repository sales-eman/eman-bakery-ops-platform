# Eman Bakery — agent handoff for GitHub account migration

Prepared 29 October 2026 (Asia/Riyadh). This records observed work and the owner's latest instructions; it does not certify a deployment or remote database.

## Start here

The owner imported `sales-eman/eman-bakery-ops-platform` into a new personal GitHub account as a private repository. The new owner/repository URL has not been supplied in this chat. The old repository was temporarily made public for import. Do not assume it was subsequently made private again.

The next agent must use the newly connected repository, verify its actual origin and full history, and read this file, `AGENTS.md`, the complete `docs/Eman_Bakery_Master_Solution_Architecture_Package.md`, `docs/STACK_DECISION.md`, and `docs/CODEX_SEQUENCE.md` before changes. Old repository references in historical documents do not authorize pushing back to the old account. Do not bulk-replace historical references or rewrite history merely to change accounts.

The import occurred BEFORE this handoff commit. A GitHub import is a copy at import time, not an ongoing sync. This handoff and its local SQL test files must be copied into the new repository separately if missing. Verify the files and commits below rather than assuming they transferred. The owner can download/copy this document into the new repository or attach it to the new chat.

## Latest owner instructions — carry forward

- Do not connect to Supabase or Vercel.
- Do not request a database password or Supabase service-role key.
- The owner will run the migration SQL manually in the development Supabase SQL editor.
- Skip Vercel preview while its plugin is not connected. No production deployment.
- Milestones 01 and 02 only have been worked on. Do not begin Milestone 03 without an explicit request.
- Completed work must exist on GitHub when requested; filesystem edits alone are insufficient. For later pushes use only the verified new origin and report the remote commit SHA. Do not push without task authorization.
- No secrets in files, chat, logs, client code, or commits.

These later owner instructions override earlier prompts that asked the agent to apply SQL or deploy a preview. Do not revive those requests automatically after reconnecting an account. Reconnecting GitHub does not itself grant database or deployment authorization.

## Completed work and exact Git history

| Commit | Contents | Remote evidence |
| --- | --- | --- |
| `157d5f1a60306ad9ed7ef0a95623163bc9787db1` | Initial architecture, PRD, agent rules, ordered prompts and comment-only SQL design | Original main before implementation |
| `2c4d02323d0199efab3f0604ac7e6e28ca3febd6` | Milestone 01 Next.js App Router + TypeScript shell | Pushed to old origin/main and verified with `git ls-remote` |
| `b4d02ba912191512eb4af581c7123921447f70f4` | Milestone 02 migration SQL only | Pushed to old origin/main and verified with `git ls-remote` |

This handoff change also preserves `supabase/tests/master_data_rls.sql` and `supabase/tests/run-local.mjs`. These were local validation files, deliberately not included in the migration-only commit. Their first repository inclusion is alongside this handoff. Obtain this handoff commit's SHA from Git history; it cannot embed its own SHA.

No application secrets were added during this work. No Supabase connection, remote SQL execution, Vercel deployment, Odoo request, or production deployment was performed by the agent. The owner has not reported whether they have since applied the SQL.

## Milestone 01 — implemented shell

Pinned runtime dependencies: Next.js `16.4.3`, React and React DOM `19.3.1`. TypeScript and type declarations are locked in `package-lock.json`. Package engines require Node >=20.9; validated tools were Node `24.19.0` and npm `11.9.0`.

Routes:

| Route | Purpose |
| --- | --- |
| `/` | Workspace overview |
| `/company/dispatch` | Company-staff dispatch placeholder |
| `/company/reconciliation` | Company-staff reconciliation placeholder |
| `/distributor/invoices/new` | Distributor B2B invoice placeholder |
| `/distributor/invoices` | Distributor invoice-status placeholder |

Company and distributor navigation groups are visually separate. Active links have `aria-current`, a skip link is provided, and CSS supports narrow screens. All four business action buttons are disabled. Role navigation is a UI preview, NOT implemented authentication or authorization. No database client, server write endpoint, Odoo client, financial calculation, quantity calculation, or live business data is connected.

Files introduced: `app/layout.tsx`, `app/page.tsx`, `app/not-found.tsx`, `app/globals.css`, the four route `page.tsx` files above, `components/navigation.tsx`, `components/placeholder.tsx`, `package.json`, `package-lock.json`, `tsconfig.json`, and `next-env.d.ts`. README development instructions and `.gitignore` were updated. `next-env.d.ts` is generated/maintained by Next.js.

## Milestone 02 — SQL authored, remote application unconfirmed

Authoritative executable SQL:

`supabase/migrations/20261029000100_master_data_and_rls.sql`

It uses a transaction and creates nine public tables:

1. `products`
2. `distributors`
3. `b2b_customers`
4. `distributor_customer_assignments`
5. `distributor_product_prices`
6. `distributor_resale_price_rules`
7. `dispatches`
8. `dispatch_lines`
9. `cycle_balance`

It also creates `private.distributor_users` and `private.current_distributor_id()` for trusted user-to-distributor membership. One user maps to one distributor. Membership must be administered by trusted server/administration; the browser cannot provision it. Unmapped users and users whose distributor is inactive see no rows through these policies.

`cycle_balance` has primary key `(distributor_id, product_id, cycle_date)`. Quantities and prices are exact `numeric` with nonnegative/positive finite-value constraints as appropriate. Business dates are explicit `date` values in Asia/Riyadh with no UTC `CURRENT_DATE` default. Timestamps use `timestamptz`.

RLS is enabled and forced on all nine public tables. Authenticated clients receive SELECT only, with policies limiting distributor records to their own mapping. Customers are visible through assignments. Products are a shared catalog visible only through that distributor's price matrix, dispatch history or cycle balance. Global price caps are visible only for visible products; another distributor's specific caps remain hidden. Anonymous access and browser mutations are denied. `service_role` receives server-side table privileges; this is a privilege declaration, NOT a stored key or an implemented business-write API. The private membership table has RLS and no client table privileges/policies. The helper is SECURITY DEFINER with fixed empty search_path, qualified names, and restricted EXECUTE grants.

Important limits for the next approved milestones:

- No confirmation procedure, balance update procedure, operational ledger, audit movement workflow, sales/reservations, outbox, or Odoo invoice table exists.
- Dispatch headers/lines are schema only. A confirmed status does not automatically update balance. Do not present schema checks as proof of transactional dispatch behavior.
- Price intervals are half-open `[effective_from, effective_until)`. Duplicate start dates and invalid intervals are constrained, but overlapping intervals are not excluded. Trusted future administration must prevent overlaps and define global vs specific cap selection before reservation writes.
- The migration expects Supabase's existing `auth.users`, `auth.uid()`, `anon`, `authenticated`, and `service_role`, and an administrative migration role capable of bypassing RLS for the helper lookup. Verify on development before claiming actual hosted RLS readiness.
- This initial migration is NOT rerunnable after successful application: tables/functions already exist. Before any future authorized remote action, establish whether the owner already applied it. Do not drop/recreate data or reapply blindly.
- Running SQL manually in the editor does not by itself establish Supabase CLI migration-history tracking. Reconcile that history deliberately if a future task adopts CLI deployments; do not assume `db push` knows about the manual application.
- `schema/001_cycle_balance_design.sql` is an older comment-only design reference, NOT the executable migration.

## Validation evidence and practical limits

Passed during this conversation:

- `npm run build`: optimized production build, all routes statically generated. Repeated after the migration was added.
- `npm run typecheck`: TypeScript passed for the shell.
- `git diff --check`: passed.
- Local requests against `npm start -- --hostname 127.0.0.1`: all five routes returned HTTP 200 with expected rendered text and navigation; exactly the current route marked active; four placeholder actions disabled; unknown path returned custom 404.
- Migration executed successfully in PGlite `0.5.13` (a local PostgreSQL runtime), with a minimal Supabase auth/role test bootstrap.
- SQL tests passed: A/B distributor isolation across all nine tables, scoped global/shared data, spoofed user_metadata ignored, unmapped/missing-subject/deactivated users denied, anonymous reads denied, browser INSERT/UPDATE/DELETE denied and no write grants, service-role writes permitted, exact decimals, unconfirmed pickups do not credit balance, invalid/nonfinite quantities rejected, duplicate cycle key rejected, foreign keys and effective interval constraints enforced.

This is local evidence only. It is NOT a test on the owner's development Supabase project, a full Supabase integration suite, a browser visual inspection, a concurrency proof, an Odoo/ZATCA validation, or a deployment. No remote database application or preview URL is confirmed.

## Reproduce locally in the new environment

Use the existing checkout; cloud tasks are already isolated. Do not create a Git worktree unless the owner asks. Inspect `git status --short` before changing files and preserve user work.

From the repository root:

```sh
npm ci
npm run build
npm run typecheck
npm run dev
```

Use `npm start -- --hostname 127.0.0.1` after a build to validate the production server instead of the dev server. Live processes do not transfer with a repository import or environment snapshot. No application environment variables are required for the present shell.

To reproduce the isolated SQL checks, install the test runtime OUTSIDE the repository (no package.json/lockfile changes required):

```sh
npm install --prefix /tmp/eman-schema-validation --no-fund --no-audit @electric-sql/pglite@0.5.13
node supabase/tests/run-local.mjs /tmp/eman-schema-validation
```

The Node runner creates an ephemeral local database, emulates the minimal Supabase auth interface, executes the migration, runs the transactional fixture assertions, and closes the database. It never connects to a remote service. The SQL test file is for a disposable local test database, not for pasting into the owner's live Supabase editor.

In the previous cloud environment the shell sandbox needed supported command escalation for npm network access, Next.js subprocesses, binding the local server, and local HTTP checks. Preserve injected proxy settings, TLS verification, and Git authentication; do not bypass networking or request replacement GitHub tokens merely because a raw token is absent. Read the environment runtime skill and current network policy in the new environment. Do not carry over runtime IDs, proxy credentials or environment assumptions.

## Environment and integration transfer

The previous session saved an onboarding `install_script` (`npm ci --no-fund --no-audit` then `npm run build`) and `start_skill` with repository startup/check instructions. Those configuration drafts are separate from Git. They were saved, but publication and successful restoration of those edits were not confirmed. One replacement environment restored the old documentation-only checkout, requiring recreation of the shell; the owner then explicitly requested and received verified Git pushes. Use Git contents and current runtime evidence, not earlier claims about a prepared snapshot.

No Build Web Apps, Supabase, or Vercel tools were available. Vercel token, project identifiers and CLI login files were absent when checked. Availability must be checked afresh, but the owner's prohibition on connecting remains until explicitly changed. Do not ask for database credentials. New GitHub authorization, repository access, Vercel linkage and cloud environment settings are separate concerns and do not automatically migrate together.

## What to do next

1. Verify the imported checkout contains `package.json`, the four pages, the migration, this handoff and the two SQL test files. If it ends at the scaffold commit, copy the migration from the old repository/owner-provided file. If it predates the scaffold, obtain those files too. Do not invent missing work from commit hashes alone.
2. Confirm the actual new GitHub origin and use only that repository for future authorized pushes. Keep the new repository private as requested. The old repository visibility is for the owner to manage; it was not changed by the agent.
3. Run the local build and SQL checks as needed to verify the new machine. This needs no Supabase/Vercel connection or secret values.
4. Ask only for the next desired milestone or, when relevant, the owner's non-secret SQL execution result. Do not assume the owner ran the migration successfully.
5. On explicit Milestone 03 approval, follow `prompts/03-dispatch.md`: implement idempotent confirmation, the balance update and non-VAT operational ledger charge in ONE transaction, plus required audit evidence and concurrency tests. Do not implement B2B invoices, reservations, outbox, Odoo or production deployment as part of that milestone. Resolve prerequisites rather than pretending the current schema already implements them.

## Business invariants to preserve

- Availability comes only from confirmed dispatches for the current Riyadh day; unsold quantity never carries to the next day.
- Quantity and maximum-price decisions occur under row/advisory locks inside one transaction; no binary floating point for money or quantity.
- Never make network/Odoo calls while holding balance locks. Lock multiple products in stable order.
- Company-to-distributor is a non-VAT operational ledger leg. Customer tax invoices must be in Eman Bakery's name with margin included.
- Odoo is the future legal book/ZATCA engine. No second invoice after a timeout; search first, ambiguous outcomes retain quantity. No invented Odoo fields, unique constraints, journal codes or ZATCA elements.
- Implement one explicitly requested milestone at a time. Report code state, database state, GitHub state and deployment state separately.

## Suggested first message in the new chat

> Continue this Eman Bakery project in the currently connected private repository. Read docs/AGENT_HANDOFF.md, AGENTS.md, and the Master Solution Architecture Package first. Verify the imported repository contains the scaffold and supabase/migrations/20261029000100_master_data_and_rls.sql. Do not connect to Supabase or Vercel, request database credentials, deploy production, or start a later milestone. First report which handoff files and commits are present and whether the local build passes. Use this new repository for any future authorized pushes. I will tell you the next milestone and whether I applied the development SQL manually.
