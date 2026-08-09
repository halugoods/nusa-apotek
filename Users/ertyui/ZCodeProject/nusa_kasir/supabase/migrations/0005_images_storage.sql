-- Create storage bucket for user images
-- Bucket: nusa-images — stores product photos, employee photos, QRIS, logos
-- Each user's images are under: {user_id}/{category}/{filename}

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('nusa-images', 'nusa-images', false, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
ON CONFLICT (id) DO NOTHING;

-- RLS Policies: users can only access their own folder (uid/{category}/*)

-- Allow SELECT: users can read their own images
DROP POLICY IF EXISTS "Users can read own images" ON storage.objects;
CREATE POLICY "Users can read own images"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'nusa-images'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow INSERT: users can upload to their own folder
DROP POLICY IF EXISTS "Users can upload own images" ON storage.objects;
CREATE POLICY "Users can upload own images"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'nusa-images'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow UPDATE: users can update their own images
DROP POLICY IF EXISTS "Users can update own images" ON storage.objects;
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

-- Allow DELETE: users can delete their own images
DROP POLICY IF EXISTS "Users can delete own images" ON storage.objects;
CREATE POLICY "Users can delete own images"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'nusa-images'
  AND auth.uid()::text = (storage.foldername(name))[1]
);
