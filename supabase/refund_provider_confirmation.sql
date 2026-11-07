-- FairTix — refunds remain pending until an administrator records a real
-- PayMongo refund reference. Run AFTER refund_functions.sql, auto_refund.sql,
-- admin_unpublish.sql, and notification_functions.sql. Safe to re-run.
-- This does not call PayMongo. The operator must issue the refund in the
-- PayMongo dashboard, then record its provider refund ID in FairTix.

alter table public.refunds add column if not exists provider_refund_id text;
alter table public.refunds add column if not exists provider_refunded_at timestamptz;
create unique index if not exists refunds_provider_refund_id_uidx
  on public.refunds(provider_refund_id) where provider_refund_id is not null;

-- The previous auto-refund SQL marked records processed without contacting
-- PayMongo. Reopen those records when no provider confirmation was recorded.
update public.refunds
   set status = 'pending', processed_at = null
 where status = 'processed' and provider_refund_id is null;

update public.transactions tr
   set status = 'completed'
  from public.refunds r
 where r.transaction_id = tr.transaction_id
   and r.status = 'pending'
   and tr.status = 'refunded';

-- Replace the automatic-settlement version. Cancellation invalidates tickets,
-- withholds organizer fees and creates pending refund records; it never says
-- the buyer has received money.
create or replace function public.create_refunds_on_event_cancel()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.status = 'canceled' and old.status is distinct from 'canceled' then
    insert into public.refunds
      (transaction_id, ticket_id, buyer_id, event_id, amount, status)
    select x.transaction_id, x.ticket_id, x.buyer_id, x.event_id, x.amount, 'pending'
    from (
      select distinct on (tr.ticket_id)
             tr.transaction_id, tr.ticket_id, tr.buyer_id, e.event_id, tr.amount
      from public.transactions tr
      join public.tickets t on t.ticket_id = tr.ticket_id
      join public.ticket_tiers tt on tt.tier_id = t.tier_id
      join public.events e on e.event_id = tt.event_id
      where (e.event_id = new.event_id or e.parent_event_id = new.event_id)
        and tr.transaction_type::text in ('purchase', 'resale')
        and tr.status::text = 'completed'
        and t.ticket_status::text <> 'used'
      order by tr.ticket_id, tr.created_at desc
    ) x
    on conflict (transaction_id) do nothing;

    -- Keep funds unavailable for payout while refund confirmation is pending.
    update public.transactions tr
       set escrow_status = 'refunded'
      from public.refunds r
     where r.transaction_id = tr.transaction_id
       and r.status = 'pending'
       and r.event_id in (
         select e.event_id from public.events e
          where e.event_id = new.event_id or e.parent_event_id = new.event_id
       );

    update public.organizer_fees f
       set status = 'withheld'
      from public.refunds r
     where r.transaction_id = f.transaction_id
       and r.status = 'pending'
       and r.event_id in (
         select e.event_id from public.events e
          where e.event_id = new.event_id or e.parent_event_id = new.event_id
       );

    update public.resale_listings rl
       set listing_status = 'canceled'
      from public.tickets t
      join public.ticket_tiers tt on tt.tier_id = t.tier_id
      join public.events e on e.event_id = tt.event_id
     where rl.ticket_id = t.ticket_id
       and rl.listing_status::text = 'active'
       and (e.event_id = new.event_id or e.parent_event_id = new.event_id);

    update public.tickets t
       set ticket_status = 'canceled', qr_status = 'invalidated'
      from public.ticket_tiers tt, public.events e
     where tt.tier_id = t.tier_id
       and e.event_id = tt.event_id
       and (e.event_id = new.event_id or e.parent_event_id = new.event_id)
       and t.ticket_status::text <> 'used';
  end if;
  return new;
end;
$$;

revoke all on function public.create_refunds_on_event_cancel()
  from public, anon, authenticated;
drop trigger if exists on_event_cancel_create_refunds on public.events;
create trigger on_event_cancel_create_refunds
  after update of status on public.events
  for each row execute procedure public.create_refunds_on_event_cancel();

-- Recording a refund requires the provider's reference. This is an audit
-- record; the admin must first verify the refund in PayMongo.
drop function if exists public.admin_process_refund(uuid);
create or replace function public.admin_process_refund(
  p_refund_id uuid,
  p_provider_refund_id text
)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_transaction_id uuid;
  v_provider_ref text := nullif(left(btrim(coalesce(p_provider_refund_id, '')), 120), '');
begin
  if not public.is_admin() then
    raise exception 'Only admins can record refund confirmation.';
  end if;
  if v_provider_ref is null then
    raise exception 'Enter the PayMongo refund ID after confirming the refund there.';
  end if;

  update public.refunds
     set status = 'processed',
         processed_at = now(),
         provider_refund_id = v_provider_ref,
         provider_refunded_at = now()
   where refund_id = p_refund_id and status = 'pending'
   returning transaction_id into v_transaction_id;
  if v_transaction_id is null then
    raise exception 'Refund not found or already confirmed.';
  end if;

  update public.transactions
     set status = 'refunded', escrow_status = 'refunded'
   where transaction_id = v_transaction_id;
  update public.organizer_fees
     set status = 'withheld'
   where transaction_id = v_transaction_id;
end;
$$;

revoke all on function public.admin_process_refund(uuid, text) from public, anon;
grant execute on function public.admin_process_refund(uuid, text) to authenticated;
