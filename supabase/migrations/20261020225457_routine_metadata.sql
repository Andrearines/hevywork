-- 0008_routine_metadata.sql
-- Metadata de planificación de la plantilla (spec 008, T-5): categoría,
-- nivel, objetivo y días semanales. Columnas nullable: las rutinas previas
-- siguen siendo válidas sin metadata. La RLS de routines no cambia.

ALTER TABLE public.routines ADD COLUMN IF NOT EXISTS category text;
ALTER TABLE public.routines ADD COLUMN IF NOT EXISTS level text;
ALTER TABLE public.routines ADD COLUMN IF NOT EXISTS goal text;
ALTER TABLE public.routines ADD COLUMN IF NOT EXISTS target_days integer;
