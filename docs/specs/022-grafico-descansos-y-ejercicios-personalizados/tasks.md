# Tareas — Spec 022

**Estado global: T-001 y T-002 APROBADAS; T-003 IMPLEMENTADA, PENDIENTE DE
REVISIÓN (2026-11-25).** Q-007/D-119 sigue cerrada. T-004…T-006 no están
implementadas; T-004 espera la aprobación de T-003.
La observación menor de legibilidad del chart queda diferida y no forma parte de
T-003.

Orden recomendado: T-001 → T-002 → T-003 → T-004 → T-005 → T-006.
T-002 es técnicamente independiente de T-001; las demás dependencias son
obligatorias. Los contratos congelados están en `docs/db.md`. Cada tarea exige sus
CA, revisión independiente y la puerta completa `flutter test --exclude-tags
golden` + `flutter analyze`, sin PNG, dependencias ni commits/push nuevos sin
permiso. La única excepción es conservar el hash ya existente/publicado de D-119.

## T-001 — Diagnosticar y corregir la sincronización actual con evidencia

- **Estado:** **APROBADA POR EL REVISOR — 2026-11-23**, sin hallazgos
  bloqueantes, mayores ni menores. Q-007/D-119 permanece cerrada.
- **Trazabilidad:** US-05, FR-10, SCR-05; NFR-01/NFR-03/NFR-05/NFR-06/NFR-08.
- **Dependencias:** ninguna técnica previa. T-006 depende de su diagnóstico.
- **Alcance:** reproducir el fallo actual antes de extender sync a nuevas entidades.
  Recorrer escritura local → cola → `processQueue`, claim, errores y esquema/RLS
  real solo si los fakes no explican el rojo. Aplicar el fix mínimo únicamente a
  la causa demostrada. No hay migración prevista.
- **Archivos relevantes:** `lib/data/sync/sync_engine.dart`,
  `lib/data/sync/sync_payload.dart`, `lib/domain/services/auth_service.dart`,
  `lib/main.dart`, `test/sync_engine_test.dart`, `test/auth_service_test.dart`,
  `test/fake_supabase.dart` y, solo si la evidencia lo exige, remoto.

### Criterios de aceptación

- **CA-01:** **Given** una mutación local y una sesión controlada, **When** se
  recorre escritura → `sync_queue` → mapeo → envío con los seams existentes,
  **Then** se registra qué invariantes pasan y cuál falla, sin borrar la cola ni
  atribuir el síntoma a una capa no ejercitada.
- **CA-02:** **Given** un camino de login con claim, **When** el claim tiene éxito
  o falla de forma inyectada, **Then** se comprueba el estado local y la intención
  de sincronización; si aparece un rojo, la corrección conserva los datos y ese
  mismo caso pasa a verde.
- **CA-03:** **Given** el caso rojo que representa la avería encontrada, **When**
  se aplica la corrección mínima, **Then** el caso pasa de rojo a verde y las
  pruebas adyacentes de éxito, backoff, `dead_letter` y mapping siguen verdes. Si
  no se obtiene rojo ni evidencia remota, la tarea permanece abierta y devuelve el
  bloqueo; no se declara sync reparada ni se piden síntomas antes de agotar las
  comprobaciones automatizables.
- **CA-04:** **Given** un rojo que demuestre que necesita SQL, **When** se prepara
  esa corrección, **Then** se devuelve al planner para delimitar una única
  migración antes de aplicarla, sin improvisarla ni mezclarla con T-006; **Given**
  el cierre, **When** se ejecuta la puerta, **Then** toda la selección no golden y
  analyze están en verde sin PNG ni commits/push nuevos sin permiso. La excepción
  documental D-119 se limita a conservar
  `9d62bac3966bfbab78e8fb0e1f1a53c6fd7c07fd`, sin reescritura de historial.

### Resultado de la primera implementación — 2026-11-23

- La primera entrega declaró CA-01…CA-04 cumplidos, pero la revisión la
  **RECHAZÓ** por cobertura insuficiente de CA-02 y por la transición de HEAD.
- La escritura real de perfil demostró que `avatar_url` existía en el payload
  local y en Postgres, pero desaparecía en `buildRemoteRow` por faltar en la
  whitelist. Regresión roja (`Expected` la URL, `Actual: null`) → verde tras añadir
  solo esa columna a `remoteColumns['profiles']`. No necesitó SQL ni replanificar.
- El claim exitoso comprobaba `localUserId`/`authUserId`, pero no sembraba cola.
  El fallido sí conservaba identidad, payload, `pending`, `attempts = 0` y
  `nextAttemptAt`. La cobertura de éxito se completó en la iteración correctora.
- Sync/auth: 33/33; suites adyacentes: 114/114. Puerta completa repetida tras un
  primer aborto del runner y nuevamente tras formatear: salida 0, 65/65 suites y
  727 pruebas reales verdes, 0 skips/goldens. `flutter analyze`: 0 incidencias;
  `git diff --check`: limpio.
- Modificados: `lib/data/sync/sync_payload.dart`, `test/sync_engine_test.dart`,
  `test/auth_service_test.dart` y `test/fake_supabase.dart`. Aquella implementación
  no añadió migraciones/dependencias ni cambió PNG/lock; el agente no ejecutó
  commits en esa fase. El estado Git posterior se describe en la iteración siguiente.

### Iteración correctora 1 — 2026-11-23

- **CA-02 corregida, pendiente de revisión:** la prueba de claim exitoso ahora
  siembra `q-claim-success` con `attempts = 2` y `nextAttemptAt` fijo, y verifica
  que la misma mutación conserva payload, `pending`, intentos y fecha tras el claim.
  Mantiene las comprobaciones anteriores de RPC e identidad; no relaja tests ni
  cambia producción. La regresión dirigida pasa 1/1.
- Sync/auth: **33/33**; adyacentes: **114/114**. Puerta completa: salida 0,
  `done.success=true`, **65/65 suites**, **727 pruebas reales verdes**, 0 fallos,
  0 skips/goldens. `flutter analyze`: 0 incidencias; format/diff-check limpios;
  33 PNG y lock sin cambios.
