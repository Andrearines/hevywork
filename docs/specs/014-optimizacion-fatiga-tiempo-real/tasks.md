# Tareas 014 — Optimización, fatiga en tiempo real y miniaturas

Orden de ejecución e iterables. **Cierre obligatorio de cada tarea**:
`flutter test` en verde + `flutter analyze` sin incidencias (constitución
§6). Si no pasa, la tarea no está terminada.

Tabla hallazgo → tarea (los 9 de la spec, bloque C):

| Hallazgo | Tarea |
|---|---|
| H1 `setState` por tecla en `_EditableSetRow` | T-008 |
| H2 efectos secundarios en `build()` (StreamBuilder) | T-009 |
| H3 `AutomaticKeepAliveClientMixin` masivo | T-010 |
| H4 3 `StreamBuilder` anidados en la sesión en vivo | T-011 |
| H5 `MediaQuery.of` en `ExerciseThumb` | T-012 |
| H6 recálculo de fatiga al abrir Progreso + relanzamiento en `didUpdateWidget` | T-004 + T-007 (RF-8) |
| H7 7 suscripciones con `setState` en `routines_view` | T-013 |
| H8 `muscle_map` reconstruye intensidades en cada `build` | T-014 |
| H9 `Image.asset` sin `cacheWidth` en la ficha de ejercicio | T-015 |

---

## T-000 · Precondición: entorno Flutter operativo
- **Objetivo**: verificar que la toolchain responde antes de tocar código
  (el montaje FUSE del SDK se está reparando en paralelo; esta tarea solo
  comprueba, no repara).
- **Archivos**: ninguno.
- **Acciones**:
  1. `flutter --version` responde.
  2. `flutter analyze` arranca (puede fallar por incidencias reales, pero
     no por SDK inaccesible).
  3. `flutter test test/units_test.dart` ejecuta al menos un test.
  4. Si el SDK sigue inaccesible: se detiene el trabajo y se avisa al
     coordinador (no se empieza T-001).
- **Criterio de aceptación**: los tres comandos se ejecutan; el test
  propuesto pasa.
- **Cierre**: `flutter test` + `flutter analyze` en verde (o bloqueo
  reportado antes de continuar).

## T-001 · A — Miniaturas en el editor de rutinas
- **Objetivo**: tarjetas `_draftTile` con `ExerciseThumb` 44 + chips +
  nombre, hidratación por ids desde el catálogo (RF-1…RF-3).
- **Archivos**:
  - crear `lib/ui/widgets/exercise_chips.dart` (extraer `_ExerciseChips`
    de `live_workout_view.dart`).
  - modificar `lib/data/repositories/catalog_repository.dart`
    (`exercisesByIds`).
  - modificar `lib/ui/views/routine_editor_view.dart` (hidratar
    `Exercise` al cargar y al elegir; `_draftTile` con miniatura).
  - modificar `lib/ui/views/live_workout_view.dart` (usar `ExerciseChips`
    público en lugar del privado).
  - tests: ampliar `test/catalog_repository_test.dart` y
    `test/routine_editor_view_test.dart`.
- **Criterio de aceptación**:
  - `exercisesByIds` devuelve solo los pedidos, tolera ids
    desconocidos/duplicados (1 consulta `isIn`).
  - Cada tarjeta del editor muestra miniatura 44 dp, chips y nombre;
    con `imagePath` nulo o roto, `ThumbFallback` sin excepción.
  - La sesión en vivo pinta igual que antes (chips extraídos, sin cambio
    visual).
  - Test widget que abre un editor con rutina y comprueba
    `find.byType(ExerciseThumb)` por tarjeta.
- **Cierre**: `flutter test` + `flutter analyze` en verde. **[x]**

## T-002 · B — Dominio: sesión activa + tendencia de fatiga
- **Objetivo**: el cálculo de fatiga incluye la sesión `active` y nace la
  función de tendencia diaria (RF-5, RF-9 parte dominio).
- **Archivos**:
  - crear `lib/domain/fatigue_trend.dart`.
  - modificar `lib/data/repositories/fatigue_repository.dart`
    (`recalculate`, `weeklyZoneStats`, `_setsOf` → `status in
    ('finished','active')`, fecha `endedAt ?? startedAt`).
  - tests: crear `test/fatigue_trend_test.dart`; ampliar
    `test/fatigue_repository_test.dart`.
- **Criterio de aceptación**:
  - Series de una sesión `active` (sin `endedAt`) entran en el caché y en
    las zonas semanales, fechadas por `startedAt`.
  - `fatigueTrend` devuelve un punto por día en la ventana, valores 0–1,
    opcionalmente de un músculo concreto; sin datos → lista vacía.
  - Los tests existentes de `muscle_fatigue` siguen en verde (dominio de
    la 007 intacto).
