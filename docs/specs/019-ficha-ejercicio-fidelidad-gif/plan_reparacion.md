# 019 — Ficha de ejercicio: reparación de navegación desde miniaturas + fidelidad/GIF

**Fecha:** 2026-11-09 · **Agente:** Planificador SDD (solo planificación, sin implementación)
**Estado:** 🔧 en reparación (la fila de `docs/specs/README.md:25` dice ✅ pero la carpeta `019-…/` no existía en disco al iniciar — ver R-6)

---

## 1. Problema reportado (verbatim)

> "cuando yo le doy a la miniatura de un ejercicio se muestra pero se muestra la anterior no la que creastes y no se pueda usar se mira un blur que no deja interacturar pero no sale la pantalla actualizada sale la antigua y eso blur"

Petición asociada: *«volverla a hacer y conectar con todas las miniaturas, las de entrenamiento en vivo y editor»*.

## 2. Diagnóstico confirmado (con evidencia)

### 2.1 Confirmaciones del coordinador

| # | Afirmación del coordinador | Veredicto | Evidencia |
|---|---|---|---|
| 1 | `ExerciseThumb` es solo visual (sin `GestureDetector` ni navegación) | ✅ **Confirmado** | `lib/ui/widgets/exercise_thumb.dart:8-41` — `StatelessWidget` que solo pinta `Image.asset`/`ThumbFallback` |
| 3 | `live_workout_view.dart:1399` (expandida) y `:1682` (colapsada) sin navegación | ✅ **Confirmado** | La colapsada está envuelta en `GestureDetector(onTap: expand)` en `:1665-1667` → tocar la miniatura **expande la tarjeta** en vez de navegar |
| 3 | `routine_editor_view.dart:720` sin navegación | ✅ **Confirmado** | `_draftTile` pinta `ExerciseThumb` dentro de un `Container` sin gesto |
| 3 | `routines_view.dart:1126-1144` (`_ExerciseThumbStrip`) sin navegación | ✅ **Confirmado** | `:1144` pinta `ExerciseThumb` sin gesto; call sites `:704` y `:1078` |
| 2 | `catalog_view.dart:262-270` navega pero **sin** `database`/`workoutRepository` | ✅ **Confirmado** | `:262-267` → `ExerciseInfoView(exercise: ex)` |
| 2 | `routine_detail_view.dart:341-353` está **CORRECTO** (pasa deps) | ❌ **CORREGIDO — está mal** | `:344-349` → `ExerciseInfoView(exercise: exercise)` **sin** `database` ni `workoutRepository` |
| 4 | Puede que `ExerciseDetailView` se use en algún punto | ❌ **Descartado en producción** | Solo queda el placeholder `lib/ui/views/exercise_detail_view.dart` y la aserción obsoleta `test/routine_detail_view_test.dart:199` (test en rojo) |

> **Corrección clave:** los **dos** puntos de entrada existentes de la ficha omiten dependencias (Q-012 en `memory.md:190` ya lo apuntaba). `routine_detail_view` **no** está correcto.

### 2.2 Causas raíz adicionales encontradas (no estaban en el diagnóstico)

