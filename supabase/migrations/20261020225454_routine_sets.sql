-- 0006_routine_sets.sql
-- Series planificadas de una rutina, una a una (spec 004, RF-1): tipo, peso,
-- repeticiones, RIR y descanso. El descanso planificado se clona también a
-- las series de la sesión nacida de la rutina (RF-2).

-- 1. Series planificadas de la rutina
CREATE TABLE public.routine_sets (
    id uuid NOT NULL,
    routine_exercise_id uuid NOT NULL REFERENCES public.routine_exercises(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    order_index integer NOT NULL,
    set_type text NOT NULL DEFAULT 'normal',
    weight_kg real NOT NULL DEFAULT 0.0,
    reps integer NOT NULL DEFAULT 0,
    rir integer NOT NULL DEFAULT 0,
    rest_seconds integer,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (id),
    UNIQUE (routine_exercise_id, order_index)
);

-- 2. Descanso planificado de la serie clonado a la sesión (RF-2)
ALTER TABLE public.workout_sets ADD COLUMN IF NOT EXISTS rest_seconds integer;

-- --------------------------------------------------------
-- SEGURIDAD (Row Level Security - RLS)
-- --------------------------------------------------------

ALTER TABLE public.routine_sets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can select own routine_sets" ON public.routine_sets FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own routine_sets" ON public.routine_sets FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own routine_sets" ON public.routine_sets FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own routine_sets" ON public.routine_sets FOR DELETE USING (auth.uid() = user_id);

-- --------------------------------------------------------
-- TRIGGERS DE UPDATED_AT
-- --------------------------------------------------------

CREATE TRIGGER update_routine_sets_modtime BEFORE UPDATE ON public.routine_sets FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- --------------------------------------------------------
-- RPC PARA LOGIN LOCAL -> REMOTO (claim_local_data)
-- --------------------------------------------------------

-- Extiende el claim con las series planificadas antes del login.
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

  update public.body_weight
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
