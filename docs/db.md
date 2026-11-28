# db.md — estado y contratos de datos de hevywork

## Estado general

- **Local vigente:** drift SQLite en `lib/data/local/database.dart`,
  `schemaVersion = 20`. La v19 está implementada y aprobada por revisión en T-003;
  la v20 está implementada en T-004 y pendiente de revisión final independiente. Antes de
  022 era v18; la versión aprobada v21 (T-006) sigue sin aplicar.
- **Remoto:** Supabase Postgres/Storage; cambios solo mediante migraciones en
  `supabase/migrations/`, una por tarea cuando aplique.
- **Réplica/cola:** SQLite es réplica de trabajo offline; Supabase es fuente de
  verdad compartida. Toda escritura local es inmediata y toda tabla remota de
  usuario tiene `user_id` + RLS.
- **Unidades:** pesos en kg en base; conversión a lb solo al mostrar.
- **Ejecución:** T-003 aplicó 18→19 y T-004 aplicó 19→20, ambas con su código drift
  generado. No hay migración Supabase, v21 ni propagación remota de las columnas
  nuevas; la réplica de personalizados, preferencias, timers e imágenes corresponde
  a T-006.

## Relación con specs previas

Esquema fijado por las specs 001 (núcleo/sync), 005 (metas), 006 (medidas),
009 (fotos progreso), 010 (plantillas), 011 (health_metrics) y 013 (avatar,
drift v18). La 020 no cambia datos. La 021 permanece cerrada sin cambios de
esquema asociados a esta ampliación.

## Spec 022 — mapa de migraciones aprobado

| Tarea | drift | Supabase | Regla |
|---|---|---|---|
| T-001, sync existente | Sin cambio previsto | Sin migración prevista | Si el rojo exige SQL, se devuelve al planner para delimitar una única migración antes de aplicarla; no se improvisa ni se mezcla con T-006. |
| T-002, gráfico | Sin cambio | Sin migración | Solo cálculo/presentación. |
| T-003, descansos | **18→19** | Sin cambio remoto todavía | Crea preferencias locales finales y timers por `workout_exercise`; no encola columnas remotas inexistentes. Ejecuta `build_runner` en implementación. |
| T-004, personalizados | **19→20** | Sin cambio remoto todavía | Extiende `exercises` para filas custom/media; guardado offline. Ejecuta `build_runner`. |
| T-005, músculos | Reutiliza v19/v20 | Sin migración | Usa las columnas musculares creadas en v19; no añade otra versión. |
| T-006, sync nueva y Perfil | **20→21** | **Una migración** | Añade metadatos locales de sync y todo el contrato remoto en `20261123000000_spec022_custom_exercises_rest_sync.sql`. Ejecuta `build_runner`; no crea una segunda migración. |

La numeración drift es secuencial por dependencias T-003 → T-004 → T-006. Ninguna
tarea salta de versión ni modifica a mano `database.g.dart`.

## 1. Preferencias de catálogo — T-003/v19 y T-006/remoto

### Tabla local `exercise_preferences` (v19)

| Columna | Tipo | Regla |
|---|---|---|
| `id` | texto UUID | PK local; se conserva en remoto. |
| `local_user_id` | texto UUID | Obligatorio; propietario local. |
| `exercise_id` | texto | Referencia local a `exercises.id`; solo filas de catálogo. |
| `rest_seconds` | entero nullable | `NULL` o 15–300; preferencia de descanso de catálogo. |
| `target` | texto nullable | Parte del override muscular; los tres campos musculares son todos nulos o todos no nulos. |
| `muscle_group` | texto nullable | Derivado del primer secundario canónico u objetivo si no hay secundarios. |
| `secondary_muscles` | texto JSON nullable | Array JSON, incluido `[]` para override sin secundarios. |
| `created_at`, `updated_at` | `DateTime` | Auditoría local; `updated_at` cambia en cada mutación. |

