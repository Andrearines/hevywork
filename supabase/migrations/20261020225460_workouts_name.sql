-- 0012_workouts_name.sql
-- Nombre de la sesión (spec 001, RF-13): drift lo guarda desde la 002 y el
-- remoto debe conservarlo para que sobreviva a una reinstalación.

ALTER TABLE public.workouts ADD COLUMN IF NOT EXISTS name text;
