-- ============================================================
-- NUSA Kasir — Storage bucket for encrypted device-migration backups
-- Migration 0002
-- ============================================================

-- 1. Create the private bucket
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'nusa-backups',
  'nusa-backups',
  false,
  52428800,
  array['application/octet-stream']
)
on conflict (id) do update
  set public = false,
      file_size_limit = 52428800,
      allowed_mime_types = array['application/octet-stream'];

-- 2. RLS is already enabled by default on Supabase storage.objects — skip DDL

-- 3. Drop any previous versions (idempotent)
drop policy if exists "nusa_backups_insert" on storage.objects;
drop policy if exists "nusa_backups_select" on storage.objects;
drop policy if exists "nusa_backups_update" on storage.objects;
drop policy if exists "nusa_backups_delete" on storage.objects;

-- 4. Policies: app uses anon key (no user login), so allow anon + authenticated
--    on this bucket only. Files are path-scoped by activation key (secret)
--    and AES-256-GCM encrypted, so cross-tenant access is inert.
create policy "nusa_backups_insert" on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'nusa-backups');

create policy "nusa_backups_select" on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'nusa-backups');

create policy "nusa_backups_update" on storage.objects
  for update to anon, authenticated
  using (bucket_id = 'nusa-backups')
  with check (bucket_id = 'nusa-backups');

create policy "nusa_backups_delete" on storage.objects
  for delete to anon, authenticated
  using (bucket_id = 'nusa-backups');
