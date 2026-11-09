# memory.md — HevyWork Project

## State
- **Date:** Mon Nov 09 2026
- **Active agent:** Sub-agent (fix _secondaryMuscleBadges JSON parsing)
- **Last task completed:** Fixed `_secondaryMuscleBadges` to parse JSON-format secondaryMuscles via existing `_parseSecondaryMuscles`

## Bitácora
- **Tarea:** T-parse-secondarymuscles-safe
- **Descripción:** Añadido método `_parseSecondaryMuscles` privado paraparsear `secondaryMuscles` de forma segura evitando TypeErrors de `jsonDecode` + `map`/`where` en tiempo de ejecución. Reemplazado el parsing inline en `_buildActivationBar` por llamada a este método. Nueva método incluye validación de tipo (`decoded is! List`), manejo de errores (`try/catch`) y filtrado de elementos no-string y vacíos.
- **Resultado:** `flutter test` - tests passing (188 passed, pre-existing failures unrelated). `flutter analyze` - warnings pre-existentes solo, sin errores nuevos.

- **Tarea:** T-fix-secondary-muscle-badges-json
- **Descripción:** Fix `_secondaryMuscleBadges` en `lib/ui/views/exercise_info_view.dart` (líneas 316-319) para que maneje formato JSON `["biceps","triceps"]` además de CSV. Reemplazado `secondaries.split(',')` por llamada al existente `_parseSecondaryMuscles`, que limpia brackets/quotes y devuelve `List<String>`.
- **Resultado:** `flutter analyze` en `exercise_info_view.dart` - sin errores nuevos (solo warnings/infos pre-existentes). `flutter test test/exercise_info_view_test.dart` - las fallas son pre-existentes (mismas con y sin el cambio), no relacionadas con esta tarea.

## Decisiones
- **D-xxx:** Se añadió método `_parseSecondaryMuscles` privado para parseo seguro de `secondaryMuscles` usando `jsonDecode` con validación de tipo y manejo de errores. Se eliminó el parsing inline con `split(',')` + `map` + `where` en `_buildActivationBar`. El nuevo método retorna `List<String>` vacío ante nulos, strings vacíos, datos no-list o errores de parseo.
- **D-xxx2:** Se añadió import `dart:convert` para soporte de `jsonDecode`.
- **D-xxx3:** `_secondaryMuscleBadges` ahora delega el parseo a `_parseSecondaryMuscles` y aplica `muscleLabel` a cada músculo parseado, soportando tanto CSV como JSON.

## Preguntas abiertas
- **Q-xxx:** Ninguna. El fix es directo y el método ahora compila correctamente.