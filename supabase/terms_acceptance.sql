-- =============================================================================
-- FairTix — Terms & Privacy acceptance (one version + one timestamp per user).
-- Run in the Supabase SQL Editor AFTER schema.sql, policies.sql and
-- security_patch.sql. Safe to re-run.
--
-- WHAT IS RECORDED
--   users.terms_version      the version label of the Terms & Privacy text the
--                            user accepted (kTermsVersion in
--                            lib/models/legal_terms.dart, mirrored by
--                            current_terms_version() below).
--   users.terms_accepted_at  when the server recorded that acceptance.
--   Both are NULL (never one without the other) until the user accepts.
--
-- HOW IT GETS THERE
--   * Registration (eventgoer and organizer): the app sends terms_version in
--     the sign-up metadata after the person ticks the checkbox. A BEFORE INSERT
--     trigger on public.users reads it from auth.users, keeps it only if it is
--     the CURRENT version, and stamps the time itself (a client clock or a
--     made-up timestamp is never used). handle_new_auth_user() in schema.sql is
--     deliberately NOT replaced, so nothing it does is lost.
--   * Existing users: they have NULL, so the app asks them once (and again only
--     when the version changes) and calls accept_terms(). Nobody is backfilled:
--     consent that was never given is not recorded.
--
-- PROTECTION
--   protect_user_columns() (security_patch.sql) is left exactly as it is: it
--   guards role, status, identity and verification columns. The two terms
--   columns get their own trigger below, so that function is not rewritten
--   (other files may rely on its current body). A signed-in non-admin can
--   change the terms columns only through accept_terms(); a direct
--   PATCH on public.users is refused. Admins, the SQL Editor and the
--   service role are unaffected, as with protect_user_columns().
--
-- TO PUBLISH NEW TERMS: change the literal in current_terms_version() and
-- kTermsVersion together; every user is asked again on next sign-in.
-- =============================================================================

alter table public.users add column if not exists terms_version text;
alter table public.users add column if not exists terms_accepted_at timestamptz;

-- Both set or both empty.
alter table public.users drop constraint if exists users_terms_pair_check;
alter table public.users add constraint users_terms_pair_check
  check ((terms_version is null) = (terms_accepted_at is null));

-- The version of the Terms & Privacy text that is in force.
create or replace function public.current_terms_version()
returns text
language sql
immutable
as $$ select '2026-11-07'::text $$;

-- ── Registration: stamp acceptance from the sign-up metadata ─────────────
create or replace function public.stamp_terms_on_signup()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_claimed text;
begin
  -- Never trust values supplied on the INSERT itself.
  new.terms_version := null;
  new.terms_accepted_at := null;

  select u.raw_user_meta_data->>'terms_version'
    into v_claimed
    from auth.users u
    where u.id = new.id;

  if v_claimed is not null and v_claimed = public.current_terms_version() then
    new.terms_version := v_claimed;
    new.terms_accepted_at := now();
  end if;

  return new;
end;
$$;

revoke all on function public.stamp_terms_on_signup() from public, anon, authenticated;

drop trigger if exists stamp_terms_on_signup on public.users;
create trigger stamp_terms_on_signup
  before insert on public.users
  for each row execute procedure public.stamp_terms_on_signup();

-- ── Protect the two columns from direct edits ────────────────────────────
create or replace function public.protect_terms_columns()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  -- No signed-in user (SQL Editor, service role) or an admin: allowed.
  if auth.uid() is null or public.is_admin() then
    return new;
  end if;

  if (new.terms_version is distinct from old.terms_version
      or new.terms_accepted_at is distinct from old.terms_accepted_at)
     and coalesce(current_setting('fairtix.terms_rpc', true), '') <> '1' then
    raise exception 'Terms acceptance can only be recorded by accepting the terms.';
  end if;

  return new;
end;
$$;

revoke all on function public.protect_terms_columns() from public, anon, authenticated;

drop trigger if exists protect_terms_columns on public.users;
create trigger protect_terms_columns
  before update on public.users
  for each row execute procedure public.protect_terms_columns();

-- ── The one way a signed-in user records acceptance ──────────────────────
-- Accepts only the version that is in force (a stale app cannot accept an
-- old text), stamps the time on the server, and returns it.
create or replace function public.accept_terms(p_version text)
returns timestamptz
language plpgsql
security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_at timestamptz;
begin
  if v_uid is null then
    raise exception 'You need to be signed in to accept the terms.';
  end if;
  if p_version is distinct from public.current_terms_version() then
    raise exception 'The Terms & Privacy were updated. Please update the app and try again.';
  end if;

  -- Transaction-local switch that protect_terms_columns() looks for.
  perform set_config('fairtix.terms_rpc', '1', true);

  update public.users
     set terms_version = p_version,
         terms_accepted_at = now()
   where id = v_uid
  returning terms_accepted_at into v_at;

  perform set_config('fairtix.terms_rpc', '', true);

  if v_at is null then
    raise exception 'Your account could not be found.';
  end if;
  return v_at;
end;
$$;

revoke all on function public.accept_terms(text) from public, anon;
grant execute on function public.accept_terms(text) to authenticated;
