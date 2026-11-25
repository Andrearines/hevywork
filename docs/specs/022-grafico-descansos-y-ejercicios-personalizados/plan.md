# Plan técnico — Spec 022

**Estado: APROBADO (D-117, 2026-11-23); T-001…T-006 listas según dependencias.**
**Estado actual:** T-001 y T-002 **APROBADAS**; **T-003 implementada, pendiente de
revisión**. Q-007 está cerrada por D-119. La observación menor de legibilidad del
chart queda diferida, fuera de T-003. La planificación no aplicó migraciones ni
regeneración; la ejecución de T-003 y su única v19 generada, verificaciones y
límites se conservan en `tasks.md` y `memory.md`.

## 1. Preflight y límites

- Proyecto móvil Flutter con backend Supabase: réplica local drift, cola de subida
  y Storage. No se crean carpetas `app/`, `api/` ni `web/`.
- `schemaVersion` al planificar: 18; vigente tras T-003: 19; destino tras la
  secuencia: 21. `image_picker` ya está declarado; no se añaden dependencias ni se
  modifica `pubspec.lock`.
- La 021 está cerrada; no se tocan sus criterios ni sus archivos.
- Al inicio había cambios preexistentes en `docs/DESIGN.md` y `pubspec.lock`. Solo
  se actualizó la sección 022 del primero; el lock se preservó.
- No se ejecutan suites ni analyze en planificación. La puerta completa es
  obligatoria al implementar cada tarea.

## 2. Evidencia estática que debe convertirse en regresión

### Gráfico (`ExerciseInfoView`)

En `lib/ui/widgets/exercise_progress_chart.dart`:

- `_computeXPositions()` devuelve siempre cuatro posiciones para dos o más puntos.
- Desde el quinto punto, el painter cambia a otra fórmula basada en
  `i / (points.length - 1)`, lo que mezcla posiciones duplicadas o no crecientes;
  área y destacado usan `xPositions.last`, no necesariamente el último nodo real.
- El ancho se deriva de `MediaQuery`, no de las restricciones reales del padre.
  `shouldRepaint` no compara todos los valores/fechas/posiciones/tamaño relevantes.
- El eje inferior usa etiquetas fijas `1M/3M/6M/<ventana>`, no fechas de puntos.
- `progressWindowDays(all)=0` hace que la UI calcule y muestre `0x / semana`.
- `PeriodDelta.absolute` ya contiene la resta con signo y `formatChartDeltaKg` ya
  conserva negativos: CA-07 necesita cobertura, no un cambio de dominio forzado.
- El test con doce puntos no inspecciona coordenadas ni cierre del área.

T-002 debe demostrar primero el fallo con coordenadas/pintura observable y después
corregir con una única distribución cronológica por índice consumida por línea,
área, nodos y destacado. Usará constraints reales, fechas reales (máximo cuatro,
deduplicadas), conservará delta/puntos/ventanas 021 y ocultará solo la frecuencia
cero artificial de «Todo». También comprobará repaint y nodos dentro del alto útil.
Sin cambios previstos en `exercise_stats.dart`/`chart_enums.dart`, sin goldens.

### Descanso

- `ExerciseInfoView._changeRest()` solo ejecuta `setState`;
  `CatalogRepository.updateRestSeconds()` todavía escribe el legacy
  `exercises.rest_seconds`, no una preferencia por usuario.
- `LiveWorkoutView._adjustRest()` solo transforma y guarda el timer del workout;
  no actualiza el predeterminado. `watchExercises` tampoco observa preferencias.
- El workout vigente tiene un único `restEndsAt/restPausedSeconds`, sin
  `workoutExerciseId` asociado; fases/avisos dismissed también son globales.
- `RestNotifier` usa ID fijo 1 y una única bandera: no representa avisos simultáneos.
- El contrato previo considera ese countdown local y no lo encola.

T-003 sustituye el modelo operativo por timers por `workout_exercise`, conserva el
global solo como fallback legacy y aplica opción C. Migra a preferencias solo los
rests de catálogo distintos de 90 y usa preferencia/90 como valor efectivo reactivo.
T-006 activa la réplica del predeterminado/countdown aprobada por D-117. El delta
aplicado al restante es el mismo que realmente cambia el predeterminado tras su
límite 15–300 s; ambas escrituras se coordinan localmente y los avisos se clavean por
`workoutExerciseId`.

### Catálogo y personalizados

- La tabla local `exercises` es una proyección común; el asset no se reescribe.
- Las preferencias de catálogo se separan para no convertir un cambio del usuario
  en una mutación del maestro.
- Las referencias de rutinas/workouts usan `exercise_id` en texto; los custom usan
  `custom_<uuid>` y se descargan antes de hidratar referencias.
- La restauración lee el asset con `kCatalogMusclePatches`, no una fila ya editada.

