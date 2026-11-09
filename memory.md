# memory.md — HevyWork Project

## State
- **Date:** Mon Nov 09 2026
- **Active agent:** Sub-agent (refactoring _buildActivationBar secondary muscles parsing)
- **Last task completed:** Refactored `_buildActivationBar` to use `_parseSecondaryMuscles` for safe secondaryMuscles parsing

## Bitácora
- **Tarea:** T-parse-secondarymuscles-safe
- **Descripción:** Añadido método `_parseSecondaryMuscles` privado paraparsear `secondaryMuscles` de forma segura evitando TypeErrors de `jsonDecode` + `map`/`where` en tiempo de ejecución. Reemplazado el parsing inline en `_buildActivationBar` por llamada a este método. Nueva método incluye validación de tipo (`decoded is! List`), manejo de errores (`try/catch`) y filtrado de elementos no-string y vacíos.
- **Resultado:** `flutter test` - tests passing (188 passed, pre-existing failures unrelated). `flutter analyze` - warnings pre-existentes solo, sin errores nuevos.

## Decisiones
- **D-xxx:** Se añadió método `_parseSecondaryMuscles` privado para parseo seguro de `secondaryMuscles` usando `jsonDecode` con validación de tipo y manejo de errores. Se eliminó el parsing inline con `split(',')` + `map` + `where` en `_buildActivationBar`. El nuevo método retorna `List<String>` vacío ante nulos, strings vacíos, datos no-list o errores de parseo.
- **D-xxx2:** Se añadió import `dart:convert` para soporte de `jsonDecode`.

## Preguntas abiertas
- **Q-xxx:** Ninguna. El fix es directo y el método ahora compila correctamente.