Restricciones: PK `id` y `UNIQUE(local_user_id, exercise_id)`. Una fila sin
`rest_seconds` ni override muscular se elimina. La restauración muscular pone a
`NULL` únicamente `target`, `muscle_group` y `secondary_muscles`; conserva
`rest_seconds`. Si ello deja la fila vacía, borra la fila y encola su delete en
T-006.

En la migración 18→19 se copian únicamente los descansos de catálogo distintos de
90 que ya existan en `exercises.rest_seconds`, asociándolos al `local_user_id` del
perfil único. Desde v19, el descanso efectivo de catálogo es
`exercise_preferences.rest_seconds ?? 90`; la antigua columna queda como dato
legacy de migración y no se vuelve a escribir para catálogo. Los personalizados
usan directamente su propio `exercises.rest_seconds` desde v20.

### Tabla remota `public.exercise_preferences` (T-006)

Mismos campos de dominio, sustituyendo `local_user_id` por
`user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE`, más
`created_at/updated_at timestamptz NOT NULL DEFAULT now()`.

- `id uuid PRIMARY KEY`; `UNIQUE(user_id, exercise_id)`.
- `exercise_id text` no tiene FK remota: los IDs maestros viven en el asset.
- Checks para rango de descanso, consistencia de los tres campos musculares y JSON
  array de `secondary_muscles jsonb`.
- Índice `(user_id, exercise_id)`, trigger `set_updated_at` y RLS completa:
  select/insert/update/delete solo cuando `auth.uid() = user_id`.
- El payload usa `secondary_muscles` como array JSON, no como cadena con JSON
  escapado. Los nulos musculares y de descanso se conservan cuando representan
  restauración/borrado de preferencia.

## 2. Countdown por ejercicio — T-003/v19 y T-006/remoto

Se añaden a `workout_exercises`, no a `workouts`:

| Columna | Local/remoto | Regla |
|---|---|---|
| `rest_ends_at` | `DateTime` / `timestamptz`, nullable | Fin absoluto cuando corre o instante pasado cuando terminó. |
| `rest_paused_seconds` | entero nullable | Restante en pausa, `>= 0`. |

`rest_ends_at` y `rest_paused_seconds` no pueden ser no nulos a la vez. Idle/skip
usa ambos nulos; running usa solo `rest_ends_at`; paused usa solo
`rest_paused_seconds`; done conserva un `rest_ends_at` pasado. El tiempo restante
siempre se calcula contra `DateTime.now()`, nunca mediante decrementos de ticks.

Cada fila `workout_exercise` es un timer independiente. Los antiguos
`workouts.rest_ends_at/rest_paused_seconds` permanecen solo como fallback local
legacy: no se migran a un ejercicio arbitrario y desaparecen al terminar, saltarse
o comenzar un timer asociado. No se añaden al whitelist remoto.

T-003 implementa el modelo local sin encolar los nuevos campos. T-006 los añade a
Postgres con los mismos checks y al payload remoto de `workout_exercises`. Los
nulos se propagan al pausar/reanudar/saltar. El `rest_seconds` de `workout_sets`
continúa siendo planificación de serie y no se mezcla con este estado.

## 3. Personalizados locales — T-004/v20

La tabla local `exercises` sigue siendo la proyección común para catálogo y
personalizados. Se añaden:

| Columna | Tipo | Uso |
|---|---|---|
| `origin` | texto, default `catalog` | `catalog` o `custom`. |
| `local_user_id` | texto UUID nullable | `NULL` para catálogo compartido; obligatorio por check SQL para `custom`. |
| `image_storage_path` | texto nullable | Última/ruta prevista de Storage; nunca se confunde con `image_path` local. |
| `image_mime_type` | texto nullable | `image/jpeg`, `image/png` o `image/webp`. |
| `image_upload_status` | texto nullable | Custom: `none`, `pending_upload`, `uploaded`, `pending_delete`, siempre no nulo; catálogo: `NULL`. |
| `image_has_remote` | booleano nullable | Metadata solo local: distingue una primera subida pendiente (`false`) de un objeto remoto conocido (`true`), incluso durante un reemplazo; `NULL` en catálogo/legacy. |
| `updated_at` | `DateTime` nullable | Obligatorio para custom; `NULL` para filas maestras antiguas. |

