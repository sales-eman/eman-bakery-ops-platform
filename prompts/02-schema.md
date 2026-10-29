# Prompt 02 — Schema and RLS

Continue in `sales-eman/eman-bakery-ops-platform`. Read `AGENTS.md` and Section 05 of the Master Solution Architecture Package.

Using the development Supabase project only:

- Add migrations for products, distributors, B2B customers, assignments, price rules, dispatches, dispatch lines, and `cycle_balance`.
- `cycle_balance` primary key is `(distributor_id, product_id, cycle_date)`.
- Quantity and money columns are `numeric`.
- Enable RLS. A distributor role may read only its own rows. Privileged writes stay server-side.
- Do not add Odoo invoice tables yet.
- Do not invent a unique constraint inside Odoo.

Show the SQL. Apply it only to the development database. Run the local build, redeploy the Vercel **preview**, and stop.