- **Cierre**: `flutter test` + `flutter analyze` en verde. **[x]**

## T-003 · B — FatigueNotifier + cableado en main.dart
- **Objetivo**: Observer/Notifier con debounce 750 ms, `flush()` y
  `markDirty()` (RF-4, RF-10).
- **Archivos**:
  - crear `lib/domain/use_cases/fatigue_notifier.dart`.
  - modificar `lib/main.dart` (global `fatigueNotifier`, fuentes
    `tableUpdates(workout_sets)` y `tableUpdates(workouts)`,
    `onSyncCompleted → flush()`).
  - modificar `lib/ui/views/live_workout_view.dart` (cierre de sesión →
    `await fatigueNotifier.flush()` en lugar de `recalculate()`).
  - modificar `lib/ui/views/past_workout_editor_view.dart`
    (`recalculate()` → `fatigueNotifier.markDirty()`).
  - crear `test/fatigue_notifier_test.dart`.
- **Criterio de aceptación**:
  - N eventos seguidos → un solo recálculo tras el delay.
  - `flush()` ejecuta ya y cancela el pendiente; si otro recálculo está en
    vuelo, se espera sin duplicar.
  - `dispose()` cancela temporizador y suscripciones (sin fugas en tests).
  - Un cambio en `workout_sets` dispara el recálculo (test con BD en
    memoria y delay corto).
- **Cierre**: `flutter test` + `flutter analyze` en verde. **[x]**

## T-004 · B/H6 — Recálculo incremental, ensureFresh y watchFatiguePanel
- **Objetivo**: escritura por diff, frescura barata y fuente única en
  stream para la UI (RF-6, RF-8, RF-14 helper).
- **Archivos**:
  - crear `lib/data/util/combine_latest.dart` (+ `test/combine_latest_test.dart`).
  - modificar `lib/data/repositories/fatigue_repository.dart`
    (diff-write en `recalculate`, `ensureFresh`, `watchFatiguePanel`).
  - tests: ampliar `test/fatigue_repository_test.dart`.
- **Criterio de aceptación**:
  - Recalcular con datos idénticos (mismo `now`) no escribe filas:
    `computedAt` intacto y `watchFatigue` sin nueva emisión.
  - Cambios reales actualizan solo las filas afectadas, dentro de
    transacción.
  - `ensureFresh()` con caché fresca no recalcula; con caché ausente o
    mayor de 30 min sí.
  - `watchFatiguePanel()` emite la terna (fatiga, zonas, tendencia) y
    vuelve a emitir al cambiar series o caché.
- **Cierre**: `flutter test` + `flutter analyze` en verde. **[x]**

## T-005 · B — Gráficas nuevas (CustomPainter)
- **Objetivo**: `ZoneVolumeChart` y `FatigueTrendChart` sin dependencias
  (RF-9).
- **Archivos**:
  - crear `lib/ui/widgets/zone_volume_chart.dart`,
    `lib/ui/widgets/fatigue_trend_chart.dart`.
  - tests: crear `test/zone_volume_chart_test.dart`,
    `test/fatigue_trend_chart_test.dart` (+ goldens
    `test/goldens/zone_volume_chart.png`,
    `test/goldens/fatigue_trend_chart.png`).
- **Criterio de aceptación**:
  - `shouldRepaint` false con los mismos datos y true con distintos.
  - Render correcto con datos, con lista vacía (estado vacío) y con un
    solo punto.
  - Estilo conforme al designer (guías punteadas, gradiente de área,
    punto final; sin `BoxShadow`), contraste AA.
  - Goldens nuevos generados y en verde.
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-006 · B — Sección de fatiga en la sesión en vivo
- **Objetivo**: `LiveFatigueSection` dentro de `live_workout_view`, visible
  por defecto y plegable, actualizada al completar cada serie (RF-7).
- **Archivos**:
  - crear `lib/ui/widgets/live_fatigue_section.dart`.
  - modificar `lib/ui/views/live_workout_view.dart` (insertar la sección
    como `SliverToBoxAdapter` tras `_progressionStrip()`; un único
    `StreamBuilder` del panel).
  - tests: crear `test/live_fatigue_section_test.dart` y ampliar
    `test/live_workout_view_test.dart`.
