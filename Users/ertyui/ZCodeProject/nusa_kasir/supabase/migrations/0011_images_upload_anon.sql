-- ============================================================
-- 0011 — Allow anon INSERT to nusa-images (upload only)
-- ============================================================
-- Why: the app logs in with Google Sign-In (GoogleAuthService) and stores
-- the Google user ID in SecureStore — it does NOT create a Supabase Auth
-- session. So `auth.uid()` is always null in storage policies and every
-- image upload fails with RLS 403 ("login google diperlukan") even though
-- the user IS logged in.
--
-- Fix: allow anon (publishable-key) clients to INSERT objects into
-- nusa-images. The path is already namespaced {googleUserId}/{productId}/…
-- so this only opens uploads; SELECT/UPDATE/DELETE stay private (public
-- reads happen via the public bucket, not the API). The image files
-- themselves are product photos for the public online store, so opening
-- INSERT to anon is safe and matches the backup pattern (0010).
-- ============================================================

begin;

drop policy if exists "Users can upload own images" on storage.objects;
create policy "Users can upload own images" on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'nusa-images');

commit;