Las columnas existentes se reutilizan así:

- `id = 'custom_<uuid>'`, evitando colisiones con los IDs del asset.
- `image_path` conserva asset path para catálogo y ruta absoluta del fichero local
  para custom. Nunca se envía esa ruta local a Postgres.
- `target`, `secondary_muscles`, `muscle_group`, `body_part`, `equipment` y
  `rest_seconds` contienen directamente los valores del custom.
- `gif_path` y `attribution` son `NULL` para custom; `created_at` se conserva.

El alta exige nombre, objetivo, equipo y parte del cuerpo recortados/no vacíos,
secundarios opcionales canónicos sin duplicados ni equivalencia con el objetivo y
descanso 15–300 s (90 al crear). `muscle_group` se deriva del primer secundario
canónico o del objetivo canónico si la lista está vacía. Como `cardiovascular system`
es un objetivo válido sin zona muscular, conserva ese mismo valor filtrable/no vacío y
fatiga, roles y mapa lo omiten sin inventar una región. Los helpers de canonicalización
aceptan tanto aliases como todos los valores ya canónicos reconocidos; el objetivo se
normaliza al vocabulario permitido y los desconocidos se rechazan. No hay borrado de
personalizados ni instrucciones custom en esta spec.

La búsqueda/paginación opera sobre la misma proyección con páginas de 50. El asset
nunca se reescribe al crear/editar un custom.

**Estado de implementación T-004 (2026-11-27):** la única migración 19→20, sus
checks e idempotencia y el generado v20 están implementados, incluida la metadata
local `image_has_remote`. Las pruebas de migración pasan 25/25 y, tras la iteración
correctora 2, la puerta completa no golden pasa 862/862 con `flutter analyze` sin
incidencias. La visibilidad limita customs al propietario; el descanso custom vive en
`exercises.rest_seconds` y las rutas locales no se añaden a payloads. Esta ejecución
está **pendiente de una nueva revisión independiente**, no aprobada, y no activa
sincronización ni Storage.

La apertura también repara una **v20 intermedia real** creada por la primera
implementación, aunque `onUpgrade` no se ejecute porque `user_version` ya sea 20. La
comprobación en `beforeOpen` es no-op si la tabla todavía no existe o si columna y CHECK
ya son correctos. Añade `image_has_remote` cuando esa es la única estructura ausente;
si el CHECK de status es antiguo, reconstruye `exercises` preservando datos, referencias
y cola. Un custom legacy con `image_upload_status NULL` se conserva como `none` durante
esa reconstrucción, y cualquier NULL nuevo queda rechazado. Una base ya correcta no se
reconstruye en reaperturas. No se incrementa la versión ni se crea otra migración.

## 4. Personalizados remotos — T-006

### Tabla `public.custom_exercises`

| Columna | Tipo/regla |
|---|---|
| `id` | `text PRIMARY KEY`, formato `custom_<uuid>`. |
| `user_id` | `uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE`. |
| `name`, `body_part`, `equipment`, `target`, `muscle_group` | `text NOT NULL`, recortados por la app. |
| `secondary_muscles` | `jsonb NOT NULL DEFAULT '[]'`, array de strings. |
| `rest_seconds` | `integer NOT NULL DEFAULT 90`, check 15–300. |
| `image_path` | `text NULL`; canonical `<user_id>/<exerciseId>` cuando hay imagen remota. |
| `image_mime_type` | `text NULL`; mismo vocabulario MIME que local. |
| `client_updated_at` | `timestamptz NULL`, informativo. |
| `created_at`, `updated_at` | `timestamptz NOT NULL DEFAULT now()`; actualización por trigger del servidor. |

