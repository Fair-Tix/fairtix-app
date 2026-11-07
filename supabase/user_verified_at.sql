-- =============================================================================
-- FairTix — approval date for accounts (users.verified_at)
-- Run in the Supabase SQL Editor. Safe to re-run.
--
-- Why: approval was only a status (id_verification_status = 'verified'); the
-- date it happened was not stored anywhere except the "Account activated" /
-- "Organizer application approved" notification. The Approved Accounts Report
-- (Admin > Revenue & Reports) reads this column.
--
-- Behaviour
--   * becomes now() when the status changes to 'verified'
--   * is cleared when the status changes to anything else (e.g. rejected)
--   * cannot be edited by a signed-in user through the API (it is kept as is
--     unless the status itself changes); the SQL Editor (no auth.uid()) may
--     still correct it by hand
--   * backfill: accounts already verified get the time of their LATEST
--     approval notification; accounts with no such notification stay NULL
--     (no date is guessed)
-- =============================================================================

alter table public.users add column if not exists verified_at timestamptz;

create or replace function public.trg_set_verified_at()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    new.verified_at := case
      when new.id_verification_status = 'verified' then now()
      else null
    end;
    return new;
  end if;

  if new.id_verification_status is not distinct from old.id_verification_status then
    -- Status unchanged: API users cannot change the date.
    if auth.uid() is not null then
      new.verified_at := old.verified_at;
    end if;
    return new;
  end if;

  new.verified_at := case
    when new.id_verification_status = 'verified' then now()
    else null
  end;
  return new;
end;
$$;

drop trigger if exists set_verified_at on public.users;
create trigger set_verified_at
  before insert or update on public.users
  for each row execute procedure public.trg_set_verified_at();

-- One-time backfill (runs as the SQL Editor role, so the trigger lets it through).
update public.users u
set verified_at = (
  select max(n.sent_at)
  from public.notifications n
  where n.user_id = u.id
    and n.channel = 'in_app'
    and lower(n.title) in ('account activated', 'organizer application approved')
)
where u.id_verification_status = 'verified'
  and u.verified_at is null;

-- Check: verified accounts that still have no date (no approval notification found).
-- select id, email, role from public.users
-- where id_verification_status = 'verified' and verified_at is null;
