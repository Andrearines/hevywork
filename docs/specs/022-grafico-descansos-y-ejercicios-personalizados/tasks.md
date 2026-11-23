# Tareas — Spec 022

**Estado global: APROBADAS Y LISTAS (D-117, 2026-11-23).**
**Tarea actual:** revisión de T-001, ya implementada; ninguna tarea está revisada
y T-002…T-006 no están implementadas.

Orden recomendado: T-001 → T-002 → T-003 → T-004 → T-005 → T-006.
T-002 es técnicamente independiente de T-001; las demás dependencias son
obligatorias. Los contratos congelados están en `docs/db.md`. Cada tarea exige sus
CA, revisión independiente y la puerta completa `flutter test --exclude-tags
golden` + `flutter analyze`, sin PNG, dependencias ni commits.

## T-001 — Diagnosticar y corregir la sincronización actual con evidencia

- **Estado:** IMPLEMENTADA — PENDIENTE DE REVISIÓN INDEPENDIENTE.
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
  analyze están en verde sin PNG ni commits.

### Resultado de implementación — 2026-11-23

- **CA-01…CA-04 cumplidos por el implementador; revisión pendiente.** La escritura
  real de perfil demostró que `avatar_url` existía en el payload local y en
  Postgres, pero desaparecía en `buildRemoteRow` por faltar en la whitelist.
- Regresión integrada roja (`Expected` la URL, `Actual: null`) → verde tras añadir
  solo esa columna a `remoteColumns['profiles']`. No necesitó SQL ni replanificar.
- Claim exitoso: conserva `localUserId` y fija `authUserId`. Claim fallido:
  conserva identidad, payload, `pending`, `attempts = 0` y `nextAttemptAt`.
- Sync/auth: 33/33; suites adyacentes: 114/114. Puerta completa repetida tras un
  primer aborto del runner y nuevamente tras formatear: salida 0, 65/65 suites y
  727 pruebas reales verdes, 0 skips/goldens. `flutter analyze`: 0 incidencias;
  `git diff --check`: limpio.
- Modificados: `lib/data/sync/sync_payload.dart`, `test/sync_engine_test.dart`,
  `test/auth_service_test.dart` y `test/fake_supabase.dart`. Sin migraciones,
  dependencias, commits ni cambios de PNG/lock. Detalle y evidencias en
  `memory.md`, sección «Bitácora de implementación — 022/T-001».

## T-002 — Reproducir y corregir datos/geometría del gráfico

- **Estado:** LISTA — siguiente en ejecución serial.
- **Trazabilidad:** US-01, FR-01/FR-02/FR-15, SCR-06; NFR-04/NFR-05/NFR-06.
- **Dependencias:** ninguna técnica respecto de T-001; debe preceder a T-003 por
  los archivos compartidos de la ficha. Sin migraciones.
- **Archivos relevantes:** `lib/ui/widgets/exercise_progress_chart.dart`,
  `lib/ui/views/exercise_info_view.dart`, `lib/domain/exercise_stats.dart`,
  `test/exercise_progress_chart_test.dart`, `test/exercise_info_view_test.dart`.

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

## T-003 — Persistir descanso y aplicar opción C con timers independientes

- **Estado:** LISTA — requiere T-002 aprobada.
- **Trazabilidad:** US-02, FR-03/FR-04/FR-11, SCR-03/SCR-06;
  NFR-01/NFR-03/NFR-04/NFR-05/NFR-07.
- **Dependencias:** T-002. Precede a T-004 por la secuencia drift. T-006 activa la
  réplica remota; esta tarea no encola columnas remotas todavía inexistentes.
- **Migración:** drift **18→19**, crea `exercise_preferences` completa y añade
  `rest_ends_at/rest_paused_seconds` a `workout_exercises`; migra descansos de
  catálogo distintos de 90 y ejecuta `build_runner` en implementación.
- **Archivos relevantes:** `lib/ui/views/exercise_info_view.dart`,
  `lib/ui/views/live_workout_view.dart`, `lib/domain/rest_timer.dart`,
  `lib/data/repositories/catalog_repository.dart`,
  `lib/data/repositories/workout_repository.dart`, tablas drift y tests de
  `exercise_info`, `live_workout`, `rest_timer`, `workout_repository` y migración.

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
| NFR-06 | Revisión inicial/final de cada tarea; 021 y trabajo ajeno intactos |
| NFR-07 | T-003/CA-10…12 y T-006/CA-20…22 con reloj/latencia controlados |
| NFR-08 | T-001/CA-01…03 y T-006/CA-21…22 con dos réplicas/cola pendiente |

## 10. Validación documental de esta entrega

- US-01…US-05, FR-01…FR-17, NFR-01…NFR-08, CA-01…CA-23 y T-001…T-006 son únicos
  y secuenciales dentro de la 022.
- Cada SCR-03/05/06/07/08/09 del DESIGN tiene tarea; cada FR y NFR tiene
  verificación asociada.
- Todos los criterios usan Given/When/Then; no quedan condicionados a Q-006.
- No hay placeholders pendientes, SQL aplicado ni cambios drift. T-001 modificó
  la whitelist de perfiles y sus pruebas; T-002…T-006 no tienen implementación.
- Q-006 está cerrada por D-117. **Tarea actual: revisión independiente de T-001.**
  Las demás se entregan al satisfacer sus dependencias.
