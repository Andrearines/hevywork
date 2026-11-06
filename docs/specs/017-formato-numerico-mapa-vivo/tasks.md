# Tareas 017 — Formato numérico y mapa muscular en vivo

Orden de ejecución e iterables. **Cierre obligatorio de cada tarea**:
`flutter test` en verde + `flutter analyze` sin incidencias (AGENTS.md).
Si no pasa, la tarea no está terminada.

Restricciones transversales: sin dependencias nuevas (RNF-1), sin
migraciones (RNF-2), sin `elevation`/`BoxShadow` (RNF-3), código en inglés
y mensajes/docs en español (RNF-4).

---

## T-001 · A — Formateador numérico compartido ≤ 2 decimales
**RF-1, RF-2 · Problema 1**

- **Objetivo**: un único punto de decisión de decimales para valores crudos:
  `80.50000000000001` → «80.5», `12000.0` → «12000», `61.25` → «61.25»,
  con un máximo de 2 decimales y sin ceros sobrantes.
- **Archivos**:
  - modificar `lib/domain/units.dart`: añadir
    `String formatNumber(double value, {int maxDecimals = 2})` (redondeo a
    `maxDecimals` y retirada de ceros sobrantes y del punto final);
    `formatDisplay`, `formatWeightKg` y `formatLengthCm` **no cambian**
    (D-030, Q-014).
  - modificar `test/units_test.dart`: casos nuevos de `formatNumber` y
    comprobación de que los tests actuales de `formatWeightKg`/
    `formatLengthCm`/`formatDisplay` siguen en verde.
  - grep de comprobación: `grep -rn "toStringAsFixed" lib/ui/` para dejar
    constancia en `plan.md` §5 de los usos ≤ 2 decimales que se conservan.
- **Criterios de aceptación (Given/When/Then)**:
  - Given `formatNumber(80.50000000000001)`, When se evalúa, Then devuelve
    `'80.5'` (nunca más de 2 decimales ni ruido de coma flotante).
  - Given `formatNumber(12000.0)`, Then devuelve `'12000'` (sin `.0`).
  - Given `formatNumber(61.25)`, Then devuelve `'61.25'`; dado
    `formatNumber(1.23456)`, Then `'1.23'`; dado `formatNumber(0.0)`, Then
    `'0'`.
  - Given `formatWeightKg(80.50000000000001, 'metric')`, Then devuelve
    `'80.5'` (el redondeo existente ya cumple ≤ 2 decimales, sin cambios en
    la función).
  - Given la suite, When se ejecuta `flutter test`, Then los tests de
    `units_test.dart` pasan y ningún test existente queda roto por este
    cambio (D-030).
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-002 · B — Valores formateados junto al mapa + test de la sección en vivo
**RF-3, RF-7 · Problemas 1 y 3**

- **Objetivo**: los chips de zona y la gráfica de barras dejan de pintar
  dobles en crudo; vuelve a compilar `test/live_fatigue_section_test.dart`.
- **Archivos**:
  - modificar `lib/ui/widgets/live_fatigue_section.dart`: extraer
    `String zoneChipLabel(MuscleZoneStats zone, String unitSystem)` (función
    pura exportada, D-032) que devuelve `Sin series` sin volumen o
    `músculo · N series · X <unidad>` usando `formatWeightKg`; el chip
    usa esa función (sustituye las líneas 211-217).
  - modificar `lib/ui/widgets/zone_volume_chart.dart`: extraer
    `String zoneVolumeLabel(MuscleZoneStats zone, String unitSystem)` y
    usarla en el `TextPainter` del painter (línea 160).
  - reescribir `test/live_fatigue_section_test.dart` (D-033): literales de
    record `(fatigue: …, zones: …, trend: …)` en lugar de
    `FatiguePanel(...)` y expectativas sobre la línea completa del chip;
    añadir caso de formato (sin `80.50000000000001` ni `12000.0`).
  - ampliar `test/zone_volume_chart_test.dart`: tests unitarios de
    `zoneVolumeLabel` (métrico e imperial, volumen con ruido).
