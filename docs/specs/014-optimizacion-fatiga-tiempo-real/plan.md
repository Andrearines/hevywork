# Plan 014 — Optimización, fatiga en tiempo real y miniaturas

Companion técnico de `spec.md`. Orden de ejecución en `tasks.md`.

## 1. Arquitectura de la solución

### 1.1 Flujo de eventos de fatiga (bloque B)

```
escritura en workout_sets / workouts
        │  (drift tableUpdates: repositorio, sync, editor pasado)
        ▼
FatigueNotifier  ── debounce 750 ms, coalescing ──► fatigueRepository.recalculate()
        │                                              │  · incluye sesión 'active'
        │ flush() ← cierre sesión / sync               │  · escritura por diff (RF-6)
        │ markDirty() ← edición registro pasado        ▼
                                          tabla drift muscle_fatigue
                                                    │ watch()
        ┌───────────────────────────────────────────┤
        ▼                                           ▼
live_fatigue_section (sesión en vivo)      progress_view._FatigueSection
        └────────── watchFatiguePanel() ───┘  (fatiga + zonas 7 d + tendencia 14 d)
                         │
              combineLatest2 propio (lib/data/util/combine_latest.dart)
```

- **Dominio puro** (sin Flutter): `muscle_fatigue.dart` (ya existe, sin
  cambios de cálculo) + `fatigue_trend.dart` (nuevo: serie diaria de
  fatiga de los últimos 14 días). Testeable sin widgets ni Supabase (§6).
- **Data**: `FatigueRepository` gana `ensureFresh()`, escritura diff,
  inclusión de la sesión activa y `watchFatiguePanel()`.
  `CatalogRepository` gana `exercisesByIds()`.
- **Coordinación**: `FatigueNotifier` (use case Observer) enlaza eventos de
  tablas con el recálculo. Vive en `domain/use_cases/` siguiendo el
  precedente de `workout_manager.dart` (que ya importa `data/`), pero es
  Dart puro: recibe `sources` y `recalculate` por inyección → test sin
  base de datos.
- **UI**: `live_workout_view` monta `LiveFatigueSection` (mapa + zonas +
  gráficas, plegable) con **un** `StreamBuilder` de `watchFatiguePanel()`;
  `progress_view` reemplaza su `StreamBuilder<Map<String,double>>` +
  `Future<List<MuscleZoneStats>>` por el mismo panel.

### 1.2 Miniaturas en el editor (bloque A)

```
catalogRepository.exercisesByIds(ids) ─► Map<String, Exercise>
        │ carga al abrir / al elegir ejercicio
        ▼
_DraftExercise.exercise (ref. en memoria, no persistida)
        ▼
_draftTile: ExerciseThumb(44) + ExerciseChips + nombre  (mismo estilo que en vivo)
```

`_ExerciseChips` se extrae de `live_workout_view.dart` a
`lib/ui/widgets/exercise_chips.dart` (widget público `ExerciseChips`) y se
usa en ambos sitios.

### 1.3 Gráficas (CustomPainter, sin dependencias)

| Widget | Painter | Datos | Patrón de referencia |
|---|---|---|---|
| `ZoneVolumeChart` | barras horizontales, top 6 zonas, guías punteadas | `List<MuscleZoneStats>` | `weight_trend.dart` (`shouldRepaint` por contenido) |
| `FatigueTrendChart` | sparkline 0–1, área con gradiente, punto final | `List<FatigueTrendPoint>` (14 d) | designer §7.9 |

## 2. Ficheros a crear

| Ruta | Contenido |
|---|---|
| `lib/domain/fatigue_trend.dart` | `FatigueTrendPoint`, `kFatigueTrendDays = 14`, `fatigueTrend({sets, days, now, muscle})` — evalúa `muscleFatigue` por día. |
| `lib/domain/use_cases/fatigue_notifier.dart` | `FatigueNotifier`: `markDirty()`, `flush()`, `dispose()`; `delay` configurable; fuentes inyectadas. |
| `lib/data/util/combine_latest.dart` | `combineLatest2`/`combineLatest3` propios (StreamController + último valor por fuente). |
| `lib/ui/widgets/exercise_chips.dart` | `ExerciseChips` (extraído de `_ExerciseChips`). |
| `lib/ui/widgets/zone_volume_chart.dart` | `ZoneVolumeChart` + painter interno. |
| `lib/ui/widgets/fatigue_trend_chart.dart` | `FatigueTrendChart` + painter interno. |
| `lib/ui/widgets/live_fatigue_section.dart` | `LiveFatigueSection`: cabecera plegable, `MuscleMap`, lista de zonas (top), las dos gráficas, estados vacíos. |
| `test/fatigue_trend_test.dart` | Dominio puro de la tendencia. |
| `test/fatigue_notifier_test.dart` | Debounce, coalescing, flush, dispose (delay corto, sin BD). |
| `test/combine_latest_test.dart` | Emisión de última combinación, cancelación, errores. |
| `test/live_fatigue_section_test.dart` | Sección: render, plegado, actualización al completar serie (DB en memoria, debounce corto). |
| `test/zone_volume_chart_test.dart` | Render + `shouldRepaint` + golden. |
| `test/fatigue_trend_chart_test.dart` | Render + `shouldRepaint` + golden. |
| `test/goldens/zone_volume_chart.png` | Golden nuevo. |
| `test/goldens/fatigue_trend_chart.png` | Golden nuevo. |

