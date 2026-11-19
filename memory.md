# Memory Log — Spec 021

## Estado actual
- Fecha: Thu Nov 19 2026.
- Agente activo: subagente implementador 021/T-002.
- Spec activa: `021-correccion-grafico-precision-numerica`.
- Última tarea implementada: **021/T-002 corregida tras revisión y lista para
  nueva revisión obligatoria**. CA-10…CA-16 quedaron validados con las nuevas
  regresiones; CA-17 usa el gate relativo permitido por el revisor. Se conservó
  la edición de series existentes entre dos cambios de unidad, se reforzó la
  reapertura del mismo workout y se corrigió el callout imperial sin tocar
  fórmulas, base kg ni persistencia. No se marca aprobación unilateral.
- **T-001 se mantiene aprobada por coordinación y fuera del alcance de esta
  intervención.** No se reabrió ni se reparó el desajuste heredado entre su
  implementación y sus tests.
- Nota de sesión conservada: el trabajo de T-001 estaba sin commitear en
  `stash@{0}` («t001-baseline-loop») de una sesión cancelada; se restauró con
  `git stash pop` sin reescribir nada.

## Contexto previo conservado
- T-014 ProgressView: `_MeasureSummaryRow` añadido al final.
- T-015 ExerciseInfoView: patrón `itemCount: entries.length.clamp(1,3)` no
  encontrado; esa petición quedó sin cambios.
- T-016 TrainView: setState en filtros ya correcto; sin cambios.
- T-017 ProfileView: título duplicado eliminado.
- D-061 previa: `_MeasureSummaryRow` como widget independiente; sin dependencias.
- Archivos previos: `progress_view.dart` y `profile_view.dart` modificados;
  `exercise_info_view.dart` y `train_view.dart` sin cambios en aquella tanda.

## Diagnóstico de planificación — 2026-11-17

### BG-01 · Gráfico de ExerciseInfoView
- Confirmado: `RoutineDetailView._openExercise()` abre
  `ExerciseInfoView(exercise: exercise)` sin `database` ni
  `workoutRepository`; con repo nulo `_loadInitialHistory()` retorna y el chart
  recibe `_history` vacío. Las entradas de catálogo, vivo, editor y lista de
  rutinas revisadas sí pasan ambas dependencias.
- Confirmado como defecto separado: `filterByProgressWindow()` compara
  `pointDate.difference(nowDate).inDays <= windowDays`; no acota correctamente
  pasado/futuro. No se identifica como causa del vacío, porque tiende a admitir
  fechas pasadas.
- Confirmado: el widget prefiltra y vuelve a filtrar, y duplica el cálculo de
  métricas del dominio; su rama de volumen puede divergir en series no válidas.
- Confirmado: el chart consume las diez tarjetas iniciales de `_history`; «Todo»
  no debe presentar esa primera página como historial completo.
- Cobertura actual insuficiente: `test/exercise_progress_chart_test.dart` solo
  instancia el widget con `sessions: []`.

### BG-02 · Pesos y decimales
- En el código vigente, métrico es identidad y `formatWeightKg(40, 'metric')`
  devuelve `40`. El ciclo `_rawKg → displayWeightKg → toKg` no explica por sí
  solo 40 → 39.99 en métrico; T-002 debe reproducir entrada, confirmación,
  drift, reconstrucción y ajuste rápido antes de tocar producción.
- `formatDisplay`, `formatWeightKg` y `formatLengthCm` ya usan hasta dos
  decimales. No existe `formatNumber`; D-030/Q-014 de la 017 describe un estado
  histórico distinto del HEAD actual.
- Persistencia redondea a 0.001 kg conforme a la 001; queda fuera del cambio de
  presentación. `kKgPerLb`, `weightStepOf`, e1RM y volumen no se alteran por
  hipótesis.
- Se localizaron formateadores paralelos en editor de rutina/sesión pasada y
  varias vistas; T-002 exige barrido de `Text`, `TextPainter` y controladores,
  no cambios cosméticos indiscriminados.
- Revisión ejecutada: `flutter test test/exercise_progress_chart_test.dart
  test/exercise_stats_test.dart test/units_test.dart` → **33 tests en verde**.
