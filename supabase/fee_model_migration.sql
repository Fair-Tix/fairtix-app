-- =============================================================================
-- FairTix — OPTIONAL one-time migration to the new fee model
-- Run AFTER purchase_functions.sql (needs organizer_fee_rate) and, if you use
-- it, BEFORE the backfill block in revenue_functions.sql. Safe to re-run.
--
-- Old model:  buyer paid ticket price + flat 10%; transactions.platform_fee
--             was always that flat 10%.
-- New model:  buyer pays the listed ticket price; FairTix's fee is
--             8% / 9% / 10% by the organizer's plan and is taken out of the
--             organizer's proceeds (see purchase_functions.sql).
--
-- This restates purchases made BEFORE the change so reports don't mix both
-- models. It uses each organizer's CURRENT plan (the plan at purchase time
-- was never recorded). If your purchases so far are only test data, you can
-- skip this and simply delete them instead.
--
-- It does NOT touch public.refunds: a refund row records what the buyer
-- actually paid at the time (including the old 10% surcharge), which is
-- still the amount that was charged on PayMongo.
-- =============================================================================

-- 1. Completed primary purchases: amount = ticket price, fee = plan rate.
update public.transactions tr
   set amount       = t.purchase_price,
       platform_fee = round(t.purchase_price * public.organizer_fee_rate(e.organizer_id), 2)
  from public.tickets t
  join public.ticket_tiers tt on tt.tier_id = t.tier_id
  join public.events e        on e.event_id = tt.event_id
 where t.ticket_id = tr.ticket_id
   and tr.transaction_type = 'purchase';

-- 2. Keep each ticket's recorded service fee in step with its transaction.
update public.tickets t
   set service_fee = tr.platform_fee
  from public.transactions tr
 where tr.ticket_id = t.ticket_id
   and tr.transaction_type = 'purchase';

-- 3. Re-sync the organizer fee rows (if any exist) with the transactions.
update public.organizer_fees f
   set gross_amount = tr.amount,
       fee_amount   = tr.platform_fee,
       net_amount   = tr.amount - tr.platform_fee,
       fee_rate     = public.organizer_fee_rate(f.organizer_id)
  from public.transactions tr
 where tr.transaction_id = f.transaction_id;
