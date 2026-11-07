# Tareas 018 — Sección de fatiga invisible en la sesión en vivo

Orden de ejecución e iterables. **Cierre obligatorio de cada tarea**:
`flutter test` en verde + `flutter analyze` sin incidencias (AGENTS.md).
Si no pasa, la tarea no está terminada.

Restricciones transversales: sin dependencias nuevas (RNF-1), sin
migraciones (RNF-2), sin `elevation`/`BoxShadow` (RNF-3), código en inglés
y mensajes/docs en español (RNF-4), sin cambios de comportamiento en
`ViewToggle` ni en Progreso (RNF-7).

---

## T-001 · A — Cabecera sin flex sin acotar (fix de la causa raíz)
**RF-1, RF-2, RF-4 · Problema 1 y 3**

- **Objetivo**: eliminar la excepción
  «RenderFlex children have non-zero flex but incoming width constraints are
  unbounded» y que la cabecera se pinte en cualquier ancho.
- **Archivos**:
  - modificar `lib/ui/widgets/live_fatigue_section.dart` (líneas 97-124):
    envolver el `Text` del título en `Expanded` con `maxLines: 1` y
    `TextOverflow.ellipsis` (cierra D-031 de la 017); envolver el
    `ViewToggle` en `Flexible(child: FittedBox(fit: BoxFit.scaleDown, …))`
    (patrón de `progress_view.dart:496-504`, D-035).
  - modificar `lib/ui/widgets/view_toggle.dart`: **solo** doc comment en
    `ViewToggle` con el contrato (requiere ancho acotado; envolver en
    `Flexible` + `FittedBox`). Sin cambios de código (RNF-7, Q-017).
  - comprobación previa al fix (queda registrada en `plan.md` §1):
    `flutter test test/tmp_probe…` ya no existe; el test de T-002/T-003 es
    la reproducción permanente.
- **Criterios de aceptación (Given/When/Then)**:
  - Given `LiveFatigueSection` dentro de un `Scaffold` (contexto real de la
    sesión en vivo), When se pinta, Then `tester.takeException()` es null y
    `find.byType(ViewToggle)` encuentra 1 widget.
  - Given la cabecera renderizada, When se inspecciona el árbol, Then no
    existe ningún `Expanded` con ancho entrante infinito (el `ViewToggle`
    cuelga de `Flexible`/`FittedBox`).
  - Given un ancho de 320 dp con el título largo
    («Fatiga: Cuádriceps (85%)»), When se pinta, Then el título muestra
    elipsis en una línea, el toggle sigue visible y `takeException()` es
    null (sin `RenderFlex overflow`).
  - Given `pubspec.yaml`, Then sin dependencias nuevas y sin migraciones.
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-002 · B — Reparar `test/live_fatigue_section_test.dart` (D-033 pendiente)
**RF-6 · Problema 5 (test roto)**

- **Objetivo**: que vuelva a compilar y que cubra la cabecera (es el test
  del área que se toca y su fallo impedía el cierre en verde).
- **Archivos**:
  - reescribir `test/live_fatigue_section_test.dart`: sustituir
    `FatiguePanel(fatigue: …, zones: …, trend: …)` por **literales de
    record** `(fatigue: …, zones: …, trend: …)` (typedef de
    `fatigue_repository.dart:13`) y revisar los `find.text` contra el
    formato vigente de los chips (`músculo · N series · X kg`).
  - casos nuevos: (a) cabecera visible con `Fatiga muscular` y toggle, (b)
    tap en la cabecera colapsa el cuerpo y conserva la cabecera, (c) ancho
    320 dp sin excepción con título largo, (d) panel vacío → «Sin series» y
    «Sin fatiga», (e) chips formateados (sin `80.50000000000001`).
- **Criterios de aceptación (Given/When/Then)**:
  - Given el fichero, When se ejecuta `flutter analyze test/
    live_fatigue_section_test.dart`, Then 0 errores (hoy: 32).
  - Given `LiveFatigueSection` con panel y **desplegada** (por defecto), When
    se pinta, Then `find.text('Fatiga muscular')` y `find.byType(ViewToggle)`
    encuentran 1 widget cada uno y `takeException()` es null.
  - Given la sección, When pulso la cabecera, Then el cuerpo
    (`MuscleMap`) desaparece y la cabecera permanece.
  - Given un panel con `weeklyVolume = 80.50000000000001`, Then el chip no
    contiene ese artefacto.
  - Given la suite, Then este fichero pasa (regresión del D-033 cerrada).
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-003 · C — Sección siempre presente + test de regresión en vivo
**RF-1, RF-3, RF-7 · Problema 1**

- **Objetivo**: que la cabecera exista desde el primer frame de la sesión en
  vivo (aunque el panel aún no emite) y dejar un test que falle sin el fix.
- **Archivos**:
  - modificar `lib/ui/views/live_workout_view.dart:329-347`: eliminar el
    `if (!fatigueSnap.hasData) → SizedBox.shrink()` y pasar
    `panel: fatigueSnap.data` (nullable) a `LiveFatigueSection` (D-036).
  - ampliar `test/live_workout_view_test.dart`: test «la sección de fatiga
    está visible al abrir la sesión en vivo» que verifique
    `find.byType(LiveFatigueSection)` (onstage, `skipOffstage` por defecto),
    `find.text('Fatiga muscular')` y `tester.takeException() == null`,
    tras las bombas de `pumpView`.
  - ampliar el mismo test con el caso «panel aún sin emitir»: comprobar que
    la cabecera ya está pintada en el primer frame (RF-3).
  - (si se confirma en el baseline) corregir el `setUpAll` de
    `test/routines_view_test.dart:21-27`: falta
    `fatigueRepository = FatigueRepository(localDb);` → hoy revienta con
    `LateInitializationError` en `live_workout_view.dart:91` al construir
    `LiveWorkoutView`.
