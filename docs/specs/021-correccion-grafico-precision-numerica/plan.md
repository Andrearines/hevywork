# Plan 021 — Gráfico de ejercicio y precisión numérica

Companion técnico de `spec.md`. T-001 y T-002 están aprobadas; la ampliación
T-003 repara toda la deuda no golden y deja `flutter analyze` sin incidencias.
La estrategia específica de T-003 está en la sección 7 y manda sobre cualquier
referencia histórica al gate relativo o a deuda ajena fuera de alcance.

## 1. Arquitectura de la reparación

### 1.1 Fuente real y puntos del gráfico

```text
RoutineDetailView / resto de entradas
        │  Exercise + AppDatabase + WorkoutRepository
        ▼
ExerciseInfoView
        │  exerciseHistory(exerciseId, página, offset)
        ├──────────────► páginas para tarjetas del historial
        └──────────────► fuente analítica del mismo ejercicio para KPI/gráfico
                              │
                              ▼
                 exerciseProgressPoints(metric)
                              │  dominio actual: warmups/incompletas fuera
                              ▼
                 filterByProgressWindow(points, window, now)
                              │  una sola vez, intervalo cerrado
                              ▼
               0/1 puntos: vacío · 2+: plot + insights
```

1. Corregir primero la entrada `RoutineDetailView`: es la causa verificada de
   repositorio nulo. No resolverlo inventando un repositorio desconectado ni
   ocultando el estado vacío.
2. Hacer testeable la preparación de puntos. Se reutiliza
   `exerciseProgressPoints()` y su enum de dominio, con un adaptador acotado al
   enum de UI si se decide conservar el contrato del widget. No mantener dos
   algoritmos de e1RM/carga/volumen.
3. Eliminar el prefiltrado temporal de `_computePoints()` y dejar solo
   `filterByProgressWindow()` (o mover ese helper puro a dominio sin cambiar su
   contrato público innecesariamente). Capturar `now` una vez por cálculo.
4. En ventana finita: `start = now.subtract(Duration(days: days))`; se admite
   `!date.isBefore(start) && !date.isAfter(now)`. En `all`, devolver los puntos
   sin ese recorte.
5. Mantener la paginación de tarjetas, pero no usar por defecto su primera
   página como sinónimo de «Todo». El implementador puede reutilizar las
   páginas existentes para la fuente analítica o añadir una consulta agregada
   específica del ejercicio si resulta más pequeña y eficiente. La decisión se
   documenta con la prueba de >10 sesiones; no se crean tablas ni sincronización.
6. El test de widget debe bombear el gráfico con dos puntos en su contexto real.
   Si el `Expanded` actual recibe altura no acotada en el sliver, se corrige
   únicamente la restricción de tamaño necesaria; no se rediseña el chart.

### 1.2 Política numérica común

```text
base de datos / dominio: double en kg o cm (sin cambios)
             │
             ├─ valor base kg ─► formatWeightKg ─┐
             ├─ valor base cm ─► formatLengthCm ─┤
             └─ valor ya mostrado ─► formatDisplay├─► texto, máx. 2 decimales
                                                   │
edición: texto visible ─► parse una vez ─► toKg/toCm│ (opcional: signo/miles)
             │                                      │
             └─ _rawKg se conserva si no hay edición┘
```

- `lib/domain/units.dart` es el punto común existente. `formatDisplay` ya
  redondea a centésimas; `formatWeightKg` y `formatLengthCm` ya convierten desde
  la base. No se añade otro formateador con el mismo cometido.
- Si el diagnóstico reproduce un defecto dentro de estas funciones, se corrige
  allí con casos de frontera. Si no, no se toca su algoritmo solo por preferencia
  estética. La política de dos cifras para no enteros (`78.40`) se conserva.
- Los wrappers de signo/miles reciben el texto ya formateado. No convierten otra
  vez el número y no redondean antes que la función común.
- Los conteos enteros no pasan por formateo decimal. Ratio, porcentaje, RPE,
  frecuencia y delta pueden usar `formatDisplay`, conservando su signo/unidad.
- La persistencia a 0.001 kg y los cálculos de e1RM/volumen se mantienen. Las
  conversiones de ida/vuelta se comprueban con tolerancia numérica, nunca con
  cuantización adicional del valor base.

