# Plan 015 — Ficha de información del ejercicio

Companion técnico de `spec.md`. Orden de ejecución en `tasks.md`.

## 1. Arquitectura de la solución

### 1.1 Flujo de datos

```
CatalogRepository / RoutineDetailView
        │  Exercise (del catálogo local)
        ▼
ExerciseInfoView ─────────────────────────────────────────────┐
        │                                                     │
        │  initState: gifCache.ensureCached(gifPath)          │
        │             → Future<File?> → Image.file            │
        │             fallback: thumbAsset → ThumbFallback    │
        │                                                     │
        ├─ WorkoutRepository.exerciseHistory(exerciseId,       │
        │       limit, offset)  ──► paginas de sesiones        │
        │                                                     │
        └─ ExerciseInfoStats (dominio puro, lib/domain/        │
                exercise_stats.dart):                          │
                · KPIs (e1RM, top set, volumen máx, series)    │
                · puntos por sesión (3 métricas)               │
                · delta de ventana y frecuencia media          │
                · RIR medio de una sesión                      │
                        │                                      │
                        ▼                                      │
        UI: badges + KPI grid + ExerciseProgressChart          │
            (CustomPainter) + cues + activación +              │
            historial paginado + CTA                           │
──────────────────────────────────────────────────────────────┘
```

- **Dominio puro** (sin Flutter): `exercise_stats.dart`. Recibe `LoggedSet`-
  like livianos (o records tipados propios) y devuelve structs; testeable
  sin base de datos ni widgets.
- **Data**: un único método nuevo en `WorkoutRepository` (patrón
  `previousSets()`): `exerciseHistory()` que pagina sesiones `finished`
  con las series del ejercicio. Sin tablas nuevas (RNF-6).
- **UI**: `ExerciseInfoView` (sustituye a `ExerciseDetailView`) +
  `ExerciseProgressChart` (widget+painter nuevos, patrón
  `weight_trend.dart`). El GIF sigue el patrón ya probado de
  `exercise_detail_view.dart` (`FutureBuilder` sobre
  `gifCache.ensureCached`).

### 1.2 Datos → secciones del mockup

| Sección del mockup | Fuente real | Nota |
|---|---|---|
| Context bar (volver / favorito / ⋮) | AppBar estándar | Favorito y ⋮ ocultos (fuera de alcance) |
| Título + badge «TIER S» | `exercises.name` | Tier omitido (sin dato) |
| Badges anatómicos | `equipment`, `bodyPart`, `target`, `secondaryMuscles` | `muscleLabel()` en español; target destacado |
| 1RM Estimado + ΔPR | `e1RM()` (Epley, `goals.dart`) sobre series del ejercicio | Chip PR = mejor − segundo mejor |
| Carga Máxima | serie de mayor `weightKg` no-warmup completada | Subtítulo `Top Set · N reps @ RIR` |
| Volumen Máx. | máximo de `setVolumeKg()` por sesión | Subtítulo «Récord en 1 sesión (N sets)» |
| Total Series | conteo de completadas no-warmup + nº de sesiones | — |
| Gráfico + ventana | puntos por sesión (3 métricas) | CustomPainter §7.9 |
| Delta Período / Frecuencia | dominio puro sobre la ventana | — |
| Biomecánica & Cues | `exercise_instructions` (es/en) | Ya existente; numeración 01, 02… |
| Distribución de activación | `target` + `secondaryMuscles` | Heurística 70/30 (Q-3) |
| Historial + tabla de series | `workout_sets` + `workout_exercises` + `workouts` | Paginado de 10; ★ = mejor e1RM histórico |
| CTA | `addExercise` / `startWorkout` | Sesión activa o nueva |
| Descanso (conservado) | `exercises.restSeconds` | Stepper ±15 s, 15–300 (002) |

## 2. Ficheros a crear

