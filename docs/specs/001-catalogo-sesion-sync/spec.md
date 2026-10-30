# Spec 001 — Catálogo local, sesión de entrenamiento y sincronización

## Contexto y objetivo
El usuario abre la app en el gimnasio (sin cobertura), elige ejercicios del
catálogo local, registra series con reps, peso, RIR y tipo de serie, y al
recuperar conexión todo se sincroniza a Supabase. Multi-dispositivo: una sola
sesión activa por cuenta; el reloj del servidor decide los conflictos.

## Usuarios
Deportistas que entrenan con uno o varios dispositivos. Cuenta Supabase Auth
opcional al inicio (Google Sign-In); si no hay conexión, la app funciona en
modo local y la cuenta se reclama al hacer login con Google.

## Historias de usuario
- H1: Como usuario quiero abrir la app sin conexión y ver los 1.324 ejercicios
  para empezar a entrenar ya.
- H2: Como usuario quiero registrar series con reps, peso, RIR y tipo
  (calentamiento/normal/fallo/drop) y ver mi e1RM al instante.
- H3: Como usuario quiero que mis datos lleguen a Supabase cuando haya red,
  sin que yo tenga que pulsar nada.
- H4: Como usuario con dos dispositivos quiero que el que gane en un conflicto
  sea el más reciente según el reloj del servidor.
- H5: Como usuario quiero tener una sola sesión en curso; si abro otra en otro
  dispositivo, la anterior se marca como abandonada.

## Requisitos funcionales (EARS)

### Catálogo local (H1)
- RF-1: CUANDO la app arranca, EL SISTEMA carga el asset de metadatos
  (≈1,8 MB, 1.324 ejercicios, instrucciones en `es` y `en`) en la tabla
  local `exercises` sin acceso a red. El asset se genera desde el clon
  local de `exercises-dataset/` con `dart run tool/build_catalog_asset.dart`
  y solo contiene los campos que la app usa.
- RF-2: MIENTRAS no hay conexión, EL SISTEMA permite buscar y filtrar
  ejercicios contra la base local.
- RF-3: CUANDO se abre la ficha de un ejercicio, EL SISTEMA muestra su
  miniatura JPG empaquetada (sin red) y, si hay red o caché, el GIF desde el
  bucket público `exercise-media` de Supabase Storage con
  `cached_network_image` (gestor por defecto). Si el GIF no está en caché y
  no hay red, muestra la miniatura local; si esta tampoco existe, placeholder.
  La atribución `© Gym visual` se muestra en la ficha.
- RF-4: EL SISTEMA NUNCA borra ejercicios del catálogo local; solo añade en
  actualizaciones de la app.

### Sesión de entrenamiento (H2)
- RF-5: CUANDO el usuario pulsa "Nueva sesión", EL SISTEMA crea un
  `workout` con `status = 'active'`, `local_user_id` del perfil local y
  `started_at = now()` local.
- RF-6: CUANDO el usuario añade un ejercicio a la sesión, EL SISTEMA crea
  `workout_exercise` con `order_index` y referencia al `exercise_id` local.
- RF-7: CUANDO el usuario registra una serie, EL SISTEMA crea `workout_set`
  con `set_type ∈ {warmup, normal, failure, drop}`, `reps ≥ 1`,
  `weight_kg ≥ 0`, `RIR ∈ [0,10]`, `completed = true`.
- RF-8: EL SISTEMA calcula y muestra `e1RM = weight_kg × (1 + (reps + RIR)/30)`
  solo si `reps ≤ 12`. SI `reps == 1 && RIR == 0`, ENTONCES `e1RM = weight_kg`.
- RF-9: EL SISTEMA computa volumen como `Σ reps × weight_kg` para series
  `normal + failure + drop`, con series `drop` al 50 %. Las `warmup` se
  excluyen de volumen y fatiga.
- RF-10: SI el usuario intenta cerrar la sesión con 0 series completadas,
  ENTONCES EL SISTEMA borra el `workout` y lo confirma.

### Sincronización (H3)
- RF-11: MIENTRAS hay cambios locales sin subir, EL SISTEMA los encola en
  `sync_queue` con `op`, `payload`, `attempts = 0`, `next_attempt_at = now()`.
- RF-12: CUANDO la app detecta conexión (reanudación, timer periódico 30 s,
  tras cada escritura local), EL SISTEMA procesa la cola en orden FIFO.
- RF-13: PARA cada item, EL SISTEMA mapea el payload a las columnas remotas
  (descarta las columnas locales que no existen, inyecta `user_id` o
  `id = auth.uid()` en `profiles`, `client_updated_at` y los campos NOT NULL
  sin defecto) y hace `upsert` en Supabase con `on_conflict: id`; SI
  `op = delete`, borra la fila remota por `id`. El servidor setea
  `updated_at = now()` via trigger. Las fechas viajan en ISO-8601.
- RF-14: SI el upsert falla por red, EL SISTEMA incrementa `attempts` y
  programa `next_attempt_at` con backoff exponencial (1 s, 2 s, 4 s, 8 s,
  máx. 60 s). NUNCA bloquea la UI. SIN sesión, no se consume ningún intento.