## 3. Ficheros a modificar

| Ruta | Cambio | Bloque/hallazgo |
|---|---|---|
| `lib/data/repositories/catalog_repository.dart` | `exercisesByIds(List<String>) → Map<String, Exercise>` (una consulta `isIn`). | A |
| `lib/ui/views/routine_editor_view.dart` | Hidratar `Exercise` al cargar/añadir; `_draftTile` con `ExerciseThumb` 44 + `ExerciseChips` + nombre. | A |
| `lib/data/repositories/fatigue_repository.dart` | Incluir sesión `active` (`endedAt ?? startedAt`); escritura diff en `recalculate()`; `ensureFresh()`; `watchFatiguePanel()` con `combineLatest2`. | B, H6 |
| `lib/main.dart` | Global `fatigueNotifier`, suscripción a `tableUpdates(workout_sets)` y `tableUpdates(workouts)`; `onSyncCompleted → flush()`. | B |
| `lib/ui/views/live_workout_view.dart` | `LiveFatigueSection` como sliver tras `_progressionStrip`; cierre de sesión → `fatigueNotifier.flush()`; H1, H2, H3, H4. | B, H1–H4 |
| `lib/ui/views/past_workout_editor_view.dart` | `recalculate()` → `fatigueNotifier.markDirty()`. | B |
| `lib/ui/views/progress_view.dart` | Apertura → `ensureFresh()`; `_FatigueSection` por `watchFatiguePanel` (fin de `didUpdateWidget`/`FutureBuilder`); añade las dos gráficas. | B, H6 |
| `lib/ui/widgets/exercise_thumb.dart` | `MediaQuery.devicePixelRatioOf(context)`. | H5 |
| `lib/ui/widgets/muscle_map.dart` | Memoizar `buildMuscleColors` + intensidades por entradas (StatefulWidget con caché en `didUpdateWidget`, o helper con caché). | H8 |
| `lib/ui/views/exercise_detail_view.dart` | `Image.asset` con `cacheWidth`/`cacheHeight` por ratio. | H9 |
| `lib/ui/views/routines_view.dart` | Coalescer: las 7 suscripciones llaman a una sola reconstrucción por frame (helper testeable en el propio fichero o en `lib/ui/util/`). | H7 |
| `README.md` | Reescritura completa en español (apartados de la RF-21). | E |
| `docs/specs/README.md` | Fila de la spec 014 («en curso» → «✅» al cierre). | F |

## 4. Decisiones de implementación clave

1. **`FatigueNotifier` puro y testeable**:

   ```dart
   FatigueNotifier({
     required List<Stream<void>> sources,   // tableUpdates de workout_sets y workouts
     required Future<void> Function() recalculate,
     Duration delay = const Duration(milliseconds: 750),
   })
   ```

   Cada emisión reinicia el temporizador; `flush()` cancela y ejecuta
   (deduplicando si ya hay un recálculo en vuelo); `dispose()` cancela
   suscripciones y temporizador. `main.dart` lo crea tras
   `fatigueRepository` y antes que `workoutRepository`.

2. **Inclusión de la sesión activa** en `_setsOf`/consultas de
   `recalculate()` y `weeklyZoneStats()`: `status.isIn(['finished',
   'active'])` y `endedAt ?? startedAt` como fecha. `_setsOf` deja de
   descartar filas con `endedAt == null` (usa el fallback).

3. **Escritura diff**: comparar filas actuales de `muscle_fatigue` con el
   nuevo mapa; upsert de diferencias y borrado de ausentes, todo en la
   misma transacción. Filas idénticas no se tocan (conservan
   `computedAt` y no emiten).

4. **`watchFatiguePanel()`**: `combineLatest2(watchFatigue(), join de
   workouts/sets/exercises de 7 días + muscle_fatigue → zonas + tendencia
   14 d)` → `({fatigue, zones, trend})`. Sin `rxdart` ni `package:async`
   (RNF-3): helper propio.