| ID | Hallazgo | Evidencia |
|---|---|---|
| H-1 | **El GIF nunca se carga.** `_gifFile` se inicializa a `null` y **nunca** se asigna: `gifCache.ensureCached` no se invoca en ningún fichero de `lib/` (grep: solo existe la clase y su instanciación en `main.dart:121`). La ficha muestra siempre la miniatura JPG local escalada a 220 dp → **imagen pixelada/«borrosa»** | `exercise_info_view.dart:37,57,247-260,264-272`; `lib/data/repositories/gif_cache.dart:31`; `lib/domain/media.dart:13` (`gifUrl`) |
| H-2 | **CTA muerto cuando faltan dependencias.** `onTap` hace `if (workoutRepo == null) return;` → el botón «Añadir a Rutina o Iniciar Sesión» **no hace nada** (ni snackbar). Igual `_loadSteps`, `_loadInitialHistory` y `_listenActiveWorkout`: guards `if (widget.database/workoutRepository == null) return` → sin pasos, sin historial, sin KPIs, sin sesión activa | `exercise_info_view.dart:63,90,1228-1229,1314-1316` |
| H-3 | **El «blur» tiene dos fuentes verificables:** (a) el CTA **flotante con `BackdropFilter(blur 8)`** que existe en el commit `HEAD` (`git show HEAD:lib/ui/views/exercise_info_view.dart:1217`, fiel al mockup `code.html` «backdrop-blur-md») — si el build en el móvil es el commiteado/instalado, el usuario ve **la pantalla antigua con ese blur** y un botón que no responde (H-2); (b) el área de media con el JPG 48 px escalado (H-1) se ve **desenfocada** | diff `git diff lib/ui/views/exercise_info_view.dart` (+472/−385 **sin commitear**); `code.html:350-356` |
| H-4 | **«Muestra la anterior / no la actualizada»:** con H-5 (abajo) el toque **no navega** → el usuario sigue viendo la pantalla anterior; si además el build está desactualizado (H-3a), ve la versión vieja de la ficha | `live_workout_view.dart`, `routine_editor_view.dart`, `routines_view.dart` (sin `onTap`) |
| H-5 | **La spec 016 ya planificó esto (Bloque G, RF-16, D-028) y nunca se implementó**: `docs/specs/016-mejoras-entrenamiento-vivo/plan.md:185-210` describe el `GestureDetector` en los tres puntos y `tasks.md` de la 016 **no contiene** ninguna tarea de miniaturas | `docs/specs/016-…/plan.md:185-210,292-293,307-308` |
| H-6 | **Estado del árbol de trabajo inestable:** `exercise_info_view.dart` modificado sin commitear (reescritura grande), `memory_dump.md` sin trackear, y 6 tests de `test/exercise_info_view_test.dart` en rojo (pasos ES/EN, historial, lb, overflow 375 dp, snackbar G35) | `git status`; `memory_dump.md:1-46` |

### 2.3 Mapeo síntoma → causa

| Síntoma del usuario | Causa |
|---|---|
| «al dar a la miniatura no sale la pantalla / sale la antigua» | H-4 + H-5 (4 puntos de entrada sin navegación; en la tarjeta colapsada el toque **expande**) |
| «no se puede usar» | H-2 + §2.1 fila 2 (deps no pasadas → CTA, historial, KPIs y cues mudos) |
| «se mira un blur que no deja interactuar» | H-3a (CTA con blur del build viejo que no responde) y/o H-3b (JPG escalado = media borrosa) |
| «no la que creastes» | H-4 (se queda en la pantalla anterior) y/o build desactualizado (H-3a) — **requiere verificación en dispositivo (T-011)** |

## 3. Alcance de la reparación

- **(a)** Consolidar `ExerciseInfoView` con el orden pedido y fidelidad al mockup `docs/pantallas/informacion_del_ejerccios/code.html`: context bar → identidad → media → KPIs → gráfico → cues (+ activación) → historial → descanso → CTA flotante. *(El orden ya está en el working tree; falta: CTA flotante fiel, GIF real, ocultar botones «fuera de alcance», y dejar la suite en verde.)*
- **(b)** Conectar **todas** las miniaturas a `ExerciseInfoView(exercise: …, database: localDb, workoutRepository: workoutRepository)`.
- **(c)** Eliminar el residuo `ExerciseDetailView` (fichero + test obsoleto).
- **(d)** GIF con `gifCache.ensureCached` y fallback a miniatura local.

**Fuera de alcance:** navegación desde `exercise_picker.dart` (Q-020), rediseño de vistas distintas de la ficha, dependencias nuevas (RNF-1), migraciones (RNF-2).

## 4. Tareas

> Numeración **T-011…T-020** para no colisionar con las T-001…T-010 que `memory.md` atribuye al cierre de la 019 (que no existe en disco).

### T-011 · Reproducción y congelación del estado
**Archivos:** ninguno de `lib/` (solo lectura + notas en `memory.md`).
- **Given** el repo con el diff sin commitear de `exercise_info_view.dart`,
- **When** se ejecuta `flutter clean && flutter run` y se toca una miniatura en (1) sesión en vivo, (2) editor de rutinas, (3) lista de rutinas, (4) catálogo, (5) detalle de rutina,
- **Then** se registra en `memory.md` qué punto navega, cuál no, si el CTA responde, si el GIF aparece y **cuál de las hipótesis H-3a/H-3b/H-4 explica el «blur» y la «pantalla antigua»**, decidiendo además si el diff de `exercise_info_view.dart` se conserva (recomendado) o se revierte.
- **Criterio:** reproducido y clasificado el síntoma; sin dudas abiertas sobre H-3.

