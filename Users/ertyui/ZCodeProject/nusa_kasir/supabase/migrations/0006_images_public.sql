-- Make nusa-images bucket PUBLIC so the web store can serve product photos
-- Write operations (INSERT/UPDATE/DELETE) remain RLS-protected to owner only

-- 1. Set bucket to public
UPDATE storage.buckets
SET public = true
WHERE id = 'nusa-images';

-- 2. Drop ALL old SELECT policies that required auth.uid() match
-- (0005 created "Users can read own images", so we must drop that exact name too)
DROP POLICY IF EXISTS "Users can read own images" ON storage.objects;
DROP POLICY IF EXISTS "Users can view own images" ON storage.objects;

-- 3. Create public read policy — anyone can view images
CREATE POLICY "Public can view images"
ON storage.objects FOR SELECT
USING (bucket_id = 'nusa-images');

-- 4. Ensure INSERT/UPDATE/DELETE are still owner-scoped (recreate if needed)
-- These policies already exist from 0005_images_storage.sql,
-- but we recreate them here for safety
DROP POLICY IF EXISTS "Users can upload own images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own images" ON storage.objects;

CREATE POLICY "Users can upload own images"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'nusa-images'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can update own images"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'nusa-images'
  AND auth.uid()::text = (storage.foldername(name))[1]
)
WITH CHECK (
  bucket_id = 'nusa-images'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can delete own images"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'nusa-images'
  AND auth.uid()::text = (storage.foldername(name))[1]
);
