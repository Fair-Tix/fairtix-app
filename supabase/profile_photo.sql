-- =============================================================================
-- FairTix — Profile photo storage (Event Goer, optional)
-- Run this in the Supabase SQL Editor AFTER schema.sql and policies.sql.
-- Safe to re-run.
--
-- Why this file exists: public.users.profile_photo_url already existed in
-- schema.sql, but there was no Storage bucket for it, so the app had
-- nowhere to upload a profile photo to (test: "Can upload a profile photo").
--
-- profile_photos/{userId}/{fileName}
--   * Public READ  — the photo is shown by plain URL; the file name is
--     timestamped so the link isn't guessable, and a profile photo is not
--     sensitive the way the ID / selfie in identity_docs are.
--   * WRITE limited to the owner's own {userId}/ folder.
--   * 5 MB limit, images only.
-- =============================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile_photos',
  'profile_photos',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "profile_photos_public_read" on storage.objects;
create policy "profile_photos_public_read"
  on storage.objects for select
  using (bucket_id = 'profile_photos');

drop policy if exists "profile_photos_insert_owner" on storage.objects;
create policy "profile_photos_insert_owner"
  on storage.objects for insert
  with check (
    bucket_id = 'profile_photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "profile_photos_update_owner" on storage.objects;
create policy "profile_photos_update_owner"
  on storage.objects for update
  using (
    bucket_id = 'profile_photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Lets the app clean up the previous photo when a new one replaces it, or
-- when the user removes their photo.
drop policy if exists "profile_photos_delete_owner" on storage.objects;
create policy "profile_photos_delete_owner"
  on storage.objects for delete
  using (
    bucket_id = 'profile_photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