### T-012 · Fidelidad y consistencia de `ExerciseInfoView`
**Archivos:** `lib/ui/views/exercise_info_view.dart`, `test/exercise_info_view_test.dart`.
- **Given** la ficha abierta desde cualquier punto de entrada con dependencias,
- **When** se pinta,
- **Then** el orden es context bar (volver · «BASE DE DATOS / Detalle de Ejercicio») → identidad (h1 + badges) → media → KPIs 2×2 → gráfico → cues + activación → historial → descanso (+ idioma/atribución) → **CTA flotante** con contenedor `bg-surface/80 + backdrop-blur` y botón 48 dp/radio 8/`add_circle` 20 dp/literal «Añadir a Rutina o Iniciar Sesión» (mockup `code.html:16-33,350-356`); los iconos «favorito» y «más opciones» quedan **ocultos** (fuera de alcance 015/016) en vez de botones muertos `onPressed: () {}`; sin `BoxShadow`/`elevation`.
- **Criterio:** los 6 tests rojos de `memory_dump.md` quedan en verde (pasos ES/EN, historial, lb, overflow 375 dp, snackbar G35) y `flutter analyze lib/ui/views/exercise_info_view.dart` sin errores ni elementos sin usar.

### T-013 · GIF real con `gifCache.ensureCached` + fallback
**Archivos:** `lib/ui/views/exercise_info_view.dart`, `test/exercise_info_view_test.dart` (GifCache inyectada con descargador fake, patrón de la 015 `plan.md:179`).
- **Given** un ejercicio con `gifPath` y un `GifCache` con descargador inyectado,
- **When** se abre la ficha,
- **Then** `initState` llama a `gifCache.ensureCached(exerciseId: exercise.id, gifPath: exercise.gifPath!)`, el `FutureBuilder` pinta `Image.file` con `cacheWidth/cacheHeight` al tamaño del contenedor, y mientras carga (o si `ensureCached` devuelve `null` por sin red/sin ruta) se muestra la **miniatura local** (`_localMedia`) sin layout saltón.
- **Criterio (GWT):** Given descargador fake que devuelve bytes, When se asienta la animación, Then hay un `Image.file` en el árbol; Given descargador que lanza, Then se ve `ThumbFallback`/miniatura y no hay excepción.

### T-014 · Navegación en la sesión en vivo (ambas tarjetas)
**Archivos:** `lib/ui/views/live_workout_view.dart`, `test/live_workout_view_test.dart`.
- **Given** la sesión en vivo con la tarjeta expandida (`:1399`) y la colapsada (`:1682`),
- **When** se toca la miniatura,
- **Then** se hace `Navigator.push(ExerciseInfoView(exercise: …, database: localDb, workoutRepository: workoutRepository))` envolviendo **solo** `ExerciseThumb` en un `GestureDetector` (D-028: no se toca `exercise_thumb.dart`), y el gesto interno **gana en la arena** sobre el `GestureDetector` de expandir de la tarjeta colapsada (`:1665`), de modo que al volver la tarjeta sigue colapsada.
- **Criterio:** Given la colapsada, When se pulsa la miniatura, Then aparece `ExerciseInfoView` **y** la tarjeta no cambia de estado; Given la expandida, When se pulsa la miniatura, Then navega y los controles de series siguen funcionando tras volver.

### T-015 · Navegación en el editor de rutinas
**Archivos:** `lib/ui/views/routine_editor_view.dart`, `test/routine_editor_view_test.dart`.
- **Given** un tile de ejercicio con `draft.exercise != null` (`:720`),
- **When** se toca la miniatura,
- **Then** navega a `ExerciseInfoView` con `database: localDb` y `workoutRepository: workoutRepository`; con `draft.exercise == null` (`ThumbFallback`) el toque **no** navega ni crashea; el resto del tile (reordenar, quitar, añadir serie) conserva su comportamiento.
- **Criterio:** Given un draft con ejercicio, When tap en la miniatura, Then `find.byType(ExerciseInfoView)`; Given `ThumbFallback`, When tap, Then no se navega.

