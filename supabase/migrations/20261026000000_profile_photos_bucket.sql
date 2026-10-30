-- Bucket para fotos de perfil (público para leer, autenticado para escribir)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url text;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('profile-photos', 'profile-photos', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Política: lectura pública
CREATE POLICY "Public read access" ON storage.objects
  FOR SELECT USING (bucket_id = 'profile-photos');

-- Política: usuarios autenticados pueden subir/actualizar su propia foto
CREATE POLICY "Authenticated users can upload their own avatar" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'profile-photos' AND
    auth.role() = 'authenticated' AND
    (storage.foldername(name))[1] = 'avatars' AND
    (storage.filename(name)) = auth.uid() || '.jpg'
  );

CREATE POLICY "Authenticated users can update their own avatar" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'profile-photos' AND
    auth.role() = 'authenticated' AND
    (storage.foldername(name))[1] = 'avatars' AND
    (storage.filename(name)) = auth.uid() || '.jpg'
  );

-- Política: usuarios autenticados pueden borrar su propia foto
CREATE POLICY "Authenticated users can delete their own avatar" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'profile-photos' AND
    auth.role() = 'authenticated' AND
    (storage.foldername(name))[1] = 'avatars' AND
    (storage.filename(name)) = auth.uid() || '.jpg'
  );