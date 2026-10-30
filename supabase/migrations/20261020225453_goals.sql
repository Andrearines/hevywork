-- 0005_goals.sql
-- Metas del usuario y registro mínimo de peso corporal (spec 005, RF-1/RF-2).
-- La única fuente de verdad del progreso (`current_value`) es el cliente: se
-- recalcula al cerrar sesión y al sincronizar (RF-3) y se sube con la meta.

-- 1. Metas
CREATE TABLE public.goals (
    id uuid NOT NULL,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type text NOT NULL,
    target_value double precision NOT NULL,
    deadline timestamptz,
    period text,
    metric_ref text,
    status text NOT NULL,
    current_value double precision,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (id)
);

-- 2. Registro mínimo de peso corporal (la spec 006 ampliará las medidas)
CREATE TABLE public.body_weight (
    id uuid NOT NULL,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    weight_kg double precision NOT NULL,
    measured_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (id)
);

-- --------------------------------------------------------
-- SEGURIDAD (Row Level Security - RLS)
-- --------------------------------------------------------

ALTER TABLE public.goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.body_weight ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can select own goals" ON public.goals FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own goals" ON public.goals FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own goals" ON public.goals FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own goals" ON public.goals FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users can select own body_weight" ON public.body_weight FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own body_weight" ON public.body_weight FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own body_weight" ON public.body_weight FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own body_weight" ON public.body_weight FOR DELETE USING (auth.uid() = user_id);

-- --------------------------------------------------------
-- TRIGGERS DE UPDATED_AT
-- --------------------------------------------------------

CREATE TRIGGER update_goals_modtime BEFORE UPDATE ON public.goals FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER update_body_weight_modtime BEFORE UPDATE ON public.body_weight FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- --------------------------------------------------------
-- RPC PARA LOGIN LOCAL -> REMOTO (claim_local_data)
-- --------------------------------------------------------

-- Extiende el claim con las metas y el peso registrado antes del login.
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
