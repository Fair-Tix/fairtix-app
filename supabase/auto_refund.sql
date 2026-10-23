-- =============================================================================
-- FairTix — AUTOMATIC refunds when an organizer/admin cancels an event.
-- Run AFTER refund_functions.sql and escrow_and_summary.sql. Safe to re-run.
--
-- Proposal: "Refunds are processed automatically by the system, with no
-- manual admin action required." Before this file the cancel trigger only
-- created 'pending' refunds and waited for admin_process_refund().
--
-- Now, the moment an event (or a multi-day parent) becomes 'canceled':
--   * every ticket not yet scanned is canceled and its QR invalidated;
--   * the CURRENT holder's latest completed payment for that ticket is
--     refunded: refunds row = 'processed', transaction = 'refunded',
--     escrow = 'refunded' (escrow_amount zeroed by settle_escrow trigger);
--   * the organizer fee on it is 'withheld';
--   * the existing transaction notification trigger sends "Refund issued".
-- Scanned (used) tickets are not refunded; their escrow was already released.
-- If a ticket was resold, the refund goes to the current holder's (resale)
-- payment; money already released for an earlier sale is not clawed back.
--
-- NOTE: this updates FairTix's ledger. Returning the actual money to the
-- buyer's GCash/Maya/card needs a PayMongo Refund API call (an Edge Function,
-- separate step). In Sandbox no real money moves either way.
-- admin_process_refund() stays as a harmless fallback for old pending rows.
-- =============================================================================

create or replace function public.create_refunds_on_event_cancel()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.status = 'canceled' and old.status is distinct from 'canceled' then

    -- 1. Refund rows: one per ticket, for its latest completed payment.
    insert into public.refunds
      (transaction_id, ticket_id, buyer_id, event_id, amount)
    select x.transaction_id, x.ticket_id, x.buyer_id, x.event_id, x.amount
    from (
      select distinct on (tr.ticket_id)
             tr.transaction_id, tr.ticket_id, tr.buyer_id,
             e.event_id, tr.amount
      from public.transactions tr
      join public.tickets t       on t.ticket_id = tr.ticket_id
      join public.ticket_tiers tt on tt.tier_id = t.tier_id
      join public.events e        on e.event_id = tt.event_id
      where (e.event_id = new.event_id or e.parent_event_id = new.event_id)
        and tr.transaction_type::text in ('purchase', 'resale')
        and tr.status::text = 'completed'
        and t.ticket_status::text <> 'used'
      order by tr.ticket_id, tr.created_at desc
    ) x
    on conflict (transaction_id) do nothing;

    -- 2. Cancel active resale listings for the event's tickets.
    update public.resale_listings rl
       set listing_status = 'canceled'
      from public.tickets t
      join public.ticket_tiers tt on tt.tier_id = t.tier_id
      join public.events e        on e.event_id = tt.event_id
     where rl.ticket_id = t.ticket_id
       and rl.listing_status::text = 'active'
       and (e.event_id = new.event_id or e.parent_event_id = new.event_id);

    -- 3. Cancel the unscanned tickets and kill their QR codes.
    update public.tickets t
       set ticket_status = 'canceled', qr_status = 'invalidated'
      from public.ticket_tiers tt, public.events e
     where tt.tier_id = t.tier_id
       and e.event_id = tt.event_id
       and (e.event_id = new.event_id or e.parent_event_id = new.event_id)
       and t.ticket_status::text <> 'used';

    -- 4. Settle immediately: pending refunds of this event -> processed.
    update public.transactions tr
       set status = 'refunded', escrow_status = 'refunded'
      from public.refunds r
     where r.transaction_id = tr.transaction_id
       and r.status = 'pending'
       and r.event_id in (
         select e.event_id from public.events e
          where e.event_id = new.event_id or e.parent_event_id = new.event_id);

    update public.organizer_fees f
       set status = 'withheld'
      from public.refunds r
     where r.transaction_id = f.transaction_id
       and r.status = 'pending'
       and r.event_id in (
         select e.event_id from public.events e
          where e.event_id = new.event_id or e.parent_event_id = new.event_id);

    update public.refunds r
       set status = 'processed', processed_at = now()
     where r.status = 'pending'
       and r.event_id in (
         select e.event_id from public.events e
          where e.event_id = new.event_id or e.parent_event_id = new.event_id);
  end if;
  return new;
end;
$$;

revoke all on function public.create_refunds_on_event_cancel() from public, anon, authenticated;

drop trigger if exists on_event_cancel_create_refunds on public.events;
create trigger on_event_cancel_create_refunds
  after update of status on public.events
  for each row execute procedure public.create_refunds_on_event_cancel();

-- Refunds that were left pending before this change: settle them now.
do $$
declare
  r record;
begin
  for r in select refund_id from public.refunds where status = 'pending' loop
    begin
      perform public.admin_process_refund(r.refund_id);
    exception when others then
      raise notice 'skipped %: %', r.refund_id, sqlerrm;
    end;
  end loop;
end;
$$;
