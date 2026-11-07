-- =============================================================================
-- FairTix — application review log + admin audit log
-- Run in the Supabase SQL Editor AFTER schema.sql, policies.sql,
-- security_patch.sql, notification_functions.sql, fraud_alerts.sql and
-- user_verified_at.sql (the backfill below reads users.verified_at).
-- Safe to re-run.
--
-- What this adds
--   1. public.account_reviews  one row per step of an application:
--        submitted    documents became complete (eventgoer: ID + selfie,
--                     organizer: venue proof + event permit)
--        approved / rejected    an admin decision
--        resubmitted  the applicant went from rejected back to pending
--        reopened     an admin set a decided/pending account back to pending
--      `reason` holds the rejection reason. admin_review_account.sql (run it
--      after this file) hands the reason to the trigger through the
--      transaction-local setting fairtix.review_reason. Rejections made
--      before that was installed have no reason.
--   2. public.admin_audit_log  what admins did: approvals, rejections,
--      suspensions / reactivations, role changes, fraud-alert reviews, resale
--      listings taken down, events canceled or unpublished, refund status
--      changes.
--
-- Both are filled by database triggers, so every path is caught (the app, an
-- RPC, or a manual edit). Only admins can read them; nobody can write to them
-- from the app. A logging error never blocks the action itself (it raises a
-- warning instead).
--
-- NOT covered: admin announcements (send_announcement), subscription-plan edits
-- and Platform Settings. History starts when this file is run; earlier actions
-- are not recorded (only approvals are backfilled, from users.verified_at).
-- =============================================================================

-- ── Tables ──────────────────────────────────────────────────────────────
create table if not exists public.account_reviews (
  review_id      uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.users(id) on delete cascade,
  applicant_type text not null check (applicant_type in ('eventgoer', 'organizer')),
  action         text not null
                   check (action in ('submitted', 'approved', 'rejected', 'resubmitted', 'reopened')),
  reason         text,
  actor_id       uuid,
  created_at     timestamptz not null default now()
);
create index if not exists account_reviews_user_idx on public.account_reviews (user_id, created_at);
create index if not exists account_reviews_created_idx on public.account_reviews (created_at desc);

create table if not exists public.admin_audit_log (
  log_id       uuid primary key default gen_random_uuid(),
  actor_id     uuid,
  action       text not null,
  target_type  text not null,
  target_id    text,
  target_label text,
  details      text,
  created_at   timestamptz not null default now()
);
create index if not exists admin_audit_log_created_idx on public.admin_audit_log (created_at desc);
create index if not exists admin_audit_log_actor_idx on public.admin_audit_log (actor_id);

alter table public.account_reviews enable row level security;
alter table public.admin_audit_log enable row level security;

drop policy if exists "account_reviews_select_admin" on public.account_reviews;
create policy "account_reviews_select_admin"
  on public.account_reviews for select using (public.is_admin());

drop policy if exists "admin_audit_log_select_admin" on public.admin_audit_log;
create policy "admin_audit_log_select_admin"
  on public.admin_audit_log for select using (public.is_admin());
-- No insert / update / delete policy: only the SECURITY DEFINER triggers write.

-- ── Helper: write one audit row ─────────────────────────────────────────
create or replace function public.write_audit(
  p_action text,
  p_target_type text,
  p_target_id text,
  p_label text,
  p_details text default null
)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.admin_audit_log (actor_id, action, target_type, target_id, target_label, details)
  values (auth.uid(), p_action, p_target_type, p_target_id, p_label, nullif(btrim(p_details), ''));
exception when others then
  raise warning 'write_audit failed: %', sqlerrm;
end;
$$;
revoke all on function public.write_audit(text, text, text, text, text) from public, anon, authenticated;

-- ── users: application steps + account actions ──────────────────────────
create or replace function public.trg_audit_users()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_admin  boolean := coalesce(public.is_admin(), false);
  v_type   text := case when new.role = 'organizer' then 'organizer' else 'eventgoer' end;
  v_label  text := coalesce(nullif(new.email, ''), new.id::text);
  -- Set by admin_review_account for the current transaction only; NULL when
  -- not set. Only trusted for admins (see the rejected branch).
  v_reason text := nullif(btrim(coalesce(current_setting('fairtix.review_reason', true), '')), '');
  v_docs_now    boolean;
  v_docs_before boolean;
