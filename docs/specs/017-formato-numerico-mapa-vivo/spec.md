# Spec 017 — Formato numérico en la UI y mapa muscular en vivo

## Contexto y objetivo

Las specs 014, 015 y 016 están **cerradas**. El usuario reporta **3 problemas
nuevos** que ninguna spec abierta cubre:

| # | Petición del usuario | Spec que toca hoy |
|---|---|---|
| 1 | En varias vistas se muestran **demasiados decimales** (p. ej. `80.50000000000001` en lugar de `80.5`), sobre todo en la **sesión en vivo**; ninguna vista debe pasar de 2 decimales | sin cubrir (formato ad hoc por vista) |
| 2 | El **mapa muscular en vivo** no permite ver la parte de atrás: la 016 implementó el toggle Frente/Espalda (T-004) pero en la sesión en vivo **no se ve / no funciona** | 016 (RF-10, cerrada) |
| 3 | El **mapa muscular** muestra muchos decimales en los valores que pinta | sin cubrir |

### Diagnóstico verificado (2026-11-06)

**P1 — decimales sueltos.** Dos focos confirmados, ambos dentro de la sesión
en vivo (y también en Progreso, que reutiliza el mismo widget):

- `lib/ui/widgets/live_fatigue_section.dart:212-216` —
  `volumeKg = displayWeightKg(zone.weeklyVolume, unitSystem)` se interpola
  **en crudo** en el chip (`'$muscleName · $setsText · $volumeText'`) →
  «Cuádriceps · 8 series · 80.50000000000001 kg» y también «12000.0 kg»
  (un `double` siempre arrastra `.0` si no se formatea).
- `lib/ui/widgets/zone_volume_chart.dart:158-160` — el `TextPainter` de la
  etiqueta de volumen pinta `'$weightKg'` en crudo → misma fuga de
  decimales junto a las barras.

El resto de la UI ya pasa por un formateador: `formatWeightKg` /
`formatDisplay` (`lib/domain/units.dart`, ≤1 decimal), `toStringAsFixed(0|1)`
o `.round()`. Queda un barrido de garantía en T-004 (RF-4), pero no se han
encontrado más focos crudos confirmados en `lib/ui/`.

**P2 — espalda en vivo.** El toggle existe y está bien implementado, pero
`lib/ui/widgets/live_fatigue_section.dart:108-120` lo renderiza **solo
`if (!isExpanded)`**: la sección arranca desplegada
(`initialState = FatigueSectionState.expanded`, línea 27), así que en la
sesión en vivo **el toggle nunca aparece**; y cuando el usuario la colapsa
para verlo, el cuerpo (y el mapa) desaparece
(`AnimatedSize` → `SizedBox.shrink()`). En Progreso el toggle sí está siempre
en la cabecera (`progress_view.dart:499-503`). El comentario de
`live_workout_view.dart:342-345` dice lo contrario de lo que ocurre
(«estará disponible cuando la sección esté expandida»), por lo que el fix de
la 016 quedó inoperante en vivo.

**P3 — decimales «en el mapa».** `MuscleMap` **no pinta texto** (verificado:
sin `Text` ni `TextPainter` en `lib/ui/widgets/muscle_map.dart`); solo tiñe
regiones. Los valores numéricos que el usuario ve junto al mapa salen de los
dos focos del P1 (chips de zona y `ZoneVolumeChart`), así que el fix es el
mismo. El rótulo de pico (`Fatiga muscular` colapsada) ya usa `.round()`.

**Hallazgo añadido (bloquea el cierre en verde).**
`test/live_fatigue_section_test.dart` **no compila**: usa
`FatiguePanel(fatigue: …, zones: …, trend: …)` como si fuera constructor,
pero `FatiguePanel` es un `typedef` de record
(`lib/data/repositories/fatigue_repository.dart:13`). `flutter analyze`
acusa 32 errores en ese fichero y `flutter test` lo da como test fallido
(fallo preexistente registrado en `memory.md`, T-007 de la 016). Hay que
reescribirlo con literales de record.

> No hay pantalla nueva: esta spec **no genera `DESIGN.md`**. Se aplican los
> tokens y reglas de `docs/designer.md` y la constitución de `AGENTS.md`.

