-- =============================================================================
-- FairTix — purchase notification trigger
-- Run this in the Supabase SQL Editor AFTER schema.sql, policies.sql and
-- purchase_functions.sql. Safe to re-run (create or replace / drop if exists).
--
-- Why a trigger: _do_ticket_purchase (purchase_functions.sql) inserts the
-- ticket and then a 'purchase' transaction in one atomic call, and it is the
-- only code path that does so (paymongo-verify and paymongo-webhook both go
-- through fulfill_ticket_purchase). Hooking the transactions insert means the
-- notification is created exactly once per real purchase, whichever path wins
-- the race, and a failed/canceled payment (no ticket, no transaction) never
-- notifies. Idempotent re-fulfillment returns early inside
-- _do_ticket_purchase before inserting, so it does not notify twice.
--
-- Runs as SECURITY DEFINER because notifications_insert_admin_only
-- (policies.sql) blocks direct client inserts — same pattern as
-- notify_verification_change in schema.sql.
-- =============================================================================

create or replace function public.notify_ticket_purchase()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_event_title text;
  v_tier_name   text;
begin
  -- Only primary purchases. Resale transactions are handled separately.
  if new.transaction_type <> 'purchase' or new.status <> 'completed' then
    return new;
  end if;

  select e.title, tt.tier_name
    into v_event_title, v_tier_name
    from public.tickets t
    join public.ticket_tiers tt on tt.tier_id = t.tier_id
    join public.events e on e.event_id = tt.event_id
    where t.ticket_id = new.ticket_id;

  insert into public.notifications (user_id, title, message, type, channel)
  values (
    new.buyer_id,
    'Ticket Purchased',
    format(
      'Your %s ticket for %s is confirmed and has been added to your wallet.',
      coalesce(v_tier_name, 'event'),
      coalesce(v_event_title, 'the event')
    ),
    'ticket',
    'in_app'
  );

  return new;
end;
$$;

revoke all on function public.notify_ticket_purchase() from public, anon, authenticated;

drop trigger if exists on_ticket_purchase_notify on public.transactions;
create trigger on_ticket_purchase_notify
  after insert on public.transactions
  for each row execute procedure public.notify_ticket_purchase();
