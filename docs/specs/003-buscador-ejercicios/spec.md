# Spec 003 — Buscador y filtros de ejercicios

## Contexto y objetivo
El catálogo de 1.324 ejercicios necesita búsqueda por nombre y filtros por
categoría, equipo, músculo y bodypart para que el usuario elija rápido en el
gimnasio. Todo en local, sin red.

## Usuarios
Mismo perfil.

## Historias de usuario
- H1: Como usuario quiero escribir "press" y ver solo los presses.
- H2: Como usuario quiero filtrar por "dumbbell" + "chest" y ver la
  intersección.
- H3: Como usuario quiero hacer scroll infinito sin que la UI se trabe.

## Requisitos funcionales (EARS)

### Búsqueda por nombre (H1)
- RF-1: CUANDO el usuario escribe ≥ 2 caracteres en el buscador, EL SISTEMA
  muestra ejercicios cuyo `name` contiene el texto (case-insensitive, acentos
  ignorados).
- RF-2: MIENTRAS el usuario escribe, EL SISTEMA actualiza resultados en
  < 100 ms (FTS5 en drift o `LIKE` con índice trigram si el volumen crece).

### Filtros combinados (H2)
- RF-3: EL SISTEMA expone chips/menús para: `body_part` (10 valores),
  `equipment` (28), `target` (19), `muscle_group` (29) y
  `secondary_muscles` (40). Múltiples selecciones = AND.
  - Decisión (aprobada): varios valores de una misma dimensión suman (OR);
    las dimensiones entre sí, y con la búsqueda por texto, se multiplican
    (AND). Un AND estricto dentro de una misma dimensión dejaría siempre
    0 resultados (p. ej. dos equipos a la vez).
- RF-4: CUANDO hay filtros activos, EL SISTEMA muestra contador de resultados
  y botón "Limpiar filtros".
- RF-6: EL SISTEMA muestra las opciones de filtro muscular **traducidas al
  español** y **fusiona los sinónimos del dataset** en una sola entrada, de
  modo que cada músculo aparece una sola vez; al elegirlo filtra por todos sus
  sinónimos crudos (amenda 2026-10-22).

### Scroll infinito (H3)
- RF-5: EL SISTEMA carga páginas de 50 ejercicios. Al llegar al 80 % del
  scroll, pide la siguiente página sin bloquear la UI.

## Requisitos no funcionales
- Búsqueda y filtros 100 % offline.
- Memoria < 20 MB para el catálogo completo en Dart.

## Casos límite
- Filtro con 0 resultados → mensaje "Prueba otros filtros".
- Cambio de filtro durante scroll → cancela petición anterior.

## Fuera de alcance
- Búsqueda semántica / embeddings.
- Favoritos / recientes (puede ir en 002 o 004).

## Criterios de finalización
- Tests de búsqueda + filtros + paginación.
- `flutter test` + `flutter analyze` verdes.

## Dudas abiertas
- Ninguna. Cerrada la semántica de selecciones múltiples (OR dentro de la
  dimensión, AND entre dimensiones y con la búsqueda).

## Ampliación 2026-10-22 — etiquetas en español y sinónimos fusionados (RF-6)

Petición del usuario (2026-10-22): unificar los nombres de músculo en español
en los filtros y corregir que los aductores se repetían.

### Decisiones

- **Fusión en la UI, no en el repositorio:** `filterOptions()` sigue
  devolviendo los valores crudos deduplicados (la 003 y sus tests no cambian).
  La traducción y la agrupación ocurren en `exerciseDimensionOptions`
  (`exercise_filter_bar.dart`), que envuelve cada músculo en un
  `DimensionOption(label, values)`.
- **Etiqueta = clave de fusión:** `muscleFilterLabel` traduce cada valor de
  `target`, `muscle_group` y `secondary_muscles` al español; los sinónimos
  comparten etiqueta (`lats`/`latissimus dorsi` → «Dorsales»,
  `deltoids`/`shoulders`/`rear deltoids` → «Hombros»,
  `groin`/`inner thighs`/`adductors` → «Aductores»). Las dimensiones no
  musculares (cuerpo, equipo) pasan sus valores tal cual.
- **Selección sobre valores crudos:** marcar una opción añade o quita todos
  sus sinónimos al `Set` de la dimensión, así que `_searchPredicate` (OR por
  valor) no cambia y el filtrado sigue siendo el de la 003.
- **Progreso en español:** la lista de zonas de `ProgressView` dejó de mostrar
  la doble línea inglés+español y ahora solo usa `muscleLabel` (español).