- Revisión ejecutada: `flutter test test/live_workout_view_test.dart
  --plain-name 'los steppers del ajuste rápido mueven el peso (RF-15)'` → falla
  porque busca `+1.3 kg`; el código vigente genera `+1.25 kg`. Es una
  expectativa obsoleta incluida en T-002, no evidencia de que 1.25 deba volver a
  1.3.
- No se ejecutó la suite completa ni `flutter analyze` en planificación. La
  puerta completa sigue siendo obligatoria al cerrar cada tarea.

## Tareas listas para el implementador

### 021 / T-001 · Restaurar datos reales y ventanas del gráfico
- Corregir `RoutineDetailView` para entregar las dependencias vigentes.
- Reutilizar puntos de dominio y una única ventana `[inicio, now]`, `Todo` sin
  recorte; evitar doble filtrado/copia de métricas.
- Separar paginación de tarjetas y fuente analítica para que doce sesiones en
  «Todo» no queden reducidas a diez; conservar queries acotadas al ejercicio.
- Regresiones: entrada real desde rutina, 0/1/2+ puntos, dentro/fuera y bordes
  de ventana, warmups/incompletas/cero legítimo, cambio de métrica, >10 sesiones
  y ausencia de errores de layout.
- Criterios detallados: CA-01…CA-09 en
  `docs/specs/021-correccion-grafico-precision-numerica/tasks.md`.
- Dependencias: independiente de T-002; se recomienda ejecutar primero por los
  archivos compartidos.

### 021 / T-002 · Diagnosticar 40 → 39.99 y unificar formato
- El test del foco real debe fallar antes del fix. Mantener como guardia el caso
  exacto 40 kg en persistencia y tras reconstruir/reabrir, sin 39.99.
- Edición: conservar base si no hay cambio, parse/conversión una vez, quick
  adjust en la unidad mostrada; cubrir ida/vuelta y cambios de unidad.
- Consolidar `formatDisplay`/`formatWeightKg`/`formatLengthCm`, sin añadir
  `formatNumber`, sin redondear dominio/persistencia a dos decimales.
- Regresiones: 1.25/61.25 legítimos, ruido binario, enteros, 40 kg = 88.18 lb,
  100 lb ≈ 45.359 kg, volumen/e1RM intactos y cada foco global modificado.
- Criterios detallados: CA-10…CA-17 en `tasks.md` de la 021.
- Dependencia técnica: ninguna de T-001; se sitúa después para evitar conflictos
  en `exercise_info_view.dart` y `exercise_progress_chart.dart`.

## Bitácora de implementación — 021/T-001 (2026-11-18)

### Diagnóstico (BG-01) confirmado en código
1. `RoutineDetailView._openExercise()` construía
   `ExerciseInfoView(exercise: exercise)` sin `database` ni
   `workoutRepository` → `_loadInitialHistory()` retornaba y el gráfico
   recibía `_history` vacío (falso «Sin datos en esta ventana»).
2. `filterByProgressWindow()` usaba
   `pointDate.difference(nowDate).inDays <= windowDays` (predicado que no
   acota el intervalo) y el widget volvía a filtrar tras prefiltrar.
3. El widget duplicaba el cálculo de métricas del dominio (copia divergente,
   rama de volumen distinta de `exercise_stats.dart`).
4. El gráfico consumía solo las diez primeras tarjetas de `_history`; «Todo»
   no veía el historial completo.

### Cambios por archivo (11 + spec 021 sin trackear)
- `lib/ui/views/routine_detail_view.dart`: pasa `database: localDb` y
  `workoutRepository: workoutRepository` al abrir la ficha desde rutina.
- `lib/ui/views/exercise_info_view.dart`: nuevo `_analyticsHistory`
  (fuente analítica separada de las páginas de tarjetas) que pagina con
  `repo.exerciseHistory(exerciseId, limit, offset)` hasta agotar; KPIs
  (`exerciseKpis`) y `ExerciseProgressChart` consumen esa fuente, no `_history`.
- `lib/ui/widgets/chart_enums.dart`: `filterByProgressWindow` con intervalo
  cerrado `[now - días, now]`; `Todo` (0 días) no recorta; `now` inyectado.