### 1.3 Diagnóstico obligatorio de 40 → 39.99

Antes del cambio funcional, T-002 añade una prueba mínima o un arnés equivalente
que registre estos estados en orden:

1. Texto introducido y `_rawKg` antes de confirmar.
2. `displayWeightKg` y `toKg` en la confirmación.
3. `weightKg` recibido por `onConfirm` y persistido en drift.
4. Texto del controlador tras confirmar y tras desmontar/volver a montar.
5. Las mismas observaciones en una ida y vuelta +1.25/−1.25 kg y, si hace falta
   para reproducir, al alternar métrico/imperial.

El primer paso cuya salida sea incorrecta identifica el foco. En métrico el paso
2 es matemáticamente identidad; por eso no se propone de antemano cambiar
`kKgPerLb`, redondear a enteros o truncar. Si el caso exacto ya pasa en HEAD, se
amplía la reproducción al flujo aún no cubierto hasta encontrar el foco real y
se deja constancia en el resultado de la tarea.

## 2. Archivos probables

| Archivo | Cambio previsto | Tarea |
|---|---|---|
| `lib/ui/views/routine_detail_view.dart` | Pasar `localDb` y `workoutRepository` a la ficha | T-001 |
| `lib/ui/views/exercise_info_view.dart` | Separar fuente analítica de páginas visibles si hace falta; mantener carga real | T-001 |
| `lib/ui/widgets/exercise_progress_chart.dart` | Usar puntos de dominio, una ventana, métricas elegibles y tamaño válido | T-001, T-002 |
| `lib/ui/widgets/chart_enums.dart` | Intervalo temporal correcto e inyección de `now`; o adaptación al helper de dominio | T-001 |
| `lib/domain/exercise_stats.dart` | Solo si hace falta exponer/reutilizar preparación de puntos; no cambiar fórmulas | T-001 |
| `lib/data/repositories/workout_repository.dart` | Solo si la fuente analítica necesita una consulta propia; siempre por `exerciseId` | T-001 |
| `lib/domain/units.dart` | Punto común; corregir solo si la causa queda demostrada aquí | T-002 |
| `lib/ui/views/live_workout_view.dart` | Foco reproducido de edición/ajuste rápido y textos | T-002 |
| `lib/ui/views/routine_editor_view.dart`, `past_workout_editor_view.dart` | Sustituir `_fmtNumber` paralelo por el enfoque común | T-002 |
| `lib/ui/views/{train,progress,measures,profile,goal_editor,body_metric_editor}_view.dart` | Auditoría y focos de formato/unidad encontrados | T-002 |
| `lib/ui/widgets/*.dart` | Auditoría de `Text`, `TextPainter` y formateadores paralelos | T-002 |
| `test/routine_detail_view_test.dart` | Regresión de apertura con datos y dependencias | T-001 |
| `test/exercise_info_view_test.dart` | Integración con sesiones reales y fuente/paginación | T-001 |
| `test/exercise_progress_chart_test.dart` | 0/1/2+ puntos, métricas, ventanas, bordes y >10 | T-001 |
| `test/exercise_stats_test.dart`, `test/exercise_history_test.dart` | Solo si se toca dominio/repo | T-001 |
| `test/units_test.dart` | 40 exacto, ruido, 1.25, kg/lb e ida/vuelta | T-002 |
| `test/live_workout_view_test.dart` | Regresión 40 kg persistida/pintada y ajuste rápido actual | T-002 |
| Tests de vistas/widgets modificados | Regresión de cada foco global corregido | T-002 |
| `docs/specs/README.md`, `memory.md` | Estado y resultado real al cierre | Coordinación |

No se editan directamente `test/goldens/*.png`. No se modifica `pubspec.yaml`.

## 3. Secuencia y dependencias

1. **T-001 — gráfico:** fuente real → dominio/ventana → paginación analítica →
   regresión widget/integración → puerta completa.
2. **T-002 — números:** reproducción del primer valor erróneo → fix mínimo →
   auditoría/adopción del enfoque común → regresiones métrico/imperial → puerta.
