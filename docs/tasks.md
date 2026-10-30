# Tareas Activas — hevywork

Este documento rastrea la ejecución de las tareas a nivel técnico. Specs 001 a
004 cerradas; la **Spec 005 (Objetivos y metas)** está en curso.

## Fase 1: El Núcleo de Entrenamiento (Spec 001)

### Bloque de Infraestructura y Datos Locales
- [x] **T1: Configuración de Base de Datos Local (Drift)**
  - Definir tablas en Drift: `exercises`, `exercise_instructions`, `workouts`, `workout_exercises`, `workout_sets`, `profiles`, `sync_queue`, `local_profile`.
  - Asegurar uso estricto de `local_user_id` donde corresponda.
  - Implementar script de regeneración de código `build_runner`.
  - `local_profile` arranca con un UUID real generado con `uuid` (antes `pending-uuid`).

- [x] **T1b: Recuperación del esquema local obsoleto**
  - `schemaVersion` 2 → 3. Al abrir, si el fichero local no tiene las columnas actuales (`exercises.image_path`, `exercise_instructions.language`, `sync_queue.status`), la migración descarta las tablas antiguas (incluidas las FTS sobrantes) y las vuelve a crear; `initializeCatalogIfEmpty()` vuelve a sembrar el catálogo.
  - El fichero local creado el 29/09 llevaba el esquema anterior (`asset_image`, `locale`/`step`/`text`, `sync_queue` sin `status`) y estaba ya en `user_version = 2`, así que drift no migraba y cualquier consulta fallaba con `no such column`. Verificado sobre una copia real de `~/Documents/hevywork.sqlite`.
  - Tests: `test/migration_test.dart` (2: reconstrucción desde esquema antiguo y subida de versión conservando datos).

- [x] **T2: Carga del Catálogo Local**
  - Script `tool/build_catalog_asset.dart`: genera `assets/exercises.json` (≈1,8 MB, 1.324 registros, instrucciones en `es` y `en`) desde el clon local `exercises-dataset/`, que queda fuera del repo.
  - Esquema adaptado al dataset: `exercises` con `media_id`, `image_path`, `gif_path`, `attribution`, `created_at` y `secondary_muscles` en JSON; `exercise_instructions` con `language`.
  - `initializeCatalogIfEmpty()` inserta ejercicios y pasos en una sola transacción, sin red, sin duplicar y sin borrar (RF-1 / RF-4).
  - Tests: `test/catalog_repository_test.dart` (conteos, fidelidad al dataset, `es`/`en`, idempotencia).

### Bloque de Backend Remoto y Autenticación (Supabase)
- [x] **T3: Configuración de Google Sign-In**
  - Configurar OAuth de Google en el Dashboard de Supabase. (Requiere acción manual del usuario en el dashboard).
  - Implementar flujo nativo con `google_sign_in` en Flutter (obtención de `idToken` y `accessToken`).
  - Autenticar en Supabase usando `signInWithIdToken`.

- [x] **T4: Esquema Supabase y Migraciones**
  - Crear archivo SQL en `supabase/migrations/` para `profiles`, `workouts`, `workout_exercises`, `workout_sets`.
  - Configurar RLS estricto (`auth.uid()`) en todas las tablas de usuario.
  - Añadir Trigger automático para actualizar `updated_at = now()`.
  - Crear RPC `claim_local_data` (SECURITY DEFINER) para migración al autenticarse.
  - Reaplicado desde el historial el 06/10/2026: la BD remota estaba sin
    tablas en `public`. Verificado: 4 tablas, 16 políticas RLS, 4 triggers
    `updated_at`, índices (`uniq_workouts_one_active`, `uniq_we_order`,
    `uniq_ws_order`) y RPC `claim_local_data` + `set_updated_at`.

### Bloque de Sincronización
- [x] **T5: Motor de Sincronización por Cola**
  - [x] Servicio que encola escrituras locales en `sync_queue` y procesador FIFO con backoff exponencial e incremento de `attempts`.
  - [x] Ids de cola con `uuid`; cliente Supabase opcional para que la app arranque y funcione en local sin credenciales.
  - [x] **RF-13**: `lib/data/sync/sync_payload.dart` mapea el payload a las columnas reales de Postgres (descarta `routine_id`, `name`, `target_*`…), inyecta `user_id`/`id = auth.uid()`, `client_updated_at` y `rir`/`weight_kg` (`NOT NULL`); `op = delete` borra la fila remota por `id`.
  - [x] **RF-14**: backoff 1 s → 60 s con techo de 60 s; sin sesión no se consume ningún intento (login diferido, RF-16).
  - [x] **RF-15**: `sync_queue.status` (`pending` / `dead_letter`, `schemaVersion` 1 → 2) y aviso por toast: `SyncEngine.notices` → `SnackBar` en `main.dart`.
  - [x] Tests: `test/sync_engine_test.dart` (11: mapeo de las 4 tablas, upsert, delete, backoff, techo, dead_letter, enqueue, modo local).
  - [x] Verificado contra Supabase real con usuario de prueba: upsert `on_conflict=id` de las 4 tablas con JWT de usuario (RLS), conflicto resuelto (reps 8 → 10) y limpieza completa (0 filas, 0 usuarios).

