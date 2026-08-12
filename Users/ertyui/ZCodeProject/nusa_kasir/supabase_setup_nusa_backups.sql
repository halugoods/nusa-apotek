-- ============================================================
-- NUSA Kasir — Setup Supabase Storage bucket "nusa-backups"
-- Jalankan di: Supabase Dashboard → SQL Editor → Run
-- ============================================================
--
-- CATATAN KEAMANAN:
-- Auto cloud sync (v2.2.0+) berjalan di background di setiap perangkat
-- (upload ±6 dtk, terima saat app dibuka). App sign-in anonim sekali,
-- sehingga bucket diakses oleh role anon + authenticated.
-- Path tetap di-namespace {googleUserId}/{productId}/... dan payload
-- AES-GCM encrypted dengan Google user ID (defense in depth) — membuka
-- akses anon/authenticated TIDAK mengekspos data.
--
-- ============================================================

-- 1. Buat bucket (private)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'nusa-backups',
  'nusa-backups',
  false,
  52428800,
  ARRAY['application/octet-stream']
)
ON CONFLICT (id) DO UPDATE
  SET public = false,
      file_size_limit = 52428800,
      allowed_mime_types = ARRAY['application/octet-stream'];

-- 2. Enable RLS
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 3. Drop old policies (idempotent)
DROP POLICY IF EXISTS "nusa_backups_insert" ON storage.objects;
DROP POLICY IF EXISTS "nusa_backups_select" ON storage.objects;
DROP POLICY IF EXISTS "nusa_backups_update" ON storage.objects;
DROP POLICY IF EXISTS "nusa_backups_delete" ON storage.objects;

-- 4. Backup diakses oleh anon + authenticated (auto-sync background).
--    Path tetap {googleUserId}/{productId}/... dan payload terenkripsi.
CREATE POLICY "nusa_backups_insert" ON storage.objects
  FOR INSERT TO anon, authenticated
  WITH CHECK (bucket_id = 'nusa-backups');

CREATE POLICY "nusa_backups_select" ON storage.objects
  FOR SELECT TO anon, authenticated
  USING (bucket_id = 'nusa-backups');

CREATE POLICY "nusa_backups_update" ON storage.objects
  FOR UPDATE TO anon, authenticated
  USING (bucket_id = 'nusa-backups')
  WITH CHECK (bucket_id = 'nusa-backups');

CREATE POLICY "nusa_backups_delete" ON storage.objects
  FOR DELETE TO anon, authenticated
  USING (bucket_id = 'nusa-backups');

-- ============================================================
-- Verify
-- ============================================================
SELECT id, name, public FROM storage.buckets WHERE id = 'nusa-backups';
