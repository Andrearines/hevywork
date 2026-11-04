# Tareas 016 — Mejoras de la sesión en vivo y adaptación a pantalla

Orden de ejecución e iterables. **Cierre obligatorio de cada tarea**:
`flutter test` en verde + `flutter analyze` sin incidencias (AGENTS.md).
Si no pasa, la tarea no está terminada.

Restricciones transversales: sin dependencias nuevas (RNF-1), sin
migraciones (RNF-2), sin `elevation`/`BoxShadow` (RNF-3), código en inglés
y mensajes/docs en español (RNF-4).

---

## T-001 · B — Diagnóstico y refuerzo de la persistencia de series
**RF-5, RF-6, RF-7 · Mejora 2**

- **Objetivo**: reproducir el fallo «las series añadidas/quitadas no se
  guardan», identificar la causa raíz (hipótesis H-p1…H-p5 de `plan.md` §5)
  y dejar la persistencia verificada de extremo a extremo.
- **Archivos**:
  - modificar `test/workout_repository_test.dart` (casos: add → query
    directa; delete → fuera; pendientes `completed=false` tras «reiniciar»
    la BD; `orderIndex` reindexado; mutación encolada a sync).
  - modificar `test/live_workout_view_test.dart` (añadir serie en la UI →
    fila en `workout_sets`; borrar → ausente; recargar la vista → igual).
  - modificar `lib/ui/views/live_workout_view.dart` y/o
    `lib/data/repositories/workout_repository.dart` **solo si** el
    diagnóstico halla la causa (fix mínimo).
  - actualizar `plan.md` §5 (hipótesis confirmadas/descartadas).
- **Criterios de aceptación (Given/When/Then)**:
  - Given una sesión activa con un ejercicio, When confirmo una serie en la
    vista en vivo, Then `SELECT * FROM workout_sets` devuelve la fila con
    peso/reps/RIR/tipo iguales a los introducidos.
  - Given una serie existente, When la borro desde la UI (confirmando el
    diálogo), Then la fila desaparece de la BD y las restantes se reindexan
    1..n.
  - Given series precargadas pendientes, When cierro y reabro la sesión,
    Then conservan valores, tipo y orden (RF-7).
  - Given una operación inválida (reps 0, sesión no editable), When se
    intenta, Then no cambia ninguna fila y aparece un snackbar (RF-6).
  - Given la causa identificada, When se documenta, Then aparece en
    `plan.md` §5 y `memory.md` con su test de regresión (o constancia de
    «no reproducido + red de seguridad» en Q-008).
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-002 · A — Notificaciones de descanso con volumen alto
**RF-1, RF-2, RF-3, RF-4 · Mejora 1**

- **Objetivo**: el aviso del descanso suena en primer plano (hoy no suena
  nada) y suena fuerte también en segundo plano.
- **Archivos**:
  - modificar `lib/domain/services/rest_notifier.dart`: canal
    `rest_timer_v2` con `Importance.high`, `Priority.high`,
    `playSound: true`, `enableVibration: true`,
    `audioAttributesUsage: AudioAttributesUsage.alarm` (Android);
    `presentSound: true` (iOS/macOS); detalles compartidos entre
    `scheduleAt()` y `showNow()`; `alertNow()` emite la notificación con
    esos detalles y cae a `SystemSound` + `HapticFeedback.vibrate()` si
    falla (RF-4).
  - modificar `lib/ui/views/live_workout_view.dart`: detectar la transición
    a `done` en el tick de `_now` y disparar `alertNow()` **una sola vez**
    por `endsAt` (bandera; reset al iniciar/nuevo descanso).
  - crear `test/rest_notifier_test.dart` (detalles extraídos a función
    pura testeable: id de canal, importancia, playSound, uso de alarma;
    `scheduleAt`/`cancel` no lanzan sin plugin).
  - ampliar `test/live_workout_view_test.dart` (el aviso se dispara una vez
    al terminar el descanso; no se dispara al pausar/saltar).
- **Criterios de aceptación (Given/When/Then)**:
  - Given el descanso en marcha en primer plano, When llega a cero, Then
    se emite exactamente un aviso audible + vibración.
  - Given el descanso en segundo plano, When llega a cero, Then la
    notificación programada usa el canal `rest_timer_v2` con uso de alarma
    (volumen alto) y se cancela al reanudar la app.
  - Given permisos denegados o plugin no disponible, When termina el
    descanso, Then hay fallback a `SystemSound` + vibración sin excepción
    propagada (RF-4).
  - Given un descanso saltado o pausado, When llega el tick, Then no se
    emite aviso.
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-003 · C — Series de la semana en la tabla de fatiga en vivo
**RF-8, RF-9 · Mejora 3**

