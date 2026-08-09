-- ============================================================
-- NUSA Kasir — Setup Supabase Storage bucket "nusa-backups"
-- Jalankan di: Supabase Dashboard → SQL Editor → Run
-- ============================================================
--
-- CATATAN KEAMANAN:
-- Backup storage requires Supabase Auth. Paths must be {auth.uid}/...
-- The bucket is private; encrypted payloads provide defense in depth.
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

-- 4. All operations require Auth and the first path segment must be auth.uid().
CREATE POLICY "nusa_backups_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'nusa-backups' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "nusa_backups_select" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'nusa-backups' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "nusa_backups_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'nusa-backups' AND (storage.foldername(name))[1] = auth.uid()::text)
  WITH CHECK (bucket_id = 'nusa-backups' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "nusa_backups_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'nusa-backups' AND (storage.foldername(name))[1] = auth.uid()::text);

-- ============================================================
-- Verify
-- ============================================================
SELECT id, name, public FROM storage.buckets WHERE id = 'nusa-backups';