## Usuarios

Atleta que entrena con la sesión en vivo: quiere leer volúmenes y pesos sin
ruido (`80.5`, no `80.50000000000001`), y quiere poder revisar la espalda en
el mapa muscular de la sesión en vivo con un toque, igual que en Progreso.

## Historias de usuario

- H1: Como usuario quiero que todos los números de la app se muestren con
  un máximo de 2 decimales (y sin `80.50000000000001` ni `12000.0` sobrantes)
  para poder leerlos de un vistazo.
- H2: Como usuario quiero ver la parte de atrás del mapa muscular **dentro
  de la sesión en vivo** tocando Frente/Espalda, para revisar la musculatura
  posterior mientras entreno.
- H3: Como usuario quiero que los valores que acompañan al mapa muscular
  (chips de zona y gráfica de barras) sean coherentes con el resto de la app
  (misma función de formato, unidad del perfil).

## Alcance

- Formateador numérico compartido ≤ 2 decimales en `lib/domain/units.dart`.
- Aplicación del formato a los chips de zona y a las etiquetas de
  `ZoneVolumeChart` (los dos focos confirmados).
- Toggle Frente/Espalda **visible con la sección desplegada** en
  `LiveFatigueSection` (sesión en vivo), conservando el comportamiento de
  Progreso.
- Barrido de garantía de decimales en `lib/ui/` con corrección de los focos
  que aparezcan.
- Reparación de `test/live_fatigue_section_test.dart` (preexistente) y tests
  nuevos de formato y toggle.
- Cierre con `flutter test` + `flutter analyze` en verde.

## Áreas de UI afectadas (A-xxx)

| Área | Fichero | Problemas |
|---|---|---|
| A-1 Formato compartido | `lib/domain/units.dart`, `test/units_test.dart` | 1 |
| A-2 Sección de fatiga en vivo | `lib/ui/widgets/live_fatigue_section.dart`, `test/live_fatigue_section_test.dart` | 1, 2, 3 |
| A-3 Gráfica de volumen semanal | `lib/ui/widgets/zone_volume_chart.dart`, `test/zone_volume_chart_test.dart` | 1, 3 |
| A-4 Sesión en vivo | `lib/ui/views/live_workout_view.dart`, `test/live_workout_view_test.dart` | 1 (auditoría), 2 (comentario/entrada) |
| A-5 Barrido resto de vistas | `lib/ui/views/*.dart`, `lib/ui/widgets/*.dart` | 1 |
| A-6 Tests obsoletos preexistentes | `test/fatigue_trend_chart_test.dart`, `test/hacker_tmp_poc_test.dart`, `test/tmp_t001_probe*_test.dart` | cierre (Q-015) |

## Requisitos funcionales (EARS)

### Formato numérico (problema 1)
- RF-1: EL SISTEMA formatea **todo valor numérico mostrado en la UI** con un
  máximo de **2 decimales**, sin artefactos de punto flotante y sin ceros
  sobrantes: `80.50000000000001` → «80.5», `12000.0` → «12000»,
  `61.25` → «61.25», `1.23456` → «1.23». El formato vive en una **función
  pura testeable** (sin widgets).
- RF-2: EL SISTEMA presenta los volúmenes en la **unidad del perfil**
  (`UnitSystemScope`, kg/lb) y las longitudes en cm/in a través de
  `formatWeightKg` / `formatLengthCm` (hoy ≤ 1 decimal) o de `formatNumber`
  cuando el valor no tiene unidad; nunca interpola el `double` en crudo.

### Valores junto al mapa muscular (problema 3)
- RF-3: EL SISTEMA pinta los valores de la sección de fatiga en vivo (chips
  de zona) y de la gráfica de barras (`ZoneVolumeChart`) a través de
  `formatWeightKg`/`formatNumber` (≤ 2 decimales, RF-1); la etiqueta se
  construye en una función pura por widget para poder testearla sin
  inspeccionar el `Canvas`.

