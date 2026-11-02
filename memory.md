# Memory — hevywork

**Last updated:** Sun Nov 01 2026

**Active agent:** Sub-agent (fix inyección workoutRepository en test de historial — Q-005)

## Last completed task

- **Task:** T-002 · Dominio sesión activa + tendencia de fatiga
- **Change**: 
  - Creado `lib/domain/fatigue_trend.dart` con la función `fatigueTrend({required List<ExerciseSetRow> sets, required int days, required DateTime now, String? muscle})` que evalúa la fatiga muscular por día (pico global o zona) con valores 0-1, devuelve lista vacía sin datos y series futuras no cuentan.
  - Modificado `lib/data/repositories/fatigue_repository.dart`:
    - `recalculate()`: ya incluye serie `active` (`status in ('finished','active')`, fecha `endedAt ?? startedAt`) y escritura diff por fatigue/raw cambiado.
    - `weeklyZoneStats()`: incluye series de sesión `active` fechadas por `startedAt`.
    - `watchFatiguePanel()`: método existente que retorna `FatiguePanel(fatigue, zones, trend)` vía `combine_latest.dart` propio.
    - `ensureFresh({Duration maxAge: 30min})`: método existente que si la caché está vieja → recalcula en background.
- **Result**: Las 8 pruebas de dominio `fatigue_trend_test.dart` y 13 pruebas de repositorio `fatigue_repository_test.dart` pasan en verde (`flutter test`). `flutter analyze` sin errores nuevos.
- **Tests**: `flutter test test/fatigue_trend_test.dart` → 8 pass / 0 fail. `flutter test test/fatigue_repository_test.dart` → 13 pass / 0 fail.

## Bitácora

| Date | Task | Change | Tests |
|------|------|--------|-------|
| 2026-11-01 | T-002: Dominio sesión activa + tendencia de fatiga | Creado `lib/domain/fatigue_trend.dart` con `fatigueTrend` usando `ExerciseSetRow`; modificado `lib/data/repositories/fatigue_repository.dart` con los métodos RF-8/RF-5 de la spec 014 | 8 pass/0 fail (dominio) + 13 pass/0 fail (repositorio); analyze limpio |

## Bitácora

| Date | Task | Change | Tests |
|------|------|--------|-------|
| 2026-11-01 | T-002: Dominio sesión activa + tendencia de fatiga | Creado `lib/domain/fatigue_trend.dart` con `fatigueTrend` usando `ExerciseSetRow`; modificado `lib/data/repositories/fatigue_repository.dart` con los métodos RF-8/RF-5 de la spec 014 | 8 pass/0 fail (dominio) + 13 pass/0 fail (repositorio); analyze limpio |
| 2026-11-01 | Q-005: inyección workoutRepository en test historial | `pumpView` pasa `workoutRepository: WorkoutRepository(localDb)`; helper `unmount` al final de cada test para drenar el timer de drift (patrón catalog_view_test) | 12 pass/0 fail; analyze limpio |
| 2026-11-01 | Bugfix: exercise_info_view null database | Guard clause `widget.database == null` en `_loadSteps()` + variable local no-null tras el guard | 5 pass/7 fail (idéntico con y sin fix; 7 fallos pre-existentes Q-005); analyze 7 issues pre-existentes |
| 2026-11-01 | T-001: Miniaturas en editor de rutinas | - Creado `lib/ui/widgets/exercise_chips.dart` (extraído `_ExerciseChips` de `live_workout_view.dart`)
- Modificado `lib/data/repositories/catalog_repository.dart`: agregado `exercisesByIds(List<String>) → Map<String, Exercise>` (una consulta `isIn`, tolera ids desconocidos/duplicados)
- Modificado `lib/ui/views/routine_editor_view.dart`: hidratación de `Exercise` por ids al cargar y al elegir desde el picker; `_draftTile` con `ExerciseThumb(44)` + `ExerciseChips` + nombre
- Modificado `lib/ui/views/live_workout_view.dart`: uso del público `ExerciseChips` en lugar del privado `_ExerciseChips`
- Actualizada prueba `test/routine_editor_view_test.dart` para pasar `catalogRepository` | `flutter test` + `flutter analyze` en verde (25 tests) |
| 2026-10-31 | T-008: Cierre spec 015 | Retired ExerciseDetailView, updated entry points to ExerciseInfoView, updated docs, placeholder goldens | 1 pass (detail view test), analyze clean |
| 2026-10-31 | T-002: Fix _loadSteps null check | Changed `localDb` reference to `widget.database!` in `_loadSteps()` function; verified steps, badges, language switching work | 5/7 tests pass (historial failures pre-existing, unrelated to this fix) |

