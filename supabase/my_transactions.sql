-- =============================================================================
-- FairTix — get_my_transactions(): the signed-in user's full transaction
-- history for the app's Transactions screen.
-- Run this in the Supabase SQL Editor AFTER schema.sql, policies.sql,
-- refund_functions.sql and auto_refund.sql. Safe to re-run.
--
-- Why this exists: the app used to read public.transactions directly and
-- join tickets -> ticket_tiers -> events with INNER joins. tickets RLS only
-- lets the CURRENT OWNER read a ticket, so as soon as a ticket was resold
-- the joined row vanished for the seller (their "Resale Sale") and for the
-- original buyer (their first "Ticket Purchase"). Refunds were never shown at
-- all: they live in public.refunds, and the original transaction just flips
-- to 'refunded'.
--
-- This function runs as SECURITY DEFINER (so the ticket/event lookup works
-- for a ticket the user no longer owns) but only ever returns rows where the
-- caller is the buyer or seller, or the refund recipient.
--
-- It returns one row per:
--   * transaction where the user is buyer or seller
--       transaction_type = 'purchase' | 'resale'
--   * refund paid to the user (public.refunds.buyer_id)
--       transaction_type = 'refund'   (a credit; separate from the purchase
--       it reverses, which stays in the list with status 'refunded')
-- =============================================================================

create or replace function public.get_my_transactions()
returns table (
  transaction_id   uuid,
  ticket_id        uuid,
  buyer_id         uuid,
  seller_id        uuid,
  transaction_type text,
  amount           numeric,
  platform_fee     numeric,
  status           text,
  created_at       timestamptz,
  tier_name        text,
  event_title      text
)
language sql stable
security definer set search_path = public
as $$
  select * from (
    -- Purchases, resale purchases and resale sales.
    select
      tr.transaction_id,
      tr.ticket_id,
      tr.buyer_id,
      tr.seller_id,
      tr.transaction_type::text,
      tr.amount::numeric,
      tr.platform_fee::numeric,
      -- A seller keeps their proceeds when the NEW holder's payment is later
      -- refunded (auto_refund.sql: money already released isn't clawed back),
      -- so the seller's row stays 'completed'. The refund shows on the buyer.
      case
        when tr.seller_id = auth.uid() and tr.status::text = 'refunded'
          then 'completed'
        else tr.status::text
      end,
      tr.created_at,
      tt.tier_name::text,
      e.title::text
    from public.transactions tr
    left join public.tickets t       on t.ticket_id = tr.ticket_id
    left join public.ticket_tiers tt on tt.tier_id = t.tier_id
    left join public.events e        on e.event_id = tt.event_id
    where tr.buyer_id = auth.uid() or tr.seller_id = auth.uid()

    union all

    -- Refunds paid back to this user.
    select
      r.refund_id,
      r.ticket_id,
      r.buyer_id,
      null::uuid,
      'refund',
      r.amount::numeric,
      0::numeric,
      case r.status when 'processed' then 'completed' else 'pending' end,
      coalesce(r.processed_at, r.created_at),
      tt.tier_name::text,
      e.title::text
    from public.refunds r
    left join public.tickets t       on t.ticket_id = r.ticket_id
    left join public.ticket_tiers tt on tt.tier_id = t.tier_id
    left join public.events e        on e.event_id = coalesce(r.event_id, tt.event_id)
    where r.buyer_id = auth.uid()
  ) all_rows
  where auth.uid() is not null
  order by created_at desc;
$$;

revoke all on function public.get_my_transactions() from public, anon;
grant execute on function public.get_my_transactions() to authenticated;