### Mapa en vivo con vista de espalda (problema 2)
- RF-4: CUANDO la sección de fatiga de la sesión en vivo está **desplegada**
  (estado por defecto), EL SISTEMA muestra el control Frente/Espalda junto al
  título, accesible con un toque; al pulsarlo el `MuscleMap` y la
  `ZoneVolumeChart` cambian a la vista posterior, por defecto sigue en
  «Frente» y se limpia la selección de músculo si la zona elegida no es
  visible en la vista activa (`_syncSelection`, criterio de la 016 RF-10).
- RF-5: EL SISTEMA conserva el toggle también con la sección colapsada
  (comportamiento actual) y el título no desborda a 320 dp (el texto se
  acota con `Expanded` + elipsis).

### Auditoría y cierre
- RF-6: EL SISTEMA no interpola ningún `double` en crudo en `lib/ui/`: el
  barrido de T-004 cubre vistas y widgets y corrige los focos que encuentre
  (incluido el formateo de la etiqueta de volumen imperial, donde la
  conversión multiplica y amplifica el ruido decimal).
- RF-7: EL SISTEMA mantiene en verde la suite: `test/live_fatigue_section_test.dart`
  vuelve a compilar (record literal en lugar de constructor) y añade casos de
  formato y de toggle.

## Requisitos no funcionales

- RNF-1: `pubspec.yaml` **sin dependencias nuevas** (AGENTS.md, principio 2).
- RNF-2: **Sin migraciones** drift ni Postgres; sin tocar esquema ni sync.
- RNF-3: Sin `elevation` ni `BoxShadow` (minimalismo Apple); jerarquía por
  tipografía y espacio. Targets táctiles ≥ 48 dp (el `ViewToggle` ya lo cumple).
- RNF-4: Código e identificadores en inglés; documentación y mensajes al
  usuario en español.
- RNF-5: Cierre obligatorio de **cada** tarea con `flutter test` en verde y
  `flutter analyze` sin incidencias (AGENTS.md §Al terminar).
- RNF-6: Sin regresiones en las specs cerradas 001–016: los tests existentes
  siguen en verde (los fallos preexistentes se listan en `plan.md` §6/Q-015).
- RNF-7: El formato y las etiquetas viven en **funciones puras** testeables
  sin widgets (mismo criterio RNF-7 de la 016).
- RNF-8: Sin sobrecostes de render: el cambio de posición del toggle no
  añade reconstrucciones por tecla (sigue siendo un widget hoja dentro de la
  cabecera).

## Casos límite

- Volumen `0.0` → «0 kg», sin `.0` ni división por cero.
- Valor con ruido de coma flotante (`80.50000000000001`, `176.369809744`) →
  redondeo a ≤ 2 decimales y sin ceros sobrantes.
- Sistema imperial: la conversión `kg * kKgPerLb` genera ruido adicional
  (`176.369809744…`) → siempre por el formateador, nunca en crudo.
- Sección desplegada a 320 dp con el toggle en la cabecera → sin
  `RenderFlex overflow` (título con `Expanded` + elipsis).
- Cambiar a «Espalda» con un músculo frontal seleccionado → la selección se
  limpia (ya implementado en `_syncSelection`, se cubre con test).
- Sección colapsada → el toggle sigue visible y el mapa no (estado actual).
- `weeklyVolume` de zona sin series → chip «Sin series» (sin volumen), como
  ya fija la 016 RF-8.

## Fuera de alcance (017)

- Cualquier migración de esquema drift/Postgres o dependencia nueva.
- Cambios en el cálculo de fatiga, volumen o tendencia (dominio intacto).
- Exportación CSV (`lib/domain/data_export.dart`): es formato máquina, no UI.
- Unidad de los KPIs de `ExerciseInfoView` (hoy en kg fijo, ver Q-016) salvo
  que se confirme en la auditoría de T-004.
- Rediseño visual, pantallas nuevas, specs 011 y 013 pendientes.
- Cambios en `ViewToggle` o en el mapa de Progreso más allá de lo que exija
  RF-4 (extracción ya hecha en la 016).

## Supuestos y preguntas abiertas