### T-016 · Navegación en la franja de miniaturas de rutinas
**Archivos:** `lib/ui/views/routines_view.dart`, `test/routines_view_test.dart`.
- **Given** `_ExerciseThumbStrip` (`:1144`) renderizando los primeros 4 ejercicios (+ contador «+N»),
- **When** se toca una miniatura,
- **Then** navega a `ExerciseInfoView` con dependencias; el contador `_MoreThumb` **no** navega; si la tarjeta de la rutina tiene su propio gesto de apertura, el gesto de la miniatura gana (no se abre la rutina a la vez).
- **Criterio:** Given la lista de rutinas, When tap en la miniatura nº1, Then `find.byType(ExerciseInfoView)` y **no** `RoutineDetailView`; los tests de franja existentes (`routines_view_test.dart:495,509` → `findsNWidgets(4)`) siguen en verde.

### T-017 · Corregir los dos puntos de entrada existentes (Q-012)
**Archivos:** `lib/ui/views/catalog_view.dart:262-267`, `lib/ui/views/routine_detail_view.dart:344-349`, `test/catalog_view_test.dart`, `test/routine_detail_view_test.dart`.
- **Given** el catálogo o el detalle de rutina,
- **When** se toca la fila/miniatura del ejercicio,
- **Then** el push pasa `database: localDb, workoutRepository: workoutRepository` (globales de `main.dart`, ya importados en ambas vistas).
- **Criterio:** Given cualquier entrada, When se abre la ficha, Then hay historial (`_historyLoaded == true`), KPIs con datos o «—», cues cargados y el **CTA responde** (snackbar) — es decir, el botón deja de ser «un blur que no deja interactuar».

### T-018 · Eliminar el residuo `ExerciseDetailView`
**Archivos:** `lib/ui/views/exercise_detail_view.dart` (borrar), `test/exercise_detail_view_test.dart` (borrar o mantener como nota), `test/routine_detail_view_test.dart:199` (cambiar a `ExerciseInfoView`).
- **Given** el repo,
- **When** se ejecuta `grep -rn "ExerciseDetailView" lib/ test/`,
- **Then** no hay coincidencias en producción y el test «la ficha del ejercicio abre su detalle completo (RF-38)» verifica `ExerciseInfoView` y pasa.
- **Criterio:** 0 usos; `flutter test test/routine_detail_view_test.dart` en verde.

### T-019 · Red de pruebas de la reparación (hereda Bloque G de la 016)
**Archivos:** `test/live_workout_view_test.dart`, `test/routine_editor_view_test.dart`, `test/routines_view_test.dart`, `test/catalog_view_test.dart`, `test/exercise_info_view_test.dart`.
- **Given** cada punto de entrada,
- **When** se ejecuta `flutter test`,
- **Then** existen tests que verifican: tap en miniatura → `ExerciseInfoView` + back (5 entradas); en la colapsada **no expande**; el CTA con dependencias responde (G34/G35); el GIF usa `ensureCached` con fallback; y los 6 tests rojos actuales están en verde.
- **Criterio:** matriz completa entrada → test (§6) sin huecos; `flutter test` sin fallos nuevos sobre el baseline (`memory_dump.md`).

### T-020 · Cierre: suite, docs y memory
**Archivos:** `memory.md`, `docs/specs/README.md:25`, `docs/specs/019-ficha-ejercicio-fidelidad-gif/{plan_reparacion.md}` (este archivo), opcional `spec.md`/`tasks.md`.
- **Given** T-011…T-019 completadas,
- **When** se ejecutan `flutter test` y `flutter analyze`,
- **Then** ambos sin errores nuevos, la fila 019 del README refleja el estado real (🔧 → ✅ solo al cerrar), `memory.md` registra diagnóstico, decisiones D-050… y preguntas Q-020…, y no queda ningún `{{placeholder}}`.
- **Criterio:** informe de cierre entregado al usuario con la matriz de trazabilidad.

## 5. Archivos a modificar (resumen)

| Archivo | Cambio |
|---|---|
| `lib/ui/views/exercise_info_view.dart` | CTA flotante fiel, GIF con `ensureCached`, ocultar botones fuera de alcance, dejar suite en verde (T-012, T-013) |
| `lib/ui/views/live_workout_view.dart` | `GestureDetector` en ambas miniaturas + push con deps (T-014) |
| `lib/ui/views/routine_editor_view.dart` | Ídem en `_draftTile` (T-015) |
| `lib/ui/views/routines_view.dart` | Ídem en `_ExerciseThumbStrip` (T-016) |
| `lib/ui/views/catalog_view.dart` | Pasar `database`/`workoutRepository` (T-017) |
| `lib/ui/views/routine_detail_view.dart` | Pasar `database`/`workoutRepository` (T-017) |
| `lib/ui/views/exercise_detail_view.dart` | **Borrar** (T-018) |
| `test/routine_detail_view_test.dart` | `ExerciseDetailView` → `ExerciseInfoView` (T-018) |
| `test/exercise_info_view_test.dart` | Reparar 6 rojos + tests de GIF/CTA (T-012, T-013, T-019) |
| `test/live_workout_view_test.dart`, `test/routine_editor_view_test.dart`, `test/routines_view_test.dart`, `test/catalog_view_test.dart` | Tests de navegación (T-019) |
| `docs/specs/019-ficha-ejercicio-fidelidad-gif/plan_reparacion.md`, `memory.md`, `docs/specs/README.md` | Documentación (T-020) |

