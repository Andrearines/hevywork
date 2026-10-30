-- 0002_rls_y_funciones.sql
-- RLS, triggers de `updated_at` y claim de los datos locales al iniciar
-- sesión (spec 001, RF-13/RF-16). Reconstruida desde el esquema aplicado en
-- el proyecto remoto.

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_sets ENABLE ROW LEVEL SECURITY;

CREATE POLICY profiles_select_own ON public.profiles
    FOR SELECT USING ((select auth.uid()) = id);
CREATE POLICY profiles_insert_own ON public.profiles
    FOR INSERT WITH CHECK ((select auth.uid()) = id);
CREATE POLICY profiles_update_own ON public.profiles
    FOR UPDATE USING ((select auth.uid()) = id)
    WITH CHECK ((select auth.uid()) = id);
CREATE POLICY profiles_delete_own ON public.profiles
    FOR DELETE USING ((select auth.uid()) = id);

CREATE POLICY workouts_select_own ON public.workouts
    FOR SELECT USING ((select auth.uid()) = user_id);
CREATE POLICY workouts_insert_own ON public.workouts
    FOR INSERT WITH CHECK ((select auth.uid()) = user_id);
CREATE POLICY workouts_update_own ON public.workouts
    FOR UPDATE USING ((select auth.uid()) = user_id)
    WITH CHECK ((select auth.uid()) = user_id);
CREATE POLICY workouts_delete_own ON public.workouts
    FOR DELETE USING ((select auth.uid()) = user_id);

CREATE POLICY workout_exercises_select_own ON public.workout_exercises
    FOR SELECT USING ((select auth.uid()) = user_id);
CREATE POLICY workout_exercises_insert_own ON public.workout_exercises
    FOR INSERT WITH CHECK ((select auth.uid()) = user_id);
CREATE POLICY workout_exercises_update_own ON public.workout_exercises
    FOR UPDATE USING ((select auth.uid()) = user_id)
    WITH CHECK ((select auth.uid()) = user_id);
CREATE POLICY workout_exercises_delete_own ON public.workout_exercises
    FOR DELETE USING ((select auth.uid()) = user_id);

CREATE POLICY workout_sets_select_own ON public.workout_sets
    FOR SELECT USING ((select auth.uid()) = user_id);
CREATE POLICY workout_sets_insert_own ON public.workout_sets
    FOR INSERT WITH CHECK ((select auth.uid()) = user_id);
CREATE POLICY workout_sets_update_own ON public.workout_sets
    FOR UPDATE USING ((select auth.uid()) = user_id)
    WITH CHECK ((select auth.uid()) = user_id);
CREATE POLICY workout_sets_delete_own ON public.workout_sets
    FOR DELETE USING ((select auth.uid()) = user_id);

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $$
begin
  new.updated_at := now();
  return new;
end;
$$;

CREATE TRIGGER trg_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_workouts_updated_at
    BEFORE UPDATE ON public.workouts
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_workout_exercises_updated_at
    BEFORE UPDATE ON public.workout_exercises
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_workout_sets_updated_at
    BEFORE UPDATE ON public.workout_sets
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

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

  -- La PK de profiles es el id de auth.users, así que si ya existe una fila
  -- para v_uid el update rompería la clave primaria y se deja como está.
  update public.profiles p
    set id = v_uid
    where p.id = p_local_user_id
      and not exists (select 1 from public.profiles x where x.id = v_uid);
end;
$$;