- Q-014: ¿Se unifica `formatDisplay` (hoy ≤ 1 decimal) a ≤ 2 decimales para
  que los pasos de 1.25 kg se muestren como «+1.25 kg» en vez de «+1.3 kg» y
  el campo de peso muestre 61.25? **Propuesta: no en esta spec** —
  `formatDisplay` ya cumple «≤ 2 decimales» y cambiarlo rompe
  `test/units_test.dart:50-54` y `test/live_workout_view_test.dart:665`
  (`'+1.3 kg'`); se deja como mejora futura si el usuario la pide.
- Q-015: ¿Qué hacer con los tests obsoletos preexistentes que impiden
  `flutter analyze` limpio? `test/tmp_t001_probe*_test.dart` (4 sondeos
  desechables de la 016), `test/hacker_tmp_poc_test.dart` (2 errores) y
  `test/fatigue_trend_chart_test.dart` (5 errores: falta el parámetro
  `days` y usan `FatigueSet` en vez de `ExerciseSetRow`). **Propuesta:**
  borrar `tmp_t001_probe*` y `hacker_tmp_poc*`, y reparar
  `fatigue_trend_chart_test.dart` a la API vigente.
- Q-016: ¿Se corrige también la unidad de los KPIs de
  `exercise_info_view.dart:389-401` (hoy `toStringAsFixed(1) kg` sin
  convertir a lb/in en imperial)? **Propuesta: incluirlo en el barrido de
  T-004** si el usuario usa imperial; es un cambio de una línea con
  `formatWeightKg`.
- Supuesto: la constitución vive en `AGENTS.md` + `docs/designer.md`
  (`docs/constitucion.md` no existe); esta spec aplica esas reglas.
- Supuesto: no hay pantalla nueva, por lo que no se genera `DESIGN.md`.

## Decisiones (cerradas)

- **D-029**: spec **nueva 017** en vez de reabrir la 016: la 016 está
  cerrada con su propia puerta de cierre (T-007) y estos 3 problemas son
  bugs/mejoras nuevos con trazabilidad propia.
- **D-030**: formateador compartido `formatNumber(double value, {int
  maxDecimals = 2})` en `lib/domain/units.dart`: redondea a ≤ 2 decimales y
  elimina ceros sobrantes y el punto final. Es la vía para **valores crudos
  que no son peso/longitud** y para el barrido de T-004. `formatDisplay`,
  `formatWeightKg` y `formatLengthCm` **no cambian** su redondeo actual
  (≤ 1 decimal, que ya cumple «≤ 2 decimales»): cambiarlos a 2 decimales
  rompería `test/units_test.dart:50-62` (`'176.4'`, `'39.4'`) y
  `test/live_workout_view_test.dart:665` (`'+1.3 kg'`) sin beneficio para
  el usuario — queda como mejora futura en Q-014.
- **D-031**: el toggle de `LiveFatigueSection` se muestra en la cabecera
  **en ambos estados** (desplegada y colapsada), con el título en `Expanded`
  + `maxLines: 1` + elipsis para no desbordar a 320 dp; sin tocar
  `view_toggle.dart` ni `progress_view.dart`.
- **D-032**: las etiquetas junto al mapa se construyen con **funciones puras
  exportadas** (`zoneChipLabel(zone, unitSystem)` y
  `zoneVolumeLabel(zone, unitSystem)`) que usan `formatWeightKg`, para
  testear el texto sin inspeccionar el `Canvas`.
- **D-033**: la reparación de `test/live_fatigue_section_test.dart` (record
  literal de `FatiguePanel`) forma parte de esta spec: es el fichero de
  prueba del área que se toca y su fallo preexistente impediría el cierre
  en verde.

## Criterios de finalización

- Ninguna vista muestra más de 2 decimales ni artefactos como
  `80.50000000000001` o `12000.0` (RF-1, RF-6).
- Los chips de zona y la gráfica de barras pintan volúmenes formateados en
  la unidad del perfil (RF-2, RF-3).
- El mapa muscular de la sesión en vivo alterna Frente/Espalda con la
  sección desplegada, con la selección coherente (RF-4, RF-5).
- `test/live_fatigue_section_test.dart` compila y cubre formato y toggle
  (RF-7).
- `pubspec.yaml` sin dependencias nuevas, sin migraciones y sin sombras.
- `flutter test` completo en verde y `flutter analyze` sin incidencias.
- `docs/specs/README.md` y `memory.md` actualizados con la fila 017.
