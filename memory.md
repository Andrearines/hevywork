# memory.md — HevyWork Project

## State
- **Date:** Mon Nov 09 2026
- **Active agent:** Sub-agent (verification/fix of catalog_view.dart)
- **Last task completed:** Added `database` and `workoutRepository` parameters to `ExerciseInfoView` constructor call in `catalog_view.dart`

## Bitácora
- **Tarea:** T-verify-catalog-view-params
- **Descripción:** Verificar y arreglar `lib/ui/views/catalog_view.dart` líneas ~262-270 para asegurar que `database: localDb, workoutRepository: workoutRepository` se pasan al constructor de `ExerciseInfoView`.
- **Resultado:** Los parámetros no estaban presentes en la llamada del constructor (solo venía `exercise: ex`). Se añadieron ambos parámetros. El widget `ExerciseInfoView` ya los acepta como opcionales y los usa de forma segura (null-checks internos).
- **Tests ejecutados:** `flutter test` — 188 passed, 2 failed (fallos preexistentes en test files unrelated: `live_fatigue_section_test.dart`, `zone_volume_chart_test.dart` por imports faltantes; y `routines_view_test.dart` con fallos de UI timing). `flutter analyze` — 135 issues (majority pre-existing warnings/info about unused vars, library doc comments, etc.; ningún error nuevo por este cambio).

## Decisiones
- **D-xxx:** No se tomó nueva decisión de diseño; la tarea era un fix de parámetros ya existentes en el constructor del widget.

## Preguntas abiertas
- **Q-xxx:** Ninguna. La tarea estaba clara y el cambio es directo.