### Sincronización — cableada con la UI
- [x] **RF-11 con escritores reales**: `WorkoutRepository` (`startWorkout`, `addExercise`, `logSet`, `finishWorkout`) encapsula RF-5/6/7/10 y encola los payloads por `enqueueMutation` (inyectable en el constructor). `main.dart` lo cablea con `syncEngine.enqueueMutation`.
  - Tests: `test/workout_repository_test.dart` (10: sesiones, ejercicios, series, validaciones RF-7, RF-10, RF-19 y payloads encolados).

### Bloque de Interfaz de Usuario y Dominio
- [x] **T6: Dominio del Entrenamiento**
  - Lógica para calcular `e1RM` basado en fórmula de spec (`weight_kg × (1 + (reps + RIR)/30)`).
  - Lógica para cómputo de volumen (excluyendo calentamientos, penalizando dropsets 50%).
  - Lógica para prevención de sesiones superpuestas (abandonar anterior si se inicia nueva).
  - Tests: `test/workout_manager_test.dart` (RF-8 y RF-9).

- [x] **T7: UI - Navegación Base y Catálogo**
  - Fuentes Space Grotesk y Geist (7 TTF, SIL OFL) en `assets/fonts/` y bloque `fonts:` en `pubspec.yaml`.
  - Paleta única en `lib/app/theme/palette.dart` (con `lib/ui/theme/colors.dart` de re-export), tema global con `buildAppTheme()` en `lib/app/theme/app_theme.dart`.
  - `HevyAppBar` y `HevyBottomNav` (4 destinos, blur 24, `Semantics`); destino sin spec reservado con `SoonView`.
  - `main.dart` con `IndexedStack` (conserva el estado del catálogo); `catalog_view.dart` y `live_workout_view.dart` sin colores hardcodeados.
  - En PROGRESO se usa `Icons.show_chart`: `Icons.monitoring` (del `designer.md` §8.1) no existe en el set `Icons` de Flutter 3.47.
  - Tests: `test/app_shell_test.dart` (5).

- [x] **T8: UI - Registro de Sesión en Vivo**
  - Implementar pantalla principal de entrenamiento, utilizando el sistema de elevación y jerarquía sin sombras (`designer.md`).
  - Tabla de series interactiva (estados activo, pendiente y completado).
  - Botones CTA, steppers numéricos, y visualización de e1RM/Volumen en tiempo real.
  - `LiveWorkoutView` con `StreamBuilder` sobre `watchWorkout`/`watchExercises`/`watchSets` (streams cacheados en el `State`; `StreamBuilder` resuscribe si cambia la identidad del stream, y cada `watch*` devuelve uno nuevo), ticker de tiempo con `Timer.periodic` y `SnackBar` para `SetValidationException`.
  - El picker del catálogo añade ejercicios a la sesión abierta y el botón de cerrar confirma (borra sin series, RF-10).
  - Tests: `test/live_workout_view_test.dart` (4: registro de serie con e1RM, validación de repeticiones, alta de ejercicio por picker, cierre con confirmación).

## Fase 2: Experiencia de Entrenamiento Fluida (Spec 002)

### Bloque de Deshacer y Editar
- [x] **T9: Deshacer y editar series** (RF-1 a RF-4)
  - `WorkoutRepository.undoLastSet()` pone la última serie `completed` a
    `false` sin borrarla; sin series completadas devuelve `null` (RF-2).
  - `WorkoutRepository.updateSet()` valida los mismos rangos que RF-7,
    redondea a 0.001 kg, actualiza `updated_at` local y re-encola con
    `completed = true` (editar una serie deshecha la vuelve a confirmar).
  - Ambos rechazan sesiones `finished`/`abandoned` con
    `SessionNotEditableException` (RF-4).
  - UI: botón "Deshacer" en la barra inferior (deshabilitado con tooltip
    "Nada que deshacer") y fila de serie pulsable que abre la hoja
    "Editar serie" con tipo, KG, REPS y RIR.
  - Tests: `test/workout_repository_test.dart` (+7: cascada, re-encolado,
    rangos RF-7, reconfirmación, sesión cerrada) y
    `test/live_workout_view_test.dart` (+2: deshacer y edición).

### Bloque de Temporizador de Descanso
- [x] **T10: Temporizador de descanso** (RF-5 a RF-8)
  - Dominio puro `RestTimer` anclado a `DateTime` (±1 s en background;
    pausa/reanudar/ajustar/saltar, nunca negativo).
  - `exercises.rest_seconds` (default 90, CHECK 15–300), `schemaVersion`
    3 → 4, ajuste en la ficha del ejercicio (stepper ±15 s).
  - Aviso en primer plano con `SystemSound` + `HapticFeedback`; en
    background con `flutter_local_notifications` + `timezone` (aprobado §2 en
    la spec): `zonedSchedule` con `AndroidScheduleMode.exactAllowWhileIdle`,
    permisos y receivers en el manifest.
  - UI: franja de descanso con cuenta atrás, pausar, ±15 s y saltar;
    `WidgetsBindingObserver` programa el aviso al pasar a background y lo
    cancela al volver.
  - Tests: `test/rest_timer_test.dart` (5), `test/workout_repository_test.dart`
    (+1 persistencia local sin encolar), `test/live_workout_view_test.dart`
    (+2 franja), `test/catalog_repository_test.dart` (+2 rango),
    `test/exercise_detail_view_test.dart` (+1 ajuste) y migración v3→v4.