- **Objetivo**: la tabla/zonas de la sección de fatiga en vivo muestran las
  series de los últimos 7 días junto a volumen y estado; la gráfica deja la
  etiqueta ambigua.
- **Archivos**:
  - modificar `lib/ui/widgets/live_fatigue_section.dart`: cada chip/zona
    muestra `músculo · N series · X kg` (formato en función pura testeable,
    unidad vía `UnitSystemScope`); sin series → «Sin series».
  - modificar `lib/ui/widgets/zone_volume_chart.dart`: etiqueta
    `N series` + `X kg` en lugar de `kg×series`.
  - crear `test/live_fatigue_section_test.dart` (render con panel, resumen
    semanal, estado vacío).
  - ampliar `test/zone_volume_chart_test.dart` (etiqueta nueva).
- **Criterios de aceptación (Given/When/Then)**:
  - Given una zona con 12 series completadas esta semana, When se pinta la
    sección en vivo, Then la fila muestra «12 series» y el volumen semanal
    en la unidad del perfil.
  - Given una zona sin series en 7 días, When se pinta, Then muestra
    «Sin series» sin ceros engañosos ni divisiones por cero.
  - Given la sesión activa con series de hoy, When cambia el panel, Then
    entran en el recuento (ventana de 7 días, RF-5 de la 014).
  - Given los datos sin cambios, When se redibuja la gráfica, Then
    `shouldRepaint` es false y el golden existente no cambia de forma.
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-004 · D — Pestaña Frente/Espalda en el mapa en vivo
**RF-10 · Mejora 4**

- **Objetivo**: alternar vista frontal/espalda dentro de la sección de
  fatiga de la sesión en vivo, como en Progreso.
- **Archivos**:
  - crear `lib/ui/widgets/view_toggle.dart` (extraer `_ViewToggle` de
    `lib/ui/views/progress_view.dart` sin cambio visual) y mover
    `kFrontCanonicals`/`kBackCanonicals` (hoy en `progress_view.dart:906`)
    a `lib/ui/widgets/muscle_map.dart`, reimportándolas donde haga falta.
  - modificar `lib/ui/views/progress_view.dart` (usar el widget
    compartido).
  - modificar `lib/ui/widgets/live_fatigue_section.dart`: estado
    `_showBack` interno con toggle, `MuscleMap` y `ZoneVolumeChart` con la
    vista elegida, limpieza de `_selectedMuscle` si la zona no es visible
    (`kFrontCanonicals`/`kBackCanonicals`).
  - modificar `lib/ui/views/live_workout_view.dart`: eliminar
    `showBack: false` fijo (línea ~334).
  - crear/ampliar `test/live_fatigue_section_test.dart`; ampliar
    `test/progress_view_test.dart` (regresión del toggle).
- **Criterios de aceptación (Given/When/Then)**:
  - Given la sesión en vivo con la sección desplegada, When pulso
    «Espalda», Then el mapa pinta la vista posterior y la gráfica de zonas
    recibe `showBack: true`.
  - Given un músculo frontal seleccionado, When cambio a «Espalda», Then
    la selección se limpia (no se resalta una zona invisible).
  - Given la vista de Progreso, When se abre, Then el toggle se ve y
    funciona igual que antes (extracción neutra).
  - Given el toggle, When se inspecciona, Then los targets siguen ≥ 48 dp
    y no hay `BoxShadow`/`elevation`.
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-005 · E — Breakpoints y ancho de contenido por tamaño real
**RF-11 · Mejora 5**

- **Objetivo**: móvil, tablet y pantalla rotada sin desbordes, con el
  contenido de tablet centrado a 640 dp (designer §4.2).
- **Archivos**:
  - crear `lib/ui/layout/screen_breakpoints.dart` (D-024).
  - modificar `lib/main.dart` (`MainNavigator`: margenes/`ConstrainedBox`
    según `screenClassOf`, sin tocar sheets ni diálogos, D-025).
  - crear `test/responsive_layout_test.dart` (matriz de tamaños).
  - crear `test/screen_breakpoints_test.dart` (fronteras 599/600/640/1024).
