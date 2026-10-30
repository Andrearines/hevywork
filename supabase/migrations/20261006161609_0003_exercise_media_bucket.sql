-- Spec 001, RF-3. Bucket público para la media del catálogo.
--
-- Las miniaturas JPG van empaquetadas como asset; los GIF se sirven desde
-- Storage y se cachean en el dispositivo. Un bucket público se lee por la URL
-- pública sin políticas en storage.objects.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'exercise-media',
  'exercise-media',
  true,
  5242880,                  -- 5 MB por archivo; el GIF más pesado pesa 227 KB
  array['image/gif']
)
on conflict (id) do nothing;