Índice `(user_id, name)`, trigger `set_updated_at` y RLS select/insert/update/
delete con `auth.uid() = user_id`. Aunque no se ofrece borrado custom en la UI,
delete queda protegido por la misma política. No se crea una tabla remota general
`exercises` ni se replica el catálogo maestro.

## 5. Imagen y Storage — T-004/local y T-006/remoto

- Bucket privado **`custom-exercise-images`**, límite **2 MiB** y MIME permitidos
  `image/jpeg`, `image/png`, `image/webp`.
- Clave canónica: **`<auth.uid()>/<exerciseId>`**, sin extensión obligatoria. El
  contenido y `image_mime_type` determinan el formato; reemplazar usa upsert en la
  misma clave.
- Políticas `TO authenticated` para select/insert/update/delete que exigen
  `bucket_id = 'custom-exercise-images'` y
  `(storage.foldername(name))[1] = auth.uid()::text`.
- Antes del claim, la ruta prevista puede usar `local_user_id`; al subir se deriva
  siempre del usuario Auth real y se reescribe `image_path`. Nunca se confía en un
  `user_id` del payload.
- `image_picker` se configura con compresión razonable (máximo 1600×1600, calidad
  85 cuando la plataforma la admita). Antes de reemplazar una imagen se comprueban
  tamaño/firma, se decodifica un frame real con las APIs Flutter/Dart existentes y se
  validan dimensiones positivas; RIFF WebP debe declarar su longitud exacta. Un
  archivo vacío, corrupto/truncado, MIME no soportado o >2 MiB se rechaza en español
  conservando borrador, selección e imagen anterior.
- `pending_upload`: el fichero local permanece disponible offline y la subida se
  reintenta. `uploaded`: la metadata remota apunta al objeto; si falta el fichero
  local se descarga bajo demanda. `pending_delete`: la UI ya muestra fallback y la
  metadata remota queda nula, pero se conserva la última clave hasta borrar el
  objeto con éxito. `none`: sin imagen ni operación.
- `image_has_remote` se fija a `true` al conocer un objeto `uploaded`/`pending_delete`
  y no se pierde al reemplazarlo por una nueva subida pendiente. Por tanto, retirar
  ese reemplazo conserva clave y `pending_delete`; retirar una primera imagen nunca
  subida vuelve a `none`, sin clave. Filas `uploaded`/`pending_delete` legacy sin el
  bit se tratan como remotas conocidas. El bit nunca se serializa a sync.
- Metadata y bytes son eventualmente consistentes: un cliente que aún no puede
  descargar el objeto muestra `ThumbFallback`, sin error de guardado ni atribución.
  Perfil no puede mostrar «Actualizado» mientras exista media pendiente.
- Quitar/reemplazar imagen no elimina el ejercicio ni su historial. El borrado del
  objeto usa la última clave remota conocida; un fallo deja `pending_delete` y no
  pierde la intención.

## 6. Estado de sincronización — T-006/v21

Se añaden a `local_profiles`:

- `last_successful_sync_at DateTime NULL`: solo se actualiza tras claim válido,
  cola sin errores, media completa y descarga correcta.
- `sync_needs_attention boolean NOT NULL DEFAULT false`: se activa ante fallo de
  claim, dead-letter, descarga o Storage; se limpia tras un ciclo completamente
  correcto.

El estado de Perfil se deriva, no se persiste como texto independiente:

1. Sin sesión → «Sin cuenta».
2. Sesión con claim pendiente, cola/media pendiente y motor ocupado →
   «Sincronizando»; si no está ocupado → «Pendiente».
3. Dead-letter o `sync_needs_attention` → «Necesita atención».
4. Claim completo, cola vacía, sin media pendiente y descarga correcta →
   «Actualizado» con `last_successful_sync_at`.

Reintentar cambia cada `dead_letter` a `pending`, `attempts = 0` y
`next_attempt_at = now`, sin borrar payloads ni ficheros. Sin sesión no se consumen
intentos.