### Bloque de Reanudar Sesión
- [x] **T11: Reanudar sesión tras cierre** (RF-9 a RF-11)
  - `local_profile.last_active_workout_id`, `schemaVersion` 4 → 5.
  - Al arrancar: sesión `active` reciente se reabre sola; si tiene más de
    7 días se pregunta reanudar o abandonar (abandonar = RF-19).
  - `restoreLastActiveWorkout()` limpia marcadores huérfanos;
    `finishWorkout`/`abandonWorkout` limpian el marcador; el marcador es
    estado local y nunca se sincroniza.
  - Tests: `test/workout_repository_test.dart` (+7: marcador, restore,
    huérfano, cierre, abandono), `test/app_shell_test.dart` (+3: reapertura
    automática, prompt abandonar, prompt reanudar) y migración v4→v5.

## Fase 3: Buscador y filtros de ejercicios (Spec 003)

### Bloque de Buscador y Filtros
- [x] **T12: Búsqueda y filtros en el repositorio** (RF-1 a RF-5)
  - `lib/domain/search_text.dart`: normalización del texto de búsqueda
    (minúsculas, sin acentos precompuestos ni combinantes, espacios
    colapsados) — el catálogo es ASCII y basta con normalizar la consulta.
  - `lib/domain/exercise_filter.dart`: `ExerciseFilter` + `ExerciseDimension`;
    OR dentro de cada dimensión, AND entre dimensiones y con la búsqueda
    (decisión aprobada en la spec).
  - `searchPage(query, filter, offset, pageSize)` devuelve la página y el
    total (contador RF-4); predicado común con `LIKE` escapado (los comodines
    son literales) y `COALESCE` para el JSON de `secondary_muscles`.
  - `filterOptions()` lee los valores de cada dimensión de la base local
    (10/28/19/29/40), sin traducir (§9).
  - Tests: `test/search_text_test.dart` (5), `test/exercise_filter_test.dart`
    (5) y `test/catalog_repository_test.dart` (+12: RF-1 acentos/case/literal,
    AND entre filtros, OR dentro, paginación, contador, opciones).

### Bloque de Interfaz
- [x] **T13: UI de buscador con filtros y scroll infinito**
  - Franja de 5 píldoras (Cuerpo/Equipo/Objetivo/Músculo/Secundarios) que
    abren una hoja de selección múltiple; contador de resultados y botón
    "Limpiar filtros" con filtros activos (RF-4).
  - Scroll infinito: pide la página siguiente al llegar al 80 % del scroll
    (RF-5); una generación descarta las peticiones obsoletas al cambiar
    búsqueda o filtro (caso límite de la 003).
  - 1 carácter no filtra (RF-1); 0 resultados → "Prueba otros filtros".
  - Tests: `test/catalog_view_test.dart` (5: búsqueda, umbral de 2 car.,
    filtro+limpiar, 0 resultados, OR en la hoja) y
    `test/catalog_view_pagination_test.dart` (1: el scroll carga las páginas).

### Tanda de adaptación al dataset (cerrada)
- [x] `assets/exercises.json` regenerado desde `exercises-dataset/` con el script de `tool/`.
- [x] Esquema local y loader alineados con el schema del dataset (`exercises.schema.json`).
- [x] Credenciales de Supabase por `--dart-define` (`SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`), sin valores hardcodeados en `lib/` (§10).
- [x] Restos prohibidos eliminados: `prisma/`, `package.json`, `package-lock.json`, `node_modules/` (§2 y §5); `exercises-dataset/` ignorado por git.
- [x] `flutter analyze` sin incidencias y `flutter test` en verde.

### Tanda de media del catálogo (RF-3)
- [x] Miniaturas JPG empaquetadas: `tool/build_catalog_asset.dart` copia `exercises-dataset/images/` a `assets/images/` (1.324, ≈8,7 MB, limpia huérfanas) y `assets/images/` está en `pubspec.yaml`.
- [x] Bucket público `exercise-media` (`image/gif`, 5 MB) creado con `supabase/migrations/0003_exercise_media_bucket.sql`.
- [x] 1.324 GIFs subidos con `dart run tool/upload_gifs.dart` (idempotente: lista lo subido antes de subir).
- [x] `lib/domain/media.dart`: `thumbAsset()` → asset local; `gifUrl()` → URL pública del bucket, `null` sin credenciales.
- [x] Lista del catálogo con miniatura y `ExerciseDetailView`: GIF con `CachedNetworkImage`, fallback a la miniatura local, pasos `es`/`en` y atribución.
- [x] Tests: `test/media_test.dart`, miniaturas empaquetadas en `catalog_repository_test.dart`, `test/exercise_detail_view_test.dart`.