3. **T-003 — deuda completa no golden:** instantánea y selección por tags →
   inventario archivo a archivo → diagnóstico por firma/causa → fixes con
   regresión roja/verde → saneamiento de análisis → puerta global completa.

No hay dependencia funcional entre los dos bugs iniciales. T-003 depende de
conservar el comportamiento aprobado de T-001/T-002, no de repetir su
implementación ni su revisión. No se ejecuta la spec 020 ni se reabren tareas
antiguas, pero sí se corrige cualquier archivo de esas specs cuando una prueba
no golden demuestre que participa en un fallo.

## 4. Estrategia de pruebas

### T-001

- **Puro:** tabla de fechas relativas a un `now` fijo para 1M/3M/6M/1A/Todo;
  inicio y `now` incluidos, anterior/futuro excluidos en ventana finita.
- **Dominio:** dos sesiones válidas generan dos puntos ordenados; solo
  warmup/incompleta no genera puntos; volumen cero no inventa carga/e1RM.
- **Repositorio/integración:** dos sesiones `finished` del ejercicio aparecen al
  abrir desde `RoutineDetailView`; otra sesión activa/abandonada o de otro
  ejercicio no se incorpora. Más de diez sesiones alimenta «Todo» sin pulsar
  «Cargar sesiones anteriores».
- **Widget:** 0 y 1 punto mantienen vacío sin insights; 2 puntos muestran
  `chartPlotKey` y no «Sin datos» ni excepciones. Cambiar métrica/ventana
  recalcula. El test falla con la entrada actual sin repositorio.

### T-002

- **Unidades:** `formatWeightKg(40, metric) = 40`; ruido binario redondeado a
  centésimas; 40 kg = 88.18 lb; 100 lb persiste aprox. 45.359 kg; 1.25/61.25
  permanecen; cero y valores enteros sin `.0`.
- **Widget en vivo:** introducir 40, reps/RIR y confirmar produce exactamente
  40 en drift y `40` visible tras reconstruir; ningún nodo muestra 39.99.
  Ida/vuelta de ajuste rápido conserva 40; los chips son ±1.25/±2.50 kg (o
  ±2.5/±5 lb) y no ±1.3 kg.
- **Efectos secundarios:** volúmenes/e1RM se calculan con valores de dominio,
  no con texto redondeado; los tests de fórmulas se mantienen sin cambios de
  expectativa matemática.
- **Cada foco del barrido:** prueba unitaria o widget con métrico e imperial
  cuando la unidad sea relevante. No se reescriben expectativas solo para
  aceptar una regresión; la actualización de `+1.3` a `+1.25` sí está justificada
  por `weightStepOf` y el requisito de decimales legítimos.
- **Puerta histórica de T-002:** sus regresiones aprobadas permanecen como
  guardia. El antiguo gate relativo queda sustituido para la entrega por D-103:
  T-003 debe cerrar con toda la selección no golden verde y análisis a cero.

## 5. Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| Arreglar solo el texto vacío y seguir sin datos | Integración desde `RoutineDetailView` con BD real |
| Corregir una ventana y romper «Todo» | Tabla pura con `now` fijo y prueba de más de una página |
| Cargar sesiones de otros ejercicios | Repositorio acotado a `exerciseId`; prueba con segundo ejercicio |
| Maquillar 39.99 en UI mientras drift guarda otro valor | Aserción tanto en persistencia como en controlador |
| Conversiones repetidas pierden precisión | Conservar base sin edición, parse único y prueba de cambio de unidad |
| Unificar formatos eliminando decimales útiles | Casos 1.25/61.25 y prohibición de redondeo global a enteros |
| Actualizar PNG en vez del código | D-101: goldens ni se ejecutan ni se editan en esta entrega |
| Suite preexistente en rojo | T-003 la incluye; inventario por archivo y puerta completa, sin gate relativo |
| Cuelgue oculto por watchdog o lote | Watchdog solo diagnóstico; JSON por archivo y globales con cobertura del manifiesto |

## 6. Sin entregables adicionales iniciales

