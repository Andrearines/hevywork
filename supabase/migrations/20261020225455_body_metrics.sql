-- 0007_body_metrics.sql
-- Registro diario de peso y medidas corporales (spec 006, RF-1): una fila por
-- usuario y fecha, idempotente por (user_id, date). Sustituye al body_weight
-- de la 005, que se consolida aquí (peso opcional + medidas + notas).

-- 1. Registro diario de peso y medidas
CREATE TABLE public.body_metrics (
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    date date NOT NULL,
    weight_kg double precision,
    measures_json jsonb,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, date)
);

-- 2. Consolidación de los pesos previos (una fila por día con su peso)
INSERT INTO public.body_metrics (user_id, date, weight_kg, created_at, updated_at)
SELECT user_id, measured_at::date, weight_kg, created_at, updated_at
FROM public.body_weight
ON CONFLICT DO NOTHING;

DROP TABLE public.body_weight;

-- --------------------------------------------------------
-- SEGURIDAD (Row Level Security - RLS)
-- --------------------------------------------------------

ALTER TABLE public.body_metrics ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can select own body_metrics" ON public.body_metrics FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own body_metrics" ON public.body_metrics FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own body_metrics" ON public.body_metrics FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own body_metrics" ON public.body_metrics FOR DELETE USING (auth.uid() = user_id);

-- --------------------------------------------------------
-- TRIGGERS DE UPDATED_AT
-- --------------------------------------------------------

CREATE TRIGGER update_body_metrics_modtime BEFORE UPDATE ON public.body_metrics FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- --------------------------------------------------------
-- RPC PARA LOGIN LOCAL -> REMOTO (claim_local_data)
-- --------------------------------------------------------

-- Extiende el claim con los registros de peso y medidas antes del login.
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

  -- La PK de profiles es el id de auth.users, así que si ya existe una fila
  -- para v_uid el update rompería la clave primaria y se deja como está.
  update public.profiles p
    set id = v_uid
    where p.id = p_local_user_id
      and not exists (select 1 from public.profiles x where x.id = v_uid);
end;
$$;