## Fase 4: Rutinas y plantillas (Spec 004)

### Bloque de Datos y Dominio
- [x] **T14: CRUD de rutinas y progresión (RF-1 a RF-4)**
  - Tablas `routines` y `routine_exercises` (drift schemaVersion 6 + migración; SQL remoto en `supabase/migrations/0004_routines.sql` con RLS y `user_id`); targets clonados a `workout_exercises` al instanciar (RF-2).
  - `RoutineRepository`: crear/editar/borrar con reconciliación por id y cola de sync; `watchRoutines`/`watchExerciseCounts`; `startWorkoutFromRoutine` abandona la sesión activa (RF-19) y omite ejercicios fuera del catálogo con aviso; rutina vacía no arranca.
  - Progresión (RF-3/RF-4): `lib/domain/progression.dart` — objetivo cumplido = `target_sets` series completadas con `reps >= target_reps` y `rir <= target_rir`; sugerencia `peso + 2.5 kg` solo con `auto_progress` activo (default ON); `applyProgressedWeight` persiste en la rutina al Aceptar.
  - Tests: `test/routine_repository_test.dart` (18: CRUD, reorden sin chocar la UNIQUE `(routine_id, order_index)`, instanciación, progresión, payloads de sync).

### Bloque de Interfaz
- [x] **T15: UI de rutinas (RF-1 a RF-4)**
  - `RoutinesView` (tab Rutinas): tarjetas con nombre, descripción y nº de ejercicios; crear/editar/borrar con confirmación; Entrenar deshabilitado con tooltip si la rutina está vacía.
  - `RoutineEditorView`: nombre, descripción, ejercicios del `ExercisePicker` con objetivo (series, reps, RIR, kg sugerido) y switch `Progresión automática`; reordenar por drag; valida objetivos fuera de rango.
  - Sesión nacida de rutina: al cerrar, hoja de progresión ejercicio a ejercicio con Aceptar/Ignorar/Sobrescribir; Aceptar escribe `+2.5 kg` en la rutina (RF-4).
  - Tests: `test/routines_view_test.dart` (6), `test/routine_editor_view_test.dart` (4) y cierre por hoja en `test/live_workout_view_test.dart` (2).

### Incidencias abiertas
- [x] **Esquema local vs remoto** (resuelto 2026-10-20): el historial
  `supabase/migrations/` se reconstruyó con las versiones aplicadas
  (`0001_esquema`, `0002_rls_y_funciones`, `0003_exercise_media_bucket`) y se
  aplicaron 004–012 al remoto: `routines`, `routine_exercises`, `routine_sets`,
  `goals`, `body_metrics`, `progress_photos`, `workouts.name` y las columnas
  de composición. El mapeo de `buildRemoteRow()` quedó alineado: `profiles`
  por `id`/`display_name`/`unit_system`, nulos del perfil propagados y
  `workouts.name` incluido. `claim_local_data` reasigna también el perfil y
  sobrevive a cada redefinición.
- [ ] El clon `exercises-dataset/` ya no está en la raíz: `tool/build_catalog_asset.dart` y `tool/upload_gifs.dart` necesitan re-clonarlo (avisan con un mensaje claro). El asset, las miniaturas y los GIFs ya están generados.

## Fase 5: Objetivos y metas (Spec 005)

### Bloque de Datos y Dominio
- [x] **T16: Metas, progreso y peso corporal (RF-1 a RF-4, RF-11)**
  - Tablas locales `goals` (con `baseline_value` solo local) y `body_weight`
    en drift (schemaVersion 7 + migración); SQL remoto en
    `supabase/migrations/0005_goals.sql` con RLS, triggers `updated_at` y
    `claim_local_data` extendido; `buildRemoteRow` mapea `goals` y
    `body_weight` (descarta `baseline_value`).
  - `lib/domain/goals.dart`: e1RM objetivo, `setVolumeKg` (sin warmups,
    drops al 50 %), mejor marca de fuerza, constancia en ventana móvil de
    7 días, dirección de peso por `baseline`, progreso que cierra la brecha
    y estados sticky (`achieved`/`abandoned` no se revierten).
  - `GoalRepository`: CRUD (editar reactiva la meta), registro de peso,
    `recalculate()` al cerrar sesión, abrir la app / el tab y registrar peso;
    cada escritura encola su payload (RF-11).
- [x] Tests: `test/goals_test.dart` (dominio puro), `test/goal_repository_test.dart`
  (CRUD, payloads, registro de peso, recálculo de los 4 tipos, plazos y
  stickiness), migración v6→v7 y `buildRemoteRow` de ambas tablas.

