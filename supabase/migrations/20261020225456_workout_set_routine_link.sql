-- 0007_workout_set_routine_link.sql
-- Vínculo de una serie de la sesión con la serie planificada de la rutina que
-- la originó (spec 004, RF-2/RF-4). Al terminar la sesión, la rutina adopta el
-- peso, las repeticiones y el RIR reales de cada serie confirmada.
--
-- No lleva clave foránea: una sesión histórica debe sobrevivir al borrado de
-- la rutina. La columna es informativa para reconstruir el vínculo.

ALTER TABLE public.workout_sets
    ADD COLUMN IF NOT EXISTS routine_set_id uuid;