- **Estado Git comprobado en solo lectura:** HEAD actual es
  `9d62bac3966bfbab78e8fb0e1f1a53c6fd7c07fd` (`sicronizacion`), posterior a
  `9730e8e`; la referencia local `origin/2.2.0` apunta al mismo hash y su reflog
  registra `update by push`. El commit incluye fix, pruebas, documentación y el
  `pubspec.lock` preexistente. Los diffs de código/pruebas y lock coinciden con las
  evidencias de la primera entrega.
- La autoría material del commit/push **no puede establecerse** con los metadatos
  disponibles; se registra como cambio no atribuible. Se conservan commit y lock,
  sin reset/revert/rebase/push/clean ni commits nuevos en esta iteración.
- **Q-007 en aquella iteración:** CA-04/NFR-06 exigía «sin commits», requisito
  incumplido en el estado actual aunque la puerta técnica estuviera verde. No se
  falseó la documentación ni se reescribió el historial para obtener aprobación.
- Archivos de esta iteración: `test/auth_service_test.dart`, `memory.md` y este
  `tasks.md`. Sin dependencias, migraciones ni cambios de producción/PNG/lock.

### Revisión técnica y refinamiento Q-007/D-119 — 2026-11-23

- El revisor considera resueltos todos los hallazgos técnicos, incluida CA-02 con
  cola sembrada y conservada tras claim exitoso. Rechazó únicamente por la regla
  literal «sin commits» y no recomendó reset ni reescritura.
- El usuario respondió **«autorizado»** a conservar ese commit como válido y
  documentar la excepción, manteniendo prohibidos commits nuevos sin permiso.
  Q-007 queda cerrada por **D-119**, exclusivamente para el commit ya
  existente/publicado `9d62bac3966bfbab78e8fb0e1f1a53c6fd7c07fd`
  (`sicronizacion`), con HEAD y `origin/2.2.0` en ese hash según evidencia local.
- No se atribuye autoría ni se autorizan commits/push futuros, reset, revert,
  rebase u otra reescritura. La regla general de AGENTS sigue vigente para
  T-001…T-006. No cambia ningún CA técnico.
- **Estado resultante:** devolver T-001 al mismo implementador para cierre y luego
  al mismo revisor para nueva revisión obligatoria. D-119 no equivale a APROBADO.

### Cierre de implementación tras D-119 — 2026-11-23

- Se verificó que spec/plan/tasks/db/README/memory limitan D-119 a conservar el
  commit `9d62bac3966bfbab78e8fb0e1f1a53c6fd7c07fd`, sin ampliar la excepción ni
  cambiar los CA técnicos. HEAD y `origin/2.2.0` estaban en ese hash; no había
  archivos staged y se conservaron los cambios del planner y la prueba de claim.
- No se modificó producción ni tests. La regresión de claim exitoso que siembra y
  conserva la cola quedó intacta, igual que spec/plan/db/README, comprobado por hash.
- Puerta repetida: `flutter test --exclude-tags golden --reporter json` → salida 0,
  `done.success=true`, **65/65 suites**, **727 pruebas reales verdes**, 0 fallos,
  0 skips/goldens. `flutter analyze`: **0 incidencias**; format/diff-check limpios;
  33 PNG sin cambios y `pubspec.lock` idéntico al HEAD. Evidencias en
  `/tmp/opencode/hevywork-t001-cierre/`.
- Sin commit, push, reset, rebase, revert, clean ni reescritura. Solo se actualizaron
  `memory.md` y este `tasks.md`. **Resultado: T-001 IMPLEMENTADA — PENDIENTE DE
  REVISIÓN FINAL**, sin declarar aprobación unilateral.

### Veredicto de revisión final — 2026-11-23

- **APROBADO**, sin hallazgos bloqueantes, mayores ni menores. Se aceptan CA-01…
  CA-04 y el cierre documental de Q-007/D-119.
- Limitaciones no bloqueantes: los resultados de puerta son los declarados por el
  implementador; el revisor trabajó en solo lectura y no tuvo acceso a `/tmp` para
  reejecutar/inspeccionar esas evidencias.
- Supabase real, RLS, Storage y segunda réplica quedan diferidos al alcance
  posterior ya delimitado; este veredicto no los declara verificados.
- Se habilita el inicio serial de **T-002**, sin reabrir diseño ni CA.

## T-002 — Reproducir y corregir datos/geometría del gráfico

- **Estado:** **APROBADA POR EL REVISOR — 2026-11-24**. CA-05…CA-08 aceptados,
  sin hallazgos bloqueantes ni mayores; una observación menor no bloqueante queda
  registrada abajo, sin reabrir la tarea.
- **Trazabilidad:** US-01, FR-01/FR-02/FR-15, SCR-06; NFR-04/NFR-05/NFR-06.
- **Dependencias:** T-001 ya está aprobada; no hay dependencia de código entre
  ambas. Debe terminar y aprobarse antes de T-003. Sin migraciones, dependencias,
  commits/push, PNG ni goldens.
- **Archivos de producción previstos:** `lib/ui/widgets/exercise_progress_chart.dart`.
  `lib/ui/views/exercise_info_view.dart` solo si hace falta ajustar la integración
  de constraints; no se prevén cambios en `lib/domain/exercise_stats.dart` ni
  `lib/ui/widgets/chart_enums.dart`.
- **Pruebas previstas:** `test/exercise_progress_chart_test.dart` como foco;
  `test/exercise_info_view_test.dart` para integración si hace falta; conservar y
  ejecutar como regresión `test/exercise_stats_test.dart` y
  `test/t002_chart_format_test.dart` de la 021.

### Criterios de aceptación

- **CA-05:** **Given** cinco o más sesiones válidas con fechas conocidas, **When**
  se pinta el gráfico, **Then** una regresión sin golden demuestra primero la
  posición incorrecta y después exige un nodo por punto, x estrictamente creciente,
  todos dentro del ancho real y área/destacado cerrados en el último nodo. Cubrir
  también 2, 4, 6 y 12 puntos.
- **CA-06:** **Given** un padre más estrecho que `MediaQuery` y viewports de 320 y
  375 dp, **When** se calcula el painter, **Then** usa las restricciones reales,
  no produce overflow y conserva la correspondencia entre puntos y fechas.
- **CA-07:** **Given** una serie cronológica cuyo último valor es menor que el
  primero, **When** se muestra el delta, **Then** conserva el signo negativo y los
  puntos del dominio/ventanas aprobados no cambian.
