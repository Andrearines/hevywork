-- 0011_community_templates.sql
-- Catálogo compartido de plantillas comunitarias (spec 010): solo lectura
-- para todos los usuarios, sin `user_id`. Excepción declarada a la
-- constitución §4 (análoga al catálogo local de ejercicios).

CREATE TABLE public.templates (
    id uuid NOT NULL PRIMARY KEY,
    name text NOT NULL,
    description text,
    category text,
    level text,
    goal text,
    target_days integer,
    weeks integer,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.template_days (
    id uuid NOT NULL PRIMARY KEY,
    template_id uuid NOT NULL REFERENCES public.templates(id) ON DELETE CASCADE,
    order_index integer NOT NULL,
    name text NOT NULL,
    CONSTRAINT uniq_template_day_order UNIQUE (template_id, order_index)
);

CREATE TABLE public.template_exercises (
    id uuid NOT NULL PRIMARY KEY,
    template_day_id uuid NOT NULL REFERENCES public.template_days(id) ON DELETE CASCADE,
    exercise_id text NOT NULL,
    order_index integer NOT NULL,
    CONSTRAINT uniq_template_exercise_order UNIQUE (template_day_id, order_index)
);

CREATE TABLE public.template_sets (
    id uuid NOT NULL PRIMARY KEY,
    template_exercise_id uuid NOT NULL REFERENCES public.template_exercises(id) ON DELETE CASCADE,
    order_index integer NOT NULL,
    set_type text NOT NULL DEFAULT 'normal',
    weight_kg numeric NOT NULL DEFAULT 0,
    reps integer NOT NULL DEFAULT 0,
    rir integer NOT NULL DEFAULT 0,
    rest_seconds integer,
    CONSTRAINT uniq_template_set_order UNIQUE (template_exercise_id, order_index)
);

CREATE INDEX idx_template_days_template ON public.template_days (template_id);
CREATE INDEX idx_template_exercises_day ON public.template_exercises (template_day_id);
CREATE INDEX idx_template_sets_exercise ON public.template_sets (template_exercise_id);

ALTER TABLE public.templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.template_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.template_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.template_sets ENABLE ROW LEVEL SECURITY;

CREATE POLICY templates_read_all ON public.templates FOR SELECT USING (true);
CREATE POLICY template_days_read_all ON public.template_days FOR SELECT USING (true);
CREATE POLICY template_exercises_read_all ON public.template_exercises FOR SELECT USING (true);
CREATE POLICY template_sets_read_all ON public.template_sets FOR SELECT USING (true);

-- Seed curado (idempotente): seis programas verificados con ejercicios
-- reales del catálogo local.

INSERT INTO public.templates (id, name, description, category, level, goal, target_days, weeks)
VALUES ('dc4ae14a-aa6e-5a68-8c92-10b4c84d9dfb', 'Cuerpo completo · Iniciación', 'Tres sesiones semanales para aprender los patrones básicos con barra y volumen moderado.', 'Full Body', 'Principiante', 'Adaptación', 3, 6)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_days (id, template_id, order_index, name)
VALUES ('a78e0339-5fe0-5185-bed7-0f7c04441b66', 'dc4ae14a-aa6e-5a68-8c92-10b4c84d9dfb', 1, 'Cuerpo completo')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('611e2027-9972-5c5f-826e-ad84830e43ea', 'a78e0339-5fe0-5185-bed7-0f7c04441b66', '0043', 1)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('6c6a6069-a0c5-57f0-8a21-8e90d7df0deb', '611e2027-9972-5c5f-826e-ad84830e43ea', 1, 'normal', 0, 8, 3, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('c0195359-7736-5771-a607-cf5524751c47', '611e2027-9972-5c5f-826e-ad84830e43ea', 2, 'normal', 0, 8, 3, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('78f2eeb8-ff9f-57fa-aa36-64e3f164cc78', '611e2027-9972-5c5f-826e-ad84830e43ea', 3, 'normal', 0, 8, 3, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('8fac87bd-375b-59b2-be9a-ca55e465aaa3', 'a78e0339-5fe0-5185-bed7-0f7c04441b66', '0025', 2)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('c8e20bb7-ca69-5d28-9582-45c86a9098b8', '8fac87bd-375b-59b2-be9a-ca55e465aaa3', 1, 'normal', 0, 8, 3, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('089c8c4d-e961-5b2a-9cf2-9cacc3f985a0', '8fac87bd-375b-59b2-be9a-ca55e465aaa3', 2, 'normal', 0, 8, 3, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('688dd64d-2182-533a-ad6b-70a68eb3ca30', '8fac87bd-375b-59b2-be9a-ca55e465aaa3', 3, 'normal', 0, 8, 3, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('72e64f67-f14f-51e9-9485-c07fa155ee81', 'a78e0339-5fe0-5185-bed7-0f7c04441b66', '0027', 3)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('a84e1ba9-49d5-52e7-9e7f-7c836785b034', '72e64f67-f14f-51e9-9485-c07fa155ee81', 1, 'normal', 0, 8, 3, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('3dc37fa0-981c-56de-9558-e7615827b0cc', '72e64f67-f14f-51e9-9485-c07fa155ee81', 2, 'normal', 0, 8, 3, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('0306615e-b70e-538a-95f1-67d06c0f6ba6', '72e64f67-f14f-51e9-9485-c07fa155ee81', 3, 'normal', 0, 8, 3, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('cbd890b8-3ddb-537d-9423-f1f4b39217eb', 'a78e0339-5fe0-5185-bed7-0f7c04441b66', '0091', 4)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('020bbf8f-5552-586e-b4c6-ff535324f261', 'cbd890b8-3ddb-537d-9423-f1f4b39217eb', 1, 'normal', 0, 10, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('5801676f-2f0d-5824-9dd4-d3eefda872c7', 'cbd890b8-3ddb-537d-9423-f1f4b39217eb', 2, 'normal', 0, 10, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('f85f4487-1233-52fe-9678-fbb37bbecaad', 'cbd890b8-3ddb-537d-9423-f1f4b39217eb', 3, 'normal', 0, 10, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('7692b685-765b-5c3b-8275-8a836de404f5', 'a78e0339-5fe0-5185-bed7-0f7c04441b66', '0294', 5)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('eff7663d-ef54-5bd3-9cf6-3d01298b36bd', '7692b685-765b-5c3b-8275-8a836de404f5', 1, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('6a9be431-76e8-5686-be82-780ab2774d6c', '7692b685-765b-5c3b-8275-8a836de404f5', 2, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('2eb2a3b6-4caa-5f6d-90bf-22c02a97f50a', 'a78e0339-5fe0-5185-bed7-0f7c04441b66', '0241', 6)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('358c72b6-ba8c-5a1b-9271-0f6edd461c3f', '2eb2a3b6-4caa-5f6d-90bf-22c02a97f50a', 1, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('a2d59af3-8ed5-5370-94b1-0883003b9914', '2eb2a3b6-4caa-5f6d-90bf-22c02a97f50a', 2, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('1f2d6258-0e76-5dce-8889-1cef0ff15583', 'a78e0339-5fe0-5185-bed7-0f7c04441b66', '0472', 7)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('67e6aaa6-d07e-591d-82dc-6896bc497f7c', '1f2d6258-0e76-5dce-8889-1cef0ff15583', 1, 'normal', 0, 10, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('a2280780-1da4-5fa3-bacd-a5663c05c728', '1f2d6258-0e76-5dce-8889-1cef0ff15583', 2, 'normal', 0, 10, 1, 60)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.templates (id, name, description, category, level, goal, target_days, weeks)
VALUES ('6206f2ac-c0ea-551e-9aae-b1af36cee5f2', 'Empuje · Hipertrofia', 'Pecho, hombros y tríceps con press banca como eje y accesorios de aislamiento.', 'Push/Pull/Legs', 'Intermedio', 'Hipertrofia', 2, 8)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_days (id, template_id, order_index, name)
VALUES ('a61be47d-6fdc-52fc-ba16-bd396a66359c', '6206f2ac-c0ea-551e-9aae-b1af36cee5f2', 1, 'Empuje')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('c7fd560a-a1d1-5f29-9a4f-6d39a69747d7', 'a61be47d-6fdc-52fc-ba16-bd396a66359c', '0025', 1)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('262f8b3a-39fe-53d5-a52b-034b48ddec47', 'c7fd560a-a1d1-5f29-9a4f-6d39a69747d7', 1, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('0ca7374d-6c8e-5cc4-996c-774e3e83f78c', 'c7fd560a-a1d1-5f29-9a4f-6d39a69747d7', 2, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('20c326b3-b257-588d-8791-13ec82d41ffd', 'c7fd560a-a1d1-5f29-9a4f-6d39a69747d7', 3, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('591e82ea-1973-5d31-a575-8161cb5f5491', 'c7fd560a-a1d1-5f29-9a4f-6d39a69747d7', 4, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('ac14f67a-55cb-59cb-99a7-4b6421a2bd18', 'a61be47d-6fdc-52fc-ba16-bd396a66359c', '0047', 2)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('964861d2-2a8a-524b-b39a-cb11c671afcf', 'ac14f67a-55cb-59cb-99a7-4b6421a2bd18', 1, 'normal', 0, 10, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('5a1aafdc-0aee-57cf-90e1-4068a80e4783', 'ac14f67a-55cb-59cb-99a7-4b6421a2bd18', 2, 'normal', 0, 10, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('8f0fe46c-970e-5287-a2f0-96cb7f7cf539', 'ac14f67a-55cb-59cb-99a7-4b6421a2bd18', 3, 'normal', 0, 10, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('766e5fb0-56c3-56da-8f11-e846e6758cd5', 'a61be47d-6fdc-52fc-ba16-bd396a66359c', '0188', 3)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('c38915fc-e627-5f39-ae6d-ace78d12ad25', '766e5fb0-56c3-56da-8f11-e846e6758cd5', 1, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('5073c323-3143-5869-9787-0c2de678c11e', '766e5fb0-56c3-56da-8f11-e846e6758cd5', 2, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('74e4b230-c8d0-5172-88c4-5fd2c241aed2', '766e5fb0-56c3-56da-8f11-e846e6758cd5', 3, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('e678eff4-e4a1-539e-a32a-b1fdb6260b26', 'a61be47d-6fdc-52fc-ba16-bd396a66359c', '0091', 4)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('db94b828-7278-5c0c-8bdc-1b9cc1430800', 'e678eff4-e4a1-539e-a32a-b1fdb6260b26', 1, 'normal', 0, 8, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('ab668305-c63b-5ca3-9ef5-b9a31f1bce2a', 'e678eff4-e4a1-539e-a32a-b1fdb6260b26', 2, 'normal', 0, 8, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('e77d0b8f-91c0-5417-a53c-d600d37cc891', 'e678eff4-e4a1-539e-a32a-b1fdb6260b26', 3, 'normal', 0, 8, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('32434183-2282-55ef-bfd3-ce8bc9216493', 'a61be47d-6fdc-52fc-ba16-bd396a66359c', '0334', 5)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('e765d8a7-df6c-57fa-a020-5a4de0666d4d', '32434183-2282-55ef-bfd3-ce8bc9216493', 1, 'normal', 0, 15, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('cec43118-585c-5423-babe-160d94567c9a', '32434183-2282-55ef-bfd3-ce8bc9216493', 2, 'normal', 0, 15, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('cb7498b4-1c55-5455-80c7-369dc826666a', '32434183-2282-55ef-bfd3-ce8bc9216493', 3, 'normal', 0, 15, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('10a45b40-5b1f-5856-aa4a-d1b912ecda0a', 'a61be47d-6fdc-52fc-ba16-bd396a66359c', '0241', 6)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('21e10d77-e968-58d9-8c4e-c65082120afb', '10a45b40-5b1f-5856-aa4a-d1b912ecda0a', 1, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('2d8b6105-a65a-5833-a0ba-31e288aed37f', '10a45b40-5b1f-5856-aa4a-d1b912ecda0a', 2, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('4eb40ea6-5151-5025-973e-d0dc387dd49d', '10a45b40-5b1f-5856-aa4a-d1b912ecda0a', 3, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('3a174039-c68a-5dae-ab37-50d24ee63b35', 'a61be47d-6fdc-52fc-ba16-bd396a66359c', '0030', 7)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('ac408abd-1470-5faf-b399-4006a497a950', '3a174039-c68a-5dae-ab37-50d24ee63b35', 1, 'normal', 0, 10, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('8c29afa1-9109-58d0-ae13-2194ca174be4', '3a174039-c68a-5dae-ab37-50d24ee63b35', 2, 'normal', 0, 10, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('8f020e41-eb74-5500-a2e4-99f4264e5c23', '3a174039-c68a-5dae-ab37-50d24ee63b35', 3, 'normal', 0, 10, 2, 90)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.templates (id, name, description, category, level, goal, target_days, weeks)
VALUES ('de8344b6-f376-52c0-9e09-42fa45f623cd', 'Tirón · Hipertrofia', 'Espalda y bíceps: dominadas, remo pesado y accesorios para la cadena posterior.', 'Push/Pull/Legs', 'Intermedio', 'Hipertrofia', 2, 8)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_days (id, template_id, order_index, name)
VALUES ('4a0556fd-a19c-5a62-84db-4209df8874d2', 'de8344b6-f376-52c0-9e09-42fa45f623cd', 1, 'Tirón')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('74d65de4-03fd-5dde-a2ac-76d2dda55e58', '4a0556fd-a19c-5a62-84db-4209df8874d2', '0652', 1)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('464b4f73-55f6-50ac-8f99-cdd2220bc620', '74d65de4-03fd-5dde-a2ac-76d2dda55e58', 1, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('013960d0-d2e6-5e56-bf90-4b1e4a18626e', '74d65de4-03fd-5dde-a2ac-76d2dda55e58', 2, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('896d61b2-d64a-5b87-ad12-fbe7dfc32c8c', '74d65de4-03fd-5dde-a2ac-76d2dda55e58', 3, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('6056d541-ef3e-53a5-a503-8e1af2e05bef', '74d65de4-03fd-5dde-a2ac-76d2dda55e58', 4, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('4e00e9fa-c2df-59cb-b013-587e5a32a104', '4a0556fd-a19c-5a62-84db-4209df8874d2', '0027', 2)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('33c0404d-66f1-57ec-a11a-44440a3db097', '4e00e9fa-c2df-59cb-b013-587e5a32a104', 1, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('259f1dc0-f3d8-5ca4-a82e-9beb818ac7e0', '4e00e9fa-c2df-59cb-b013-587e5a32a104', 2, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('c174a1cb-05fd-5288-9e15-e37883afa8bd', '4e00e9fa-c2df-59cb-b013-587e5a32a104', 3, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('a43e2fec-a46b-5256-800e-2fad8953c203', '4e00e9fa-c2df-59cb-b013-587e5a32a104', 4, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('c3d5622f-1c6b-5b24-9f9b-ee1a290ad375', '4a0556fd-a19c-5a62-84db-4209df8874d2', '2330', 3)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('3a0efc14-7318-5baf-b45e-8786b4554418', 'c3d5622f-1c6b-5b24-9f9b-ee1a290ad375', 1, 'normal', 0, 10, 1, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('c2a367fb-70df-56ce-8c3c-cb3eaf0c5f62', 'c3d5622f-1c6b-5b24-9f9b-ee1a290ad375', 2, 'normal', 0, 10, 1, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('211dfedb-8d70-57da-9b82-8a0e068b767a', 'c3d5622f-1c6b-5b24-9f9b-ee1a290ad375', 3, 'normal', 0, 10, 1, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('b436cf1f-5668-5303-b7f0-a63e08cb45a0', '4a0556fd-a19c-5a62-84db-4209df8874d2', '0294', 4)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('524c0973-ef01-517a-b1b9-078a342145e3', 'b436cf1f-5668-5303-b7f0-a63e08cb45a0', 1, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('10503825-e7a5-5e20-8d0f-84cba03151eb', 'b436cf1f-5668-5303-b7f0-a63e08cb45a0', 2, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('729c54cd-74b8-5afb-b5f5-cc163972d286', 'b436cf1f-5668-5303-b7f0-a63e08cb45a0', 3, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('877498a2-723b-56c7-8ab7-a55c391d35d2', '4a0556fd-a19c-5a62-84db-4209df8874d2', '0298', 5)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('358e89b6-3647-5bba-b115-bcdc6f08eaef', '877498a2-723b-56c7-8ab7-a55c391d35d2', 1, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('58e9100d-bb6b-509c-83f9-374f38558da3', '877498a2-723b-56c7-8ab7-a55c391d35d2', 2, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('aa2ffcdb-f216-537f-a67c-040a69f39589', '877498a2-723b-56c7-8ab7-a55c391d35d2', 3, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('9f64aa44-819b-545b-8755-1b8d14b71716', '4a0556fd-a19c-5a62-84db-4209df8874d2', '0215', 6)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('15c424ad-d70c-5e50-9ac4-77bd016d6d11', '9f64aa44-819b-545b-8755-1b8d14b71716', 1, 'normal', 0, 15, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('a983037b-7b05-53cf-b842-ba2c5f1b4d09', '9f64aa44-819b-545b-8755-1b8d14b71716', 2, 'normal', 0, 15, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('c70fd551-cbce-5852-9857-6b2a33b25de2', '9f64aa44-819b-545b-8755-1b8d14b71716', 3, 'normal', 0, 15, 1, 60)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.templates (id, name, description, category, level, goal, target_days, weeks)
VALUES ('7ad200c5-6789-5969-a956-972b2af84ad3', 'Pierna · Fuerza', 'Sentadilla y peso muerto como levantamientos principales, con volumen bajo y descansos largos.', 'Full Body', 'Intermedio', 'Fuerza', 2, 8)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_days (id, template_id, order_index, name)
VALUES ('d41d2ee7-9c2e-5328-8cfb-739bf9825a3f', '7ad200c5-6789-5969-a956-972b2af84ad3', 1, 'Pierna')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('1193d3bb-e311-5e1e-ae4f-fa33c35b95fe', 'd41d2ee7-9c2e-5328-8cfb-739bf9825a3f', '0043', 1)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('70c551e2-8751-57e7-9ac5-7b17d3489065', '1193d3bb-e311-5e1e-ae4f-fa33c35b95fe', 1, 'normal', 0, 5, 2, 180)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('48be3a46-d047-572e-a9ae-d4bd008fdadc', '1193d3bb-e311-5e1e-ae4f-fa33c35b95fe', 2, 'normal', 0, 5, 2, 180)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('42f692f4-eb4a-5e64-b79f-c489cd862a73', '1193d3bb-e311-5e1e-ae4f-fa33c35b95fe', 3, 'normal', 0, 5, 2, 180)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('9dbca43f-c86b-512d-ab9b-5cb185e09efb', '1193d3bb-e311-5e1e-ae4f-fa33c35b95fe', 4, 'normal', 0, 5, 2, 180)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('304f1e4d-d1a0-5c51-a7e9-45fec2a3d5d3', '1193d3bb-e311-5e1e-ae4f-fa33c35b95fe', 5, 'normal', 0, 5, 2, 180)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('e53c4ccd-fc40-5ccd-a1cf-d00b49f885b7', 'd41d2ee7-9c2e-5328-8cfb-739bf9825a3f', '0032', 2)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('33e80fb6-f8c2-5df4-88b1-240b8b9d5372', 'e53c4ccd-fc40-5ccd-a1cf-d00b49f885b7', 1, 'normal', 0, 5, 3, 180)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('e93b0eae-b9e1-562d-a401-51e3aa0481e7', 'e53c4ccd-fc40-5ccd-a1cf-d00b49f885b7', 2, 'normal', 0, 5, 3, 180)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('4c674d6c-9b24-500b-a154-4895008d387a', 'e53c4ccd-fc40-5ccd-a1cf-d00b49f885b7', 3, 'normal', 0, 5, 3, 180)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('424d2de5-a0e6-503a-a0ab-5280ee3be437', 'd41d2ee7-9c2e-5328-8cfb-739bf9825a3f', '0085', 3)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('8f7fca89-c25b-56bd-93d5-53f9e3b77316', '424d2de5-a0e6-503a-a0ab-5280ee3be437', 1, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('8825540d-e87a-508f-97c0-a4d57afee132', '424d2de5-a0e6-503a-a0ab-5280ee3be437', 2, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('57259447-ee26-5211-a8b9-829a5902cbc2', '424d2de5-a0e6-503a-a0ab-5280ee3be437', 3, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('caee98c7-a4c7-5557-926f-8b7197af03ad', 'd41d2ee7-9c2e-5328-8cfb-739bf9825a3f', '0054', 4)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('788b84db-561a-53f6-84c8-2e8cedc8530e', 'caee98c7-a4c7-5557-926f-8b7197af03ad', 1, 'normal', 0, 8, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('520604c7-f141-5aa9-aa17-04f18a5a9d5d', 'caee98c7-a4c7-5557-926f-8b7197af03ad', 2, 'normal', 0, 8, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('3dae142c-1a1a-5db0-8614-636dad7b7ca1', 'caee98c7-a4c7-5557-926f-8b7197af03ad', 3, 'normal', 0, 8, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('09cdb62e-5a87-50e3-ad71-d6c270ecc121', 'd41d2ee7-9c2e-5328-8cfb-739bf9825a3f', '1372', 5)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('d53059af-874f-5be7-b77e-5792918b78a9', '09cdb62e-5a87-50e3-ad71-d6c270ecc121', 1, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('88a4a813-60c0-5b72-bc19-7150a3c2c6b0', '09cdb62e-5a87-50e3-ad71-d6c270ecc121', 2, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('6065e416-ac02-52d6-947a-199af908ed11', '09cdb62e-5a87-50e3-ad71-d6c270ecc121', 3, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('eeeb0091-0a58-5695-987b-671a7c551731', '09cdb62e-5a87-50e3-ad71-d6c270ecc121', 4, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('1f3dba62-7fb4-5ac5-bdaa-08c6041dcfc2', 'd41d2ee7-9c2e-5328-8cfb-739bf9825a3f', '0472', 6)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('9d9a3467-c996-5900-a3be-35d3afd7856f', '1f3dba62-7fb4-5ac5-bdaa-08c6041dcfc2', 1, 'normal', 0, 10, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('ec698bbb-3724-5848-a439-9bd9d3459d64', '1f3dba62-7fb4-5ac5-bdaa-08c6041dcfc2', 2, 'normal', 0, 10, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('50fb4964-ac80-5371-b662-e5392053032c', '1f3dba62-7fb4-5ac5-bdaa-08c6041dcfc2', 3, 'normal', 0, 10, 1, 60)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.templates (id, name, description, category, level, goal, target_days, weeks)
VALUES ('19b09839-1405-5b85-95c9-a4a6ebfe4282', 'PPL · Programa', 'Programa de seis días (empuje, tirón y pierna, dos veces por semana) para hipertrofia.', 'Push/Pull/Legs', 'Intermedio', 'Hipertrofia', 6, 8)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_days (id, template_id, order_index, name)
VALUES ('fa6fe25c-c95c-5c2d-9df7-bd53d42362d0', '19b09839-1405-5b85-95c9-a4a6ebfe4282', 1, 'Empuje')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('833ba083-2606-5f8f-9540-0ff1ad40a456', 'fa6fe25c-c95c-5c2d-9df7-bd53d42362d0', '0025', 1)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('98e17c20-c9b6-5282-bf10-6ee3a85c01d8', '833ba083-2606-5f8f-9540-0ff1ad40a456', 1, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('7f52b259-0cdf-5aad-9e8e-85ce0b24e20b', '833ba083-2606-5f8f-9540-0ff1ad40a456', 2, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('500fb9b5-1661-5443-a499-ceba1f523dc2', '833ba083-2606-5f8f-9540-0ff1ad40a456', 3, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('872c40e1-2ffa-54a0-96d7-f660ea8d08ed', '833ba083-2606-5f8f-9540-0ff1ad40a456', 4, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('7bb7da30-c01f-55a0-8789-900d9b4d23ec', 'fa6fe25c-c95c-5c2d-9df7-bd53d42362d0', '0047', 2)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('01e36dc8-98fa-5ac4-9cfe-fa2dcc863b83', '7bb7da30-c01f-55a0-8789-900d9b4d23ec', 1, 'normal', 0, 10, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('99766a90-0407-518e-890e-fcc9b1df6fd0', '7bb7da30-c01f-55a0-8789-900d9b4d23ec', 2, 'normal', 0, 10, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('34e70810-54c6-530f-b618-09413f3a5993', '7bb7da30-c01f-55a0-8789-900d9b4d23ec', 3, 'normal', 0, 10, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('e0f13d7f-67ed-5ebf-893b-39293a580ba0', 'fa6fe25c-c95c-5c2d-9df7-bd53d42362d0', '0188', 3)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('702bda54-fa41-5991-84c5-690942a9bb68', 'e0f13d7f-67ed-5ebf-893b-39293a580ba0', 1, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('1fa147c8-82f7-59e4-a0b1-eb70908da4b1', 'e0f13d7f-67ed-5ebf-893b-39293a580ba0', 2, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('963daca4-baf3-53bc-92bf-5ce57de2340d', 'e0f13d7f-67ed-5ebf-893b-39293a580ba0', 3, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('b6369846-41cc-536a-927f-d142d593e128', 'fa6fe25c-c95c-5c2d-9df7-bd53d42362d0', '0091', 4)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('2c9328f6-e81b-5ab7-a0ca-888382d16fed', 'b6369846-41cc-536a-927f-d142d593e128', 1, 'normal', 0, 8, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('f7c1c8f4-f943-5624-a1ac-895e3d10294e', 'b6369846-41cc-536a-927f-d142d593e128', 2, 'normal', 0, 8, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('17ed79e7-9966-59c6-9a51-fc74e10376ae', 'b6369846-41cc-536a-927f-d142d593e128', 3, 'normal', 0, 8, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('f7d822da-2291-5762-8648-590ff1babcaa', 'fa6fe25c-c95c-5c2d-9df7-bd53d42362d0', '0334', 5)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('30186d7a-0a91-58e6-9e9f-0469578d7f8e', 'f7d822da-2291-5762-8648-590ff1babcaa', 1, 'normal', 0, 15, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('3eed2bda-0a07-58ce-a78c-0a15eb4053e0', 'f7d822da-2291-5762-8648-590ff1babcaa', 2, 'normal', 0, 15, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('e7948322-3574-51a4-9196-8778023a1636', 'f7d822da-2291-5762-8648-590ff1babcaa', 3, 'normal', 0, 15, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('166bfa2c-5758-552f-8de3-b38942a27393', 'fa6fe25c-c95c-5c2d-9df7-bd53d42362d0', '0241', 6)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('5421a738-fa75-57c6-a6ec-1dab7741c4a4', '166bfa2c-5758-552f-8de3-b38942a27393', 1, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('d93733e1-0421-5607-905f-aafd73c96d4a', '166bfa2c-5758-552f-8de3-b38942a27393', 2, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('c03e1cc8-fbee-5df1-b64b-e14359e92d9c', '166bfa2c-5758-552f-8de3-b38942a27393', 3, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('a9cd8152-138c-5577-84bd-761e43aabf20', 'fa6fe25c-c95c-5c2d-9df7-bd53d42362d0', '0030', 7)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('27aca2c8-6c56-5992-9e0b-2147d18f02df', 'a9cd8152-138c-5577-84bd-761e43aabf20', 1, 'normal', 0, 10, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('a776ae30-23e5-53bd-8077-faf994c57003', 'a9cd8152-138c-5577-84bd-761e43aabf20', 2, 'normal', 0, 10, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('a4f976dc-cb38-5f48-bdbf-7df219ba9a0c', 'a9cd8152-138c-5577-84bd-761e43aabf20', 3, 'normal', 0, 10, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_days (id, template_id, order_index, name)
VALUES ('40e13843-30f4-5056-bcf8-190603c9cd46', '19b09839-1405-5b85-95c9-a4a6ebfe4282', 2, 'Tirón')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('7acc72aa-9ba8-5a0e-82a1-543a4d3bb73e', '40e13843-30f4-5056-bcf8-190603c9cd46', '0652', 1)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('3a9ce60d-70eb-5054-a5ee-09326b10c3c1', '7acc72aa-9ba8-5a0e-82a1-543a4d3bb73e', 1, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('d45c637d-f847-501a-b370-94bc2ef631b6', '7acc72aa-9ba8-5a0e-82a1-543a4d3bb73e', 2, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('9d086822-0d33-5931-8c18-f1b203fe9d3b', '7acc72aa-9ba8-5a0e-82a1-543a4d3bb73e', 3, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('8d26b0ff-b7c7-502f-a06a-cb3bb4560950', '7acc72aa-9ba8-5a0e-82a1-543a4d3bb73e', 4, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('07787c8c-b429-53c0-b550-a4b5d7752cd1', '40e13843-30f4-5056-bcf8-190603c9cd46', '0027', 2)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('3fe43a6a-6ad3-5d4e-88fb-cb733aef2159', '07787c8c-b429-53c0-b550-a4b5d7752cd1', 1, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('c1342945-8a7d-5d2a-a142-19fbff77e469', '07787c8c-b429-53c0-b550-a4b5d7752cd1', 2, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('2579d368-bac0-552c-b98f-a491f2176e23', '07787c8c-b429-53c0-b550-a4b5d7752cd1', 3, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('592c3446-9a52-5b67-a1df-bd58ecd03b38', '07787c8c-b429-53c0-b550-a4b5d7752cd1', 4, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('3763994d-ee27-5bc8-bac1-ce042b6e831f', '40e13843-30f4-5056-bcf8-190603c9cd46', '2330', 3)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('c6c7e18f-71d5-5276-bf24-96fda51a1623', '3763994d-ee27-5bc8-bac1-ce042b6e831f', 1, 'normal', 0, 10, 1, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('ac8b5a13-4c8e-5539-9cae-61f2fd54e0f9', '3763994d-ee27-5bc8-bac1-ce042b6e831f', 2, 'normal', 0, 10, 1, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('c2724972-bbaf-5a5b-9830-c0d0d324a524', '3763994d-ee27-5bc8-bac1-ce042b6e831f', 3, 'normal', 0, 10, 1, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('d51c611e-fe79-5e37-9a40-c462d0157483', '40e13843-30f4-5056-bcf8-190603c9cd46', '0294', 4)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('f50c6dea-4b94-5bea-a676-491e8212786d', 'd51c611e-fe79-5e37-9a40-c462d0157483', 1, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('60835889-9961-5374-bcd0-036d1df021f7', 'd51c611e-fe79-5e37-9a40-c462d0157483', 2, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('89c3334b-c9b5-5220-8aa0-899e9e4c77a4', 'd51c611e-fe79-5e37-9a40-c462d0157483', 3, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('9aed8daa-a74d-573e-8f16-8de0e19fc673', '40e13843-30f4-5056-bcf8-190603c9cd46', '0298', 5)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('68b3854a-562c-5650-8853-21cfac9401e3', '9aed8daa-a74d-573e-8f16-8de0e19fc673', 1, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('dace7d5c-c075-5883-9d98-125bea317132', '9aed8daa-a74d-573e-8f16-8de0e19fc673', 2, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('5cd44f3f-52f0-5b7a-8635-46832af52f81', '9aed8daa-a74d-573e-8f16-8de0e19fc673', 3, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('b8e87f53-5cdc-55e7-94ac-076a094cd151', '40e13843-30f4-5056-bcf8-190603c9cd46', '0215', 6)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('3c6dc723-e2ed-59f9-a19e-56273fecd7d6', 'b8e87f53-5cdc-55e7-94ac-076a094cd151', 1, 'normal', 0, 15, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('6c8f504c-9da2-5de4-b932-ef126605ed7f', 'b8e87f53-5cdc-55e7-94ac-076a094cd151', 2, 'normal', 0, 15, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('e67d604a-6f41-5e51-8348-40f26824e878', 'b8e87f53-5cdc-55e7-94ac-076a094cd151', 3, 'normal', 0, 15, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_days (id, template_id, order_index, name)
VALUES ('1b806c34-ff8d-59fb-a5a2-8cfa0314f968', '19b09839-1405-5b85-95c9-a4a6ebfe4282', 3, 'Pierna')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('809b9b94-e800-5409-95a1-056d490d0160', '1b806c34-ff8d-59fb-a5a2-8cfa0314f968', '0043', 1)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('4ee8e784-9fb5-5aad-a886-c224672364da', '809b9b94-e800-5409-95a1-056d490d0160', 1, 'normal', 0, 6, 2, 180)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('cb49402f-d7ff-5f28-99b7-a592542d0767', '809b9b94-e800-5409-95a1-056d490d0160', 2, 'normal', 0, 6, 2, 180)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('29b2fa93-87ba-58b5-b55a-d7218fff297d', '809b9b94-e800-5409-95a1-056d490d0160', 3, 'normal', 0, 6, 2, 180)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('b0df5f3a-c3b2-5e88-a2f7-81f5450dfc11', '809b9b94-e800-5409-95a1-056d490d0160', 4, 'normal', 0, 6, 2, 180)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('519c46e1-d4ab-557e-9aa5-e31c8f0d156f', '1b806c34-ff8d-59fb-a5a2-8cfa0314f968', '0085', 2)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('5d8a97fb-04a1-5d55-b43a-d328de93850b', '519c46e1-d4ab-557e-9aa5-e31c8f0d156f', 1, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('443404cd-f34d-51dd-b155-0b7f5a87f59e', '519c46e1-d4ab-557e-9aa5-e31c8f0d156f', 2, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('b4186046-9918-5229-b234-bd911d1c2399', '519c46e1-d4ab-557e-9aa5-e31c8f0d156f', 3, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('7fa0c051-d5b0-5ed6-b1ac-2e478a461218', '1b806c34-ff8d-59fb-a5a2-8cfa0314f968', '2287', 3)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('9cbf5782-c7bb-545a-aa72-33ebffd1752b', '7fa0c051-d5b0-5ed6-b1ac-2e478a461218', 1, 'normal', 0, 10, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('081640cb-9755-5297-94c0-34c1b62701db', '7fa0c051-d5b0-5ed6-b1ac-2e478a461218', 2, 'normal', 0, 10, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('81125477-d701-5d81-b4ba-9fd1e8893153', '7fa0c051-d5b0-5ed6-b1ac-2e478a461218', 3, 'normal', 0, 10, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('4e2a2f86-df75-55f6-abb7-ce48f098ce92', '1b806c34-ff8d-59fb-a5a2-8cfa0314f968', '0586', 4)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('96576f9b-0871-51a8-a2b6-c9848a8f2113', '4e2a2f86-df75-55f6-abb7-ce48f098ce92', 1, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('9813c819-7ad2-59e9-b7c8-d6cff84e58b2', '4e2a2f86-df75-55f6-abb7-ce48f098ce92', 2, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('81921c3d-bb47-55e7-88f5-a8f0ed2cfbc7', '4e2a2f86-df75-55f6-abb7-ce48f098ce92', 3, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('05b82410-d7ba-5dc3-93ce-0d8a4ae5882a', '1b806c34-ff8d-59fb-a5a2-8cfa0314f968', '0054', 5)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('ca9b69f2-f054-546a-bed2-59a24303b299', '05b82410-d7ba-5dc3-93ce-0d8a4ae5882a', 1, 'normal', 0, 10, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('b161825f-1f60-54e3-9761-ede0932b5db7', '05b82410-d7ba-5dc3-93ce-0d8a4ae5882a', 2, 'normal', 0, 10, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('18614481-978e-56b6-aea3-0b30e6422b9a', '05b82410-d7ba-5dc3-93ce-0d8a4ae5882a', 3, 'normal', 0, 10, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('c4327121-577a-5a99-9e23-3235a82f8ea8', '1b806c34-ff8d-59fb-a5a2-8cfa0314f968', '1372', 6)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('246ff631-1f6c-5512-bea3-ac5213a76f8d', 'c4327121-577a-5a99-9e23-3235a82f8ea8', 1, 'normal', 0, 15, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('f3ae3900-a67a-59f9-b89e-bd3501dd5fd7', 'c4327121-577a-5a99-9e23-3235a82f8ea8', 2, 'normal', 0, 15, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('dd9ee373-96ce-5b8f-a91a-86082242a13e', 'c4327121-577a-5a99-9e23-3235a82f8ea8', 3, 'normal', 0, 15, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('a5280a09-3971-5b1a-b87e-702f7bfa0f9a', 'c4327121-577a-5a99-9e23-3235a82f8ea8', 4, 'normal', 0, 15, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('45e2d591-7142-5e37-9c7d-c63dfd26cb33', '1b806c34-ff8d-59fb-a5a2-8cfa0314f968', '0472', 7)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('0ad838b5-1fc9-5151-9c94-403c239b23c4', '45e2d591-7142-5e37-9c7d-c63dfd26cb33', 1, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('ba6530b0-dff2-57c2-8479-c58f38a4f278', '45e2d591-7142-5e37-9c7d-c63dfd26cb33', 2, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('4bbc8898-e745-54fa-bc17-013a5fcb18d3', '45e2d591-7142-5e37-9c7d-c63dfd26cb33', 3, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.templates (id, name, description, category, level, goal, target_days, weeks)
VALUES ('357016c3-d3de-5e38-8885-ae342ee734a8', 'Torso / Pierna · Programa', 'Cuatro sesiones semanales alternando torso y pierna, con progresión automática.', 'Torso-Pierna', 'Principiante', 'Hipertrofia', 4, 8)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_days (id, template_id, order_index, name)
VALUES ('f6348704-1f76-5a4a-be5b-bf24d2473781', '357016c3-d3de-5e38-8885-ae342ee734a8', 1, 'Torso')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('3ca4efa7-e6bc-5524-9cc2-410b6b60c599', 'f6348704-1f76-5a4a-be5b-bf24d2473781', '0025', 1)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('a6ba6c71-553f-520e-8e00-b47bc1e8796f', '3ca4efa7-e6bc-5524-9cc2-410b6b60c599', 1, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('0f48a97d-adfb-5485-81cb-502bb9ac8fdb', '3ca4efa7-e6bc-5524-9cc2-410b6b60c599', 2, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('77348397-12fa-58d9-8b77-262325ffd0c6', '3ca4efa7-e6bc-5524-9cc2-410b6b60c599', 3, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('7e405573-5e8d-51e8-8fc2-96290306c877', '3ca4efa7-e6bc-5524-9cc2-410b6b60c599', 4, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('c6d97842-bde1-520f-85fb-36fb853a4672', 'f6348704-1f76-5a4a-be5b-bf24d2473781', '0027', 2)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('fb2dbdd2-9545-5113-85ea-614033a14a7d', 'c6d97842-bde1-520f-85fb-36fb853a4672', 1, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('3b28b59e-8166-5649-9182-1f78dff69150', 'c6d97842-bde1-520f-85fb-36fb853a4672', 2, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('0778424c-ee77-5187-a515-8eec7e3b4331', 'c6d97842-bde1-520f-85fb-36fb853a4672', 3, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('d4451cfe-0647-5447-9602-27481aecaf2a', 'c6d97842-bde1-520f-85fb-36fb853a4672', 4, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('a224cfd1-382b-5bb5-adde-2510e2fabd11', 'f6348704-1f76-5a4a-be5b-bf24d2473781', '0652', 3)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('efc4f7d3-99de-5522-b04a-84fc6e662fd7', 'a224cfd1-382b-5bb5-adde-2510e2fabd11', 1, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('3a8e30df-4d80-51b8-8f15-fb3c2fa838e4', 'a224cfd1-382b-5bb5-adde-2510e2fabd11', 2, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('9f4baad0-97e5-5db1-97ed-76893eeb7809', 'a224cfd1-382b-5bb5-adde-2510e2fabd11', 3, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('3226e7c1-3d7b-57fb-8a39-85f238988220', 'f6348704-1f76-5a4a-be5b-bf24d2473781', '0334', 4)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('53b81764-acf4-5930-aad3-4ba97189a8c0', '3226e7c1-3d7b-57fb-8a39-85f238988220', 1, 'normal', 0, 15, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('7465e5d5-3f63-58d3-9e67-763c58f725b2', '3226e7c1-3d7b-57fb-8a39-85f238988220', 2, 'normal', 0, 15, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('a8dda5dc-ae90-577b-a774-421852153ede', '3226e7c1-3d7b-57fb-8a39-85f238988220', 3, 'normal', 0, 15, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('1beab355-0990-5b1f-8b33-262521cb25f7', 'f6348704-1f76-5a4a-be5b-bf24d2473781', '0294', 5)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('1702e02a-f1fb-52c3-8fdd-c70255647cd5', '1beab355-0990-5b1f-8b33-262521cb25f7', 1, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('c3dd503b-8c8e-503b-9e41-c0691b875158', '1beab355-0990-5b1f-8b33-262521cb25f7', 2, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('1bd7f125-4bbf-569c-b544-3d3b3b873f0c', '1beab355-0990-5b1f-8b33-262521cb25f7', 3, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('40d2f95a-2bb4-584c-9e1f-9c0c2744d674', 'f6348704-1f76-5a4a-be5b-bf24d2473781', '0241', 6)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('9dee2ac6-0469-5a5e-8fdf-5f443cb844c1', '40d2f95a-2bb4-584c-9e1f-9c0c2744d674', 1, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('615b596c-fca6-56a9-a96c-867b19fb759a', '40d2f95a-2bb4-584c-9e1f-9c0c2744d674', 2, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('0198a2ec-2e01-5871-a739-e1ec88fd0c4f', '40d2f95a-2bb4-584c-9e1f-9c0c2744d674', 3, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_days (id, template_id, order_index, name)
VALUES ('f502e915-f3b7-5620-9cbf-3c552c00eae6', '357016c3-d3de-5e38-8885-ae342ee734a8', 2, 'Pierna')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('a1d796c5-7253-5bfe-8977-7afa0a03dcf3', 'f502e915-f3b7-5620-9cbf-3c552c00eae6', '0043', 1)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('1553ce1f-4874-5578-814c-632ad22646f0', 'a1d796c5-7253-5bfe-8977-7afa0a03dcf3', 1, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('9d45d798-c3c0-57db-bf00-6635ee85ee6e', 'a1d796c5-7253-5bfe-8977-7afa0a03dcf3', 2, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('106de1b5-5e5d-5043-a56f-dd5659894ccd', 'a1d796c5-7253-5bfe-8977-7afa0a03dcf3', 3, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('45d06a35-9902-5df3-a5cb-25c367d8edcc', 'a1d796c5-7253-5bfe-8977-7afa0a03dcf3', 4, 'normal', 0, 8, 2, 120)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('81356504-6556-5b1b-b38e-af6faec93634', 'f502e915-f3b7-5620-9cbf-3c552c00eae6', '0085', 2)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('db7d1906-31d9-55f1-89c6-23bab556f68b', '81356504-6556-5b1b-b38e-af6faec93634', 1, 'normal', 0, 10, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('91c9eeea-f5da-5a05-8408-ea52337bdf50', '81356504-6556-5b1b-b38e-af6faec93634', 2, 'normal', 0, 10, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('c58490dd-453c-532c-b65c-fcdd07f1c9cd', '81356504-6556-5b1b-b38e-af6faec93634', 3, 'normal', 0, 10, 2, 90)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('11774c19-61d0-587f-b789-6668055228a4', 'f502e915-f3b7-5620-9cbf-3c552c00eae6', '2287', 3)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('968f81d2-7264-52ba-a9c3-fab6f7b3b531', '11774c19-61d0-587f-b789-6668055228a4', 1, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('29fbf9d3-4a6a-53f1-92c7-343668c9aabf', '11774c19-61d0-587f-b789-6668055228a4', 2, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('42987848-8cde-5969-a511-76a5eb941416', '11774c19-61d0-587f-b789-6668055228a4', 3, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('e467d44f-fa26-5f3f-a988-e99190a97f7c', 'f502e915-f3b7-5620-9cbf-3c552c00eae6', '0586', 4)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('1b49301a-d744-5452-b67b-25b1af7c72c5', 'e467d44f-fa26-5f3f-a988-e99190a97f7c', 1, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('f0bc0e8b-ad87-573c-8c3b-ef583c08fdf7', 'e467d44f-fa26-5f3f-a988-e99190a97f7c', 2, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('80862ce4-455d-5f04-8d0c-7993f92ca5d9', 'e467d44f-fa26-5f3f-a988-e99190a97f7c', 3, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('48f1c1f5-4c5d-55ce-be7f-88bf68bacd61', 'f502e915-f3b7-5620-9cbf-3c552c00eae6', '1372', 5)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('2c6296f8-c93a-5378-8761-33ce0b57bfef', '48f1c1f5-4c5d-55ce-be7f-88bf68bacd61', 1, 'normal', 0, 15, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('214e9bfe-9126-51bb-9a58-53be378c950c', '48f1c1f5-4c5d-55ce-be7f-88bf68bacd61', 2, 'normal', 0, 15, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('65f53b69-71c5-5846-8f68-5a159612d3e6', '48f1c1f5-4c5d-55ce-be7f-88bf68bacd61', 3, 'normal', 0, 15, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('e73f0205-25de-5096-9dfc-df8110be1c8a', '48f1c1f5-4c5d-55ce-be7f-88bf68bacd61', 4, 'normal', 0, 15, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_exercises (id, template_day_id, exercise_id, order_index)
VALUES ('0c0b281f-b813-5f58-a14f-c569541044bb', 'f502e915-f3b7-5620-9cbf-3c552c00eae6', '0472', 6)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('7996a7d9-fae3-548c-b37b-87524ab584be', '0c0b281f-b813-5f58-a14f-c569541044bb', 1, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('3ca2300a-488e-5f9b-875d-d00891ee09bd', '0c0b281f-b813-5f58-a14f-c569541044bb', 2, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.template_sets (id, template_exercise_id, order_index, set_type, weight_kg, reps, rir, rest_seconds)
VALUES ('2397dfa0-54bb-5bc0-927b-bf273d33364d', '0c0b281f-b813-5f58-a14f-c569541044bb', 3, 'normal', 0, 12, 1, 60)
ON CONFLICT (id) DO NOTHING;

