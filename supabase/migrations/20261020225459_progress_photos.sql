-- 0010_progress_photos.sql
-- Fotos de progreso (spec 009, RF-5/RF-6): una fila por foto con su vista
-- (front/side/back) y la clave del fichero en el bucket privado
-- `progress-photos`. El fichero se sube en segundo plano desde la app
-- (RF-7) y cada objeto queda limitado a la carpeta del propio usuario.

-- 1. Tabla de fotos
CREATE TABLE public.progress_photos (
    id uuid NOT NULL PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    date date NOT NULL,
    view text NOT NULL CHECK (view IN ('front', 'side', 'back')),
    path text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX progress_photos_user_date_idx
    ON public.progress_photos (user_id, date DESC);

-- --------------------------------------------------------
-- SEGURIDAD (Row Level Security - RLS)
-- --------------------------------------------------------

ALTER TABLE public.progress_photos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can select own progress_photos" ON public.progress_photos FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own progress_photos" ON public.progress_photos FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own progress_photos" ON public.progress_photos FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own progress_photos" ON public.progress_photos FOR DELETE USING (auth.uid() = user_id);

-- --------------------------------------------------------
-- TRIGGERS DE UPDATED_AT
-- --------------------------------------------------------

CREATE TRIGGER update_progress_photos_modtime BEFORE UPDATE ON public.progress_photos FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- --------------------------------------------------------
-- BUCKET PRIVADO DE STORAGE (RF-6)
-- --------------------------------------------------------

-- Las fotos son datos personales: bucket privado, JPEG, 500 KB por archivo
-- (NFR de compresión de la 009).
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'progress-photos',
    'progress-photos',
    false,
    524288,
    array['image/jpeg']
)
ON CONFLICT (id) DO NOTHING;

-- Cada objeto vive en la carpeta del usuario autenticado (`<uid>/<id>.jpg`).
CREATE POLICY "Users can view own progress photos" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'progress-photos' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can upload own progress photos" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'progress-photos' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can update own progress photos" ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'progress-photos' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can delete own progress photos" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'progress-photos' AND (storage.foldername(name))[1] = auth.uid()::text);

-- --------------------------------------------------------
-- RPC PARA LOGIN LOCAL -> REMOTO (claim_local_data)
-- --------------------------------------------------------

-- Extiende el claim con las fotos de progreso antes del login.
CREATE OR REPLACE FUNCTION public.claim_local_data(p_local_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'claim_local_data requiere sesion iniciada'
      using errcode = '42501';
  end if;

  if p_local_user_id is null or p_local_user_id = v_uid then
    return;
  end if;

  update public.workouts
    set user_id = v_uid
    where user_id = p_local_user_id;

  update public.workout_exercises
    set user_id = v_uid
    where user_id = p_local_user_id;

  update public.workout_sets
    set user_id = v_uid
    where user_id = p_local_user_id;

  update public.routines
    set user_id = v_uid
    where user_id = p_local_user_id;

  update public.routine_exercises
    set user_id = v_uid
    where user_id = p_local_user_id;

  update public.routine_sets
    set user_id = v_uid
    where user_id = p_local_user_id;

  update public.goals
    set user_id = v_uid
    where user_id = p_local_user_id;

  update public.body_metrics
    set user_id = v_uid
    where user_id = p_local_user_id;

  update public.progress_photos
    set user_id = v_uid
    where user_id = p_local_user_id;

  -- La PK de profiles es el id de auth.users, así que si ya existe una fila
  -- para v_uid el update rompería la clave primaria y se deja como está.
  update public.profiles p
    set id = v_uid
    where p.id = p_local_user_id
      and not exists (select 1 from public.profiles x where x.id = v_uid);
end;
$$;