- `lib/ui/widgets/exercise_progress_chart.dart`: función pura
  `progressChartPoints(sessions, metric, window, now)` delegando en
  `exerciseProgressPoints` + `filterByProgressWindow` (una sola ventana, un
  solo `now`); se eliminan `_computePoints`, `_periodDelta`, `_weeklyFrequency`
  y el doble filtro; insights con `periodDelta`/`weeklyFrequency` del dominio;
  delta con signo real; `Expanded` → `SizedBox` acotado para el `CustomPaint`
  (evita altura no acotada en el sliver) y `Expanded`/`Flexible`+ellipsis en la
  fila de cabecera del plot.
- Tests: `test/routine_detail_view_test.dart` (+46: CA-01),
  `test/exercise_info_view_test.dart` (+86: CA-02/CA-07 y
  `takeException() isNull`), `test/exercise_progress_chart_test.dart` (+275:
  CA-03…CA-06, CA-08).
- Docs de coordinación: `docs/specs/015-…/tasks.md`, `docs/specs/017-…/tasks.md`,
  `docs/specs/README.md` (referencias a la 021, de la sesión de planificación).
- `test/failures/train_view_*.png`: artefactos de una corrida previa,
  restaurados desde el stash (no son goldens de referencia).

### Tests añadidos y comando/resultados (con cambios T-001)
- `flutter test test/exercise_progress_chart_test.dart` → **9/9 verdes**
  (baseline HEAD: 1 test; +8 nuevos): bordes de ventana con `now` fijo,
  `Todo` sin recorte, 0/1 punto vacío, 2+ puntos con plot+insights, ventanas
  dentro/fuera, métricas del dominio, warmups/incompletas sin puntos, volumen
  cero legítimo, >10 puntos sin overflow.
- `flutter test test/exercise_stats_test.dart` → **19/19 verdes** (igual que
  baseline; fuente analítica del dominio intacta).
- `flutter test test/exercise_info_view_test.dart` → **7 pass / 10 fail**
  (baseline: 5/11). Los 10 fallos son subconjunto exacto de los 11
  preexistentes; el fix arregla «pagina de 10 en 10 y desaparece al agotar»
  (CA-07) y añade «la fuente analítica excluye estado, fecha y otro ejercicio»
  (CA-02) en verde.
- `flutter test test/routine_detail_view_test.dart` → **8 pass / 1 fail**
  (baseline 7/1): nuevo «abrir desde rutina carga el historial real y pinta
  progresión» (CA-01) en verde; el único fallo es el golden preexistente.

### Suite completa por lotes (timeout por lote; `nproc=4`)
- Lotes de 4 ficheros (o individuales si cuelgan) cubriendo los **62 ficheros
  de `test/`**; agregado de corridas definitivas: **887 tests ejecutados,
  851 pass, 36 fail, 0 skip**.
- Baseline de HEAD con el mismo método: **877 ejecutados, 840 pass, 37 fail,
  0 skip**. Δ: +10 tests nuevos (8 chart + 1 info + 1 rutina), 1 fallo
  preexistente arreglado (CA-07), **0 fallos nuevos**.
- Los 36 fallos actuales, uno a uno verificados idénticos en baseline
  (worktree `/tmp/hevywork-baseline` @ 606bcd6): 10 en
  `exercise_info_view_test` (UI antigua duplicada: «ES»×2, «815 kg»×2,
  badges/CTA/scroll; fuera del alcance del gráfico), 2 goldens
  (`routine_detail.png` y `train_view.png`), 4 `live_fatigue_section`,
  7 `responsive_layout`, 3 `small_screen_layout`, 2 `app_shell`,
  1 `profile_view`, 1 `progress_view`, 1 `live_workout_view`.
- **Cuelgues (test «did not complete») — 5, todos preexistentes** (aislados,
  con y sin cambios de T-001, resultado idéntico):
  - `test/routines_view_test.dart` → «borrar pide confirmación y elimina la
    rutina con sus hijos» (el bloqueo reportado para la suite completa;
    reproduce también aislado en baseline: +5 -1 y el mismo «did not
    complete»).
  - `test/app_shell_test.dart` → «Reanudar sesión al arrancar…» (+6 -3).
  - `test/profile_view_test.dart` → «con sesiones terminadas muestra métricas
    y PR» (+0 -2).
  - `test/progress_view_test.dart` → «una meta activa muestra su % de
    cumplimiento (H3)» (+4 -2).
  - `test/live_workout_view_test.dart` → «sin repeticiones avisa y no registra
    la serie» (+0 -2).
  Por eso `flutter test` completo no termina: el cuelgue corta el runner
  (además, `flutter test` a veces descarta ficheros listados en lotes
  grandes; se verificó la cobertura fichero a fichero).