- RF-15: CUANDO un item llega a `attempts > 10`, EL SISTEMA lo marca como
  `dead_letter` en `sync_queue.status` y notifica al usuario (toast), sin
  borrarlo.

### Login diferido, Google Sign-In y claim (H3, H5)
- RF-16: EL SISTEMA integra el SDK nativo de Google Sign-In (`google_sign_in`)
  para obtener el `idToken` y realizar el login en Supabase vía
  `supabase.auth.signInWithIdToken()`.
- RF-17: AL iniciar sesión con éxito, EL SISTEMA invoca la RPC
  `claim_local_data(p_local_user_id)` (SECURITY DEFINER) que reasigna
  `user_id = auth.uid()` a todas las filas del perfil local. Sin esta RPC,
  RLS impediría leer lo propio.
- RF-18: EL SISTEMA borra `local_profile.auth_user_id` y escribe el
  `auth.uid()`; a partir de entonces todo usa el `user_id` real.
- RF-25 (amenda T-20): EL SISTEMA permite iniciar sesión y crear cuenta con
  correo y contraseña contra Supabase Auth
  (`supabase.auth.signInWithPassword()` / `supabase.auth.signUp()`). AL
  entrar con sesión, invoca `claim_local_data` (RF-17). SI el alta queda
  pendiente de confirmación de correo (sin sesión), informa que se envió el
  mensaje y no ejecuta el claim. Los errores de Auth se muestran traducidos
  al español.

### Resolución de conflictos y sesión única (H4, H5)
- RF-18: EL SERVIDOR decide el ganador por `updated_at` (trigger `now()`).
  El cliente solo manda `client_updated_at` informativo.
- RF-19: CUANDO el usuario inicia una sesión en un dispositivo y ya hay otra
  `active` en la cuenta, EL SISTEMA pone la anterior a `status = 'abandoned'`
  y crea la nueva. La abandonada se sincroniza y queda en el historial.

### Base de datos local (drift)
- RF-20: Tablas: `exercises`, `exercise_instructions`, `workouts`,
  `workout_exercises`, `workout_sets`, `profiles`, `sync_queue`,
  `local_profile`. `schemaVersion = 2` en la 001 (v2: `sync_queue.status`
  para el `dead_letter` de RF-15).
  - `exercises` guarda además `secondary_muscles` como JSON, `media_id`,
    `image_path`, `gif_path`, `attribution` y `created_at`, tomados del
    dataset; las miniaturas JPG van empaquetadas en `assets/images/` y los
    GIFs en el bucket `exercise-media`, del que solo se persisten rutas.
  - `exercise_instructions` guarda `language` (`es`, `en`) con clave
    `(exercise_id, language, step_number)`.
- RF-21: `local_profile` tiene `id = 1` (CHECK), `local_user_id uuid`,
  `auth_user_id uuid nullable`, `display_name`, `unit_system`.

### Base de datos remota (Postgres)
- RF-22: Tablas: `profiles`, `workouts`, `workout_exercises`,
  `workout_sets`. Con RLS y `user_id`. Sin tabla `exercises`.
- RF-23: Trigger `set_updated_at` en cada tabla de usuario: `updated_at = now()`.
- RF-24: RPC `claim_local_data(p_local_user_id uuid)` SECURITY DEFINER.

- RF-26 (amenda 2026-10-20, alineación de esquema): el historial de
  migraciones refleja lo realmente aplicado en Supabase
  (`20260929194019_0001_esquema`, `20260929194042_0002_rls_y_funciones`,
  `20261006161609_0003_exercise_media_bucket` y las migraciones 004–012).
  `profiles` se identifica por `id = auth.uid()` (su PK, sin `user_id`),
  `workouts.name` viaja al remoto y los nulos del perfil se propagan para
  poder borrar nombre, sexo o altura. `claim_local_data` conserva la
  reasignación del perfil además de las tablas de datos.

## Requisitos no funcionales
- Arranque en frío < 1 s en móvil medio (catálogo ya en disco).
- Escritura local < 50 ms (sin red).
- Sincronización en segundo plano; UI siempre responsiva.
- Plataformas: Android, iOS, web, Linux, macOS, Windows.

## Casos límite
- App cerrada a mitad de sesión → RF-25 (ver 002): se reanuda.
- Dos series con mismo `order_index` por bug → `UNIQUE (workout_exercise_id, order_index)`.
- `weight_kg` con más de 3 decimales → redondeo a 0.001 kg en persistencia.
- Usuario sin cuenta durante semanas → cola crece; límite práctico 10 000 items.

## Fuera de alcance (001)
- Deshacer/editar series (002).
- Timer de descanso (002).
- Filtros avanzados de ejercicios (003).
- Rutinas, objetivos, medidas, mapa muscular (004–007).

## Criterios de finalización
- Todos los RF con test automático (unit/widget) + `flutter test` verde.
- `flutter analyze` sin issues.
- Demo manual: offline → 3 ejercicios × 3 series → cerrar → online → verificar en Supabase.

## Dudas abiertas
- Ninguna en la 001. Todas las decisiones están cerradas arriba.