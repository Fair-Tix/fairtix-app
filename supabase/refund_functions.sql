-- =============================================================================
-- FairTix — refund log (admin: Financial Controls)
-- Run this in the Supabase SQL Editor AFTER schema.sql, policies.sql,
-- purchase_functions.sql and revenue_functions.sql. Safe to re-run.
--
-- Before this file nothing in the project recorded a refund: transactions
-- has a 'refunded' status but no code ever set it, and there was nowhere to
-- store a reason or timestamp. This adds:
--   1. public.refunds — the refund log (one row per refunded purchase).
--   2. A trigger that creates a 'pending' refund for every completed
--      primary purchase when an event is set to 'canceled', and cancels the
--      affected tickets (so the wallet shows them as "canceled").
--   3. admin_process_refund() — the admin marks a refund as processed,
--      which flips the transaction/escrow to 'refunded' and withholds the
--      organizer fee so revenue totals stay correct.
--
-- This does NOT call PayMongo. In this sandbox project "processed" means
-- the admin has handled the refund outside the app (e.g. in the PayMongo
-- dashboard) and is recording it here.
-- =============================================================================

-- ── Refund log table ────────────────────────────────────────────────────
create table if not exists public.refunds (
  refund_id      uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references public.transactions(transaction_id),
  ticket_id      uuid references public.tickets(ticket_id),
  buyer_id       uuid not null references public.users(id),
  event_id       uuid references public.events(event_id),
  amount         numeric(10,2) not null,
  reason         text not null default 'Event canceled',
  status         text not null default 'pending'
                   check (status in ('pending', 'processed')),
  created_at     timestamptz not null default now(),
  processed_at   timestamptz
);

-- One refund per transaction, so re-running a cancel can never double-refund.
create unique index if not exists refunds_transaction_uidx
  on public.refunds (transaction_id);
create index if not exists refunds_buyer_idx  on public.refunds (buyer_id);
create index if not exists refunds_status_idx on public.refunds (status);

alter table public.refunds enable row level security;

-- Admins read everything; buyers read their own. No client insert/update
-- policy on purpose: rows are created by the trigger below and updated only
-- through admin_process_refund().
drop policy if exists "refunds_select_own_or_admin" on public.refunds;
create policy "refunds_select_own_or_admin"
  on public.refunds for select
  using (public.is_admin() or buyer_id = auth.uid());

-- ── Event canceled -> pending refunds + canceled tickets ────────────────
create or replace function public.create_refunds_on_event_cancel()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.status = 'canceled' and old.status is distinct from 'canceled' then

    -- A multi-day parent being canceled covers its generated day-children.
    -- ON CONFLICT means a repeat cancel creates no second refund. No
    -- notification is sent here: the existing notify_on_event_canceled trigger
    -- (trg_notify_event_canceled) already tells the organizer and every holder,
    -- and trg_notify_transaction sends "Refund issued" when the admin
    -- processes the refund, so adding one here would send it twice.
    insert into public.refunds (transaction_id, ticket_id, buyer_id, event_id, amount)
    select tr.transaction_id, tr.ticket_id, tr.buyer_id, e.event_id, tr.amount
    from public.transactions tr
    join public.tickets t       on t.ticket_id = tr.ticket_id
    join public.ticket_tiers tt on tt.tier_id = t.tier_id
    join public.events e        on e.event_id = tt.event_id
    where (e.event_id = new.event_id or e.parent_event_id = new.event_id)
      and tr.transaction_type = 'purchase'
      and tr.status = 'completed'
      and t.ticket_status <> 'used'
    on conflict (transaction_id) do nothing;

    -- Cancel any active resale listings for the event's tickets...
    update public.resale_listings rl
       set listing_status = 'canceled'
      from public.tickets t
      join public.ticket_tiers tt on tt.tier_id = t.tier_id
      join public.events e        on e.event_id = tt.event_id
     where rl.ticket_id = t.ticket_id
       and rl.listing_status = 'active'
       and (e.event_id = new.event_id or e.parent_event_id = new.event_id);

    -- ...then cancel the tickets themselves and kill their QR codes.
    update public.tickets t
       set ticket_status = 'canceled', qr_status = 'invalidated'
      from public.ticket_tiers tt, public.events e
     where tt.tier_id = t.tier_id
       and e.event_id = tt.event_id
       and (e.event_id = new.event_id or e.parent_event_id = new.event_id)
       and t.ticket_status <> 'used';
  end if;
  return new;
end;
$$;

revoke all on function public.create_refunds_on_event_cancel() from public, anon, authenticated;

drop trigger if exists on_event_cancel_create_refunds on public.events;
create trigger on_event_cancel_create_refunds
  after update of status on public.events
  for each row execute procedure public.create_refunds_on_event_cancel();

-- ── Admin: mark a refund processed ──────────────────────────────────────
create or replace function public.admin_process_refund(p_refund_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_transaction_id uuid;
begin
  if not public.is_admin() then
    raise exception 'Only admins can process refunds.';
  end if;

  update public.refunds
     set status = 'processed', processed_at = now()
   where refund_id = p_refund_id and status = 'pending'
   returning transaction_id into v_transaction_id;

  if v_transaction_id is null then
    raise exception 'Refund not found or already processed.';
  end if;

  update public.transactions
     set status = 'refunded', escrow_status = 'refunded'
   where transaction_id = v_transaction_id;

  -- A refunded sale earns the platform no fee.
  update public.organizer_fees
     set status = 'withheld'
   where transaction_id = v_transaction_id;
end;
$$;

revoke all on function public.admin_process_refund(uuid) from public, anon;
grant execute on function public.admin_process_refund(uuid) to authenticated;