### `flutter analyze`
- Baseline: **54 incidencias**. Con T-001: **52 incidencias, 0 nuevas**
  (diff normalizado sin números de línea: vacío), 2 resueltas por T-001
  (`prefer_is_empty` de la copia eliminada en el chart y `unused_import`
  `dart:async` del test del chart). Las 52 restantes son preexistentes.

### Goldens
- `test/goldens/routine_detail.png`: diff **1.11 % / 19965 px** — idéntico en
  baseline y con T-001; `routine_detail_testImage.png` e
  `isolatedDiff.png` **byte a byte iguales** (mismo md5) con y sin cambios →
  T-001 no altera ese render. El golden está desactualizado desde el primer
  commit (`ebef920`), mientras la vista cambió en `5b880e6`. **No se
  regeneró** (D-090).
- `train_view.png`: mismo diff en baseline y con cambios (preexistente).
- No se editó ningún PNG a mano.

### Criterios de aceptación
- **CA-01…CA-08: cumplidos** (tests en verde citados arriba; CA-09 no aplica
  aún a este grupo).
- **CA-09: parcial.** Validación de revert hecha en la sesión previa con 4
  revertidos puntuales (dependencias de `RoutineDetailView`, predicado
  temporal, `_history` vs `_analyticsHistory`, `Expanded` del chart): cada
  prueba asociada falló con el fix retirado. La segunda parte («`flutter test`
  pasa por completo») **no se cumple literalmente**: la suite queda con 36
  fallos y 5 cuelgues preexistentes de HEAD (desglose arriba); con cambios de
  T-001 el número de fallos baja de 37 a 36 y no se añade ninguno. Por eso
  **T-001 no se marca como completada en `tasks.md`**.
- Puerta de analyze: cumplida en términos de «sin incidencias nuevas» (52
  preexistentes, 0 nuevas); el literal «cero incidencias» ya era imposible en
  HEAD (54).

### Decisiones nuevas
- **D-090:** No regenerar `routine_detail.png`: el diff es preexistente y
  byte idéntico con y sin T-001; regenerarlo no estaría justificado por el fix
  (y la 021 prohíbe usar goldens como solución).
- **D-091:** No corregir fuera de alcance los fallos/cuelgues preexistentes
  (info-view antigua, app_shell, profile/progress/live_workout,
  live_fatigue/responsive/small_screen, goldens `routine_detail` y
  `train_view`); solo se evidencian y comparan con baseline.
- **D-092:** La fuente analítica se pagina de forma eager al cargar la ficha
  (todas las páginas del ejercicio) para que «Todo» no dependa de pulsar
  «Cargar sesiones anteriores», manteniendo las tarjetas paginadas; consulta
  siempre por `exerciseId`.

### Pendiente
- **T-002 (40 → 39.99 y formato global): NO implementada, pendiente.**
- Q-003/Q-004 abiertas más abajo.

## Bitácora de implementación — 021/T-002 (2026-11-19)

### Diagnóstico reproducido
- En métrico, 40 kg es identidad en `displayWeightKg`/`toKg`; `kKgPerLb`,
  `weightStepOf`, `_roundKg`, las fórmulas de dominio y la persistencia a 0.001
  kg no originan el defecto. No se reprodujo el literal `39.99` desde 40 kg
  métricos exactos.
- El primer estado incorrecto localizado es el cambio de unidad en una fila
  nueva de `_EditableSetRow`: tras escribir `40` en métrico, `_rawKg` aún podía
  ser nulo y al pasar a imperial el controlador seguía mostrando `40`, no
  `88.18`. Si se confirmaba en ese estado, el texto se interpretaba como 40 lb
  y se persistían **18.144 kg**. El problema era el límite edición/unidad, no la
  conversión compartida.
- La reversión temporal de solo `live_workout_view.dart` confirmó la causa:
  `test/t002_precision_test.dart` falló con `Expected: '88.18'`,
  `Actual: '40'`. El archivo corregido se restauró automáticamente, se comprobó
  byte a byte y el test volvió a **1/1 verde**.