## 7. Whitelist, claim, descarga y conflictos

T-006 amplía `remoteColumns`:

- `custom_exercises`: columnas remotas anteriores, sin rutas locales ni estados de
  subida.
- `exercise_preferences`: columnas remotas de preferencia.
- `workout_exercises`: añade `rest_ends_at` y `rest_paused_seconds`.

Reglas especiales de payload:

- Los nulos que representan borrado de imagen, restauración muscular, ausencia de
  preferencia o transición de timer se conservan; no desaparecen por el filtro
  general de nulos.
- `secondary_muscles` viaja como array `jsonb`; fechas en ISO-8601; `created_at` y
  `updated_at` los asigna el servidor.
- `custom_exercises.image_path` se recalcula con el Auth UID. No se aceptan
  `origin`, `local_user_id`, `image_upload_status`, `image_has_remote` ni
  `image_storage_path` remoto.

La migración reemplaza `claim_local_data` preservando todas las reasignaciones
vigentes y añade `custom_exercises` y `exercise_preferences`. En una colisión de
preferencia `(user_id, exercise_id)` se resuelve de forma determinista por el
`updated_at` del servidor más reciente, sin violar unicidad ni dejar el claim a
medio completar. El perfil local solo fija `auth_user_id` tras éxito completo.

Descarga:

1. T-001 deja caracterizada/reparada la sincronización base sin presumir causa.
2. T-006 incorpora `custom_exercises` y `exercise_preferences` antes de resolver
   referencias de rutinas/workouts, y después los timers de `workout_exercises`.
3. Una fila remota no reemplaza una fila local con mutación pendiente/dead-letter
   para la misma entidad. Tras subir y confirmar, se acepta la versión del servidor.
4. Sin mutación local pendiente, Supabase gana; el servidor ordena escrituras
   concurrentes con `updated_at`. No se comparan relojes de dispositivos.
5. La réplica ocurre en arranque/login, tras escrituras, reanudación y ciclo de 30 s;
   no se añaden canales realtime ni dependencias.

La creación de un custom se encola antes de permitir referencias nuevas a él. La
cola existente conserva FIFO; los nuevos descargables resuelven custom/preferencias
antes de hidratar sus referencias. Un fallo de imagen no impide sincronizar los
datos del ejercicio, pero mantiene el estado global pendiente/de atención.

## 8. Restauración y compatibilidad

- La fuente maestra muscular es `assets/exercises.json` con
  `kCatalogMusclePatches` aplicado de forma idempotente. No se usa una fila local
  ya editada ni una versión remota custom como origen.
- Restaurar catálogo no modifica `exercises.target/secondary_muscles/muscle_group`
  maestros: elimina solo el override efectivo de `exercise_preferences`.
- Las migraciones conservan workouts, rutinas, series, historial, imágenes previas,
  descansos y asset. `custom_<uuid>` mantiene resolubles las referencias por texto.
- Toda operación funciona sin cuenta/red. RLS/Storage se prueban con dos usuarios;
  offline se prueba con Supabase ausente y errores inyectados.

## 9. Puerta de implementación

Cada tarea que toque drift ejecuta el comando aprobado de `build_runner` y tests de
upgrade. T-006 revisa SQL/RLS/Storage antes de aplicar su única migración. Al
terminar cada tarea: `flutter test --exclude-tags golden` completa en verde y
`flutter analyze` sin incidencias, sin modificar PNG, añadir dependencias ni hacer
commits/push nuevos sin permiso. Las únicas excepciones son D-119, para conservar en
T-001 el commit ya existente/publicado
`9d62bac3966bfbab78e8fb0e1f1a53c6fd7c07fd`, y D-135, para conservar en T-004 el
commit/push ya existente `9c2ec8a2c6f019177996658009d85a7260e098eb`. Ninguna se
extiende a otro hash ni autoriza nuevas operaciones Git o reescritura de historial.
