# Stack decision

Decision date: 29 October 2026. This records the target, not permission to provision paid resources without the owner’s approval.

## Chosen split

| Concern | Technology | Why |
|---|---|---|
| Web application and request/response API | Next.js on Vercel | Codex’s documented deploy path uses the Vercel plugin. Preview URLs are the default. Production promotion stays explicit. |
| Operational database, auth, row locks, RLS | Supabase Postgres | Transactions, `SELECT … FOR UPDATE`, advisory locks, and row-level security are required. These are not Vercel features. |
| Durable invoice delivery | Cloud Tasks + Cloud Run worker | Vercel request functions are not a durable worker. A timeout or instance recycle must not lose an outbox job or create a second tax invoice. |
| Legal invoice and ZATCA | Odoo Online 19 JSON-2 | Odoo is the legal book. The app does not sign XML itself unless a written exception exists. |

## ChatGPT hosting versus Vercel

ChatGPT and Codex do not provide a general hosting platform that replaces Vercel for this system.

- Codex builds or edits the repository.
- The documented “deploy an app or website” path deploys a **preview** through the **Vercel plugin**.
- ChatGPT does not run the Postgres row locks, the Cloud Tasks queue, or the Odoo worker.
- Skipping Vercel would still require some other host for the Next.js app (Cloud Run, for example). It would not remove the need for Supabase and a durable worker.

Use Vercel for the website and the short request/response API. Do not put the Odoo worker only inside a Vercel serverless function.

## What must not be stored in the repository

- Odoo API keys
- Supabase service-role keys
- Database passwords
- Cloud credentials

Names of required secrets may be documented. Values may not.