### Implementación
- `_EditableSetRow` registra `_textEdited`; al cambiar de unidad parsea una sola
  vez el texto manual desde la unidad anterior, guarda `_rawKg` en kg y formatea
  la nueva unidad. Confirmar y quick adjust fijan base kg y texto mediante los
  helpers comunes, evitando reconversión acumulativa.
- Presentación consolidada con `formatDisplay`, `formatWeightKg` y
  `formatLengthCm`; `kgDeltaLabel` reutiliza el formato común. Los wrappers de
  miles en train/profile reciben una cadena ya formateada y no vuelven a
  redondear el double. No se añadió `formatNumber`.
- Producción tocada por T-002:
  - `lib/domain/weight_progress.dart`.
  - `lib/ui/views/live_workout_view.dart`, `train_view.dart`,
    `profile_view.dart`, `progress_view.dart`, `measures_view.dart`,
    `body_metric_editor_view.dart`, `goal_editor_view.dart`,
    `routine_editor_view.dart`, `past_workout_editor_view.dart`,
    `routine_detail_view.dart` y `exercise_info_view.dart`.
  - `lib/ui/widgets/exercise_progress_chart.dart` y
    `lib/ui/widgets/measure_evolution.dart`.
- Tests actualizados: `units_test.dart`, `goals_test.dart`,
  `weight_trend_test.dart`, `live_workout_view_test.dart`,
  `body_metric_editor_view_test.dart`, `goal_editor_view_test.dart`,
  `measures_view_test.dart`, `past_workout_editor_view_test.dart`,
  `profile_view_test.dart`, `progress_view_test.dart`,
  `routine_detail_view_test.dart`, `routine_editor_view_test.dart`,
  `train_view_test.dart` y `exercise_info_view_test.dart`.
- Tests nuevos: `test/t002_precision_test.dart` (arnés consolidado CA-10…CA-14)
  y `test/t002_chart_format_test.dart` (presentación métrica/imperial del chart
  mediante su API pública actual). En archivos compartidos con T-001 solo se
  conservaron sus cambios previos y se añadieron los focos T-002.
- No se tocaron `lib/domain/units.dart`, fórmulas de dominio, repositorios ni
  precisión de persistencia. Tampoco se modificaron los archivos concurrentes
  de catálogo asignados como fuera de alcance.

### Validación funcional dirigida
- `flutter test test/t002_precision_test.dart` → **1/1** tras la restauración y
  de nuevo tras retirar comentarios del arnés. Cubre 40 kg exactos, ruido
  binario, reapertura, quick adjust ±1.25, kg↔lb, cambio de unidad y drift.
- `flutter test test/units_test.dart test/goals_test.dart
  test/t002_chart_format_test.dart` → **47/47**: formato común, conversiones,
  steps, deltas y CA-15 con doubles de dominio inalterados.
- `flutter test test/body_metric_editor_view_test.dart
  test/goal_editor_view_test.dart test/measures_view_test.dart` → **24/24**.
- Train sin golden **12/12**; focos profile **3/3**; focos progress **4/4**;
  RPE de exercise info **1/1**; `setsSummary` de routine detail **1/1**.
  Regresiones de routine editor/past workout y `weight_trend` en verde; la
  corrida por lotes confirma además `weight_trend` **10/10**.
- Auditoría CA-16: `rg` no encuentra `formatNumber`/`_fmtNumber` ni
  `toStringAsFixed` en `lib/ui`. Las conversiones restantes terminan en los
  helpers/wrappers comunes; porcentajes enteros conservan `round()`.
- `git diff --check` sin incidencias en los archivos de T-002. No se añadieron
  dependencias, migraciones ni commits.

### Suite global, análisis y exclusiones
- Los comandos globales no golden agotaron 300 s y 600 s por cuelgues del
  arnés. Se repitió con 16 lotes de cuatro archivos y después individualmente
  los archivos incompletos. El agregado JSON definitivo llegó a **638 tests
  reales completados: 605 pass, 33 fail, 0 skip**, con resultados en 64 de los
  65 archivos.
- Cinco suites (`exercise_info`, `live_workout`, `profile`, `progress` y
  `routines_view`) abortan en `tearDownAll`/carga con `Bad state: Cannot close
  sink while adding stream`, incluso aisladas con 180 s, y dejan tests sin
  cargar. Otro caso heredado de `app_shell` quedó sin completar al comprobar los
  tests sanos del grupo de reanudación. Por tanto **638 no es una suite completa**
  y no se declara un delta numérico frente al histórico 887/851/36, cuya
  agregación no se reproduce con este método.