### Bloque de Interfaz
- [x] **T17: Dashboard de metas (H3, RF-2, RF-4)**
  - Tab Progreso → `ProgressView`: banner «¡Metas logradas!», tarjetas por
    tipo con % de cumplimiento, acciones de editor/borrar con confirmación,
    diálogo «Registrar peso» y recálculo al abrir.
  - `GoalEditorView`: formulario por tipo (peso, fuerza con ejercicio, volumen
    por ejercicio/músculo con periodo, constancia) y plazo; al cerrar sesión,
    snackbar «¡Meta lograda! / ¡N metas logradas!» (RF-4).
  - Tests: `test/progress_view_test.dart` (6) y `test/goal_editor_view_test.dart`
    (5).

---

## Fase 6: Peso y medidas corporales (Spec 006)

### Bloque de Datos y Dominio
- [x] **T18: Registro diario de peso y medidas (RF-1, RF-2, RF-11)**
  - `lib/domain/body_metrics.dart`: `kBodyMeasures` (Cuello, Pecho, Brazo,
    Cintura, Pierna, Pantorrilla), `measureLabel`, `decodeMeasures` /
    `encodeMeasures` y `measureDeltas` frente al registro anterior.
  - Tabla `body_metrics` en drift (schemaVersion 10): PK compuesta
    `(local_user_id, date)`; la migración v9→v10 consolida `body_weight`
    (una fila por día) y lo descarta. SQL remoto en
    `supabase/migrations/0007_body_metrics.sql` con PK `(user_id, date)`, RLS,
    trigger `updated_at` y `claim_local_data` actualizado.
  - `BodyMetricRepository`: upsert por día (el último gana, campos `Value(null)`
    pueden limpiarse), borrado de cualquier fecha, `latestWeightKg()`; cada
    cambio encola su payload por fecha (RF-11). `GoalRepository` deja de
    escribir peso y solo lee (`_latestWeightKg()`).
  - `sync_payload`/`sync_engine`: `body_metrics` exige `date` (no `id`);
    el push elimina por `.eq('user_id').eq('date')` y hace
    `onConflict: 'user_id, date'`.
- [x] Tests: `test/body_metrics_test.dart` (dominio), `test/body_metric_repository_test.dart`
  (upsert, edición, borrado, validaciones, payloads), migración v6→v10 y
  v9→v10 con copia verificada, `buildRemoteRow` de `body_metrics`, y
  `goals_test.dart` con registros sin peso.

### Bloque de Interfaz
- [x] **T19: Tendencia y tabla de medidas en Progreso (RF-3)**
  - Sección «Peso y medidas» bajo las metas en `ProgressView`: sparkline
    (`lib/ui/widgets/weight_trend.dart`, `CustomPainter` según designer §7.9)
    con chips 30/90/365, botón «Añadir registro», tarjetas de registro con Δ
    frente al anterior y menú Editar/Borrar (confirmación), con recálculo de
    metas al guardar/borrar.
  - `BodyMetricEditorView`: fecha picker, peso opcional, las seis medidas en
    cm, notas y validación («Añade peso o medidas», «Pon un peso válido»).
  - Tests: `test/progress_view_test.dart` (10) y
    `test/body_metric_editor_view_test.dart` (6).

---

## Fase 7: Mapa muscular de fatiga (Spec 007)

### Bloque de Datos y Dominio
- [x] **T20: Modelo de fatiga y cache local (RF-1, RF-2, RF-6)**
  - `lib/domain/muscle_fatigue.dart`: tabla de equivalencias interna
    (`kMuscleAliases`, los 29 grupos del dataset → 15 músculos canónicos),
    `setFatigueFactor` (normal/failure 1.0, drop 0.5, warmup 0),
    `fatigueDecayFactor` (`e^(-días/7)`), suma ponderada por músculo
    (`rawMuscleFatigue`) y normalización 0–1 relativa al máximo
    (`normalizeMuscleFatigue`). Ventana de cálculo: 30 días.
  - Tabla local `muscle_fatigue` en drift (schemaVersion 11): PK
    `(local_user_id, muscle)`, valor normalizado + `raw` + `computed_at`;
    migración v10→v11. Dato derivado: sin migración remota.
  - `FatigueRepository`: `recalculate()` (tomando el volumen crudo
    `weight_kg × reps` de las series completadas y delegando en el dominio) y
    `watchFatigue()`. Hook `onSyncCompleted` en `SyncEngine` (RF-6/H2),
    cableado en `main.dart`, más recálculo al cerrar sesión y al abrir el tab.