| Ruta | Contenido |
|---|---|
| `lib/domain/exercise_stats.dart` | `ExerciseKpis`, `ExerciseSessionPoint`, `ExerciseSessionSummary`, `exerciseKpis(...)`, `exerciseProgressPoints(...)`, `periodDelta(...)`, `weeklyFrequency(...)`, `sessionRirMean(...)` — reutiliza `e1RM`, `setVolumeKg`. |
| `lib/ui/views/exercise_info_view.dart` | `ExerciseInfoView`: context bar, GIF/miniatura, badges, descanso, KPIs, gráfico, cues, activación, historial, CTA. |
| `lib/ui/widgets/exercise_progress_chart.dart` | `ExerciseProgressChart` + `CustomPainter` (línea, área, guías punteadas, punto final; estado vacío con < 2 puntos). |
| `test/exercise_stats_test.dart` | Dominio: KPIs, puntos, delta, frecuencia, casos límite. |
| `test/exercise_history_test.dart` (o ampliar `workout_repository_test.dart`) | Paginación, orden, exclusión de active/abandoned, warmups. |
| `test/exercise_info_view_test.dart` | Vista completa: GIF con caché inyectada, fallbacks, KPIs, filtros del gráfico, historial, CTA. |
| `test/exercise_progress_chart_test.dart` | Render, estado vacío, `shouldRepaint`, golden `test/goldens/exercise_progress_chart.png`. |

## 3. Ficheros a modificar

| Ruta | Cambio |
|---|---|
| `lib/data/repositories/workout_repository.dart` | `exerciseHistory({exerciseId, limit, offset})` → `List<ExerciseSessionSummary>` (join de las 3 tablas, `status = finished`, `endedAt desc`, offset/límite). |
| `lib/ui/views/catalog_view.dart` | Navegación a `ExerciseInfoView` (antes `ExerciseDetailView`). |
| `lib/ui/views/routine_detail_view.dart` | Ídem. |
| `docs/specs/README.md` | Fila 015 («en curso» → ✅ al cierre). |
| `docs/designer.md` | §13: fila «Ficha de información del ejercicio» apuntando a `informacion_del_ejerccios/`; §7.15 componente nuevo (tarjeta de KPI 2×2 + historial condensado) si se considera necesario. |

- `lib/ui/views/exercise_detail_view.dart`: **se retira del flujo** (los
  entry points usan la nueva vista). Si Q-1 decide convivencia, se
  mantiene sin cambios; si sustitución total, se elimina en la tarea de
  cierre (decisión registrada en tasks.md).
- `test/exercise_detail_view_test.dart`: se reorienta a la nueva vista o
  se elimina junto con el fichero (según Q-1).

## 4. Decisiones de implementación clave

1. **Consulta paginada única**:

   ```dart
   Future<List<ExerciseSessionSummary>> exerciseHistory({
     required String exerciseId,
     required int limit,
     int offset = 0,
   });
   ```

   `ExerciseSessionSummary`: `workoutId`, `name`, `endedAt`, `volumeKg`,
   `sets` (lista de `ExerciseSetRow`: `orderIndex`, `setType`,
   `weightKg`, `reps`, `rir`, `e1rm`), `rirMean`. Solo `status =
   'finished'` y `endedAt != null`; `warmup` incluida en la tabla (marcada
   «(Cal.)»), excluida de volumen/KPIs.

2. **KPIs y puntos en dominio puro**: `exerciseKpis` devuelve
   `bestE1rm + achievedAt + secondBestE1rm` (para el chip PR),
   `topSet` (peso, reps, rir), `maxSessionVolume + setCount`,
   `totalSets + sessionCount`. `exerciseProgressPoints` agrupa por
   sesión y métrica (`e1rm | load | volume`). Todo con el mismo criterio
   de `personalRecords()`: completadas, sin warmups, `reps <= 12` para
   e1RM.

3. **KPIs y gráfico comparten la primera página**: la vista carga la
   primera página del historial (10 sesiones) para la tarjeta más
   reciente; los KPIs y el gráfico usan agregados del dominio sobre el
   historial del ejercicio. Para no cargar todo el historial en la UI,
   el dominio acepta las series ya fetcheadas; **supuesto (Q-5
   relacionado)**: se fetchan las series del ejercicio de la ventana «Todo»
   de forma paginada progresiva (páginas de 50 sesiones) solo para KPIs y
   gráfico, o bien se limita la ventana máxima a 1A en v1. Decisión de
   implementación: ventana de agregados limitada a las últimas 50
   sesiones / 1 año, y «Todo» itera páginas (máx. 5) al selector.
