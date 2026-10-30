-- 0009_body_composition.sql
-- Composición corporal y datos del atleta (spec 009, RF-1/RF-4): % de grasa y
-- masa magra por registro diario, más sexo y altura del perfil para la
-- estimación US Navy. Columnas nullable: los registros y perfiles previos
-- siguen siendo válidos. La RLS de ambas tablas no cambia.

ALTER TABLE public.body_metrics ADD COLUMN IF NOT EXISTS body_fat_pct double precision;
ALTER TABLE public.body_metrics ADD COLUMN IF NOT EXISTS lean_mass_kg double precision;

ALTER TABLE public.body_metrics
    ADD CONSTRAINT body_metrics_body_fat_pct_range
    CHECK (body_fat_pct IS NULL OR body_fat_pct BETWEEN 0 AND 70);

ALTER TABLE public.body_metrics
    ADD CONSTRAINT body_metrics_lean_mass_kg_positive
    CHECK (lean_mass_kg IS NULL OR lean_mass_kg > 0);

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS sex text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS height_cm double precision;

ALTER TABLE public.profiles
    ADD CONSTRAINT profiles_sex_values
    CHECK (sex IS NULL OR sex IN ('male', 'female'));

ALTER TABLE public.profiles
    ADD CONSTRAINT profiles_height_cm_positive
    CHECK (height_cm IS NULL OR height_cm > 0);
