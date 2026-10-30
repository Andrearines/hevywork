-- 0001_esquema.sql
-- Tablas base de la cuenta (spec 001): perfil del atleta, sesiones,
-- ejercicios de la sesión y series. Reconstruida desde el esquema aplicado
-- en el proyecto remoto.

CREATE TABLE public.profiles (
    id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name text,
    unit_system text NOT NULL DEFAULT 'metric'
        CHECK (unit_system IN ('metric', 'imperial')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (id)
);

CREATE TABLE public.workouts (
    id uuid NOT NULL,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'finished', 'abandoned')),
    started_at timestamptz NOT NULL,
    ended_at timestamptz,
    notes text,
    client_updated_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (id)
);

CREATE TABLE public.workout_exercises (
    id uuid NOT NULL,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    workout_id uuid NOT NULL REFERENCES public.workouts(id) ON DELETE CASCADE,
    exercise_id text NOT NULL,
    order_index integer NOT NULL,
    notes text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (id),
    CONSTRAINT uniq_we_order UNIQUE (workout_id, order_index)
);

CREATE TABLE public.workout_sets (
    id uuid NOT NULL,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    workout_exercise_id uuid NOT NULL
        REFERENCES public.workout_exercises(id) ON DELETE CASCADE,
    order_index integer NOT NULL,
    set_type text NOT NULL
        CHECK (set_type IN ('warmup', 'normal', 'failure', 'drop')),
    reps integer NOT NULL CHECK (reps >= 1),
    weight_kg numeric NOT NULL CHECK (weight_kg >= 0),
    rir integer NOT NULL CHECK (rir >= 0 AND rir <= 10),
    completed boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (id),
    CONSTRAINT uniq_ws_order UNIQUE (workout_exercise_id, order_index)
);

CREATE INDEX idx_workouts_user ON public.workouts (user_id);
CREATE INDEX idx_workouts_user_time
    ON public.workouts (user_id, started_at DESC);
CREATE UNIQUE INDEX uniq_workouts_one_active
    ON public.workouts (user_id)
    WHERE status = 'active';
CREATE INDEX idx_workout_exercises_parent
    ON public.workout_exercises (workout_id);
CREATE INDEX idx_workout_exercises_user
    ON public.workout_exercises (user_id);
CREATE INDEX idx_workout_sets_parent
    ON public.workout_sets (workout_exercise_id);
CREATE INDEX idx_workout_sets_user
    ON public.workout_sets (user_id);