- **CA-08:** **Given** fechas reales y la ventana «Todo», **When** se pintan eje e
  insights, **Then** hay como máximo cuatro etiquetas `dd/MM` —con año si hace
  falta— sin duplicados ni overflow y se oculta cualquier frecuencia cero artificial
  en lugar de mostrar `0x / semana`.

### Encargo refinado contra el código vigente — 2026-11-23

No se reabren DESIGN ni CA-05…CA-08. La ejecución debe seguir este orden:

1. **Rojo geométrico antes del fix.** Con más de cuatro puntos, obtener las
   posiciones o llamadas de pintura reales y demostrar duplicados/no crecimiento.
   Hoy `_computeXPositions()` devuelve cuatro x para todo `points.length >= 2` y
   el painter cambia desde `i = 4` a `i * width / (points.length - 1)`. No vale
   como única regresión comprobar que el widget existe o que no lanza overflow.
2. **Una sola geometría para todo el painter.** Para 2/4/6/12 puntos, exigir un
   nodo por punto, `x.length == points.length`, x estrictamente creciente y
   `0 <= x <= anchoReal`. Línea, área, nodos y destacado deben consumir la misma
   distribución cronológica por índice; el cierre del área y las dos circunferencias
   del destacado terminan en `nodes.last`, no en `xPositions.last` de una lista
   auxiliar. Comprobar también los nodos dentro del alto útil del canvas conforme
   al DESIGN.
3. **Constraints reales.** Sustituir el ancho derivado de
   `MediaQuery.of(context).size.width` por el que realmente recibe el chart
   (`LayoutBuilder` o equivalente). Probar un padre explícitamente más estrecho que MediaQuery y
   viewports/padres a 320 y 375 dp, sin excepción/overflow y conservando la
   correspondencia punto-fecha. Repetir con cambio de ancho y mismo número de
   puntos: `shouldRepaint` vigente solo compara longitud/min/max/window/metric y no
   debe dejar geometría obsoleta al cambiar valores, fechas, x o tamaño.
4. **Dominio 021 intacto.** No cambiar `exerciseProgressPoints`, el filtrado de
   ventanas, `periodDelta`, `weeklyFrequency`, `formatChartDeltaKg` ni los valores
   devueltos por `progressChartPoints`. La inspección actual muestra que
   `PeriodDelta.absolute` ya contiene la resta con signo y el formateador ya admite
   negativos: CA-07 necesita una regresión de UI con último valor menor que el
   primero, no convertirlo a magnitud ni modificar dominio por una suposición
   histórica. Solo el rojo geométrico >4 es obligatorio antes del fix; los demás
   comportamientos ya correctos se caracterizan sin romperlos.
5. **Fechas reales y frecuencia.** Reemplazar las etiquetas inferiores fijas
   `1M/3M/6M/<ventana>` por fechas de puntos representativos, como máximo cuatro,
   incluyendo primer/último punto cuando sean fechas distintas. Usar `dd/MM`,
   añadir año cuando el rango lo haga necesario y deduplicar sesiones del mismo
   día. Probar rango de años cruzados, más de cuatro fechas y 320 dp sin overflow.
   No eliminar el título de ventana seleccionada ni confundirlo con el eje.
6. **«Todo» sin cero artificial.** `progressWindowDays(all)` devuelve 0 y
   `weeklyFrequency` devuelve entonces 0. En ese caso no se crea el insight de
   frecuencia ni aparece `0x / semana`; en ventanas finitas se conserva el cálculo
   actual, incluida la expectativa `0.16x / semana` de `t002_chart_format_test`.
   Cero/un punto mantiene el estado vacío sin plot/insights.

**Seam de prueba/API:** mantener el constructor y callbacks de
`ExerciseProgressChart`, las claves públicas existentes y las funciones de dominio.
La primera prueba roja puede inspeccionar el `CustomPaint.painter` vigente y sus
posiciones/llamadas con un canvas de registro de prueba. Para la solución se permite
extraer una geometría pura `@visibleForTesting` —nodos, área y destacado— consumida
realmente por el painter, o añadir claves semánticas al eje si facilitan contar las
etiquetas. No exponer una API de dominio nueva ni añadir mockito/goldens. Una prueba
que solo compare una nueva helper consigo misma no demuestra el rojo original.

**Regresiones dirigidas mínimas antes de la puerta común:** chart, stats y
`t002_chart_format_test`; añadir ficha si se modifica su integración. Al cierre se
mantiene obligatoria la selección completa no golden + `flutter analyze`.

**Riesgos acotados:** acceder a un painter privado desde prueba es frágil; centralizar
solo x pero olvidar área/destacado; `shouldRepaint` obsoleto tras resize; etiquetas
duplicadas en sesiones del mismo día o con año truncado; ocultar también frecuencias
finitas válidas; y romper expectativas 021 al «arreglar» un delta que ya conserva
el signo.

**Estado Git de entrega:** al cerrar esta planificación HEAD es
`d227ebcbb13355cc4561a9c91b7ae2ec5db27956` (`fix`), distinto del hash histórico
de D-119; la transición no se atribuye ni se reescribe. D-119 no cubre ese nuevo
hash ni habilita commits/push. El implementador debe conservarlo y trabajar sin
nuevas operaciones de este tipo.

### Implementación — 2026-11-24

- **Reanudación e integridad:** se conservó el trabajo parcial válido sin reiniciar
  planificación. HEAD permaneció en `d227ebcbb13355cc4561a9c91b7ae2ec5db27956`
  durante la interrupción; no hay otra transición que atribuir. No se ejecutaron
  commit, push, reset, rebase, revert ni clean.
- **CA-05, rojo→verde:** antes del fix, una prueba con seis sesiones ejecutó el
  painter real sobre `TestRecordingCanvas` y falló porque el quinto nodo retrocedía:
  `Expected: a value less than <236.0>`, `Actual: <295.0>`, salida 1. Evidencia:
  `/tmp/opencode/hevywork-t002/red-geometry.txt`. La misma prueba terminó 1/1 verde
  tras el fix (`green-geometry-final.txt`). Las regresiones de 2/4/6/12 puntos
  comprueban un nodo por punto, x estrictamente creciente dentro del canvas, nodos
  dentro del alto, identidad de paths consumidos y dos circunferencias destacadas en
  `nodes.last`; el área termina horizontal y verticalmente en el cierre previsto.