**No se tocan:** `lib/ui/widgets/exercise_thumb.dart` (compartido; D-028), `pubspec.yaml` (RNF-1), esquemas/migraciones (RNF-2).

## 6. Matriz de trazabilidad punto de entrada → tarea → criterio

| Punto de entrada | Línea | Hoy | Tarea | Criterio |
|---|---|---|---|---|
| Catálogo | `catalog_view.dart:262` | navega **sin deps** | T-017 | ficha con datos + CTA responde |
| Detalle de rutina | `routine_detail_view.dart:344` | navega **sin deps** | T-017 | ídem |
| Vivo · tarjeta expandida | `live_workout_view.dart:1399` | sin navegación | T-014 | tap → ficha con deps |
| Vivo · tarjeta colapsada | `live_workout_view.dart:1682` | tap **expande** | T-014 | tap → ficha, **sin** expandir |
| Editor de rutinas | `routine_editor_view.dart:720` | sin navegación | T-015 | tap → ficha; fallback no navega |
| Lista de rutinas (franja) | `routines_view.dart:1144` | sin navegación | T-016 | tap → ficha; «+N» no navega |
| Picker de ejercicios | `exercise_picker.dart:195` | **selección** (`pop`) | Q-020 | mantener selección (fuera de alcance) |

## 7. Riesgos

| Riesgo | Mitigación |
|---|---|
| En la colapsada, el `GestureDetector` de expandir gane en la arena y no navegue | Gesture interno sobre `ExerciseThumb` + test «navega y no expande» (016 §7) |
| El gesto de la miniatura "robe" el tap a la tarjeta de rutina en la lista | Test que verifica que **no** se abre `RoutineDetailView` al tocar la miniatura |
| Reparar la fidelidad rompa los tests de la 015/019 (textos, claves, orden) | Conservar claves `exercise-info-cta`, `rest-detail-*`, `history-load-more`; actualizar solo expectativas justificadas y revisarlas una a una |
| El diff sin commitear de `exercise_info_view.dart` se pierda o genere conflicto | T-011 decide conservarlo (recomendado) y commitear por tarea |
| GIF sin red rompe el layout | Fallback a miniatura mientras `ensureCached` corre y si devuelve `null` (H-1) |

## 8. Preguntas abiertas

- **Q-020:** ¿El picker de ejercicios (`exercise_picker.dart:195`, que hace `pop` con el ejercicio elegido) debe navegar a la ficha? **Propuesta: no** — rompería la selección; si se quiere, sería un icono aparte.
- **Q-021:** ¿Área tocable = solo la miniatura o también chips/nombre (hereda Q-013)? **Propuesta:** solo la miniatura en esta reparación.
- **Q-022:** ¿Conservar el diff sin commitear de `exercise_info_view.dart` (recomendado, ya trae el orden correcto) o revertir a `HEAD` y rehacer? Se resuelve en T-011.

## 9. Criterios de aceptación globales

1. **Given** cualquier miniatura de ejercicio en vivo, editor, lista de rutinas, catálogo o detalle de rutina, **When** se toca, **Then** se abre `ExerciseInfoView` del **ese** ejercicio con `database: localDb` y `workoutRepository: workoutRepository`.
2. **Given** la ficha abierta, **When** se pinta, **Then** el GIF se resuelve con `gifCache.ensureCached` (o fallback a miniatura sin saltos de layout), el orden de secciones es el del §3(a) y el CTA flotante **responde** con snackbar.
3. **Given** el repo, **When** se ejecutan `flutter test` y `flutter analyze`, **Then** sin errores nuevos y sin elementos sin usar; `grep ExerciseDetailView lib/ test/` → 0 coincidencias.
4. Sin dependencias nuevas, sin migraciones, sin `BoxShadow`/`elevation`.
