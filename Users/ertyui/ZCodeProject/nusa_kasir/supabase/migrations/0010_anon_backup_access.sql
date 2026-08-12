-- ============================================================
-- 0010 — Auto cloud sync: allow anon + authenticated backup access
-- ============================================================
-- Why: file-based auto-sync runs in the background on every device
-- (no interactive login). The app signs in anonymously once, so the
-- backup upload/download works without the user opening Google auth.
-- Paths stay namespaced {googleUserId}/{productId}/... and payloads
-- are AES-GCM encrypted with the Google user ID (defense in depth),
-- so opening access to anon+authenticated does NOT expose data.
-- ============================================================

begin;

drop policy if exists "nusa_backups_insert" on storage.objects;
drop policy if exists "nusa_backups_select" on storage.objects;
drop policy if exists "nusa_backups_update" on storage.objects;
drop policy if exists "nusa_backups_delete" on storage.objects;

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

commit;