- **CA-06:** `LayoutBuilder` sustituye el ancho de `MediaQuery`. Los casos con padre
  24 dp más estrecho que viewports de 320/375 dp verifican el ancho real y la
  alineación del eje. Otra regresión cambia valores, fechas y ancho con el mismo
  número de puntos y exige `shouldRepaint`; el caso sin cambios no repinta.
- **CA-07:** una serie desordenada de 100 → 80 kg conserva los puntos cronológicos,
  la ventana de 90 días y muestra `-20.0 kg`. No se modificó dominio ni se cambió el
  signo a magnitud. Las regresiones de `exercise_stats` y `t002_chart_format` siguen
  verdes.
- **CA-08, segundo rojo→verde:** el eje usa días únicos representativos, como máximo
  cuatro, con primer/último día y año al cruzar años. La primera versión con cuatro
  fechas completas falló a 320 dp por `A RenderFlex overflowed by 170 pixels on the
  right`; `FittedBox` ajusta las fechas sin truncarlas y el caso pasó a verde. «Todo»
  omite el insight de frecuencia; una ventana finita conserva `0.16x / semana` y los
  estados de cero/un punto permanecen vacíos. Se registra **D-120** en `memory.md`.
- **Archivos de implementación:** `lib/ui/widgets/exercise_progress_chart.dart` y
  `test/exercise_progress_chart_test.dart`, además de esta ficha y `memory.md`. No fue
  necesario modificar `exercise_info_view.dart`, `exercise_stats.dart` ni
  `chart_enums.dart`; se conservaron T-001, specs, planificación y trabajo ajeno.
- **Pruebas dirigidas:** chart **17/17**; chart + stats + formato 021 **37/37**;
  esas tres suites más `exercise_info_view_test` y `routine_detail_view_test`,
  **64/64**. Todas con `--exclude-tags golden` cuando corresponde y sin skips.
- **Puerta completa:** `flutter test --exclude-tags golden --reporter json` → salida
  0, `done.success=true`, **65/65 suites**, **735 pruebas reales verdes**, 0 fallos,
  0 skips y 0 goldens iniciados. `testStart=testDone=844`, incluidos 109 eventos
  ocultos del runner. Evidencias: `/tmp/opencode/hevywork-t002/full-test.json` y
  `full-test-summary.txt`.
- **Análisis e higiene:** `flutter analyze` → 0 incidencias; format check y
  `git diff --check` limpios. `pubspec.lock` y los **33 PNG** conservan sus hashes
  iniciales. Sin dependencias, migraciones, goldens, skips ni timeouts de prueba.
- **Resultado:** CA-05…CA-08 implementados y puerta verde. **T-002 IMPLEMENTADA —
  PENDIENTE DE REVISIÓN OBLIGATORIA**; no se inicia T-003 ni se declara aprobación.

### Veredicto de revisión — 2026-11-24

- **APROBADO**, sin hallazgos bloqueantes ni mayores. CA-05…CA-08 quedan aceptados
  y T-002 no se reabre.
- **Observación menor no bloqueante:** la regresión de fechas a 320 dp no ejercita
  `textScaler` 1.3 ni la escala efectiva aplicada por `FittedBox`. El revisor
  recomienda caracterizar después la legibilidad según DESIGN §9.
- Seguimiento diferido, **fuera de T-003**: no se añade trabajo de chart, no cambia
  la puerta aprobada ni crea una dependencia para persistencia/timers.

## T-003 — Persistir descanso y aplicar opción C con timers independientes

- **Estado:** **IMPLEMENTADA — PENDIENTE DE REVISIÓN (2026-11-25)**.
  No está aprobada; T-004 permanece bloqueada hasta esa revisión.
- **Trazabilidad:** US-02, FR-03/FR-04/FR-11, SCR-03/SCR-06;
  NFR-01/NFR-03/NFR-04/NFR-05/NFR-07.
- **Dependencias:** T-002 ya aprobada. Precede a T-004 por la secuencia drift.
  T-006 activa la réplica remota; esta tarea no encola columnas remotas todavía
  inexistentes ni añade migración Supabase.
- **Migración:** una sola migración drift **18→19**, crea `exercise_preferences`
  completa y añade `rest_ends_at/rest_paused_seconds` a `workout_exercises`; migra
  descansos de catálogo distintos de 90 y ejecuta `build_runner` en implementación.
- **Producción prevista:** `lib/data/local/tables/exercise_preferences.dart` (nueva),
  `lib/data/local/tables/workouts.dart`, `lib/data/local/database.dart` y el generado
  `lib/data/local/database.g.dart`; `lib/data/repositories/catalog_repository.dart`,
  `lib/data/repositories/workout_repository.dart`, `lib/domain/rest_timer.dart`,
  `lib/domain/services/rest_notifier.dart`, `lib/ui/views/exercise_info_view.dart` y
  `lib/ui/views/live_workout_view.dart`. No tocar chart, PNG, lock ni whitelist remota.
- **Pruebas previstas:** `test/migration_test.dart`,
  `test/catalog_repository_test.dart`, `test/workout_repository_test.dart`,
  `test/rest_timer_test.dart`, `test/rest_notifier_test.dart`,
  `test/exercise_info_view_test.dart` y `test/live_workout_view_test.dart`; conservar
  las regresiones previas y añadir integración/sync solo si se toca ese código.

### Criterios de aceptación

- **CA-09:** **Given** un ejercicio con descanso inicial conocido, **When** se
  cambia en la ficha, se desmonta y se vuelve a abrir, **Then** se lee el nuevo
  valor persistido y no se inicia ni modifica un countdown desde la ficha.
- **CA-10:** **Given** una tarjeta live con countdown corriendo o en pausa,
  **When** se edita su descanso, **Then** en la misma interacción se persisten el
  nuevo predeterminado y el nuevo restante visible; una segunda serie y una
  reapertura usan el predeterminado actualizado.
- **CA-11:** **Given** una tarjeta sin countdown o una acción pausar/reanudar/
  saltar, **When** se ejecuta, **Then** solo cambia el estado que corresponde y el
  predeterminado permanece intacto; los límites 15–300 s no producen tiempo
  restante negativo y el restante recibe el delta realmente aplicado al default.
