-- Milestone 02: master data and read isolation only.
-- Apply with an administrative migration connection to the DEVELOPMENT project.
-- No dispatch confirmation, balance mutation RPC, reservations, invoices or outbox.
begin;

-- Membership is provisioned by trusted administration, never by browser metadata.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated, service_role;

create table public.products (
  id uuid primary key default gen_random_uuid(),
  sku text not null unique check (btrim(sku) <> ''),
  name text not null check (btrim(name) <> ''),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.distributors (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (btrim(code) <> ''),
  name text not null check (btrim(name) <> ''),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table private.distributor_users (
  user_id uuid primary key references auth.users(id),
  distributor_id uuid not null references public.distributors(id),
  created_at timestamptz not null default now()
);
create index distributor_users_distributor_idx on private.distributor_users(distributor_id);
alter table private.distributor_users enable row level security;
-- No client grants or policies on the membership table.
revoke all on private.distributor_users from public, anon, authenticated;
grant select, insert, update, delete on private.distributor_users to service_role;

-- The function owner is the administrative migration role. Fixed search_path and
-- a fully qualified lookup prevent object substitution. It exposes only the
-- caller's own mapping. auth.uid() derives from the verified Supabase JWT subject.
create function private.current_distributor_id()
returns uuid
language sql stable security definer
set search_path = ''
as $$
  select du.distributor_id
  from private.distributor_users as du
  join public.distributors as d on d.id = du.distributor_id
  where du.user_id = (select auth.uid()) and d.active
$$;
revoke all on function private.current_distributor_id() from public, anon, authenticated;
grant execute on function private.current_distributor_id() to authenticated, service_role;

create table public.b2b_customers (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (btrim(code) <> ''),
  legal_name text not null check (btrim(legal_name) <> ''),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.distributor_customer_assignments (
  distributor_id uuid not null references public.distributors(id),
  customer_id uuid not null references public.b2b_customers(id),
  created_at timestamptz not null default now(),
  primary key (distributor_id, customer_id)
);
create index assignments_customer_idx on public.distributor_customer_assignments(customer_id);

create table public.distributor_product_prices (
  id uuid primary key default gen_random_uuid(),
  distributor_id uuid not null references public.distributors(id),
  product_id uuid not null references public.products(id),
  transfer_unit_price numeric not null
    check (transfer_unit_price >= 0 and transfer_unit_price < 'Infinity'::numeric),
  effective_from date not null,
  effective_until date,
  created_at timestamptz not null default now(),
  unique (distributor_id, product_id, effective_from),
  check (effective_until is null or effective_until > effective_from)
);
create index product_prices_product_idx on public.distributor_product_prices(product_id);

create table public.distributor_resale_price_rules (
  id uuid primary key default gen_random_uuid(),
  -- NULL is a company-wide product cap; non-NULL is a distributor-specific cap.
  distributor_id uuid references public.distributors(id),
  product_id uuid not null references public.products(id),
  max_resale_price numeric not null
    check (max_resale_price >= 0 and max_resale_price < 'Infinity'::numeric),
  effective_from date not null,
  effective_until date,
  created_at timestamptz not null default now(),
  check (effective_until is null or effective_until > effective_from)
);
create unique index resale_rules_distributor_start_idx
  on public.distributor_resale_price_rules(distributor_id, product_id, effective_from)
  where distributor_id is not null;
create unique index resale_rules_global_start_idx
  on public.distributor_resale_price_rules(product_id, effective_from)
  where distributor_id is null;

create table public.dispatches (
  id uuid primary key default gen_random_uuid(),
  distributor_id uuid not null references public.distributors(id),
  -- Explicit Asia/Riyadh civil date; no UTC-server CURRENT_DATE default.
  cycle_date date not null,
  status text not null default 'draft' check (status in ('draft', 'confirmed', 'cancelled')),
  reference text,
  notes text,
  created_by uuid not null references auth.users(id),
  confirmed_by uuid references auth.users(id),
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  check ((status = 'confirmed' and confirmed_at is not null and confirmed_by is not null)
    or (status <> 'confirmed' and confirmed_at is null and confirmed_by is null))
);
create index dispatches_distributor_cycle_idx on public.dispatches(distributor_id, cycle_date);

create table public.dispatch_lines (
  id uuid primary key default gen_random_uuid(),
  dispatch_id uuid not null references public.dispatches(id),
  product_id uuid not null references public.products(id),
  requested_qty numeric not null check (requested_qty > 0 and requested_qty < 'Infinity'::numeric),
  confirmed_qty numeric not null default 0 check (confirmed_qty >= 0 and confirmed_qty < 'Infinity'::numeric),
  transfer_unit_price numeric not null check (transfer_unit_price >= 0 and transfer_unit_price < 'Infinity'::numeric),
  created_at timestamptz not null default now(),
  unique (dispatch_id, product_id)
);
create index dispatch_lines_product_idx on public.dispatch_lines(product_id);

create table public.cycle_balance (
  distributor_id uuid not null references public.distributors(id),
  product_id uuid not null references public.products(id),
  cycle_date date not null,
  available_qty numeric not null default 0
    check (available_qty >= 0 and available_qty < 'Infinity'::numeric),
  max_resale_price numeric not null
    check (max_resale_price >= 0 and max_resale_price < 'Infinity'::numeric),
  created_at timestamptz not null default now(),
  primary key (distributor_id, product_id, cycle_date)
);
create index cycle_balance_product_idx on public.cycle_balance(product_id);

comment on column public.cycle_balance.cycle_date is 'Asia/Riyadh civil date, explicitly supplied by trusted server logic.';
comment on table public.cycle_balance is 'Locked projection. Future writes must use one transaction and row/advisory locks. Unconfirmed dispatches never increase availability. No mutation workflow is implemented in Milestone 02.';
comment on table public.distributor_product_prices is 'Effective dates use half-open intervals [effective_from, effective_until). Trusted writes must reject overlapping applicable intervals.';
comment on table public.distributor_resale_price_rules is 'Half-open effective intervals. Future trusted price administration must prevent overlaps and define global/specific cap precedence before reservation implementation.';

-- Revoke Supabase's possible default table privileges explicitly. Browsers receive
-- SELECT only; there are no INSERT/UPDATE/DELETE policies or mutation functions.
alter table public.products enable row level security;
alter table public.products force row level security;
revoke all on public.products from public, anon, authenticated;
grant select on public.products to authenticated;
grant select, insert, update, delete on public.products to service_role;

alter table public.distributors enable row level security;
alter table public.distributors force row level security;
revoke all on public.distributors from public, anon, authenticated;
grant select on public.distributors to authenticated;
grant select, insert, update, delete on public.distributors to service_role;

alter table public.b2b_customers enable row level security;
alter table public.b2b_customers force row level security;
revoke all on public.b2b_customers from public, anon, authenticated;
grant select on public.b2b_customers to authenticated;
grant select, insert, update, delete on public.b2b_customers to service_role;

alter table public.distributor_customer_assignments enable row level security;
alter table public.distributor_customer_assignments force row level security;
revoke all on public.distributor_customer_assignments from public, anon, authenticated;
grant select on public.distributor_customer_assignments to authenticated;
grant select, insert, update, delete on public.distributor_customer_assignments to service_role;

alter table public.distributor_product_prices enable row level security;
alter table public.distributor_product_prices force row level security;
revoke all on public.distributor_product_prices from public, anon, authenticated;
grant select on public.distributor_product_prices to authenticated;
grant select, insert, update, delete on public.distributor_product_prices to service_role;

alter table public.distributor_resale_price_rules enable row level security;
alter table public.distributor_resale_price_rules force row level security;
revoke all on public.distributor_resale_price_rules from public, anon, authenticated;
grant select on public.distributor_resale_price_rules to authenticated;
grant select, insert, update, delete on public.distributor_resale_price_rules to service_role;

alter table public.dispatches enable row level security;
alter table public.dispatches force row level security;
revoke all on public.dispatches from public, anon, authenticated;
grant select on public.dispatches to authenticated;
grant select, insert, update, delete on public.dispatches to service_role;

alter table public.dispatch_lines enable row level security;
alter table public.dispatch_lines force row level security;
revoke all on public.dispatch_lines from public, anon, authenticated;
grant select on public.dispatch_lines to authenticated;
grant select, insert, update, delete on public.dispatch_lines to service_role;

alter table public.cycle_balance enable row level security;
alter table public.cycle_balance force row level security;
revoke all on public.cycle_balance from public, anon, authenticated;
grant select on public.cycle_balance to authenticated;
grant select, insert, update, delete on public.cycle_balance to service_role;

create policy distributor_self_read on public.distributors
  for select to authenticated
  using (id = (select private.current_distributor_id()));

create policy assignments_own_read on public.distributor_customer_assignments
  for select to authenticated
  using (distributor_id = (select private.current_distributor_id()));

create policy customers_assigned_read on public.b2b_customers
  for select to authenticated
  using (exists (
    select 1 from public.distributor_customer_assignments as a
    where a.customer_id = b2b_customers.id
      and a.distributor_id = (select private.current_distributor_id())
  ));

create policy transfer_prices_own_read on public.distributor_product_prices
  for select to authenticated
  using (distributor_id = (select private.current_distributor_id()));

create policy dispatches_own_read on public.dispatches
  for select to authenticated
  using (distributor_id = (select private.current_distributor_id()));

create policy dispatch_lines_own_read on public.dispatch_lines
  for select to authenticated
  using (exists (
    select 1 from public.dispatches as d
    where d.id = dispatch_lines.dispatch_id
      and d.distributor_id = (select private.current_distributor_id())
  ));

create policy balances_own_read on public.cycle_balance
  for select to authenticated
  using (distributor_id = (select private.current_distributor_id()));

-- Shared catalog records are visible only when linked to the caller's own
-- price matrix, dispatch history or cycle balance. Other catalog rows stay hidden.
create policy products_assigned_read on public.products
  for select to authenticated
  using (
    exists (select 1 from public.distributor_product_prices as p
      where p.product_id = products.id and p.distributor_id = (select private.current_distributor_id()))
    or exists (select 1 from public.cycle_balance as b
      where b.product_id = products.id and b.distributor_id = (select private.current_distributor_id()))
    or exists (select 1 from public.dispatch_lines as l
      join public.dispatches as d on d.id = l.dispatch_id
      where l.product_id = products.id and d.distributor_id = (select private.current_distributor_id()))
  );

create policy resale_rules_applicable_read on public.distributor_resale_price_rules
  for select to authenticated
  using (
    distributor_id = (select private.current_distributor_id())
    or (distributor_id is null and exists (
      select 1 from public.products as p where p.id = distributor_resale_price_rules.product_id
    ))
  );

commit;