- **Criterios de aceptación (Given/When/Then)**:
  - Given una zona con `weeklyVolume = 80.50000000000001` en métrico, When
    se pinta el chip, Then el texto es `… · 80.5 kg` y **no** contiene
    `80.50000000000001`.
  - Given una zona con `weeklyVolume = 12000.0`, Then el chip muestra
    `12000 kg` (sin `.0`).
  - Given una zona imperial con volumen convertido (`× kKgPerLb`), Then la
    etiqueta tiene ≤ 2 decimales y la unidad `lb`.
  - Given una zona sin series, Then `zoneChipLabel` devuelve `Sin series`
    (sin volumen), conservando el RF-8 de la 016.
  - Given el fichero `test/live_fatigue_section_test.dart`, When se ejecuta
    `flutter analyze` y `flutter test`, Then compila y pasa (cierra el
    fallo preexistente listado en `memory.md`).
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-003 · C — Toggle Frente/Espalda visible con la sección desplegada
**RF-4, RF-5 · Problema 2**

- **Objetivo**: en la sesión en vivo se puede ver la espalda del mapa con
  un toque, sin tener que colapsar la sección (que oculta el mapa).
- **Archivos**:
  - modificar `lib/ui/widgets/live_fatigue_section.dart` (líneas 85-125):
    el `ViewToggle` se renderiza **en ambos estados** (quitar
    `if (!isExpanded)`), el título se envuelve en `Expanded` con
    `maxLines: 1` y `TextOverflow.ellipsis` (D-031). Fallback si desborda a
    320 dp: fila propia sobre el `MuscleMap` en `_ExpandedBody`.
  - modificar `lib/ui/views/live_workout_view.dart` (~342-345): corregir el
    comentario inverso sobre cuándo está disponible el toggle.
  - ampliar `test/live_fatigue_section_test.dart`: toggle visible con la
    sección expandida y cambio de vista.
- **Criterios de aceptación (Given/When/Then)**:
  - Given `LiveFatigueSection` con panel y **desplegada** (estado por
    defecto), When se pinta, Then `find.text('Espalda')` y
    `find.text('Frente')` encuentran 1 widget cada uno.
  - Given la sección desplegada, When pulso «Espalda», Then
    `MuscleMap.showBack == true` y `ZoneVolumeChart.showBack == true`
    (campos públicos del widget).
  - Given un músculo frontal seleccionado, When cambio a «Espalda», Then la
    selección se limpia (no se resalta una zona invisible).
  - Given la sección **colapsada**, Then el toggle sigue visible y el
    cuerpo oculto (comportamiento de la 016 conservado).
  - Given un viewport de 320 dp con la sección desplegada, When se pinta,
    Then `tester.takeException()` es null (sin `RenderFlex overflow` con el
    título en elipsis).
  - Given el toggle, When se inspecciona, Then targets ≥ 48 dp y sin
    `BoxShadow`/`elevation`.
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-004 · D — Barrido de decimales en `lib/ui/` (auditoría RF-6)
**RF-1, RF-2, RF-6 · Problema 1**

- **Objetivo**: garantizar que ninguna vista interpola un `double` en
  crudo ni usa más de 2 decimales.
- **Archivos**:
  - barrido sobre `lib/ui/views/*.dart` y `lib/ui/widgets/*.dart` con la
    lista de comprobación de `plan.md` §1.4: (a) interpolación cruda de
    dobles, (b) `toStringAsFixed(n)` con n > 2, (c) `displayWeightKg` /
    `displayLengthCm` colados en un string sin formatear.
  - modificar los focos encontrados (ya confirmado:
    `live_workout_view.dart` comentario; revisar
    `exercise_info_view.dart:389-401` — kg fijo sin convertir, Q-016).
  - crear/ampliar el test que cubra cada foco corregido (unitario de la
    función pura o widget test con `find.text`).
  - `test/goldens/*`: regenerar solo los afectados y revisar el diff a
    mano.