- **CA-12:** **Given** varias tarjetas y un reloj fijo, **When** coexisten timers
  o cambia el ciclo de vida, **Then** cada countdown conserva su
  `workoutExerciseId`, corre simultáneamente y no depende de ticks; el global solo
  funciona como fallback legacy hasta terminar, saltarse o iniciar uno asociado.

### Encargo refinado contra el código vigente — 2026-11-24

No se reabren producto, DESIGN ni CA-09…CA-12. La observación de chart de T-002
queda explícitamente fuera. El trabajo aprobado de T-002 está aún sin commitear y
debe conservarse.

#### A. Orden obligatorio de cambios

1. Conservar evidencia inicial de Git/archivos y obtener rojos ejecutables del
   comportamiento actual cuando sea posible: ficha que olvida al remontar, ajuste
   live que no cambia el predeterminado de la serie siguiente y dos tarjetas que
   terminan compartiendo el timer del workout. No borrar las pruebas legacy: las
   que describen el modelo nuevo se adaptan a `workout_exercise`; el global recibe
   cobertura específica de fallback.
2. Crear las tablas/columnas y el paso 18→19 completos, registrar la nueva tabla en
   `@DriftDatabase` y **después** ejecutar una sola vez
   `dart run build_runner build --delete-conflicting-outputs`. No editar a mano
   `database.g.dart`, no crear v20/v21 ni SQL Supabase.
3. Implementar primero dominio puro y repositorios con pruebas de migración,
   preferencias, estados y opción C; después conectar ficha, LiveWorkout y avisos.
   Una corrección de UI no debe duplicar reglas ya cubiertas en dominio/repositorio.
4. Ejecutar regresiones dirigidas y, al cierre, la puerta completa
   `flutter test --exclude-tags golden` + `flutter analyze`. Sin skips, dependencias,
   PNG/goldens, commits ni push.

#### B. Migración drift 18→19 y conservación

- `exercise_preferences` se crea ya con su contrato final de `docs/db.md`: `id` PK,
  `local_user_id`, `exercise_id`, `rest_seconds` nullable, triplete muscular
  nullable, `created_at/updated_at`, `UNIQUE(local_user_id, exercise_id)`, rango
  `NULL o 15–300` y consistencia muscular todo-nulo/todo-no-nulo. T-003 solo escribe
  descanso; no adelanta la UI ni las reglas musculares de T-005.
- `workout_exercises` recibe `rest_ends_at` y `rest_paused_seconds`, ambos nullable,
  con checks `rest_paused_seconds >= 0` y prohibición de ambos no nulos. No se añaden
  a `workouts`, que conserva sus dos columnas legacy.
- En `onUpgrade`, `from < 19` usa las guardas idempotentes existentes para tabla y
  columnas. La copia toma el `local_user_id` del perfil único y solo los valores de
  `exercises.rest_seconds != 90`: inserta una preferencia por ejercicio, con UUID,
  timestamps y `INSERT OR IGNORE`/upsert que no duplica ni pisa una fila dejada por
  una migración interrumpida. No crea usuarios ni copia el valor 90 como override.
- No se reescribe `exercises.rest_seconds`: queda legacy para catálogo. Tampoco se
  copia `workouts.rest_*` a un ejercicio arbitrario ni se borra durante la apertura.
  Workouts, ejercicios, series, historial, cola y payloads anteriores deben quedar
  byte/lógicamente intactos salvo las nuevas filas/columnas aprobadas.
- Adaptar las expectativas mecánicas `user_version` 18→19 en `migration_test.dart`
  y añadir una base v18 real/simulada con descansos 90/120/15, perfil conocido,
  historial y cola. Comprobar copia selectiva, propietario, unicidad, checks,
  idempotencia, generated v19 y conservación. Sembrar después una preferencia en
  una base creada directamente como v19: `onCreate` no ejecuta backfill.

#### C. Preferencia y descanso efectivo reactivo

- `CatalogRepository.updateRestSeconds` deja de escribir el maestro `exercises` para
  catálogo: valida 15–300 y hace upsert solo de `rest_seconds` + `updated_at` en la
  preferencia del usuario/ejercicio, conservando el triplete muscular. El valor 90
  es válido; la limpieza de filas vacías corresponde a las operaciones nullable de
  T-005, no a esta mutación entera.
- Exponer lectura y `watch` del descanso efectivo por usuario/ejercicio. En toda
  pantalla con base real, catálogo usa **`preference.restSeconds ?? 90`**, nunca una
  segunda lectura del legacy. `workout_sets.rest_seconds` sigue siendo el override
  planificado de esa serie y `exercises.rest_seconds` no se vuelve a escribir en T-003.
- `watchExercises` debe reaccionar también a `exercise_preferences` y proporcionar a
  LiveWorkout el valor efectivo sin romper su forma de record `(item, exercise)` ni
  el consumo de `TrainView`; se permite proyectar una copia de `Exercise` con el rest
  efectivo o un seam equivalente. El arranque de un descanso resuelve el valor fresco
  en ese momento, no una copia obsoleta; un override planificado no nulo conserva
  prioridad.
- `ExerciseInfoView` sustituye su `setState`-only por lectura/watch y escritura del
  repositorio, cancelando suscripciones al desmontar. Mantener `rest-detail-*`.
  Remontar recupera la preferencia y cambiarla no toca `rest_ends_at`,
  `rest_paused_seconds` ni el countdown legacy. Un cambio desde ficha sí actualiza
  el predeterminado visible/usable en Live, pero no reinicia un timer ya activo.
- Las pruebas actuales que insertan directamente un `Exercise(restSeconds: 120)` en
  una base v19 deben sembrar también su preferencia 120 y limpiar/restaurar
  preferencias entre casos; no se debe reintroducir el fallback legacy para hacerlas
  pasar.

#### D. Timers por `workoutExerciseId` y opción C

- Mantener `RestTimer` anclado a `DateTime`: **idle** = ambos nulos/módulo oculto;
  **running** = solo `rest_ends_at` futuro; **paused** = solo `rest_paused_seconds`;
  **done** = `rest_ends_at` pasado y restante cero. Skip/clear pasa a idle; un nuevo
  set que no sea warmup arranca/reinicia solo su tarjeta. Guardar/restaurar no usa
  decrementos de ticks ni altera otros items.