No proceden `DESIGN.md`, `docs/api.md` ni carpetas nuevas de app: no hay UI ni
API nuevas. Tampoco se crea una spec de saneamiento separada. Si una evidencia
de T-003 obliga excepcionalmente a cambiar el esquema, antes de aplicarlo se
actualizarán este plan, la documentación de datos vigente y `memory.md` con la
migración concreta; no se da por autorizada una migración genérica. La
constitución vigente es `docs/constitution.md` junto con `AGENTS.md` (este
último manda si difieren).

## 7. Plan técnico de T-003 — saneamiento integral no golden

### 7.1 Punto de partida e invariantes

- Inventario estático de planificación: **65 archivos** `test/**/*_test.dart`,
  **8 llamadas/casos golden en 6 archivos** y ninguna declaración `skip:`,
  `@Skip`, `Timeout(...)` o `timeout:` en los tests. Estas cifras sirven para
  auditar cobertura, no como sustituto del descubrimiento dinámico del runner.
- `flutter analyze --no-pub` de planificación: **55 incidencias** (2 errores,
  31 warnings y 22 infos), salida 1. No se ejecutó ningún golden.
- La corrida histórica de T-002 (**638/605/33**) es incompleta: cinco suites
  abortaron y dejaron casos sin cargar. No se utilizará como objetivo numérico
  ni se comparará aritméticamente con 887/851/36. T-003 parte de un inventario
  nuevo sobre el árbol vigente.
- Se conservan las correcciones y regresiones aprobadas T-001/T-002. No se
  revierte, resetea, limpia ni commitea trabajo propio o concurrente. Se registra
  `HEAD` y `git status` al inicio; si cambian durante una corrida, esa corrida se
  marca no concluyente y se repite sobre una sola instantánea. No se mezclan
  resultados de revisiones distintas ni se ejecutan procesos Flutter concurrentes
  sobre el mismo `build/`.
- Cualquier archivo puede ser causa o solución, incluidos catálogo, aliases,
  asset, v18, sincronización o deuda de otra spec. La procedencia «ajena» ya no
  es una exclusión. Sí lo son el rediseño gratuito, las dependencias nuevas, los
  commits y cualquier cambio no sustentado por una evidencia.

### 7.2 Exclusión golden por caso, con cobertura demostrable

Se añade `tags: ['golden']` **únicamente a las ocho declaraciones** que contienen
`matchesGoldenFile`. No se etiqueta un `group`, un archivo completo ni casos
vecinos; no se añade `skip`, no se cambian títulos para filtrar y no se toca el
contenido de ningún PNG. El caso del mapa vacío demuestra por qué no basta una
regex sobre «golden:»: su título actual no contiene ese prefijo.

| Archivo | Casos que reciben la etiqueta | N.º |
|---|---|---:|
| `test/train_view_test.dart` | `golden: TrainView con datos (T-007 / SCR-02)` | 1 |
| `test/muscle_map_test.dart` | `golden: vista frontal con fatiga repartida`; `golden: vista trasera con fatiga repartida`; `sin datos el mapa completo se dibuja en gris neutro (RF-5)` | 3 |
| `test/routines_view_test.dart` | `golden: RoutinesView con datos (T-005 / CA-01)` | 1 |
| `test/routine_detail_view_test.dart` | `golden: detalle de rutina con ejercicios (RF-38)` | 1 |
| `test/progress_view_test.dart` | `golden: Progreso sin datos (T-12)` | 1 |
| `test/live_workout_view_test.dart` | `golden: LiveWorkoutView con datos (T-009 / SCR-03)` | 1 |

La firma vigente de `testWidgets` admite `tags`, y el CLI instalado admite
`--exclude-tags`; por tanto no hacen falta dependencias, wrappers de test ni
cambios en `analysis_options.yaml`. El comando de selección es:

```sh
flutter test --exclude-tags golden
```

Antes de aceptar el resultado se comprueba:

1. Las ocho ocurrencias de `matchesGoldenFile` pertenecen a una declaración
   etiquetada y no aparece una novena ocurrencia sin etiqueta.
2. Ningún `group` o archivo completo recibe la etiqueta; ningún caso adquiere
   `skip`. Los demás casos de los seis archivos mixtos siguen siendo
   descubiertos y terminados.