### Sincronización actual

Lectura acotada de `sync_engine.dart`, `sync_payload.dart`, `auth_service.dart`,
`main.dart`, `sync_engine_test.dart` y `auth_service_test.dart`:

- El motor procesa hasta 50 elementos `pending`, hace upsert/delete con `user_id`,
  borra el item solo tras éxito, aplica backoff y conserva `dead_letter`.
- Los tests existentes usan `pusher` inyectado; no prueban por sí solos Supabase
  real, RLS, Storage, claim fallido ni restauración en otra réplica.
- El claim tiene manejo propio de errores; no se afirma que sea la avería.
- No aparece una descarga general de tablas de usuario en el motor consultado; se
  contrasta mediante pruebas antes de llamarla causa.

T-001 empieza por casos automatizables y, solo si son insuficientes, por una
prueba remota acotada con datos desechables. No requiere otra pregunta de producto.

## 3. Arquitectura aprobada por fases

### Fase 1 — Diagnósticos

1. **T-001:** caracterizar sync actual, obtener rojo, aplicar el fix mínimo si la
   evidencia lo identifica y volver a verde. Sin migración prevista.
2. **T-002:** regresión geométrica >4 puntos, dimensiones reales, signo y etiquetas
   aprobadas; después, corrección mínima.

Son independientes en código. El orden de entrega recomendado es T-001 → T-002,
aunque T-002 podría ejecutarse en paralelo sin tocar sync.

### Fase 2 — Datos y comportamiento local

3. **T-003:** drift v19, persistencia de descanso, timers independientes y opción C.
4. **T-004:** drift v20, alta/edición local de personalizados, imagen y catálogo.
5. **T-005:** override muscular/restauración sobre v19/v20, sin otra migración.

T-003 sigue a T-002 por la ficha compartida. T-004 sigue a T-003 por la secuencia
drift y catálogo. T-005 sigue a T-004 para cubrir catálogo y custom con el mismo
editor. Toda escritura funciona sin red.

### Fase 3 — Sincronización y visibilidad

6. **T-006:** depende de T-001 y T-005 (transitivamente de todas). Drift v21, una
   única migración Supabase, whitelist, subida/descarga, Storage, claim, resolución
   de referencias y SCR-05. No añade realtime ni dependencias.

## 4. Contratos congelados

La fuente normativa detallada es `docs/db.md`. Resumen para implementación:

| Contrato | Decisión |
|---|---|
| Preferencias de catálogo | `exercise_preferences`, una por usuario/ejercicio, con `rest_seconds` y triplete muscular nullable. Restaurar solo anula el triplete y conserva descanso. |
| Descanso efectivo | Catálogo: preferencia o 90. Custom: `exercises.rest_seconds`. `workout_sets.rest_seconds` sigue siendo planificación de serie. |
| Timers | `workout_exercises.rest_ends_at/rest_paused_seconds`, uno por tarjeta; global de `workouts` solo fallback legacy local. |
| Personalizados | Proyección local en `exercises` con `origin=custom`, `local_user_id` y `custom_<uuid>`; réplica en `custom_exercises`, nunca en el asset ni en una tabla remota maestra. |
| Músculos | Target/secundarios canónicos; `muscle_group = secondary[0]` u objetivo si lista vacía. Restauración desde asset + patches. |
| Media | Bucket privado `custom-exercise-images`, clave `<auth.uid()>/<exerciseId>`, JPEG/PNG/WebP ≤2 MiB. Ruta local nunca se sube como remota. |
| Sincronización | `user_id` real tras claim, FIFO, pull sin sobrescribir mutaciones locales pendientes, servidor `updated_at` para conflicto final. |
| Perfil | Derivado de claim, motor, cola, media y descarga; `Actualizado` solo tras ciclo completo. Reintento reactiva dead-letter sin borrar nada. |

### Migraciones por tarea

- **T-003:** drift 18→19; `exercise_preferences` completa + timer por workout
  exercise. Sin SQL remoto ni encolado de campos todavía inexistentes.
- **T-004:** drift 19→20; origen/propietario/media/update de `exercises`. Sin SQL
  remoto.
- **T-005:** sin versión nueva; usa las columnas de v19/v20.
- **T-006:** drift 20→21 para estado sync + una sola migración
  `20261123000000_spec022_custom_exercises_rest_sync.sql` con tablas, checks,
  índices, triggers, RLS, Storage y claim completo.
- **T-001/T-002:** sin migración prevista. Si T-001 demuestra que necesita SQL, se
  devuelve al planner antes de aplicarla; no se consume la migración de T-006.

En implementación, cada cambio drift usa
`dart run build_runner build --delete-conflicting-outputs`; no se edita a mano el
generado. En planificación no se ejecuta.

## 5. Reglas de sincronización y offline

