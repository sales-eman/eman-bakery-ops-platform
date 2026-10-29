-- DESIGN ONLY. Do not apply to production.
-- This file records the locking contract from the architecture package.
-- Exact table names may follow the application migration once Milestone 2 is approved.
-- Odoo identifiers are intentionally absent.

-- cycle_date is the Asia/Riyadh civil date, computed by the application
-- with an explicit time zone. Do not use CURRENT_DATE on a UTC server.

-- create table cycle_balance (
--   distributor_id uuid not null,
--   product_id uuid not null,
--   cycle_date date not null,
--   available_qty numeric not null,
--   max_resale_price numeric not null,
--   primary key (distributor_id, product_id, cycle_date)
-- );

-- Reservation shape (illustrative, not an executable migration):
-- begin;
-- select available_qty, max_resale_price
--   from cycle_balance
--  where distributor_id = $1
--    and product_id = $2
--    and cycle_date = $3
--  for update;
-- -- If no row exists, FOR UPDATE locks nothing.
-- -- Create the row when the dispatch is confirmed, or take a
-- -- transaction-scoped advisory lock on (distributor, product, cycle)
-- -- before inserting the first sale.
-- -- Re-check assignment, confirmed quantity, and max price here.
-- -- Insert the sale as reserved. Insert the outbox only after that milestone.
-- commit;

-- A sale holds quantity while status is reserved, submitted, cleared, or ambiguous.
-- Draft does not hold quantity.
-- Do not release a cleared identity except through a credit note with its own key.