3. La corrida JSON no contiene `testStart` de los ocho casos, sí contiene casos
   no golden de cada archivo mixto, y sus `suite.path` cubren el manifiesto
   completo de archivos de test. Los conteos de declaraciones estáticas se usan
   como auditoría secundaria, no como total dinámico obligatorio porque hay
   casos generados en bucles.
4. Un aviso del analyzer dentro del cuerpo Dart de un caso golden también se
   corrige: excluir su ejecución no excluye su análisis. Esa corrección no puede
   cambiar la captura, el matcher ni el PNG.

### 7.3 Inventario por archivos, watchdogs y contabilidad

Los lotes grandes ya demostraron que se pueden descartar archivos y ocultar una
suite abortada. El diagnóstico se hará primero **archivo a archivo**, con un
manifiesto ordenado de los 65 paths y artefactos fuera del repo, por ejemplo en
`/tmp/opencode/hevywork-t003/<run-id>/`:

```sh
timeout --signal=TERM --kill-after=10s 180s \
  flutter test <un-archivo> --exclude-tags golden --concurrency=1 \
  --file-reporter json:<log-fuera-del-repo>.json
```

- El watchdog de 180 s es una alarma diagnóstica, no una expectativa de
  duración ni una puerta. Salida 124/137, JSON truncado, ausencia de evento
  `done` o tests sin `testDone` significan **incompleto**. Se puede repetir con
  un watchdog mayor para distinguir arranque lento de bloqueo, pero nunca se usa
  `--ignore-timeouts`, se desactiva el timeout del test o se declara éxito por
  haber agotado el watchdog.
- Para cada archivo se registra: selección descubierta, pass/fail, tests sin
  completar, errores de carga, última prueba/evento, firma de excepción y código
  de salida. Todo archivo del manifiesto debe quedar contabilizado exactamente
  una vez; un lote con paths ausentes no es válido.
- Después se reproduce la firma de forma dirigida. `--plain-name` está permitido
  para aislar un caso **no golden**, nunca como selección de la puerta final.
  La concurrencia 1 ayuda a localizar; no es la configuración única de cierre,
  porque la corrida global con concurrencia normal también debe pasar.
- El inventario distingue: producción defectuosa, arnés/ciclo de vida
  defectuoso, expectativa demostrablemente obsoleta, interferencia entre tests o
  ejecución contaminada. «Preexistente» describe origen, no reduce prioridad ni
  permite omitirlo.
- Cada fix enlaza en `memory.md` la firma roja, la causa demostrada, el cambio y
  la regresión verde. Si se retira temporalmente el fix para comprobar el rojo,
  se restaura solo ese cambio y se verifica el diff; no se usa stash/reset sobre
  trabajo ajeno.

### 7.4 Paquetes de diagnóstico ya acotados

Son puntos de entrada, no conclusiones anticipadas ni fixes autorizados sin
reproducción. Cualquier firma nueva se añade al mismo inventario.