- **Criterios de aceptación (Given/When/Then)**:
  - Given una sesión en vivo recién abierta con el panel en `waiting`, When
    se pinta, Then la cabecera «Fatiga muscular» está en el árbol onstage y
    no se devuelve `SizedBox.shrink()` para esa sección.
  - Given la sesión con datos, When se pinta, Then `MuscleMap` está presente
    y `takeException()` es null (sin las 13 excepciones de layout que
    reproduce hoy el test).
  - Given el test nuevo, When se ejecuta **sin** el fix de T-001, Then falla
    (0 widgets + excepciones) → regresión efectiva.
  - Given `pubspec.yaml`, Then sin dependencias nuevas y sin migraciones.
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-004 · D — `dispose()` completo de `_LiveWorkoutViewState`
**RF-5 · Problema 4**

- **Objetivo**: cancelar lo que se crea en `initState` y activar el guard
  `_disposed`, para no dejar timers/suscripciones de drift abiertos (hoy
  `localDb.close()` se cuelga en `tearDownAll`).
- **Archivos**:
  - modificar `lib/ui/views/live_workout_view.dart`: añadir
    `@override void dispose()` en `_LiveWorkoutViewState` que haga
    `_disposed = true`, `WidgetsBinding.instance.removeObserver(this)`,
    `_clockTimer?.cancel()`, `_now.dispose()`,
    `_fatigueNotifier?.dispose()` y `_restNotifier.cancel()` (fire-and-forget,
    D-037).
  - ampliar `test/live_workout_view_test.dart`: caso de desmontaje con
    `unmount(tester)` al final de un test que use la vista (patrón D-002)
    que termine sin colgar.
  - comprobar que los guards `_disposed` de las líneas 265/272 pasan a ser
    efectivos (el flag ya se pone a true).
- **Criterios de aceptación (Given/When/Then)**:
  - Given la vista desmontada, When se ejecuta `dispose`, Then no quedan
    timers periódicos (`_clockTimer`) ni suscripciones del
    `FatigueNotifier` activas.
  - Given un test que abre y desmonta la sesión en vivo, When termina, Then
    `localDb.close()` en `tearDownAll` completa (sin timeout).
  - Given la suite completa, Then no aparecen nuevos fallos por `dispose`
    doble o `setState` tras desmontar.
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-005 · E — Cierre: suite completa y documentación
**Cierre de la 018**

- **Objetivo**: puerta final de la spec.
- **Archivos**:
  - `pubspec.yaml` (verificar sin dependencias nuevas).
  - `docs/specs/README.md`: fila 018 con estado y decisiones clave.
  - `memory.md`: bitácora de las 5 tareas, D-034…D-038, Q-017/Q-018,
    `Last updated`, corrección de la ruta de la 017 y de los tests
    obsoletos ya borrados (Q-015).
  - `plan.md` §6.3: baseline final de la suite.
- **Criterios de aceptación (Given/When/Then)**:
  - Given la suite completa, When se ejecuta `flutter test`, Then está en
    verde salvo los fallos preexistentes listados en `plan.md` §6.3 (sin
    empeorar el baseline).
  - Given `flutter analyze`, Then sin incidencias nuevas.
  - Given la hoja de ruta, Then la fila 018 y `memory.md` reflejan el
    cierre, las decisiones y las preguntas abiertas.
  - Given `pubspec.yaml`, Then sin dependencias nuevas ni migraciones.
- **Cierre**: `flutter test` + `flutter analyze` en verde. **Fin de la
  spec 018.**

---

## Matriz de trazabilidad RF → tarea

| RF | Tarea(s) |
|---|---|
| RF-1 (sección pintada sin excepciones) | T-001, T-003 |
| RF-2 (`ViewToggle` con ancho acotado) | T-001 |
| RF-3 (cabecera aunque el panel no emita) | T-003 |
| RF-4 (título con elipsis a 320 dp) | T-001, T-002 |
| RF-5 (`dispose` completo) | T-004 |
| RF-6 (`live_fatigue_section_test` en verde) | T-002 |
| RF-7 (test de regresión en vivo) | T-003 |

## Matriz de trazabilidad Área (A-xxx) → tarea

| Área | Tarea(s) |
|---|---|
| A-1 Cabecera de la sección | T-001 |
| A-2 Toggle compartido | T-001 |
| A-3 Sesión en vivo | T-003, T-004 |
| A-4 Tests de la sección | T-002 |
| A-5 Tests de la sesión en vivo | T-003, T-004 |

## Matriz de trazabilidad Petición del usuario → tarea

| Petición | Diagnóstico | Tarea(s) |
|---|---|---|
| «en live workout no se mira el mapa de fatiga en vivo, ni el tap» | `Row` de la cabecera entrega ancho infinito a `ViewToggle` (`Expanded`/`FlexFit.tight`) → excepción de layout → `SliverToBoxAdapter` con `geometry.visible=false` (regresión del commit `e2e8c1f`, T-007·M de la 017) | T-001, T-003 |
| (derivado) sección ausente si el panel no emite | gate `!hasData → SizedBox.shrink()` | T-003 |
| (derivado) el único test del área no compila | `FatiguePanel` usado como constructor siendo record typedef (D-033 pendiente) | T-002 |
| (derivado) `db.close()` cuelga en los tests | sin `dispose()` en `_LiveWorkoutViewState` | T-004 |
