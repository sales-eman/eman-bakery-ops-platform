-- Run ONLY in a disposable local database after the migration. Fixtures roll back.
-- Requires Supabase auth.uid(), auth.users and API roles; local harness emulates them.
begin;
insert into auth.users(id) values
 ('10000000-0000-0000-0000-000000000001'),
 ('10000000-0000-0000-0000-000000000002'),
 ('10000000-0000-0000-0000-000000000003');
insert into public.distributors(id,code,name) values
 ('20000000-0000-0000-0000-000000000001','A','Distributor A'),
 ('20000000-0000-0000-0000-000000000002','B','Distributor B');
insert into private.distributor_users(user_id,distributor_id) values
 ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),
 ('10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002');
insert into public.products(id,sku,name) values
 ('30000000-0000-0000-0000-000000000001','A','Product A'),
 ('30000000-0000-0000-0000-000000000002','B','Product B'),
 ('30000000-0000-0000-0000-000000000003','NONE','Unassigned product');
insert into public.b2b_customers(id,code,legal_name) values
 ('40000000-0000-0000-0000-000000000001','A','Customer A'),
 ('40000000-0000-0000-0000-000000000002','B','Customer B');
insert into public.distributor_customer_assignments(distributor_id,customer_id)
 select d.id,c.id from public.distributors d join public.b2b_customers c on c.code=d.code;
insert into public.distributor_product_prices(distributor_id,product_id,transfer_unit_price,effective_from)
 select d.id,p.id,0.10,'2026-10-29' from public.distributors d join public.products p on p.sku=d.code;
insert into public.distributor_resale_price_rules(distributor_id,product_id,max_resale_price,effective_from)
 select d.id,p.id,0.30,'2026-10-29' from public.distributors d join public.products p on p.sku=d.code;
insert into public.distributor_resale_price_rules(product_id,max_resale_price,effective_from)
 select id,0.40,'2026-10-29' from public.products;
insert into public.dispatches(id,distributor_id,cycle_date,created_by)
 select d.id,d.id,'2026-10-29',u.user_id from public.distributors d join private.distributor_users u on u.distributor_id=d.id;
insert into public.dispatch_lines(dispatch_id,product_id,requested_qty,transfer_unit_price)
 select d.id,p.id,1.25,0.10 from public.distributors d join public.products p on p.sku=d.code;
insert into public.cycle_balance(distributor_id,product_id,cycle_date,max_resale_price)
 select d.id,p.id,'2026-10-29',0.30 from public.distributors d join public.products p on p.sku=d.code;

-- Assertions execute with caller privileges, not SECURITY DEFINER.
create function pg_temp.assert_count(table_name text, expected bigint) returns void
language plpgsql as $$
declare actual bigint;
begin
 execute format('select count(*) from public.%I',table_name) into actual;
 if actual <> expected then raise exception '%: expected %, got %',table_name,expected,actual; end if;
end $$;
create function pg_temp.assert_no_writes(table_name text) returns void
language plpgsql as $$
begin
 if has_table_privilege(current_user,'public.'||table_name,'INSERT')
 or has_table_privilege(current_user,'public.'||table_name,'UPDATE')
 or has_table_privilege(current_user,'public.'||table_name,'DELETE')
 or has_table_privilege(current_user,'public.'||table_name,'TRUNCATE') then
 raise exception 'Browser write privilege on %',table_name; end if;
end $$;

set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
-- A forged distributor in user_metadata must not change membership.
select set_config('request.jwt.claims','{"user_metadata":{"distributor_id":"20000000-0000-0000-0000-000000000002"}}',true);
select pg_temp.assert_count(t,1) from unnest(array['products','distributors','b2b_customers',
 'distributor_customer_assignments','distributor_product_prices','dispatches','dispatch_lines','cycle_balance']) t;