| Paquete | Evidencia inicial y causa que debe aislarse | Archivos iniciales, ampliables por evidencia |
|---|---|---|
| **A. Contrato del chart/T-001** | Dos errores de compilación por `now` y `progressChartPoints`; aviso de `_analyticsHistory`; CA-02 sin `chart-plot`. Restaurar la API y el comportamiento aprobados, no borrar las nuevas pruebas ni devolver el chart a una copia divergente. | `lib/ui/widgets/exercise_progress_chart.dart`, `chart_enums.dart`, `lib/ui/views/exercise_info_view.dart`, `lib/domain/exercise_stats.dart`; `test/exercise_progress_chart_test.dart`, `exercise_info_view_test.dart`, `routine_detail_view_test.dart` |
| **B. Cierre asíncrono y recursos** | Cinco suites abortan con `Cannot close sink while adding stream`; hay timers pendientes y cierres incompletos. Investigar suscripciones drift activas al cerrar BD, globals del arnés, observers y disposición de notifiers. En `LiveWorkoutView.dispose()` se cancela el reloj, pero debe comprobarse el ciclo completo de `_fatigueNotifier`, `_restNotifier` y observers; no se afirma que una sola línea explique las cinco suites. | `live_workout_view.dart`, `domain/use_cases/fatigue_notifier.dart`, `domain/services/rest_notifier.dart`, `main.dart`, repositorios/streams implicados; `exercise_info_view_test.dart`, `live_workout_view_test.dart`, `profile_view_test.dart`, `progress_view_test.dart`, `routines_view_test.dart`, `app_shell_test.dart` |
| **C. Borrado de rutina con hijos** | El caso se cuelga tras confirmar y bombear. Separar espera infinita de animación/frame, stream que no termina, cascada de repositorio, diálogo/navegación y cierre de BD. No sustituir la espera por un timeout mayor ni borrar la aserción de hijos. | `lib/ui/views/routines_view.dart`, `lib/data/repositories/routine_repository.dart`, `test/routines_view_test.dart`; sync/cola solo si la traza lo demuestra |
| **D. Live workout** | Stepper con timer de `FatigueNotifier`; progresión sin encontrar «Terminar»; fallo histórico de e1RM y casos que no completan. Determinar si el CTA está ausente, fuera de viewport, no hit-testeable o si el arnés no llega al estado contractual. Conservar los formatos aprobados T-002. | `live_workout_view.dart`, `workout_manager.dart`, notifiers y `test/live_workout_view_test.dart`, `test/t002_precision_test.dart` |
| **E. Contratos visuales/funcionales no golden** | Deuda histórica: 10 exercise-info antiguos (duplicados ES/815 kg, badges, CTA/scroll), 4 live-fatigue, 7 responsive, 3 small-screen, 2 app-shell y focos profile/progress/live. Comparar con specs y comportamiento vigente antes de tocar producción o expectativas. | Vistas/widgets y tests homónimos; `live_fatigue_section.dart`, `screen_breakpoints.dart`, `main.dart`, `profile_view.dart`, `progress_view.dart`, `exercise_info_view.dart` |
| **F. Catálogo, aliases y v18** | Ahora están dentro si un test no golden los vincula. Ejecutar y diagnosticar sus suites sin asumir que fallan ni que la v18 necesita otra migración. Mantener coherentes parche, generador, asset y aliases si se tocan. | `lib/data/catalog_patches.dart`, `tool/build_catalog_asset.dart`, `assets/exercises.json`, `lib/domain/muscle_fatigue.dart`, `lib/data/local/database.dart`; `catalog_patches_test.dart`, `catalog_repository_test.dart`, `migration_test.dart`, `muscle_fatigue_test.dart` |
| **G. Nuevas firmas y orden/concurrencia** | Fallos intermitentes, estado compartido, orden de tests y cierres que solo aparecen en global. Repetir el caso aislado, su archivo y global; una pasada aislada no prueba que esté resuelto en global. | Los que señale la traza; no hay restricción por spec o procedencia |

### 7.5 Saneamiento de las 55 incidencias de análisis

Inventario agrupado de la corrida de planificación; los números son el punto de
partida y el resultado exigido es cero, también para incidencias que aparezcan
mientras se corrigen tests:

| Grupo | Archivos y recuento inicial |
|---|---|
| Dominio (1) | `fatigue_trend.dart` (1) |
| Vistas (23) | `exercise_detail_view.dart` (1), `exercise_info_view.dart` (5), `live_workout_view.dart` (4), `profile_view.dart` (1), `progress_view.dart` (10), `routine_editor_view.dart` (1), `train_view.dart` (1) |
| Widgets (19) | `exercise_progress_chart.dart` (6), `fatigue_trend_chart.dart` (5), `live_fatigue_section.dart` (1), `zone_volume_chart.dart` (7) |
| Tests (12) | `exercise_detail_view_test.dart` (1), `exercise_info_view_test.dart` (2), `exercise_progress_chart_test.dart` (2), `live_fatigue_section_test.dart` (1), `live_workout_view_test.dart` (1), `responsive_layout_test.dart` (2), `routine_detail_view_test.dart` (1), `screen_breakpoints_test.dart` (1), `zone_volume_chart_test.dart` (1) |

- Los dos errores (`undefined_named_parameter now` y `undefined_function
  progressChartPoints`) se resuelven dentro del paquete A, manteniendo las
  regresiones T-001.