- En los errores disponibles no apareció una nueva diferencia de presentación
  atribuible a T-002: e1RM `106.7` de live es el fallo histórico; profile falla
  antes en elementos ajenos; exercise info conserva su deuda y añade el foco
  CA-02 sin `chart-plot` por el estado heredado de T-001; routine detail conserva
  el CA-01 heredado. Todos los focos T-002 se validaron dirigidos en verde.
- Se filtraron los ocho goldens y seis casos con cuelgue/timeout ya documentado
  (cinco históricos y el stepper de live). No se ejecutaron los nueve tests de
  `exercise_progress_chart_test.dart` por sus dos errores heredados de API.
- `flutter analyze` final → **55 incidencias**: 52 históricas + dos errores del
  test de chart (`now`/`progressChartPoints`) + `prefer_final_fields` de
  `_analyticsHistory`. Ninguna incidencia nueva apunta a T-002.
- **Goldens excluidos por instrucción expresa:** no se ejecutaron, diagnosticaron,
  editaron, regeneraron ni borraron; no se usó `--update-goldens`. Los PNG y
  artefactos ya modificados en el árbol se conservaron intactos y no se
  atribuyen a T-002.

### Decisiones nuevas
- **D-093:** El defecto 40 → valor inesperado se corrige en el límite de
  edición/cambio de unidad de `_EditableSetRow`; no en `kKgPerLb`, fórmulas de
  dominio ni `formatDisplay`.
- **D-094:** `_textEdited` distingue texto manual de escrituras programáticas;
  la conversión manual se hace una vez desde la unidad anterior y `_rawKg` es
  siempre la base kg para confirmar y ajustar.
- **D-095:** Los separadores de miles envuelven cadenas ya formateadas; no se
  introduce otro redondeo sobre el double original ni otro formateador numérico.
- **D-096:** En T-002 los goldens quedan totalmente fuera de ejecución y cambios;
  la validación se limita a tests funcionales/unitarios/widget no golden y
  análisis estático. Esta decisión no altera PNG ni usa capturas como fix.

### Iteración correctora tras rechazo de revisión — 2026-11-19
- **Bloqueante de serie existente:** se añadió al arnés una serie pendiente real
  de 40 kg (`completed: false`), editada a 50 y alternada
  métrico→imperial→métrico antes de confirmar. En rojo volvió a `40`; el fix da
  prioridad a `_rawKg` sobre `widget.set` en `didChangeDependencies`. En verde,
  controlador y drift conservan **50 kg**.
- **CA-11 completa:** el primer tramo usa 40 kg × 1 y RIR 0 para que volumen y
  1RM sean 40 kg. Comprueba esos dos resúmenes, desmonta y reabre el mismo
  `workoutId`, verifica el mismo `confirmedSetId`, 40 en drift/controlador y dos
  textos `40` + dos `kg`; `39.99` está ausente antes y después.
- **Expectativas live:** actualizadas a `62.50` y `60 → 62.50 kg`, sin ±1.3 kg.
  El test de stepper terminó sus pasos pero falló al desmontar por un timer de
  `FatigueNotifier`; el de progresión falló antes por no encontrar «Terminar».
  Ambos quedan registrados como fallos preexistentes de arnés/deuda, no como
  diferencias de formato introducidas por esta iteración.
- **Callout imperial:** el componente conservado se expone como `DevicesCallout`
  con `@visibleForTesting`, sin añadirlo a la pantalla. El peso no nulo pasa por
  `displayWeightKg`; null conserva el estado vacío y grasa/`%` no se convierte.
  En rojo imperial no aparecía `88.18 lb`; en verde métrico muestra `40 kg`,
  imperial `88.18 lb`, grasa `20 %` y nunca `40 lb`.
- **Resultados:** rojas reproducidas para doble toggle y callout; arnés T-002
  **1/1**; lote T-002 + units + chart **18/18**; progreso dirigido **5/5**.
  `flutter analyze` → **55 incidencias, 0 nuevas**. No se ejecutaron goldens,
  no se tocó PNG y no se usó `--update-goldens`.
