-- Add foto_path column to socis (nullable; stores the filename in the storage bucket)
ALTER TABLE public.socis
  ADD COLUMN IF NOT EXISTS foto_path TEXT;

COMMENT ON COLUMN public.socis.foto_path IS 'Filename dins del bucket socis-fotos (normalment <numero_soci>.jpg). NULL si no hi ha foto.';

-- Create private bucket socis-fotos
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'socis-fotos',
  'socis-fotos',
  false,
  5242880,  -- 5MB
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
  SET public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Remove any previous policies on this bucket (in case the migration is re-run)
DROP POLICY IF EXISTS "socis_fotos_admin_select" ON storage.objects;
DROP POLICY IF EXISTS "socis_fotos_admin_insert" ON storage.objects;
DROP POLICY IF EXISTS "socis_fotos_admin_update" ON storage.objects;
DROP POLICY IF EXISTS "socis_fotos_admin_delete" ON storage.objects;

-- Admin-only access to objects in the socis-fotos bucket.
-- Checks the `admins` table (email = auth email).
CREATE POLICY "socis_fotos_admin_select"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'socis-fotos'
  AND EXISTS (
    SELECT 1 FROM public.admins a
    WHERE a.email = (auth.jwt() ->> 'email')
  )
);

CREATE POLICY "socis_fotos_admin_insert"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'socis-fotos'
  AND EXISTS (
    SELECT 1 FROM public.admins a
    WHERE a.email = (auth.jwt() ->> 'email')
  )
);

CREATE POLICY "socis_fotos_admin_update"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'socis-fotos'
  AND EXISTS (
    SELECT 1 FROM public.admins a
    WHERE a.email = (auth.jwt() ->> 'email')
  )
)
WITH CHECK (
  bucket_id = 'socis-fotos'
  AND EXISTS (
    SELECT 1 FROM public.admins a
    WHERE a.email = (auth.jwt() ->> 'email')
  )
);

CREATE POLICY "socis_fotos_admin_delete"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'socis-fotos'
  AND EXISTS (
    SELECT 1 FROM public.admins a
    WHERE a.email = (auth.jwt() ->> 'email')
  )
);
