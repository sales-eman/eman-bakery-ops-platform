// Install @electric-sql/pglite in an isolated directory and pass that directory.
// Never connects to Supabase or another remote database.
import { createRequire } from 'node:module';
import { resolve } from 'node:path';
import { readFile } from 'node:fs/promises';
if (!process.argv[2]) throw new Error('Usage: node supabase/tests/run-local.mjs <pglite-install-directory>');
const require = createRequire(resolve(process.argv[2], 'package.json'));
const { PGlite } = require('@electric-sql/pglite');
const db = new PGlite();
try {
  // Minimal auth interface for testing policies; this is NOT deployed SQL.
  await db.exec(`
    create role anon nologin;
    create role authenticated nologin;
    create role service_role nologin bypassrls;
    create schema auth;
    create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
    $$;
    grant usage on schema auth,public to anon,authenticated,service_role;
    grant execute on function auth.uid() to anon,authenticated,service_role;
  `);
  await db.exec(await readFile(new URL('../migrations/20261029000100_master_data_and_rls.sql', import.meta.url), 'utf8'));
  console.log('PASS migration executes on fresh local PostgreSQL runtime');
  await db.exec(await readFile(new URL('./master_data_rls.sql', import.meta.url), 'utf8'));
  console.log('PASS distributor isolation, catalog scoping, forged metadata, unmapped/deactivated/anonymous access, write privileges, numeric and relational constraints');
} finally {
  await db.close();
}