- **D-097:** Tras una conversión de unidad, `_rawKg` contiene la base vigente y
  tiene prioridad sobre el valor original de `widget.set`; este último no debe
  sobrescribir una edición al alternar unidades.
- **D-098:** El callout conservado se prueba directamente mediante visibilidad
  exclusiva para tests, sin cambiar su presencia en la UI; el peso base kg se
  convierte y el porcentaje de grasa permanece independiente.

### Cierre
- **CA-10…CA-16 validados tras la iteración; CA-17 validado con el gate
  relativo permitido por el revisor.** No se exige suite completa verde ni
  goldens; los fallos heredados quedan separados y analyze no añade incidencias.
  T-002 queda lista para la nueva revisión obligatoria, sin aprobación
  unilateral. La spec 021 permanece activa.

## Decisiones D-xxx
- **D-085:** Se crea la spec 021 con solo dos tareas de corrección; no se
  reabren 015/017/019 ni se mezcla el trabajo con la fidelidad 020.
- **D-086:** La reparación del gráfico separa causa del vacío (fuente/dependencia)
  de errores de ventana/paginación; un solo filtro y lógica común de dominio.
- **D-087:** Para esta reparación, D-087 sustituye la descripción técnica
  histórica de D-030/Q-014: se consolidan los tres helpers existentes de
  `units.dart`; no se añade `formatNumber` y se conservan decimales como 1.25.
- **D-088:** La precisión de persistencia 0.001 kg y las fórmulas de dominio no
  cambian. Conversión en el límite de edición y redondeo a dos decimales solo
  para presentación.
- **D-089:** No se edita un golden como solución. Solo se regenera con Flutter
  si el código corregido afecta una captura, tras pruebas funcionales y revisión.

Nota de numeración: esta tanda empieza en D-085 para no colisionar con IDs ya
usados/reservados en la documentación y resúmenes posteriores de la 020 (hasta
D-084 localizado), aunque el memory anterior estuviera más resumido.

## Preguntas abiertas Q-xxx
- Nuevas preguntas bloqueantes para 021: **ninguna**. Reproducir la secuencia
  exacta de 39.99 es parte obligatoria de T-002, no una pregunta de producto.
- Q-002 heredada: patrón clamp(1,3) no encontrado en ExerciseInfoView; no
  bloquea ninguna de las dos correcciones y no forma parte de su alcance.
- **Q-003 (nueva, para el coordinador):** la deuda preexistente de HEAD (36
  fallos + 5 cuelgues + 2 goldens desactualizados, todos verificados en
  baseline) — ¿se crea una tarea/spec aparte? Sin resolverla, la puerta
  literal «`flutter test` en verde» de la 021 no puede pasar.
- **Q-004 (nueva, para el coordinador):** ¿se acepta el gate relativo (sin
  regresiones frente a baseline) para dar T-001 por cerrada? La implementación
  está entregada y CA-01…CA-08 cumplidos; solo CA-09 depende de esta respuesta.
  Para T-002, el revisor permitió explícitamente el gate relativo en esta
  iteración; CA-10…CA-17 quedan validados con ese criterio y pendientes de una
  nueva revisión obligatoria, sin aprobación unilateral.

## Archivos generados/actualizados en esta planificación
- Creados:
  - `docs/specs/021-correccion-grafico-precision-numerica/spec.md`
  - `docs/specs/021-correccion-grafico-precision-numerica/plan.md`
  - `docs/specs/021-correccion-grafico-precision-numerica/tasks.md`
- Actualizados:
  - `docs/specs/015-informacion-ejercicio/tasks.md` (referencia a 021 T-001).
  - `docs/specs/017-formato-numerico-mapa-vivo/tasks.md` (referencia a 021
    T-002 y estado real de D-030/Q-014).
  - `docs/specs/README.md` (fila 021 activa/planificada).
  - `memory.md`.
- Código de producción/tests: **sin cambios en esta sesión de planificación**.

## Resumen para retomar
Coordinador: entregar al implementador solamente 021/T-001 y después 021/T-002,
con sus CA y archivos probables. Exigir diagnóstico reproducido, tests de
regresión y puerta `flutter test` + `flutter analyze`. No rediseñar, no rehacer
trabajo anterior, no editar PNG como fix y no marcar ninguna tarea completada si
la puerta no pasa.

## Corrección de datos musculares del catálogo — 2026-11-18 (T39, fuera de la 021)

