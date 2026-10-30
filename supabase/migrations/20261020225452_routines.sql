-- 0004_routines.sql
-- Plantillas (rutinas), sus ejercicios y las columnas de objetivo clonadas
-- a la sesión nacida de una rutina (spec 004, RF-1 y RF-2).

-- 1. Rutinas (plantillas de entrenamiento)
CREATE TABLE public.routines (
    id uuid NOT NULL,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name text NOT NULL,
    description text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (id)
);

-- 2. Ejercicios de la rutina (objetivo + progresión configurable)
CREATE TABLE public.routine_exercises (
    id uuid NOT NULL,
    routine_id uuid NOT NULL REFERENCES public.routines(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    exercise_id text NOT NULL,
    order_index integer NOT NULL,
    target_sets integer,
    target_reps integer,
    target_rir integer,
    suggested_weight_kg real,
    auto_progress boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (id),
    UNIQUE (routine_id, order_index)
);

-- 3. La sesión nacida de una rutina lleva el id de la plantilla (RF-2)
ALTER TABLE public.workouts ADD COLUMN IF NOT EXISTS routine_id uuid
    REFERENCES public.routines(id) ON DELETE SET NULL;

-- 4. El objetivo se clona a los ejercicios de la sesión (RF-2)
ALTER TABLE public.workout_exercises ADD COLUMN IF NOT EXISTS target_sets integer;
ALTER TABLE public.workout_exercises ADD COLUMN IF NOT EXISTS target_reps integer;
ALTER TABLE public.workout_exercises ADD COLUMN IF NOT EXISTS target_rir integer;
ALTER TABLE public.workout_exercises ADD COLUMN IF NOT EXISTS suggested_weight_kg real;

-- --------------------------------------------------------
-- SEGURIDAD (Row Level Security - RLS)
-- --------------------------------------------------------

ALTER TABLE public.routines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.routine_exercises ENABLE ROW LEVEL SECURITY;

-- Políticas para routines
CREATE POLICY "Users can select own routines" ON public.routines FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own routines" ON public.routines FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own routines" ON public.routines FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own routines" ON public.routines FOR DELETE USING (auth.uid() = user_id);

-- Políticas para routine_exercises
CREATE POLICY "Users can select own routine_exercises" ON public.routine_exercises FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own routine_exercises" ON public.routine_exercises FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own routine_exercises" ON public.routine_exercises FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own routine_exercises" ON public.routine_exercises FOR DELETE USING (auth.uid() = user_id);

-- --------------------------------------------------------
-- TRIGGERS DE UPDATED_AT
-- --------------------------------------------------------

CREATE TRIGGER update_routines_modtime BEFORE UPDATE ON public.routines FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER update_routine_exercises_modtime BEFORE UPDATE ON public.routine_exercises FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- --------------------------------------------------------
-- RPC PARA LOGIN LOCAL -> REMOTO (claim_local_data)
-- --------------------------------------------------------

-- Extiende el claim con las rutinas: transfiere la propiedad al usuario
-- autenticado igual que workouts y series.
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

  -- La PK de profiles es el id de auth.users, así que si ya existe una fila
  -- para v_uid el update rompería la clave primaria y se deja como está.
  update public.profiles p
    set id = v_uid
    where p.id = p_local_user_id
      and not exists (select 1 from public.profiles x where x.id = v_uid);
end;
$$;