5. **`ensureFresh({Duration maxAge = 30 min})`**: `max(computed_at)` de la
   tabla; null o más viejo que `maxAge` → `recalculate()` en background;
   de lo contrario no hace nada. Sustituye al recálculo de la apertura de
   Progreso.

6. **Eventos de series en vivo**: al confirmar/desconfirmar serie el
   repositorio escribe `workout_sets` → `tableUpdates` → notifier. No hay
   cableado UI→notifier (una sola fuente de verdad), y el sync también
   queda cubierto.

7. **Sección en vivo**: `SliverToBoxAdapter(child: LiveFatigueSection())`
   justo después de `_progressionStrip()`; desplegada por defecto; al
   plegar queda una cabecera con la zona más cargada. Un único
   `StreamBuilder<FatiguePanel>`; mapas y gráficas dentro de
   `RepaintBoundary` (ya lo hace `MuscleMap`).

8. **H4**: combinar `_workout`, `_exercises` y `_sets` con
   `combineLatest3` en `initState`; el `StreamBuilder` resultante solo
   renderiza. Se hace en la tarea de H4 (T-011), después de montar la
   sección de fatiga (T-006) para no reescribir el mismo código dos veces.

9. **H2**: en `initState`, suscripción a `_workout` que guarda
   `_startedAt`/`_currentWorkout` y dispara `_loadPrevious()` y
   `_refreshSuggestions()` (con sus banderas `_previousLoaded`/
   `_suggestionsScheduled` intactas) vía `addPostFrameCallback`. `build()`
   solo lee estado.

10. **Sin esquema nuevo**: cero migraciones drift y cero migraciones
    Postgres (constitución §5 sin cambios que hacer).

## 5. Estrategia de tests

### Unit (dominio puro y repos con `NativeDatabase.memory()`)
- `fatigue_trend_test.dart`: pico diario 0–1, ventana de 14 días,
  músculo concreto vs global, series futuras, vacío.
- `fatigue_notifier_test.dart`: N eventos seguidos → 1 recálculo tras el
  delay; `flush()` inmediato y cancela el pendiente; eventos durante un
  recálculo en vuelo; `dispose()` sin fugas. Delay de 10–20 ms en test.
- `combine_latest_test.dart`: emite combinaciones con el último valor de
  cada fuente, cancelación limpia, fuente que termina.
- `fatigue_repository_test.dart` (ampliar el existente): recálculo con
  sesión `active` incluida (fecha `startedAt`); diff sin cambios no escribe
  (computa `computedAt` intacto); `ensureFresh()` no recalcula con caché
  fresca y sí con vieja; `watchFatiguePanel()` emite al cambiar series o
  caché.
- `catalog_repository_test.dart` (ampliar): `exercisesByIds` con ids
  parciales/duplicados/desconocidos.
- `muscle_fatigue_test.dart`: sin cambios de dominio — se mantiene en
  verde como red de seguridad.

### Widget (pantallas)
- `routine_editor_view_test.dart` (ampliar): el tile muestra miniatura
  (`find.byType(ExerciseThumb)`) al cargar y al añadir; fallback sin
  `imagePath`; chips visibles.
- `live_fatigue_section_test.dart` / `live_workout_view_test.dart`
  (ampliar): la sección renderiza y está desplegada; al completar una serie
  (con delay corto + `pumpAndSettle`) la fatiga del mapa/zonas cambia;
  plegar/desplegar conserva datos.
- `progress_view_test.dart` (ampliar): al cambiar el caché
  `muscle_fatigue` la sección se actualiza por stream; abrir Progreso con
  caché fresca no fuerza recálculo (spy/contador sobre
  `FatigueRepository.recalculate` o `ensureFresh` con reloj controlado);
  tocar el mapa no relanza la recarga de zonas (conteo de lecturas).
- Tests de regresión por hallazgo (uno por tarea C), p. ej. escribir en el
  campo RIR actualiza el chip sin romper la fila (H1), la ficha decodifica
  la imagen (H9), etc.

### Goldens
- Nuevos: `zone_volume_chart.png`, `fatigue_trend_chart.png`.
- Regenerar si la UI cambia: `progress_empty.png` (T-007),
  `muscle_map_front/back/empty.png` (T-014 debe ser visualmente neutro —
  el golden lo demuestra), `routine_detail.png` solo si T-001 lo afecta.
  Comando: `flutter test --update-goldens test/<archivo>_test.dart` y
  revisión visual del diff.

### Cierre obligatorio por tarea
```bash
flutter test
flutter analyze
```
Ambos en verde antes de pasar a la siguiente tarea (constitución §6).