### Bloque de Interfaz
- [x] **T21: Mapa vectorial frente/espalda en Progreso (RF-3, RF-4, RF-5)**
  - `assets/maps/muscle_map.svg`: asset propio (autoría propia), viewBox
    100×170, grupos `<g id="vista_musculo">` con paths bilaterales; ids =
    músculo canónico (RF-4). Declarado como `assets/maps/` en `pubspec.yaml`.
  - `lib/ui/widgets/muscle_map.dart`: parser SVG → `Path` en build (RF-3),
    `MuscleMapPainter` (relleno con el gradiente frío→rojo de RF-2; gris
    #9B9B9B sin datos, RF-5; costura fina del fondo) y widget `MuscleMap`
    (geometría cacheada del asset, inyectable en tests).
  - Sección «Fatiga muscular» al inicio de `ProgressView`: toggle
    Frente/Espalda, leyenda frío→rojo, los tres músculos más cargados y aviso
    sin datos.
  - Tests: `test/muscle_fatigue_test.dart` (dominio), `test/fatigue_repository_test.dart`
    (cache, ventana, aliases), `test/muscle_map_test.dart` (parser + golden
    frente/espalda/vacío), `test/migration_test.dart` (v10→v11) y
    `test/progress_view_test.dart` + `test/sync_engine_test.dart`.

---

## Fase 8: Amendas de 2026-10-22 (Specs 007 y 008)

### Bloque de Datos y Dominio
- [x] **T22: Estados por rol y antigüedad del mapa (RF-25 a RF-31, spec 007)**
  - `lib/domain/muscle_fatigue.dart`: el estado de una zona deja de salir de
    la normalización relativa al máximo y pasa a salir del **rol** y de la
    **antigüedad**. Constantes de ancla `kHighValue` (1,0), `kOptimalValue`
    (0,5) y `kRecoveredValue` (0,0); ventanas `kPrimaryHighDays` (2),
    `kPrimaryRecoverDays` (3) y `kSecondaryRecoverDays` (2).
  - API nueva: `muscleRoles` (antigüedad en días por rol),
    `primaryFatigueValue` (ignora el volumen) y `secondaryFatigueValue`
    (parte en Óptimo, sube a Alto con volumen normalizado > 0,75).
    `muscleFatigue` devuelve `max(principal, secundario)`.
  - Desaparecen `secondaryCanonicals` y el parámetro `secondaryFloor`; se
    extrae `kZoneHighThreshold` (0,75) para compartir umbral con RF-24.
  - `FatigueRepository`: las series de **peso corporal** (peso 0, reps > 0)
    cuentan para el rol aunque su volumen sea 0; el `join` se unifica en
    `_setsOf`.

### Bloque de Corrección de datos
- [x] **T23: El primario real es `target`, no `muscle_group` (RF-32 a RF-34)**
  - Diagnóstico: en 1323 de 1324 ejercicios `muscle_group` coincide con
    `secondary_muscles[0]` (el primer secundario), no con el músculo
    objetivo. La app iluminaba el primer secundario y descartaba el objetivo
    (pecho, bíceps, dorsal y glúteos no se marcaban). Afectaba a 1321 de
    1324 ejercicios.
  - `FatigueSet.muscleGroup` → `FatigueSet.target`; el primario se resuelve
    con `kTargetMuscleAliases` (vocabulario `target`: `pectorals`, `delts`,
    `quads`, `abs`…) y los secundarios siguen con `kMuscleAliases`
    (vocabulario `secondary_muscles`: `chest`, `shoulders`, `quadriceps`…).
  - `kTargetMuscleAliases` adscribe sin zona propia (`abductors` → glúteos,
    `adductors` → cuádriceps, `levator scapulae` → trapecio, `serratus
    anterior` → oblicos) y descarta `cardiovascular system`.
  - La columna `muscle_group` **no se borra**: alimenta los filtros de
    ejercicios y las metas por grupo.
  - Cobertura: 1277 de 1324 ejercicios con primario dibujable.

### Bloque de Interfaz
- [x] **T24: Pantalla de detalle de rutina (RF-38, spec 008)**
  - `lib/ui/views/routine_detail_view.dart` (nueva, solo lectura): chips de
    metadata de planificación, descripción, y lista de ejercicios con
    miniatura, nombre, objetivo muscular traducido, equipo y resumen de
    series (`3 series · 8 reps · RIR 2 · 60 kg`, con rangos colapsados y
    peso en la unidad del perfil). Estado vacío propio.
  - Cada ejercicio abre su `ExerciseDetailView` completa; acciones
    «Iniciar Hoy» y «Editar» (recarga el detalle al volver).
  - `RoutinesView`: «Ver detalle» de la tarjeta secundaria y la nueva acción
    de la destacada abren el detalle en vez del editor.
  - Tests: `test/routine_detail_view_test.dart` (8, con golden
    `goldens/routine_detail.png`).
- [x] **T25: Miniaturas de ejercicios en las tarjetas de rutina (RF-39,
  spec 008)**
  - `_ExerciseThumbStrip` en `routines_view.dart`: franja con los primeros
    cuatro ejercicios (`ExerciseThumb`, 44 dp) y contador «+N» con el resto.
    Plana, sin sombras, con `Wrap` para no desbordar en móvil estrecho.
  - Se muestra en la tarjeta destacada (entre métricas y desglose) y en las
    secundarias (entre pills y footer). Sin tocar el repositorio: se filtra
    `_catalog` por `routine.id` con `_exercisesOf`.
  - Tests: `test/routines_view_test.dart` (+2): desbordamiento «+N» y que
    ambas tarjetas muestran la franja.
- [x] **T26: Etiquetas de músculo en español en Progreso (spec 003/007)**
  - `ProgressView`: la lista de zonas dejó de mostrar la doble línea
    inglés+español; ahora una sola etiqueta con `muscleLabel` (español). Se
    elimina `_englishName`.
  - Tests: `test/progress_view_test.dart` — aserciones de zona pasadas del
    inglés al español (`Pectoralis Major`→`Pecho`, `Latissimus Dorsi`→
    `Dorsales`, `Hamstrings`→`Isquios`).
- [x] **T27: `target` de leg press y hack squat → `quads` (dato)**
  - `assets/exercises.json`: 10 ejercicios (`0046, 2611, 1425, 0739, 1464,
    1463, 0741, 0743, 0755, 0760`) pasan de `glutes` a `quads`. Las variantes
    de gemelo sobre leg press (`1385, 1391, 1392`) se quedan en `calves`.
  - Aplica a instalaciones nuevas (el asset solo se importa en BD vacía).
- [x] **T28: Fusión de sinónimos en el filtro muscular (RF-6, spec 003)**
  - `exercise_filter_bar.dart`: nuevo `muscleFilterLabel` (etiqueta española
    por valor) y `exerciseDimensionOptions`, que agrupa los sinónimos del
    dataset en un `DimensionOption(label, values)` y ordena por etiqueta. El
    sheet marca/quita todos los sinónimos de una opción a la vez;
    `filterOptions()` y `_searchPredicate` siguen sobre valores crudos.
  - Tests: `test/exercise_filter_test.dart` (+5): etiquetas, fusión
    `lats`/`latissimus dorsi`, `groin`/`inner thighs`→Aductores, `target` y
    dimensiones no musculares.

### Tests de la tanda
- [x] `test/muscle_fatigue_test.dart` (39): alias `target`, `muscleRoles`,
  estados por rol y `muscleFatigue` con glúteos y peso corporal.
- [x] `test/fatigue_repository_test.dart` (13): primario desde `target`,
  glúteos marcados, ventanas temporales, peso corporal y secundarios.
- [x] `test/progress_view_test.dart` (+1): regresión de glúteos en el mapa.
- [x] `test/routines_view_test.dart` (+3): «Ver detalle» abre el detalle y
  franja de miniaturas con «+N».
- [x] `test/exercise_filter_test.dart` (+5): etiquetas en español y fusión
  de sinónimos del filtro (RF-6).

---
 
## Fase 9: Ajustes UI y registro pasado (Spec 012 + optimización editor)
 
### T29: Icono de lanzamiento personalizado (2026-10-25)
- [x] `flutter_launcher_icons ^0.14.4` configurado en `pubspec.yaml` con
  `assets/logo.png` y genera los iconos Android/iOS/macOS/web/Windows.
- [x] Verificación: `android/app/src/main/res/mipmap-*/ic_launcher.png` y
  `ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png` coinciden con el logo.
- [x] Limpieza: `assets/logo.png.bak` eliminado; `flutter clean && flutter pub get`.
 
### T30: Corrección del modal de login (2026-10-25)
- [x] Diagnóstico: `authService == null` al ejecutar `flutter run` sin
  `--dart-define` (requiere `tool/run.sh` que lee `.env`); la fila del
  perfil tenía `onTap = null` y no reaccionaba.
- [x] `profile_view.dart`: fila honesta con título «Sincronización sin
  configurar» y hint «Arranca con tool/run.sh»; `_signInWithEmail` muestra
  `SnackBar` en lugar de retorno silencioso.
- [x] Test: `test/profile_view_test.dart` +1 («sin configuración de Supabase
  la fila explica el motivo y no abre nada»).
 
### T31: Registro de entrenamientos pasados (Spec 012, RF-1 a RF-8)
- [x] **Spec** `docs/specs/012-registro-pasado/spec.md`: sesión `finished`
  creada directamente con fecha/hora/duración elegidas; origen dual
  (rutina existente o manual por catálogo); sin migración de esquema.
- [x] **Repositorio** `WorkoutRepository.createPastWorkout(...)`: transacción
  atómica (workout + ejercicios + series `completed=true`), encola
  payloads tras confirmar, valida RF-7 (reps ≥ 1, peso ≥ 0, RIR 0–10) y
  hora no futura.
- [x] **Editor** `PastWorkoutEditorView` (pantalla completa, patrón
  `BodyMetricEditorView`): fecha + hora inicio + duración (60 min default);
  botones «Elegir rutina» (bottom sheet con `watchRoutines`) y «Añadir
  ejercicio» (picker del catálogo); series con kg/reps/RIR editables,
  3 por defecto al añadir ejercicio; recalcula fatiga y metas al guardar.
- [x] **CTA** en `train_view.dart`: sustituye el diálogo «aún no disponible»
  por navegación al editor.
- [x] Tests: `workout_repository_test.dart` +9, `past_workout_editor_view_test.dart`
  6, `train_view_test.dart` actualizado.
 
### T32: Optimización del editor de rutinas (2026-10-25)
- [x] **P1**: `onChanged: setState` en el nombre → `ValueListenableBuilder`
  solo en la barra de guardado (rebuild mínimo por tecla).
- [x] **P2**: `ReorderableListView(children:)` → `ReorderableListView.builder`
  (itemBuilder + itemCount, sin materializar todos los tiles).
- [x] **P3**: `RepaintBoundary` duplicado (envoltura + tile) → solo en el tile.
- [x] **P4**: Claves de series indexadas → estables por `set.key`
  (`draft-set-kg-set-0`, `draft-remove-set-set-0`, …).
- [x] **P5**: Carga N+1 (`Future.wait`) → `routineSetsBatch()` en una query.
- [x] **P6**: `_onReorder` con callback deprecado + bug de índice →
  `onReorderItem` (índice ya ajustado).
- [x] **P7**: Barra de guardado sin spinner → `CircularProgressIndicator`
  con `kOnPrimary` sobre fondo `kPrimary`.
- [x] **P8**: `dispose()` dentro de `setState` → mutate + dispose + `setState(() {})`.
- [x] **Extra**: `_loadExercises` pasa `id: set.id` y `unitSystem` (corrige
  conversión imperial + estabiliza ids; `analyze` limpio).
- [x] Test de reorden: arrastrar el primer ejercicio abajo lo deja el último.
 
*Nota: Tareas para las Specs 002 a 007 se detallarán en futuras iteraciones una vez completado el núcleo de la Spec 001.*

---

## Fase 10: Perfil, récords y fotos (Spec 013)

### T33: Spec 013 y decisiones (2026-10-26)
- [x] `docs/specs/013-perfil-foto-y-vistas/spec.md` con RF-1 a RF-14
  (foto de perfil, pestañas de récords, borrado de fotos, objetivos con
  tope y visor corregido).
- [x] `docs/specs/README.md` con la fila 013 en «en curso».
- [x] Decisiones cerradas en la propia spec: bucket público nuevo
  `profile-photos`, `profiles.avatar_url` en la misma migración, PRs con
  pestañas «Este mes» + «Histórico», borrado masivo con confirmación,
  tope de 3 tarjetas.
- [x] `docs/designer.md` §7.11, §7.12, §7.13 y §7.14 con los componentes
  nuevos y su desviación respecto del set de Stitch.

### T34: Foto de perfil (Spec 013, RF-1 a RF-5)
- [x] Local: columna `avatar_url` en `local_profiles`, `schemaVersion`
  18 y migración `from < 18` con `_addColumnIfMissing`; build_runner
  regenerado.
- [x] Remoto: `supabase/migrations/20261026000000_profile_photos_bucket.sql`
  añade `profiles.avatar_url` + bucket público `profile-photos` con
  políticas de escritura en `avatars/<auth.uid>.jpg`. **Pendiente de
  aplicar en Supabase remoto.**
- [x] `setAvatarUrl()` en `ProfileRepository` + `avatar_url` en el payload
  de sync.
- [x] UI: `_pickAvatar` con bottom sheet Cámara/Galería (RF-1),
  comprobación de sesión **antes** de abrir el selector (RF-3),
  subida `uploadBinary` 512 px / calidad 80 con upsert y snackbars
  (RF-5), avatar con `errorBuilder` de vuelta al icono (RF-4) y
  `Semantics(button)`.

### T35: Visor de fotos — página inicial y contador (Spec 013, RF-14)
- [x] `_PhotoViewerPage` pasa a `StatefulWidget`: `PageController`
  persistente, `initialPage` acotado en `initState`, contador en
  `onPageChanged`.

### T36: Récords personales con pestañas (Spec 013, RF-6 a RF-9)
- [x] Dominio: `PersonalRecord.achievedAt` + `LoggedSet.endedAt`;
  `personalRecords()` fecha la mejor marca con `ended_at` de la serie
  ganadora; helper `isWithinMonth` (mes civil, no 30 días); elimina la
  función muerta `personalRecordsThisMonth`.
- [x] UI: `_Records` con `SegmentedButton` «Este mes» (por defecto) e
  «Histórico», estado vacío propio del mes (RF-7).
- [ ] Tests: filtro mensual + cambio de pestañas.

### T37: Objetivos con scroll interno (Spec 013, RF-13)
- [x] Widget `lib/ui/widgets/capped_scroll.dart` (`CappedScroll`): hasta
  `visibleItems` elementos y scroll interno por encima del límite.
- [x] Perfil: `_Goals` envuelto (cap 3 filas, 54 dp).
- [x] Progreso: `_goalSection` envuelve las tarjetas (cap 3 tarjetas,
  132 dp) sin tocar el banner de logros.
- [ ] Tests: 3 metas sin scroll, 4 metas con scroll interno que descubre
  la oculta.

### T38: Borrado de fotos individual y masivo (Spec 013, RF-10 a RF-12)
- [x] `PhotoRepository.deleteAllPhotos()`: borra fichero, encola delete
  por fila y limpia la tabla local.
- [x] UI: menú en la tarjeta «Ver foto / Eliminar», acción de borrar en
  el AppBar del visor y «Eliminar todo» bajo la rejilla (oculto sin
  fotos), los tres con `AlertDialog` de confirmación.
- [ ] Tests: borrado desde el menú, borrado masivo y visor con borrado.