- **Criterio de aceptación**:
  - La sección muestra mapa muscular vectorial, lista de zonas, ambas
    gráficas y estado vacío sin series.
  - Completar una serie (delay corto + `pumpAndSettle`) actualiza mapa,
    zonas y gráficas sin navegar.
  - Plegar/desplegar funciona, conserva datos y respeta targets ≥ 48 dp.
  - Sin sombras; `RepaintBoundary` en mapa y gráficas.
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-007 · B/H6 — Progreso en vía stream
- **Objetivo**: `_FatigueSection` alimentada por `watchFatiguePanel`, sin
  `recalculate()` de apertura ni relanzamiento en `didUpdateWidget`;
  gráficas añadidas a Progreso (RF-8, RF-10, parte UI de RF-9).
- **Archivos**:
  - modificar `lib/ui/views/progress_view.dart` (`initState` →
    `ensureFresh()`; sección por panel; añadir `ZoneVolumeChart` y
    `FatigueTrendChart`; eliminar `_zones`/`didUpdateWidget`).
  - golden: regenerar `test/goldens/progress_empty.png` si cambia.
  - tests: ampliar `test/progress_view_test.dart`.
- **Criterio de aceptación**:
  - Abrir Progreso con caché fresca no ejecuta `recalculate()`; con caché
    vieja lo ejecuta una vez (`ensureFresh`).
  - Cambiar el caché desde el repositorio actualiza la sección sin
    navegar (stream).
  - Tocar el mapa cambia la selección sin recargar zonas (no hay
    relanzamiento de `weeklyZoneStats`).
  - Las dos gráficas se ven en Progreso con los mismos widgets de T-005.
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-008 · C/H1 — Sin `setState` por tecla en las filas de serie
- **Objetivo**: RF-11.
- **Archivos**: `lib/ui/views/live_workout_view.dart`
  (`_EditableSetRowState`); ampliar `test/live_workout_view_test.dart`.
- **Criterio de aceptación**:
  - El listener de `_rirCtrl` que hacía `setState` de la fila se sustituye
    por `ValueListenableBuilder` en `_rirChip`.
  - Escribir en KG no reconstruye la fila (`_rawKg` se asigna sin
    `setState`); los steppers rápidos siguen usando el valor escrito.
  - Test: teclear en RIR/KG mantiene el chip y los ajustes rápidos
    correctos y la confirmación de serie sigue validando.
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-009 · C/H2 — Sin efectos secundarios en `build()`
- **Objetivo**: RF-12.
- **Archivos**: `lib/ui/views/live_workout_view.dart` (movas de
  `_startedAt`/`_currentWorkout`/`_loadPrevious`/`_refreshSuggestions` a
  `initState` vía suscripción); ampliar `test/live_workout_view_test.dart`.
- **Criterio de aceptación**:
  - `build()` no asigna estado de instancia ni agenda callbacks; las
    banderas `_previousLoaded`/`_suggestionsScheduled` se cumplen igual.
  - Test de regresión: la vista arranca, carga previa y sugerencias
    aparecen una sola vez tras reconstrucciones repetidas.
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-010 · C/H3 — `AutomaticKeepAliveClientMixin` por tarjeta, no por fila
- **Objetivo**: RF-13.
- **Archivos**: `lib/ui/views/live_workout_view.dart`
  (`_ExerciseCardState` conserva el mixin; `_EditableSetRowState` lo
  elimina junto a `super.build`); ampliar `test/live_workout_view_test.dart`.
- **Criterio de aceptación**:
  - Solo la tarjeta declara `wantKeepAlive`.
  - Test: sesión larga → desplazar fuera y volver conserva el texto
    escrito sin confirmar en una fila (estado vivo dentro de la tarjeta)
    y la selección de tipo de serie.
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-011 · C/H4 — Un solo `StreamBuilder` en la sesión en vivo
- **Objetivo**: RF-14 con `combineLatest3` propio (incluye la fuente del
  panel de fatiga en el mismo `StreamBuilder` si resulta natural).
- **Archivos**: `lib/ui/views/live_workout_view.dart`; ampliar
  `test/live_workout_view_test.dart`.
- **Criterio de aceptación**:
  - Los streams de workout, ejercicios y series se combinan en `initState`
    y `build` tiene un único `StreamBuilder` de sesión (la sección de
    fatiga puede ser el único `StreamBuilder` adicional).
  - Test de regresión: render completo, estados de carga y guardado
    siguen igual.
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-012 · C/H5 — `MediaQuery.devicePixelRatioOf` en `ExerciseThumb`
- **Objetivo**: RF-15.
- **Archivos**: `lib/ui/widgets/exercise_thumb.dart`; ampliar un test que
  renderice `ExerciseThumb` (p. ej. `test/routine_editor_view_test.dart`
  o `test/exercise_detail_view_test.dart`).