- Centralizar la opción C en una función pura con un único `now` y probarla con reloj
  fijo. Para running/paused:
  `newDefault = clamp(oldDefault + requestedDelta, 15, 300)`,
  `appliedDelta = newDefault - oldDefault` y
  `newRemaining = max(0, remainingAt(now) + appliedDelta)`.
  Se persiste `newDefault` y se reconstruye `endsAt = now + newRemaining` o el restante
  pausado, conservando fase. Nunca se asigna `newDefault = newRemaining` ni se aplica
  dos veces el delta. En los límites, el restante recibe el delta efectivo —incluido
  cero— y puede llegar a cero, nunca a negativo.
- La mutación de predeterminado + countdown se coordina en una única transacción
  local de repositorio/servicio compartido; no se muestra éxito con solo una mitad
  persistida y no espera red. Pausar/reanudar/saltar no cambia preferencia. Idle/done
  no inventan una opción C: pausar un done no lo convierte en `paused(0)` y una
  tarjeta idle solo arranca por la acción de serie prevista.
- Una tarjeta running/paused muestra `DESCANSO` + nombre, tiempo tabular y controles
  `−15/+15/+30`, pausa/reanudación y salto; done queda visible como `LISTO` hasta
  clear/skip. Las claves de controles se scopean por `workoutExerciseId`, por ejemplo
  `rest-plus-<id>`, para poder actuar sobre dos módulos simultáneos. El módulo vive en
  la tarjeta expandida, no en `_summaryStrip`; colapsar solo oculta presentación.
- Añadir ejercicio deja su timer idle; borrarlo elimina su fila. **Reemplazar** un
  ejercicio limpia sus dos campos de timer para no heredar el countdown del ejercicio
  anterior. Dos items del mismo `exerciseId` comparten predeterminado, pero un ajuste
  modifica solo el countdown del `workoutExerciseId` pulsado.

#### E. Fallback legacy, ciclo de vida y notificaciones

- El método/estado antiguo de `workouts` queda explícitamente separado como legacy.
  No se migra a un item ni recibe opción C por carecer de ejercicio asociado. La antigua
  píldora/módulo global solo puede representarlo mientras no haya pasado a done, no se
  haya saltado y no se inicie ningún timer asociado; esos tres caminos lo retiran de la
  UI y limpian ambos campos legacy sin tocar preferencias. El modelo nuevo no vuelve a
  escribir el global; iniciar un timer asociado también cancela el aviso legacy.
- El ticker existente solo actualiza `now` y evalúa transiciones por item. Sustituir
  `_restDismissed/_lastRestPhase` globales por estado por `workoutExerciseId`, para que
  dos timers lleguen a done y alerten una vez cada uno, sin aviso repetido en cada tick.
- `RestNotifier` deja de compartir el ID fijo 1 y una única bandera para el modelo nuevo.
  Usar una clave por `workoutExerciseId` y un ID entero **determinista entre procesos**;
  reservar la clave/ID legacy para el fallback. `scheduleAt`, `cancel`, `alertNow` y
  `resetAlertFlag` deben dirigirse a esa clave. Al ir a background se programa cada
  running futuro, no los paused/idle; al volver se cancelan los avisos gestionados.
  Pausa/skip/clear/done y nuevo start cancelan o reprograman solo la clave afectada.
- Para pruebas se permite inyectar reloj y notifier/fake en `LiveWorkoutView`, sin nueva
  dependencia. Verificar coexistencia, reanudación con `endsAt` absoluto, pausa congelada,
  background/resume y una alerta por item. El fallo de permiso/plataforma sigue sin
  romper el entrenamiento.
- Controles nuevos/tocados con targets ≥44 dp (los actuales `_restAction` y botones de
  ficha usan 36), labels/tooltips y `tabular-nums`. Comprobar SCR-03/SCR-06 a 320/375 dp
  y `textScaler` 1.3 sin overflow; no incluir el chart ni su `FittedBox` en este trabajo.

#### F. Límite de sincronización y pruebas de cierre

- No modificar `remoteColumns`, `sync_payload.dart`, `sync_queue`, migraciones Supabase
  ni `_exercisePayload` para introducir los campos nuevos. Guardar preferencia/timer no
  llama al enqueuer ni crea mutaciones remotas; conservar la regla de no tocar
  `updated_at` de workout/workout_exercise por estado local salvo que un contrato v19
  explícito lo exija. `exercise_preferences.updated_at` sí cambia en cada mutación.
- **Migración/repositorio:** upgrade real e interrumpido, checks running/paused/done/
  idle, preferencia efectiva/streams, rango invocado con 14/301, preservación muscular,
  payload/cola sin entradas nuevas y `updated_at` esperado.
- **Dominio:** running/paused, ±15/+30, topes 15/300 con delta efectivo, restante a cero,
  idle/done y reanudación con reloj fijo.
- **Ficha:** cambio → desmontar → remontar, persistencia entre dos instancias, countdown
  previo intacto y reactividad del predeterminado en Live.
- **Live:** dos ejercicios simultáneos con distinto restante; cada control actúa solo en
  su ID; opción C persiste ambas mitades y la segunda serie sin override usa el nuevo
  default; pausa/reanudación/skip conservan default; remontar restaura estados; warmup no
  arranca; replace limpia; global legacy termina/salta/se desplaza al iniciar asociado.
- **Avisos/responsive:** IDs estables/distintos y cancelación por clave, alertas no
  duplicadas, schedule/cancel en ciclo de vida, 320/375 + textScaler 1.3 y targets 44 dp.

**Riesgos concretos:** backfill que copia 90 o duplica filas; lectura legacy que deja
ficha/Live divergentes; upsert que borra músculos de T-005; dos escrituras no atómicas;
delta crudo en vez de delta efectivo; timer compartido por `exerciseId` en vez de
`workoutExerciseId`; reemplazo que hereda countdown; ID de notificación no estable o
cancelación de otro timer; global legacy que reaparece tras done; suites antiguas que
siguen leyendo `workouts.rest_*` sin distinguir fallback; y actualizar generated antes de
terminar el esquema.

### Registro de implementación — 2026-11-25

- **CA-09:** la ficha lee/escribe `exercise_preferences`, recupera el valor tras
  desmontar y conserva intactos countdown, `workout_exercises.updated_at`, valor
  legacy y cola. El rojo inicial de reapertura quedó en
  `/tmp/opencode/hevywork-t003/red-info-reopen.txt`.