- Imports/variables/elementos sin uso no se borran mecánicamente si delatan una
  sección desconectada: se contrasta con la spec y los tests. Se elimina solo
  código realmente muerto; se reconecta únicamente el comportamiento exigido,
  sin rediseño.
- Deprecations y estilo se migran a la API vigente preservando comportamiento.
  No se usan `// ignore`, `ignore_for_file`, exclusiones nuevas en
  `analysis_options.yaml` ni una desactivación global de reglas para ocultar
  incidencias. Si una regla parece imposible de cumplir, se informa del bloqueo;
  no se disfraza con una supresión.
- No se relaja la puerta a «0 errores»: warnings e infos también cuentan. Los
  tests golden excluidos en runtime siguen incluidos en `flutter analyze`.

### 7.6 Reglas para tocar tests, catálogo o esquema

**Actualización de un test.** Antes de editarlo se documentan: contrato de spec o
comportamiento vigente, reproducción roja, causa por la que el arnés/expectativa
es incorrecto y aserción que seguirá protegiendo el requisito. Está prohibido
borrar el caso, añadir `skip`, convertir una aserción precisa en `findsWidgets`
sin justificación, capturar y descartar excepciones o cambiar el valor esperado
al valor defectuoso. Un test nuevo o corregido debe fallar sin el fix cuando el
defecto sea de producción.

**Catálogo/activos.** Se permite tocar parche, generador, asset y aliases cuando
la traza lo exija. Se mantienen las invariantes existentes (1.324 ejercicios,
`muscle_group = secondary_muscles[0]`, cobertura de aliases y conformidad
asset↔parche) y se añade una regresión del fallo concreto. No se modifica un
artefacto generado de forma incoherente con su fuente.

**Esquema.** No hay migración prevista. Si un test no golden demuestra que no hay
fix correcto más pequeño, antes del cambio se registra la consulta/fallo, la
razón técnica y el archivo de migración. El esquema remoto cambia solo mediante
una migración en `supabase/migrations/` para esta tarea, con RLS/`user_id`
cuando corresponda; el local mediante `schemaVersion` de drift, generación con
`build_runner` y pruebas de migración. Se actualiza la documentación de datos.
Si no se cumple esta evidencia, no se toca el esquema.

### 7.7 Puerta final reproducible

1. **Auditoría de selección e integridad:** ocho tags golden individuales, cero
   skips nuevos, ningún caso no golden excluido por nombre/archivo, manifiesto
   de tests completo y conjunto+hashes de PNG iguales antes/después. No se pasó
   `--update-goldens` ni se ejecutó un golden.
2. **Regresiones dirigidas:** todos los paquetes A…G y las guardias T-001/T-002
   en verde, incluidos chart, entrada desde rutina, `t002_precision_test`, units
   y los seis archivos mixtos con `--exclude-tags golden`.
3. **Contabilidad por archivo:** cada uno de los 65 paths tiene una corrida
   completa y verde, o queda cubierto y verificado por la corrida global JSON;
   no queda ningún archivo ausente, test sin `testDone`, suite abortada ni
   recurso pendiente. Los watchdogs solo han servido para encontrar los bloqueos.
4. **Global con concurrencia normal:**

   ```sh
   flutter test --exclude-tags golden --reporter expanded
   ```

   Debe terminar por sí sola con salida 0. Como ya hay firmas de concurrencia y
   orden, se repite una segunda corrida completa con una semilla fija registrada:

   ```sh
   flutter test --exclude-tags golden --test-randomize-ordering-seed=<semilla>
   ```

   Ambas deben pasar sin skips nuevos ni omisiones. Al menos una se acompaña de
   JSON fuera del repo para comprobar `done.success == true`, igualdad entre
   tests iniciados/terminados no ocultos, resultados exitosos y cobertura del
   manifiesto de suites. La semilla no selecciona tests: solo cambia su orden.
5. **Análisis:** `flutter analyze` sale 0 con **0 issues**; no se acepta
   «0 errores» ni «sin incidencias nuevas».
6. **Registro:** se documentan comandos, semilla, recuentos dinámicos reales,
   causas y archivos modificados. Si algo no pasa, T-003 y 021 permanecen
   activas; no se aprueba con gate relativo ni se cierra administrativamente.
