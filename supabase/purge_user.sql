-- =============================================================================
-- FairTix -- purge_user(email): delete a user AND everything that blocks the
-- delete (tickets, transactions, refunds, resale listings, events, ...).
-- FOR TEST DATA ONLY. Run from the Supabase SQL Editor:
--     select public.purge_user('someone@example.com');
-- Not callable from the app (execute is revoked from public/anon/authenticated).
-- Refuses to delete admin accounts. Deleting an organizer also deletes their
-- events and every ticket/transaction on those events, including other users'.
-- Safe to re-run.
-- =============================================================================

create or replace function public.purge_user(p_email text)
returns text
language plpgsql
security definer set search_path = public
as $$
declare
  v_id uuid;
  v_role text;
  v_events uuid[];
  v_tickets uuid[];
  v_tx uuid[];
  v_listings uuid[];
begin
  select id, role::text into v_id, v_role
  from public.users where lower(email) = lower(trim(p_email));
  if v_id is null then
    raise exception 'No user with email %', p_email;
  end if;
  if v_role = 'admin' then
    raise exception 'Refusing to delete an admin account.';
  end if;

  select coalesce(array_agg(event_id), '{}') into v_events
  from public.events where organizer_id = v_id;

  select coalesce(array_agg(t.ticket_id), '{}') into v_tickets
  from public.tickets t
  where t.owner_id = v_id
     or t.tier_id in (select tier_id from public.ticket_tiers where event_id = any(v_events));

  select coalesce(array_agg(transaction_id), '{}') into v_tx
  from public.transactions
  where buyer_id = v_id or seller_id = v_id or ticket_id = any(v_tickets);

  select coalesce(array_agg(listing_id), '{}') into v_listings
  from public.resale_listings
  where seller_id = v_id or ticket_id = any(v_tickets);

  delete from public.fraud_alerts
   where user_id = v_id or event_id = any(v_events)
      or ticket_id = any(v_tickets) or listing_id = any(v_listings);
  delete from public.qr_scan_logs
   where ticket_id = any(v_tickets)
      or session_id in (select session_id from public.scanner_sessions
                        where organizer_id = v_id or event_id = any(v_events));
  delete from public.refunds
   where buyer_id = v_id or event_id = any(v_events)
      or ticket_id = any(v_tickets) or transaction_id = any(v_tx);
  delete from public.organizer_fees
   where organizer_id = v_id or transaction_id = any(v_tx);
  delete from public.transactions where transaction_id = any(v_tx);
  delete from public.resale_listings where listing_id = any(v_listings);
  delete from public.tickets where ticket_id = any(v_tickets);
  delete from public.events where organizer_id = v_id;
  delete from auth.users where id = v_id;

  return 'Deleted ' || p_email;
end;
$$;

revoke all on function public.purge_user(text) from public, anon, authenticated;