4. **GIF**: mismo patrón que la ficha actual — `Future<File?>` en
   `initState` con `gifCache.ensureCached`, `FutureBuilder` con
   `Image.file` y fallback miniatura/`ThumbFallback` (RF-2, RNF-1). Sin
   `CachedNetworkImage` ni dependencias nuevas.

5. **Gráfico**: `ExerciseProgressChart(points, height)` con painter
   propio; guías horizontales con valores min/máx redondeados, eje
   temporal con 4 etiquetas (inicio, mitad, fin «Hoy (valor)»), punto
   final destacado. Selector de métrica (3 pills) y ventana (5 pills)
   viven en la vista; estado local con `setState` (sin Riverpod).

6. **CTA**: bottom bar sticky con botón primario blanco 48 dp (designer
   §7.1). `onPressed`: `watchActiveWorkout` ya resuelto en la vista → si
   hay activa, `addExercise(workoutId, exerciseId)` + snackbar «¡Añadido
   a la sesión!»; si no, `startWorkout()` + `addExercise` + snackbar
   «Sesión iniciada con el ejercicio».

7. **Activación muscular**: barra segmentada con `Row` de `Expanded`
   flex = pesos; target 70 %, secundarios 30 % repartidos; leyenda con
   puntos de color (grises/tonos del tema, sin colores saturados, designer
   §2.5). `muscleLabel()` para el texto.

8. **Fechas y unidades**: `DateTime` local, «Hace N días/meses» con
   formato ya usado en la app; pesos con `displayWeightKg` +
   `weightUnitOf(UnitSystemScope.of(context))`.

## 5. Estrategia de tests

### Unit (dominio puro y repo con `NativeDatabase.memory()`)
- `exercise_stats_test.dart`:
  - KPIs con y sin datos; e1RM excluye warmups, incompletas y `reps > 12`;
    chip PR solo con segundo mejor; top set por peso; volumen máximo por
    sesión; conteos.
  - Puntos por métrica y ventana; un punto no rompe; delta con primero 0;
    frecuencia con 0 sesiones (sin NaN).
  - `sessionRirMean` con RIRs nulos.
- `workout_repository_test.dart` (ampliar): `exerciseHistory` pagina,
  ordena `endedAt desc`, ignora sesiones active/abandoned, solo series
  del `exerciseId` pedido.

### Widget
- `exercise_info_view_test.dart`:
  - Abre con ejercicio sin historial → KPIs «—», gráfico vacío,
    historial vacío, CTA visible.
  - Con historial (BD en memoria sembrada) → KPIs con valores, tabla de
    la sesión más reciente con «(Cal.)» y ★, «Cargar sesiones
    anteriores» que pagina.
  - `GifCache` inyectada con descargador fake que devuelve bytes →
    `Image.file` se pinta; descargador que falla → miniatura local;
    sin credenciales → miniatura local.
  - Cambiar métrica/ventana redibuja (puntos del painter o texto de
    insights).
  - CTA: con sesión activa solo añade (1 workout activo tras el tap);
    sin sesión activa crea una.
  - Descanso ±15 s sigue funcionando (claves existentes).
- `exercise_progress_chart_test.dart`: render con 2+ puntos; estado
  vacío con 0/1; `shouldRepaint`; golden.

### Goldens
- Nuevo: `test/goldens/exercise_progress_chart.png`.
- Regenerar si procede: `routine_detail.png` (T-002 puede afectar al
  contenido de la tarjeta de ejercicio del detalle de rutina — revisar).

### Cierre obligatorio por tarea
```bash
flutter test
flutter analyze
```
Ambos en verde antes de pasar a la siguiente tarea (AGENTS.md).