- **Criterio de aceptación**:
  - El ratio se lee con `devicePixelRatioOf`; el `cacheWidth`/`cacheHeight`
    calculado no cambia (miniatura idéntica).
  - Test widget que monta `ExerciseThumb` con y sin `imagePath` y verifica
    render + `ThumbFallback`.
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-013 · C/H7 — Suscripciones coalescidas en `routines_view`
- **Objetivo**: RF-17: una sola reconstrucción por frame para las 7
  fuentes.
- **Archivos**:
  - crear helper testeable (p. ej. `lib/ui/util/coalescer.dart`) o
    implementarlo como método testeable del propio estado.
  - modificar `lib/ui/views/routines_view.dart`.
  - tests: test unitario del helper + ampliar `test/routines_view_test.dart`.
- **Criterio de aceptación**:
  - N emisiones síncronas de fuentes distintas producen una única
    reconstrucción (test del helper: contador de agendados == 1).
  - La UI de Rutinas sigue mostrando rutinas, contadores, stats, última
    uso, catálogo, sesión activa e historial (test de regresión).
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-014 · C/H8 — Memoizar derivados del mapa muscular
- **Objetivo**: RF-18: `muscle_map.dart` no reconstruye colores e
  intensidades si no cambian sus entradas.
- **Archivos**: `lib/ui/widgets/muscle_map.dart`; ampliar
  `test/muscle_map_test.dart`.
- **Criterio de aceptación**:
  - Los mapas derivados se recalculan solo al cambiar `fatigue`,
    `showBack` o `selected` (memoización verificable con un test que
    comprueba identidad/valor de los datos derivados entre builds).
  - Goldens `muscle_map_front.png`, `muscle_map_back.png`,
    `muscle_map_empty.png` sin cambios visuales (prueba de neutralidad).
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-015 · C/H9 — `cacheWidth` en la imagen de la ficha
- **Objetivo**: RF-19.
- **Archivos**: `lib/ui/views/exercise_detail_view.dart`; ampliar
  `test/exercise_detail_view_test.dart`.
- **Criterio de aceptación**:
  - `Image.asset` declara `cacheWidth`/`cacheHeight` acotados por
    `devicePixelRatio` y tamaño mostrado; sin `BoxShadow` ni cambios de
    layout.
  - Test: la ficha renderiza la miniatura y `ThumbFallback` sin errores.
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-016 · D — Doc-comentarios y patrones en ficheros tocados
- **Objetivo**: RF-20. Documentar con `///` en español las clases,
  métodos y constantes públicas de **los ficheros tocados por la 014**
  (nuevos y modificados, lista en plan.md §3) y dejar constancia de los
  patrones: Observer/Notifier (`FatigueNotifier`), Repository (ya
  existente), combinación de streams (helper), CustomPainter de gráficas.
  Nada de comentarios intrusivos; identificadores en inglés (§11).
- **Archivos**: todos los de la tabla de plan.md §3 + los creados.
- **Criterio de aceptación**:
  - Cada clase/método público de esos ficheros tiene `///` en español.
  - `flutter analyze` no emite avisos por documentación ausente/duplicada.
  - La constancia de aprobación del usuario queda en la spec (ya está en
    `spec.md`, Decisiones).
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-017 · E — README.md reescrito en español
- **Objetivo**: RF-21.
- **Archivos**: `README.md` (raíz).
- **Criterio de aceptación**:
  - Apartados: descripción; arquitectura por capas (dominio / data /
    UI); cómo ejecutar (incluido `./tool/run.sh`); `--dart-define`
    (SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, nota de la secreta solo para
    `tool/`); comandos clave (`flutter run/test/analyze`,
    `build_runner`, `build_catalog_asset`, `upload_gifs`); estructura de
    datos (drift local + Postgres fuente de verdad, cola de sync, asset
    del catálogo); sección de specs (`docs/specs/`); atribución de medios
    `© Gym visual — https://gymvisual.com/`.
  - En español, sin secretos ni URLs de proyecto hardcodeadas (§10).
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-018 · F — Cierre: goldens, suite completa y hoja de ruta
- **Objetivo**: RF-22 y puerta final de la spec.
- **Archivos**: `test/goldens/*` (regenerar los que la UI de la 014
  cambió: `progress_empty.png`, los nuevos de T-005, verificar
  `muscle_map_*` y `routine_detail.png`), `docs/specs/README.md` (fila
  014: estado **✅** y decisiones clave).
- **Criterio de aceptación**:
  - Goldens revisados visualmente tras `--update-goldens` (solo diffs
    esperados).
  - `pubspec.yaml` sin dependencias nuevas.
  - `flutter test` completo en verde (~572 tests + los nuevos).
  - `flutter analyze` sin incidencias.
  - Fila 014 añadida/actualizada en `docs/specs/README.md`.
- **Cierre**: `flutter test` + `flutter analyze` en verde. **Fin de la
  spec 014.**