begin
  begin
    -- Documents became complete -> "submitted"
    if new.role = 'organizer' then
      v_docs_now    := new.venue_proof_url is not null and new.event_permit_url is not null;
      v_docs_before := old.venue_proof_url is not null and old.event_permit_url is not null;
    else
      v_docs_now    := new.id_document_url is not null and new.selfie_photo_url is not null;
      v_docs_before := old.id_document_url is not null and old.selfie_photo_url is not null;
    end if;
    if v_docs_now and not v_docs_before then
      insert into public.account_reviews (user_id, applicant_type, action, actor_id)
      values (new.id, v_type, 'submitted', auth.uid());
    end if;

    -- Review status changes
    if new.id_verification_status is distinct from old.id_verification_status then
      if new.id_verification_status = 'verified' then
        insert into public.account_reviews (user_id, applicant_type, action, actor_id)
        values (new.id, v_type, 'approved', auth.uid());
        if v_admin then
          perform public.write_audit('account_approved', v_type, new.id::text, v_label, null);
        end if;
      elsif new.id_verification_status = 'rejected' then
        insert into public.account_reviews (user_id, applicant_type, action, reason, actor_id)
        values (new.id, v_type, 'rejected', case when v_admin then v_reason end, auth.uid());
        if v_admin then
          perform public.write_audit('account_rejected', v_type, new.id::text, v_label, v_reason);
        end if;
      elsif new.id_verification_status = 'pending' then
        if v_admin then
          insert into public.account_reviews (user_id, applicant_type, action, actor_id)
          values (new.id, v_type, 'reopened', auth.uid());
          perform public.write_audit('account_review_reopened', v_type, new.id::text, v_label,
            'was ' || old.id_verification_status::text);
        elsif old.id_verification_status = 'rejected' then
          insert into public.account_reviews (user_id, applicant_type, action, actor_id)
          values (new.id, v_type, 'resubmitted', auth.uid());
        end if;
      end if;
    end if;

    -- Account status (suspend / reactivate / deactivate)
    if new.account_status is distinct from old.account_status then
      perform public.write_audit(
        case new.account_status::text
          when 'suspended' then 'account_suspended'
          when 'active' then 'account_reactivated'
          else 'account_' || new.account_status::text
        end,
        v_type, new.id::text, v_label,
        'was ' || old.account_status::text
          || case when auth.uid() is null then ' (no signed-in user: SQL Editor/service role)' else '' end
      );
    end if;

    -- Role change
    if new.role is distinct from old.role then
      perform public.write_audit('role_changed', v_type, new.id::text, v_label,
        old.role::text || ' -> ' || new.role::text);
    end if;
  exception when others then
    raise warning 'trg_audit_users failed: %', sqlerrm;
  end;
  return new;
end;
$$;
revoke all on function public.trg_audit_users() from public, anon, authenticated;

drop trigger if exists audit_users on public.users;
create trigger audit_users
  after update on public.users
  for each row execute procedure public.trg_audit_users();

-- ── fraud_alerts: review decisions ──────────────────────────────────────
create or replace function public.trg_audit_fraud_alerts()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.status is distinct from old.status then
    perform public.write_audit(
      'fraud_alert_' || new.status::text, 'fraud_alert', new.alert_id::text,
      new.alert_type::text,
      coalesce(new.resolution_note, '')
    );
  end if;
  return new;
end;
$$;
revoke all on function public.trg_audit_fraud_alerts() from public, anon, authenticated;

drop trigger if exists audit_fraud_alerts on public.fraud_alerts;
create trigger audit_fraud_alerts
  after update on public.fraud_alerts
  for each row execute procedure public.trg_audit_fraud_alerts();

-- ── resale_listings: an admin takes a listing down ──────────────────────
create or replace function public.trg_audit_resale_listings()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if coalesce(public.is_admin(), false)
     and old.listing_status::text = 'active'
     and new.listing_status::text = 'canceled' then
    perform public.write_audit('resale_listing_removed', 'resale_listing',
      new.listing_id::text, new.listing_id::text, null);
  end if;
  return new;
end;
$$;
revoke all on function public.trg_audit_resale_listings() from public, anon, authenticated;

drop trigger if exists audit_resale_listings on public.resale_listings;
create trigger audit_resale_listings
  after update of listing_status on public.resale_listings
  for each row execute procedure public.trg_audit_resale_listings();

-- ── events: an admin cancels or unpublishes ─────────────────────────────
create or replace function public.trg_audit_events()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.status is distinct from old.status and coalesce(public.is_admin(), false) then
    perform public.write_audit(
      case new.status::text
        when 'canceled' then 'event_canceled_by_admin'
        when 'draft' then 'event_unpublished_by_admin'
        else 'event_status_changed_by_admin'
      end,
      'event', new.event_id::text, new.title,
      old.status::text || ' -> ' || new.status::text
    );
  end if;
  return new;
end;
$$;
revoke all on function public.trg_audit_events() from public, anon, authenticated;

drop trigger if exists audit_events on public.events;
create trigger audit_events
  after update of status on public.events
  for each row execute procedure public.trg_audit_events();

-- ── refunds: an admin changes a refund's status ─────────────────────────
create or replace function public.trg_audit_refunds()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.status::text is distinct from old.status::text and coalesce(public.is_admin(), false) then
    perform public.write_audit('refund_status_changed', 'refund', new.refund_id::text,
      new.refund_id::text, old.status::text || ' -> ' || new.status::text);
  end if;
  return new;
end;
$$;
revoke all on function public.trg_audit_refunds() from public, anon, authenticated;

drop trigger if exists audit_refunds on public.refunds;
create trigger audit_refunds
  after update on public.refunds
  for each row execute procedure public.trg_audit_refunds();

-- ── Backfill: approvals that already happened ───────────────────────────
-- Only where the approval date is known (users.verified_at). Rejections and
-- submission dates before today are unknown and are NOT guessed.
insert into public.account_reviews (user_id, applicant_type, action, created_at)
select u.id,
       case when u.role = 'organizer' then 'organizer' else 'eventgoer' end,
       'approved',
       u.verified_at
from public.users u
where u.role in ('buyer', 'organizer')
  and u.id_verification_status = 'verified'
  and u.verified_at is not null
  and not exists (
    select 1 from public.account_reviews r
    where r.user_id = u.id and r.action = 'approved'
  );