## Decisiones D-xxx

- D-002: en `exercise_info_view_test.dart`, la suscripción a `watchActiveWorkout()` se desmonta con el helper `unmount` (patrón de `catalog_view_test.dart`) en vez de dejar que el binding desmonte el árbol al final del test (drift deja un timer pendiente y `db.close()` se cuelga)
- D-001: `exercise_info_view.dart` — manejar `database` null con guard clause temprano en `_loadSteps()` y local `final database = widget.database!` tras el guard, en vez de cambiar la firma del constructor (comportamiento con `database != null` intacto)
- T-008 ExerciseDetailView sustituida por ExerciseInfoView (Q-1 decisión confirmada)
- T-008 entry points en catalog_view y routine_detail_view actualizados
- T-008 no se añadieron dependencias nuevas
- T-008 docs/README.md y designer.md actualizados
- T-002 `_loadSteps` uses `widget.database!` instead of uninitialized `localDb` (decision confirmed)
- D-014: `CatalogRepository.exercisesByIds()` usa una sola consulta `isIn` en lugar de N consultas individuales (RF-3 / spec 014)
- D-015: `ExerciseChips` extraído a widget público para compartir entre vista en vivo y editor de rutinas (RF-3)
- D-016: `_draftTile` ahora muestra `ExerciseThumb(44)` + `ExerciseChips` + nombre, con fallback `ThumbFallback` cuando `imagePath` es nulo o roto
- D-017: `RoutineEditorView` recibe `CatalogRepository` como parámetro opcional con valor por defecto para compatibilidad

## Preguntas abiertas Q-xxx

- Q-1: resuelta (sustitución total) — constancia en T-008
- Q-005: resuelta 2026-11-01 — `workoutRepository` inyectado en `pumpView` + helper `unmount` para drenar el timer de drift; 12/12 tests en verde
- Q-006: ¿Se necesitan pruebas widget adicionales para `ExerciseThumb` en el editor (criterio: `find.byType(ExerciseThumb)` por tarjeta)?

---

**Next task:** Sin pendientes abiertos. Candidatos: correr `flutter test` completo para confirmar que nada más se afectó, o retomar la spec activa en `docs/specs/` (015 cerrada).
## Bugs de la spec 014 - Arreglados

### Bug 1: Fatiga mapa no se actualiza en tiempo real
**Causa:** El cache `muscleFatigue` solo se recalculaba en sync completion o al cerrar sesión, no durante el entrenamiento en vivo. El `FatigueNotifier` con debounce no estaba conectado al view.

**Solución:** Integrado `FatigueNotifier` en `_LiveWorkoutViewState` que escucha el stream `_sets` con debounce de 750ms (el mismo que `FatigueNotifier.defaultDelay`). Cada vez que se añade una serie, el notifier marca `dirty` y después del delay ejecuta `fatigueRepository.recalculate()`, actualizando el cache y propagando los cambios a través de `watchFatigue()` → `watchFatiguePanel()`.

### Bug 2: No se ven otros músculos/zones
**Causa:** En `ZoneVolumeChart`, los nombres de músculo se mostraban como claves brutas (`zone.muscle`) sin traducir al español mediante `muscleLabel`, lo que provocaba nombres en inglés o sin traducir en las gráficas.

**Solución:** Modificado `lib/ui/widgets/zone_volume_chart.dart` para importar y usar `mm.muscleLabel(zone.muscle)` en lugar de `zone.muscle` directo al pintar la etiqueta del nombre. Esto asegura nombres consistentes y traducidos (ej. "Cuádriceps" en lugar de "quadriceps").

### Bug 3: Nombres de músculos no se ven bien en gráficas
**Causa:** Mismo que Bug 2 - los nombres de músculo en las gráficas no pasaban por la función de traducción `muscleLabel`.

**Solución:** Ya corregido en el fix de Bug 2 - el `ZoneVolumeChart` ahora usa `muscleLabel` para mostrar nombres en español.

### Bug 4: App se cierra al tocar "Entendido" con varias recomendaciones
**Causa:** En `_progressionStrip()`, el `Row` usaba por defecto `mainAxisSize: MainAxisSize.max`, haciendo que el `Expanded` del texto ocupara todo el espacio restante, lo que provocaba que el botón "Entendido" se superpusiera o quedara sin espacio adecuado cuando había múltiples recomendaciones de peso.

**Solución:** Agregado `mainAxisSize: MainAxisSize.min` al `Row` en `_progressionStrip()` para que el row only ocupe el espacio que necesitan sus hijos, en lugar de llenar todo el ancho disponible. Esto permite que el botón "Entendido" tenga su tamaño natural sin conflictos.