- **Alcance aprobado**: corregir `target` + `secondary_muscles` (con
  `muscle_group` sincronizado a `secondary_muscles[0]`). Fuera de alcance:
  `instruction_steps`, media/gif, `body_part`, `equipment`, esquema remoto,
  dependencias y la fusión de sinónimos (`traps`/`trapezius`, `deltoids`/
  `shoulders`, `lats`/`latissimus dorsi`), que ya resuelve T28.
- **Fuente única**: `lib/data/catalog_patches.dart` (nuevo) con
  `kCatalogMusclePatches` (365 ids → `target` + `secondary_muscles`) y
  `applyCatalogPatches()`. Lo consumen los tres puntos de persistencia:
  - `assets/exercises.json` parcheado directamente (el clon
    `exercises-dataset/` no está en la máquina, no se puede regenerar).
  - `tool/build_catalog_asset.dart`: lo aplica al generar y termina con
    error si un id del parche no existe en el dataset → sobrevive a las
    regeneraciones.
  - Migración drift `schemaVersion` 17 → 18: en la rama `from < 18`
    reaplica los `UPDATE` por id (idempotentes) y `DELETE FROM muscle_fatigue`
    (caché derivado; lo reconstruye `ensureFresh` o el cierre de sesión).
- **Reglas aplicadas** (365 filas): 42 elevaciones de gemelo con
  `hamstrings`/`glutes`/`quadriceps` → `[ankles, feet]`; 27 curls de muñeca
  con `biceps`/`triceps`/`brachialis` → `[wrist flexors|wrist extensors,
  grip muscles]`; 131 curls de bíceps `[forearms]` → `+ brachialis`; 75
  abdominales y 59 tríceps completados; 8 aperturas `+ triceps`; 18
  misceláneo (femorales, remos de hombros, elevación lateral, tobillo);
  **7 con `target` equivocado**: `0365`, `0366`, `0397` → `forearms`,
  `3119` y `1714` → `quads`, `1750` → `pectorals`, `3662` → `delts`
  (verificados con la miniatura y las instrucciones); y `1003`, el único
  que rompía `muscle_group = secondary_muscles[0]`.
- **`kMuscleAliases` +11** (`lib/domain/muscle_fatigue.dart`): `feet`,
  `brachialis`, `rear deltoids`, `back`, `upper chest`, `grip muscles`,
  `lower abs`, `groin`, `inner thighs`, `sternocleidomastoid`, `shins` —
  252 entradas secundarias que el mapa descartaba por no tener alias.
- **Invariantes**: 1.324 registros; 19 `target` / 29 `muscle_group` /
  40 `secondary_muscles` intactos (RF-3) y `muscle_group = secondary[0]`
  en las 1.324.
- **Tests**: nuevo `test/catalog_patches_test.dart` (5: recuentos,
  invariante, conformidad asset↔parche y cobertura de alias);
  `test/migration_test.dart` +1 («la v18 reaplica el parche…») y
  `user_version` 17 → 18 en 16 puntos;
  `test/catalog_repository_test.dart` biceps secundario 194 → 171.
- **Estado de la puerta**: `flutter analyze` → **52 incidencias, iguales al
  baseline, 0 errores y 0 nuevas en los ficheros tocados**. `flutter test`
  **no se completó**: la suite completa cuelga en los 5 tests preexistentes
  documentados más arriba y, además, otra sesión estaba corriendo tests en
  el mismo repo (`test/t002_diag_test.dart`), lo que contamina por CPU y por
  `build/`. Queda pendiente de revisión manual:
  `flutter test test/catalog_patches_test.dart test/migration_test.dart
  test/catalog_repository_test.dart test/muscle_fatigue_test.dart`.
- **Hallazgo fuera de alcance (no tocado)**: `muscleLabel()` en
  `lib/ui/widgets/muscle_map.dart` solo conoce las 18 zonas canónicas y
  devuelve el valor crudo, así que la ficha del ejercicio muestra en inglés
  valores como `lower back`, `brachialis` o `grip muscles` (comportamiento
  ya documentado en `test/exercise_info_view_test.dart:239` «muscleLabel
  fallthrough»). El parche aumenta las filas afectadas (`brachialis`
  14 → 148, `grip muscles` 1 → 31); candidato a una tarea propia.