1. Escritura local primero; sin sesión/red no se consumen intentos y UI nunca
   espera red.
2. Un custom se encola antes de nuevas referencias. La descarga resuelve custom y
   preferencias antes que rutinas/workouts; no se rompe el FIFO de subida vigente.
3. Una réplica remota no pisa una entidad con mutación local pendiente/dead-letter.
   Tras confirmar la subida, manda la versión del servidor.
4. Metadata y bytes pueden converger en momentos distintos: si falta el objeto se
   muestra `ThumbFallback`; el perfil sigue pendiente/atención hasta completarlo.
5. Reemplazo usa upsert en la misma clave. Quitar imagen propaga metadata nula y
   conserva `pending_delete` hasta borrar el objeto remoto.
6. `claim_local_data` conserva todas las tablas anteriores y añade las nuevas;
   `auth_user_id` local solo cambia tras claim completo.
7. No hay canal realtime: arranque/login, escrituras, reanudación y ciclo de 30 s.
   La opción C sí es inmediata en la tarjeta local.

## 6. Estrategia de pruebas

- **Rojo→verde:** cada bugfix comienza con una prueba que falle por la firma
  observada y conserva evidencia del rojo.
- **Gráfico:** coordenadas de 2, 4, 5, 6 y 12 puntos; último nodo/área; ancho del
  padre a 320/375 dp; fechas reales sin duplicados; delta negativo; frecuencia.
- **Sync:** éxito, fallo de red, claim, backoff/dead-letter, descarga, payload/RLS
  según el rojo. Un fake verde no se presenta como prueba de Supabase real.
- **Descanso:** reapertura, countdown corriendo/en pausa, ajuste inmediato, varios
  timers, fallback legacy y dos dispositivos en T-006.
- **Personalizados:** galería/cámara mediante seams, permiso denegado, archivo
  inválido, offline, búsqueda/páginas de 50, reemplazo/borrado de imagen y segunda
  réplica.
- **Músculos:** catálogo/custom, aliases, sin secundarios, duplicados, restauración
  parcial y conservación del historial.
- **Seguridad:** dos usuarios para RLS y Storage; sin rutas locales remotas.
- **Puerta final por tarea:** `flutter test --exclude-tags golden` completa y
  `flutter analyze`, sin modificar PNG ni añadir skips para obtener verde.

## 7. Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| Atribuir sync a claim/RLS/descarga sin evidencia | T-001 rojo→verde; escalado solo con evidencia. |
| Romper referencias remotas a un custom | ID estable, orden de descarga y prueba de dos réplicas. |
| Sobrescribir catálogo o perder restauración | Maestro separado de preferencias; prueba de restauración parcial. |
| Metadata sin imagen u objeto huérfano | Estado local explícito, fallback y reintento de media/delete. |
| Sobrescribir trabajo offline al descargar | Guardia de cola por entidad y servidor como ganador tras ack. |
| Migraciones incompatibles | Versiones por tarea, tests de upgrade y una sola migración T-006. |
| Tocar 021, lock, PNG o trabajo ajeno | Diff acotado y revisión inicial/final. |

## 8. Entrega al implementador

Entregar **T-003 al implementador como tarea actual**. T-001 y T-002 ya están
aprobadas; después seguir T-004 → T-005 → T-006. El orden schema/generated →
repositorios/dominio → UI/notificaciones, las pruebas y los riesgos vigentes están
en `tasks.md` §T-003. No se reabren CA-09…CA-12 ni se incorpora trabajo de chart.
Cada tarea exige sus CA, regresiones, puerta completa no golden + analyze y revisión
independiente, sin commits/push nuevos.

## 9. Refinamiento de proceso T-001 — Q-007/D-119

El revisor considera resueltos todos los hallazgos técnicos, incluida CA-02 con
cola sembrada y conservada tras claim exitoso; su rechazo restante fue únicamente
la exigencia literal «sin commits». No recomendó reset ni reescritura.

El usuario respondió **«autorizado»** a conservar el commit como válido y registrar
la excepción, manteniendo prohibidos commits nuevos sin permiso. D-119 cierra
Q-007 y se limita al commit ya existente/publicado
`9d62bac3966bfbab78e8fb0e1f1a53c6fd7c07fd` (`sicronizacion`), con HEAD y
`origin/2.2.0` en ese hash según evidencia local. No atribuye autoría ni autoriza
commits/push futuros, reset, revert, rebase u otra reescritura.

La puerta común queda: sin PNG ni dependencias nuevas y sin commits/push nuevos
sin permiso en T-001…T-006. La excepción no alteró CA-01…CA-03 ni ningún otro CA
técnico. La revisión final posterior devolvió **APROBADO** para T-001, sin
hallazgos bloqueantes/mayores/menores; sus límites no bloqueantes constan en
`tasks.md` y `memory.md`.