select pg_temp.assert_count('distributor_resale_price_rules',2);
do $$ begin
 if exists(select 1 from public.distributors where code='B') then raise exception 'A can read B'; end if;
 if (select private.current_distributor_id()) <> '20000000-0000-0000-0000-000000000001'::uuid then raise exception 'Forged membership'; end if;
 if has_table_privilege(current_user,'private.distributor_users','SELECT') then raise exception 'Membership exposed'; end if;
 begin
  insert into public.distributors(code,name) values ('FORGED','Forged');
  raise exception 'Browser INSERT succeeded';
 exception when insufficient_privilege then null; end;
 begin
  update public.cycle_balance set available_qty=999;
  raise exception 'Browser UPDATE succeeded';
 exception when insufficient_privilege then null; end;
 begin
  delete from public.dispatches;
  raise exception 'Browser DELETE succeeded';
 exception when insufficient_privilege then null; end;
end $$;
select pg_temp.assert_no_writes(t) from unnest(array['products','distributors','b2b_customers',
 'distributor_customer_assignments','distributor_product_prices','distributor_resale_price_rules',
 'dispatches','dispatch_lines','cycle_balance']) t;

select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
select pg_temp.assert_count(t,1) from unnest(array['products','distributors','b2b_customers',
 'distributor_customer_assignments','distributor_product_prices','dispatches','dispatch_lines','cycle_balance']) t;
select pg_temp.assert_count('distributor_resale_price_rules',2);
do $$ begin
 if exists(select 1 from public.distributors where code='A') then raise exception 'B can read A'; end if;
end $$;

-- Unmapped authenticated user and missing subject have no row visibility.
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000003',true);
select pg_temp.assert_count(t,0) from unnest(array['products','distributors','b2b_customers',
 'distributor_customer_assignments','distributor_product_prices','distributor_resale_price_rules',
 'dispatches','dispatch_lines','cycle_balance']) t;
select set_config('request.jwt.claim.sub','',true);
select pg_temp.assert_count('products',0);

reset role;
-- Removing membership access by deactivating the distributor takes effect immediately.
update public.distributors set active=false where code='A';
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
select pg_temp.assert_count(t,0) from unnest(array['products','distributors','b2b_customers',
 'distributor_customer_assignments','distributor_product_prices','distributor_resale_price_rules',
 'dispatches','dispatch_lines','cycle_balance']) t;

set local role anon;
do $$ begin
 begin
  perform * from public.products;
  raise exception 'Anonymous SELECT succeeded';
 exception when insufficient_privilege then null; end;
end $$;

set local role service_role;
select pg_temp.assert_count('distributors',2);
insert into public.products(sku,name) values ('SERVICE','Server-only write');
reset role;

do $$
declare bad text;
begin
 -- Exact decimal preservation, no availability credited for requested dispatches.
 if (select sum(transfer_unit_price) from public.distributor_product_prices) <> 0.20::numeric then raise exception 'Decimal mismatch'; end if;
 if exists(select 1 from public.cycle_balance where available_qty<>0) then raise exception 'Draft dispatch credited'; end if;
 foreach bad in array array['-1','NaN','Infinity','-Infinity'] loop
  begin
   update public.cycle_balance set available_qty=bad::numeric;
   raise exception 'Invalid quantity accepted: %',bad;
  exception when check_violation then null; end;
 end loop;
 begin
  insert into public.cycle_balance select * from public.cycle_balance limit 1;
  raise exception 'Duplicate cycle key accepted';
 exception when unique_violation then null; end;
 begin
  update public.dispatch_lines set product_id='99999999-0000-0000-0000-000000000001';
  raise exception 'Orphan product accepted';
 exception when foreign_key_violation then null; end;
 begin
  update public.distributor_product_prices set effective_until=effective_from;
  raise exception 'Invalid effective interval accepted';
 exception when check_violation then null; end;
 if exists(select 1 from pg_policies where schemaname='public' and cmd<>'SELECT') then raise exception 'Mutation policy exists'; end if;
 if (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace
     where n.nspname='public' and c.relkind='r' and c.relrowsecurity and c.relforcerowsecurity) <> 9 then raise exception 'RLS missing'; end if;
end $$;
rollback;