- **Criterios de aceptación (Given/When/Then)**:
  - Given el barrido, When se ejecutan las 4 comprobaciones sobre
    `lib/ui/`, Then no queda ningún `double` en crudo en un `Text` o
    `TextPainter` (lista firmada en `plan.md` §5).
  - Given cualquier valor mostrado en la UI, Then tiene ≤ 2 decimales y sin
    artefactos `80.50000000000001` / `12000.0`.
  - Given los focos corregidos, When se ejecuta la suite, Then los tests
    nuevos fallarían sin el fix (regresión efectiva).
  - Given `pubspec.yaml`, Then sin dependencias nuevas y sin migraciones.
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-005 · E — Cierre: tests obsoletos, suite completa y documentación
**RF-7 · Cierre de la 017**

- **Objetivo**: puerta final de la spec.
- **Archivos**:
  - Q-015: borrar `test/tmp_t001_probe*_test.dart` (4) y
    `test/hacker_tmp_poc_test.dart` (2 errores de analyze) si se confirma;
    reparar `test/fatigue_trend_chart_test.dart` (parámetro `days` requerido
    y `ExerciseSetRow` en lugar de `FatigueSet`).
  - `pubspec.yaml` (verificar sin dependencias nuevas).
  - `docs/specs/README.md` (fila 017 con estado y decisiones clave).
  - `memory.md` (bitácora de las 5 tareas, D-029…D-033, Q-014…Q-016,
    `Last updated`).
  - `plan.md` §5/§6 (resultado final del barrido y de los tests).
- **Criterios de aceptación (Given/When/Then)**:
  - Given la suite completa, When se ejecuta `flutter test`, Then está en
    verde (tests existentes + los nuevos de 017).
  - Given `flutter analyze`, Then sin incidencias (0 errores).
  - Given la hoja de ruta, Then la fila 017 y `memory.md` reflejan el
    cierre y las preguntas abiertas.
  - Given `pubspec.yaml`, Then sin dependencias nuevas y sin migraciones.
- **Cierre**: `flutter test` + `flutter analyze` en verde. **Fin de la
  spec 017.**

---

## Matriz de trazabilidad RF → tarea

| RF | Tarea(s) |
|---|---|
| RF-1 (≤ 2 decimales, sin artefactos) | T-001, T-004 |
| RF-2 (unidad del perfil por el formateador) | T-001, T-004 |
| RF-3 (chips y gráfica formateados, función pura) | T-002 |
| RF-4 (toggle visible con sección desplegada) | T-003 |
| RF-5 (toggle también colapsado, sin desborde a 320 dp) | T-003 |
| RF-6 (barrido sin dobles en crudo en `lib/ui/`) | T-004 |
| RF-7 (suite verde y test de la sección reparado) | T-002, T-005 |

## Matriz de trazabilidad Área (A-xxx) → tarea

| Área | Tarea(s) |
|---|---|
| A-1 Formato compartido | T-001 |
| A-2 Sección de fatiga en vivo | T-002, T-003 |
| A-3 Gráfica de volumen semanal | T-002 |
| A-4 Sesión en vivo | T-003, T-004 |
| A-5 Barrido resto de vistas | T-004 |
| A-6 Tests obsoletos preexistentes | T-005 |

## Matriz de trazabilidad Problema → tarea

| Problema del usuario | Diagnóstico | Tarea(s) |
|---|---|---|
| 1 · Demasiados decimales en vistas | `live_fatigue_section.dart:212-216` y `zone_volume_chart.dart:158-160` pintan dobles en crudo; resto sin focos confirmados | T-001, T-002, T-004 |
| 2 · Mapa en vivo sin parte trasera | `live_fatigue_section.dart:108-120` solo pinta el toggle `if (!isExpanded)` y la sección arranca expandida | T-003 |
| 3 · Decimales en el mapa muscular | `MuscleMap` no pinta texto; los valores salen de los dos focos del problema 1 | T-002 |