- **Criterios de aceptación (Given/When/Then)**:
  - Given un ancho de 599 dp, When se evalúa el breakpoint, Then es
    `phone` con margen 16 y gutter 12; dado 600 dp, Then es `tablet` con
    margen 24 y contenido máximo 640 centrado.
  - Given las cuatro pestañas, When se montan a 320, 360, 375, 412, 768,
    1024 y 1366 dp (retrato y horizontal), Then `tester.takeException()` es
    null (sin `RenderFlex overflow`) y la pill no tapa el contenido.
  - Given una tablet en horizontal, When se pinta el shell, Then el cuerpo
    está centrado y no supera 640 dp de ancho.
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-006 · E — Aislamiento de la configuración del sistema
**RF-12, RF-13 · Mejora 6**

- **Objetivo**: el layout sigue el tamaño real de pantalla y no se rompe
  con la escala de fuente/pantalla del sistema.
- **Archivos**:
  - modificar `lib/main.dart` (`builder` de `MaterialApp`: acotar
    `textScaler` al rango 1.0–1.3, constante; verificar API vigente
    `MediaQuery.withClampedTextScaling` vs `copyWith + TextScaler.clamp`).
  - modificar `test/small_screen_layout_test.dart` (escala 1.0/1.3/2.0 y
    horizontal, heredando el patrón).
  - ampliar `test/responsive_layout_test.dart` (misma matriz con escala
    1.0, 1.3 y 2.0 → mismo layout base, sin desbordes).
- **Criterios de aceptación (Given/When/Then)**:
  - Given el sistema con escala de fuente 2.0, When arranca la app, Then
    el texto renderiza con el tope configurado y ninguna pestaña desborda.
  - Given escala 1.0 y 1.3, When se pintan las pestañas, Then el ancho de
    contenido y los márgenes coinciden (layout independiente de la escala).
  - Given los cambios, When se ejecuta la suite, Then los tests existentes
    siguen en verde (RNF-6) y `small_screen_layout_test` cubre retrato y
    horizontal.
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-007 · F — Cierre: goldens, suite completa y documentación
**RF-13 · Cierre de la 016**

- **Objetivo**: puerta final de la spec.
- **Archivos**:
  - `test/goldens/*` (regenerar solo los afectados por etiquetas/toggle:
    revisar diff a mano).
  - `pubspec.yaml` (verificar sin dependencias nuevas).
  - `docs/specs/README.md` (fila 016 con estado y decisiones clave).
  - `memory.md` (bitácora de las 7 tareas, D-018…D-025, Q-007…Q-011,
    `Last updated`).
  - `plan.md` §5 (resultado final del diagnóstico).
- **Criterios de aceptación (Given/When/Then)**:
  - Given la suite completa, When se ejecuta `flutter test`, Then está en
    verde (tests existentes + los nuevos de 016).
  - Given `flutter analyze`, Then sin incidencias.
  - Given la hoja de ruta, Then la fila 016 y `memory.md` reflejan el
    cierre y las preguntas abiertas.
  - Given `pubspec.yaml`, Then sin dependencias nuevas y sin migraciones.
- **Cierre**: `flutter test` + `flutter analyze` en verde. **Fin de la
  spec 016.**

---

## Matriz de trazabilidad RF → tarea

| RF | Tarea(s) |
|---|---|
| RF-1 (aviso en primer plano) | T-002 |
| RF-2 (canal alto volumen) | T-002 |
| RF-3 (segundo plano + cancelación) | T-002 |
| RF-4 (fallback sin permisos) | T-002 |
| RF-5 (persistir add/edit/undo/delete) | T-001 |
| RF-6 (sin escritura parcial, error visible) | T-001 |
| RF-7 (pendientes tras reiniciar) | T-001 |
| RF-8 (series semanales en tabla en vivo) | T-003 |
| RF-9 (etiqueta legible de la gráfica) | T-003 |
| RF-10 (toggle Frente/Espalda) | T-004 |
| RF-11 (breakpoints y tablet 640 dp) | T-005 |
| RF-12 (escala de texto acotada) | T-006 |
| RF-13 (accesibilidad sin regresiones) | T-004, T-005, T-006, T-007 |

## Matriz de trazabilidad Área (A-xxx) → tarea

| Área | Tarea(s) |
|---|---|
| A-1 Aviso del descanso | T-002 |
| A-2 Tabla de series en vivo | T-001 |
| A-3 Sección de fatiga en vivo | T-003, T-004 |
| A-4 Gráfica de volumen semanal | T-003 |
| A-5 Shell y pestañas | T-005, T-006 |
| A-6 Progreso (reutilización) | T-004 |