- **CA-10/CA-11:** opción C pura con delta efectivo y topes 15–300; preferencia y
  countdown se escriben en una transacción local. La segunda serie y la reapertura
  usan el nuevo default; pausa/reanudar/skip no lo alteran y done/idle no inventan
  ajustes. Los rojos iniciales de segunda serie y dos items están en
  `red-live-second-set.txt` y `red-live-two-items.txt`.
- **CA-12:** módulos por `workoutExerciseId`, reloj absoluto y notifier fake
  inyectable; coexistencia, controles aislados, warmup, replace, reanudación,
  legacy acotado, background/resume y una alerta por item tienen regresiones.
  `RestNotifier` reserva legacy/ID 1 y deriva IDs FNV-1a estables para items.
- **Datos:** solo drift 18→19 y su generado. La generación recuperada terminó en
  43 s con 315 outputs; el aviso del runner indica que la opción retirada
  `--delete-conflicting-outputs` fue ignorada. No hubo regeneraciones posteriores
  porque el esquema no volvió a cambiar. Backfill selectivo !=90, idempotencia,
  checks y conservación quedaron cubiertos.
- **Responsive:** controles tocados ≥44 dp; Live y ficha pasan 320/375 dp con
  `textScaler` 1.3. El encabezado de activación usa `Wrap` para evitar overflow;
  no se modificó el chart ni su observación diferida de T-002.
- **Pruebas:** lote dominio/datos/ficha **119/119**, Live **25/25**, ficha final
  **20/20**, notifier **3/3** y workout tras lint **52/52**. Puerta final
  `flutter test --exclude-tags golden --reporter expanded`: **758/758, salida 0**;
  `flutter analyze`: **0 incidencias, salida 0**. Formato y `git diff --check`
  limpios. Evidencias en `/tmp/opencode/hevywork-t003/full-gate-test-final.txt`,
  `full-gate-test-final.exit`, `full-gate-analyze.txt` y
  `full-gate-analyze.exit`.
- **Límites:** sin cambios en sync/payloads/whitelist/cola, Supabase, dependencias,
  lock, PNG/goldens, skips ni timeouts de pruebas. `pubspec.lock` y hashes de PNG
  fuente coinciden con el inicio; HEAD sigue en
  `d227ebcbb13355cc4561a9c91b7ae2ec5db27956`, sin commits/push ni operaciones
  destructivas. Se conservaron T-001/T-002, la 021 y el trabajo ajeno.
- **Cierre:** implementación completada con CA-09…CA-12 cubiertos; queda
  **pendiente de revisión independiente**, no aprobada. Decisiones D-121…D-123 y
  bitácora completa en `memory.md`. Sin bloqueos ni preguntas abiertas.

## T-004 — Crear personalizados locales con imagen e integrarlos en catálogo

- **Estado:** LISTA — requiere T-003 aprobada.
- **Trazabilidad:** US-03, FR-05/FR-06/FR-13/FR-14/FR-17,
  SCR-06/SCR-07/SCR-08; NFR-01…NFR-06.
- **Dependencias:** T-003 y contratos v19/v20 de `docs/db.md`. No requiere T-001
  para guardado local; T-006 activa su sincronización.
- **Migración:** drift **19→20**, extiende `exercises` con origen, propietario,
  metadata/estado de imagen y `updated_at`; ejecuta `build_runner`. Sin SQL remoto.
- **Archivos relevantes:** catálogo/repositorio, `CatalogView`,
  selector/`ExercisePicker`, `ExerciseInfoView`, `CustomExerciseEditorView`,
  `ThumbFallback`, tablas drift/migración local y tests de catálogo/editor/migración.

### Criterios de aceptación

- **CA-13:** **Given** nombre, objetivo, equipo y parte del cuerpo válidos,
  secundarios opcionales y descanso inicial de 90 s, **When** el usuario guarda sin
  red, **Then** el custom `custom_<uuid>` queda disponible de inmediato, sobrevive
  a reapertura y aparece en búsqueda/selección con páginas de 50 sin alterar el
  asset; el rango 15–300 s y los campos obligatorios se validan.
- **CA-14:** **Given** galería o cámara, **When** la selección es válida, **Then**
  los bytes/ruta local y MIME se conservan y la miniatura/ficha muestran esa imagen;
  **When** no hay imagen o aún no está disponible, **Then** aparece `ThumbFallback`
  tonal con mancuerna y el guardado sigue permitido.
- **CA-15:** **Given** permiso denegado, cámara no disponible, MIME no soportado o
  archivo vacío/>2 MiB, **When** falla la selección, **Then** se informa en español
  y se conservan borrador e imagen anterior; **Given** un guardado repetido,
  **When** está en curso, **Then** no crea duplicados.
- **CA-16:** **Given** una base v19, **When** se aplica v20, **Then** conserva
  catálogo/historial/preferencias, exige `local_user_id` en todo custom y pasa
  migración + `build_runner`; no hay dependencias ni PNG nuevos.

## T-005 — Editar músculos de cualquier ejercicio y restaurar catálogo

- **Estado:** LISTA — requiere T-004 aprobada.
- **Trazabilidad:** US-04, FR-08/FR-09/FR-17, SCR-06/SCR-09;
  NFR-01/NFR-03/NFR-04/NFR-05/NFR-06.
- **Dependencias:** T-004; reutiliza las columnas musculares de v19 y custom de
  v20. **Sin migración drift ni remota nueva.**
- **Archivos relevantes:** `ExerciseInfoView`, editor muscular, repositorio de
  catálogo/override, aliases y recálculo de fatiga, `exercise_preferences`, asset
  con `kCatalogMusclePatches` y tests unitarios/widget.

### Criterios de aceptación

- **CA-17:** **Given** un ejercicio de catálogo o personalizado, **When** el
  usuario guarda objetivo y secundarios válidos, **Then** ficha, filtros y fatiga
  consumen la nueva selección sin duplicados ni modificar series/cargas; catálogo
  usa override y custom actualiza su propia fila.
- **CA-18:** **Given** un catálogo con override, **When** confirma «Restaurar
  originales», **Then** vuelven exactamente los valores del asset con patches,
  desaparece solo el override muscular y se conservan descanso, imagen e historial;
  **When** vuelve a editar, **Then** puede crear otro override.
- **CA-19:** **Given** ausencia de secundarios, aliases equivalentes o un
  secundario igual al objetivo, **When** se valida, **Then** se impiden duplicados/
  equivalencias y `muscle_group` queda en el primer secundario canónico u objetivo
  si la lista está vacía; **Given** un personalizado, **When** abre el editor,
  **Then** no se ofrece una restauración de catálogo inexistente.

## T-006 — Sincronizar nuevos datos, countdown, imágenes y estado en Perfil

- **Estado:** LISTA — requiere T-001 y T-005 aprobadas; transitivamente todas.
- **Trazabilidad:** US-02/US-03/US-04/US-05,
  FR-07/FR-12/FR-16 y propagación de FR-03/FR-04/FR-08/FR-09;
  SCR-03/SCR-05/SCR-06/SCR-07/SCR-08/SCR-09; NFR-01…NFR-08.
- **Dependencias:** T-001 y T-005; contratos completos de `docs/db.md`.
- **Migraciones:** drift **20→21** para `last_successful_sync_at` y
  `sync_needs_attention`, con `build_runner`; una única migración Supabase
  `20261123000000_spec022_custom_exercises_rest_sync.sql` con tablas/columnas,
  checks, índices, triggers, RLS, bucket/políticas y claim completo.
- **Archivos relevantes:** sync/repositorios de las nuevas entidades, Storage,
  `main.dart`, `ProfileView`, `sync_payload.dart`, tablas drift y tests de
  sync/migración/perfil/dos réplicas/RLS/Storage.

### Criterios de aceptación

- **CA-20:** **Given** un personalizado con o sin imagen creado offline, **When**
  vuelve la conexión, **Then** metadata y bytes se suben con la identidad real del
  usuario, en orden compatible con sus referencias y sin borrar el original local;
  un fallo deja una intención reintentable y nunca permite «Actualizado» con media
  pendiente.
- **CA-21:** **Given** una segunda réplica vacía con la misma cuenta, **When**
  descarga los datos, **Then** puede resolver el personalizado en catálogo,
  rutinas/workouts y ficha, recuperar su imagen o `ThumbFallback` y aplicar
  override/restauración; **When** no hay red o Storage falla, **Then** los datos
  locales existentes siguen utilizables y una mutación pendiente no se sobrescribe.
- **CA-22:** **Given** descanso predeterminado y countdown asociado, **When** dos
  dispositivos editan, pausan, reanudan o saltan y sincronizan, **Then** replican
  `rest_seconds`, `rest_ends_at/rest_paused_seconds` con nulos de transición
  correctos, sin mezclarlos con el descanso planificado de una serie.
- **CA-23:** **Given** la migración remota y dos usuarios, **When** se revisa y
  prueba, **Then** cada tabla nueva tiene `user_id`, RLS y políticas Storage sin
  acceso cruzado; **Given** elementos pendientes/`dead_letter` o fallo de claim/
  descarga/media, **When** se consulta o reintenta desde Perfil, **Then** se
  distinguen los cinco estados aprobados, se reactiva dead-letter sin borrar datos
  y nunca se exponen secretos.

## 7. Matriz SCR → tarea

| SCR | Tareas |
|---|---|
| SCR-03 | T-003, T-006 |
| SCR-05 | T-001, T-006 |
| SCR-06 | T-002, T-003, T-004, T-005, T-006 |
| SCR-07 | T-004, T-006 |
| SCR-08 | T-004, T-006 |
| SCR-09 | T-005, T-006 |

## 8. Matriz FR → tarea

| FR | Tareas |
|---|---|
| FR-01, FR-02, FR-15 | T-002 |
| FR-03, FR-04, FR-11 | T-003; T-006 para propagación |
| FR-05, FR-06, FR-13, FR-14 | T-004 |
| FR-07, FR-12, FR-16 | T-006 |
| FR-08, FR-09 | T-005; T-006 para propagación |
| FR-10 | T-001 |
| FR-17 | T-004, T-005 |

## 9. Verificación NFR

| NFR | Verificación asociada |
|---|---|
| NFR-01 | T-001/CA-01…03, T-003/CA-09…12, T-004/CA-13, T-006/CA-20…22 |
| NFR-02 | T-004/CA-16 y revisión final de diff/lock |
| NFR-03 | T-001/CA-04, T-003/migración v19, T-004/CA-16, T-006/CA-23; T-005 sin migración |
| NFR-04 | T-002/CA-06/08, T-003/CA-12, T-004/CA-13…15, T-005/CA-17…19, T-006/CA-23 |
| NFR-05 | Puerta obligatoria al cierre de cada tarea; hashes/diff de PNG |
| NFR-06 | Revisión inicial/final de cada tarea; 021 y trabajo ajeno intactos; sin commits/push nuevos sin permiso. D-119 exceptúa solo conservar `9d62bac3966bfbab78e8fb0e1f1a53c6fd7c07fd` en T-001 |
| NFR-07 | T-003/CA-10…12 y T-006/CA-20…22 con reloj/latencia controlados |
| NFR-08 | T-001/CA-01…03 y T-006/CA-21…22 con dos réplicas/cola pendiente |

## 10. Validación documental de esta entrega

- US-01…US-05, FR-01…FR-17, NFR-01…NFR-08, CA-01…CA-23 y T-001…T-006 son únicos
  y secuenciales dentro de la 022.
- Cada SCR-03/05/06/07/08/09 del DESIGN tiene tarea; cada FR y NFR tiene
  verificación asociada.
- Todos los criterios usan Given/When/Then; no quedan condicionados a Q-006.
- T-001 modificó la whitelist de perfiles y sus pruebas; T-002 corrigió el chart
  y añadió regresiones; T-003 implementó drift v19, descansos persistentes y timers
  independientes y está pendiente de revisión. T-004…T-006 no tienen implementación;
  no se aplicó SQL Supabase ni se adelantaron drift v20/v21.
- Q-006 está cerrada por D-117 y Q-007 por D-119. **T-001 y T-002 APROBADAS** por
  revisión. La observación menor de legibilidad de T-002 queda diferida sin reabrirla.
  **Tarea actual: revisión de T-003 IMPLEMENTADA**, sin autoaprobación ni cambios
  en CA-09…CA-12. T-004…T-006 se entregan al satisfacer dependencias.
