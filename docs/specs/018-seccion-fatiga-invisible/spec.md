# Spec 018 — Sección de fatiga invisible en la sesión en vivo

## Contexto y objetivo

Las specs 014–017 están cerradas. El usuario reporta un **bug nuevo** que
ninguna spec abierta cubre:

| # | Petición del usuario (verbatim) | Spec que toca hoy |
|---|---|---|
| 1 | «en la pantalla live workout no se mira el mapa de fatiga en vivo, no se muestra ni el tap para ver el mapa» | regresión del fix de toggle de la 017 (commit `e2e8c1f`) |

### Reproducción confirmada (entrevista 2026-11-07)

- Se reproduce en la **app real (dispositivo/emulador)** con build reciente.
- En la pestaña **Progreso** el mapa de fatiga **sí se ve** → descarta el
  perfil local y el caché `muscle_fatigue` como causa.
- La sección **nunca aparece desde el inicio** de la sesión en vivo: ni
  cabecera, ni tap, ni mapa, ni chips, ni gráficas.

### Diagnóstico verificado (2026-11-07)

**Causa raíz: excepción de layout en el `ViewToggle` de la cabecera → el
`SliverToBoxAdapter` que aloja la sección queda con `geometry.visible == false`
y no se pinta.**

1. `lib/ui/widgets/live_fatigue_section.dart:85-124` — la cabecera es un
   `Row(mainAxisAlignment: spaceBetween)` con tres hijos **no flexibles**:
   `Text` (título), `Icon` y `Padding(child: ViewToggle)`. Un hijo no
   flexible de un `Row` recibe `maxWidth: double.infinity`.
2. `lib/ui/widgets/view_toggle.dart:24` y `:65-79` — `ViewToggle` es
   `Container → Row(mainAxisSize: min) → [_ToggleSegment, _ToggleSegment]`
   y cada `_ToggleSegment` es **`Expanded(...)`** (`FlexFit.tight`).
3. `Expanded` dentro de un `Row` con ancho entrante infinito lanza:
   `RenderFlex children have non-zero flex but incoming width constraints are
   unbounded` (flutter/lib/src/rendering/flex.dart: «if the incoming layout
   constraints are unbounded, and any children have a non-zero flex factor and
   a `FlexFit.tight` fit (as applied by `Expanded`), the `RenderFlex` will
   assert»).
4. La excepción se propaga por toda la cadena de `layout()` (13 reportes
   iguales, uno por cada ancestro: `ViewToggle` → `Padding` → `Row` → … →
   `RenderSliverToBoxAdapter`). El sliver nunca llega a fijar geometría
   visible: en el test de widget `find.byType(LiveFatigueSection)` devuelve
   **0** con `skipOffstage: true` (el `Viewport` solo visita los slivers con
   `geometry.visible == true`, `viewport.dart:351`) y **1** con
   `skipOffstage: false`. Es decir: el widget está en el árbol pero **no se
   pinta** → exactamente el síntoma reportado (sin cabecera, sin tap, sin
   mapa).

**Evidencia de que el fallo es de layout y no de datos.** Instrumentando el
`StreamBuilder<FatiguePanel>` de `live_workout_view.dart:329` en un test de
widget se observa exactamente:

```
DBG-PANEL state=ConnectionState.waiting hasData=false error=null
DBG-PANEL state=ConnectionState.active  hasData=true  error=null   ← construye la sección
… 13 excepciones de layout (RenderFlex) …
find.byType(LiveFatigueSection) → 0 (skipOffstage: true) / 1 (false)
```

El panel **sí emite** y el `StreamBuilder` **sí recibe datos**; el
`LiveFatigueSection` se construye y revienta al hacer layout.

**Por qué falla ahora (regresión).** El commit `e2e8c1f` (T-007 · M de la
017, «toggle siempre visible en cabecera») eliminó el guard
`if (!isExpanded)` y dejó el `ViewToggle` **siempre** dentro del `Row` de la
cabecera:

```diff
-              if (!isExpanded)
-                Padding(
-                  padding: const EdgeInsets.only(left: 8),
-                  child: ViewToggle(...),
+              Padding(
+                padding: const EdgeInsets.only(left: 8),
+                child: ViewToggle(...),
```

Antes de ese commit la sección arrancaba **expandida**
(`initialState = FatigueSectionState.expanded`), el toggle no se renderizaba
por lo que no había excepción (ese era precisamente el bug P2 de la 017: el
toggle no se veía nunca). Ahora se renderiza siempre → **la sección entera
deja de pintarse**.

**Por qué Progreso no falla.** `lib/ui/views/progress_view.dart:496-504`
envuelve su toggle en `Flexible(child: FittedBox(fit: BoxFit.scaleDown, …))`,
que **acota el ancho** antes de llegar al `Row` con `Expanded`; además usa su
propia clase privada `_ViewToggle` (`progress_view.dart:699`), no la
compartida `ViewToggle`.

**Causas descartadas (con evidencia):**

| Hipótesis | Evidencia descartada |
|---|---|
| `watchFatiguePanel()` no emite / cierra | sonda `test/tmp_probe_panel_stream_test.dart`: emite `(fatigue: {}, trend: [], zones: [])` sin error ni `DONE` |
| `_profile()` (`getSingle` sobre `localProfiles`) lanza `StateError` | hay exactamente 1 fila `id=1`; además Progreso (que usa el mismo `_profile()` vía `watchFatigue()`) se ve |
| Caché `muscle_fatigue` vacío o corrupto | Progreso se ve; el panel emite `fatigue: {}` sin excepción |
| `_zonesAndTrend` / `muscleZoneStats` / `fatigueTrend` lanzan | ninguna lanza con datos vacíos ni con series (lectura de `muscle_fatigue.dart:299-331`, `fatigue_trend.dart`) |
| El `StreamBuilder` no recibe datos | instrumentación: `ConnectionState.active`, `hasData=true`, `error=null` |

**Defectos secundarios detectados en el mismo barrido** (todos en alcance):

1. **Sin `dispose()` en `_LiveWorkoutViewState`** (`live_workout_view.dart:57`):
   no se cancelan `_fatigueNotifier`, `_clockTimer`, `_now`, ni se hace
   `WidgetsBinding.instance.removeObserver(this)`; y `_disposed` (línea 77)
   **nunca se pone a `true`**, con lo que los guards de las líneas 265/272 son
   inútiles. Efecto observable: las suscripciones de drift quedan abiertas y
   `localDb.close()` en `tearDownAll` **se cuelga** (sonda `PROBE C` no
   completó en 600 s).
2. **Gate silencioso**: `live_workout_view.dart:332-336` pinta
   `SizedBox.shrink()` mientras `!fatigueSnap.hasData`, así que hasta que el
   panel emite (y si falla, para siempre) no hay ni cabecera.
3. **D-031 de la 017 quedó a medias**: el título de la cabecera
   (`live_fatigue_section.dart:100-103`) es un `Text` **sin** `Expanded`,
   `maxLines: 1` ni elipsis → a 320 dp puede desbordar el `Row`.
4. **`test/live_fatigue_section_test.dart` no compila**: sigue usando
   `FatiguePanel(...)` como si fuera constructor siendo un `typedef` de
   record (`flutter analyze` → 32 errores). El único test que habría cazado
   esta regresión está roto desde la 016/017 (D-033 sin cerrar).

> No hay pantalla nueva: esta spec **no genera `DESIGN.md`**. Se aplican los
> tokens y reglas de `docs/designer.md` y la constitución de `AGENTS.md`.

## Usuarios

Atleta que entrena con la sesión en vivo: quiere ver, mientras entrena, el
mapa muscular de fatiga con su cabecera plegable (tap), los chips de zona y
las gráficas, en cualquier pantalla (desde 320 dp), sin que la sección
desaparezca.

## Historias de usuario

- H1: Como usuario quiero ver la sección «Fatiga muscular» con su tap de
  plegado en la sesión en vivo desde que abro la sesión, para poder consultar
  el mapa mientras entreno.
- H2: Como usuario quiero que el mapa, los chips de zona y las gráficas se
  pinten sin errores en pantallas estrechas (320 dp), para no perder la
  sección por un desborde de layout.
- H3: Como usuario quiero que el título de la cabecera no tape el control
  Frente/Espalda cuando es largo («Fatiga: Cuádriceps (85%)»), para poder
  seguir alternando de vista.

## Alcance

- Corrección del layout de la cabecera de `LiveFatigueSection` (acotación del
  `ViewToggle` + título con `Expanded`/ellipsis).
- Eliminación del gate `!hasData → SizedBox.shrink()` en `LiveWorkoutView`
  (la sección se pinta siempre, con panel nulo si hace falta).
- `dispose()` completo de `_LiveWorkoutViewState`.
- Reparación de `test/live_fatigue_section_test.dart` (record literal) y
  tests de regresión del bug en `test/live_workout_view_test.dart`.
- Cierre con `flutter test` + `flutter analyze` en verde.

## Áreas de UI afectadas (A-xxx)

| Área | Fichero | Problema |
|---|---|---|
| A-1 Cabecera de la sección | `lib/ui/widgets/live_fatigue_section.dart` | 1 (flex sin acotar), 3 (título sin ellipsis) |
| A-2 Toggle compartido | `lib/ui/widgets/view_toggle.dart` | 1 (doc del contrato; sin cambio de comportamiento) |
| A-3 Sesión en vivo | `lib/ui/views/live_workout_view.dart` | 2 (gate), 4 (sin dispose) |
| A-4 Tests de la sección | `test/live_fatigue_section_test.dart` | 5 (no compila) |
| A-5 Tests de la sesión en vivo | `test/live_workout_view_test.dart` | 1 (regresión) |

## Requisitos funcionales (EARS)

### Visibilidad de la sección (problema 1)

- RF-1: Cuando `LiveWorkoutView` muestra una sesión en vivo, EL SISTEMA
  pinta la sección de fatiga completa (cabecera con tap, mapa muscular, chips
  de zona y gráficas) **sin ninguna excepción de layout**, independientemente
  de que el stream del panel ya haya emitido.
- RF-2: EL SISTEMA acota el ancho del `ViewToggle` en la cabecera de
  `LiveFatigueSection` con `Flexible` + `FittedBox(fit: BoxFit.scaleDown)`
  (mismo patrón que `progress_view.dart:496-504`), de modo que el `Row` de la
  cabecera nunca entrega `maxWidth: infinity` a un hijo con `flex > 0` y
  `FlexFit.tight`.
- RF-3: EL SISTEMA renderiza la cabecera de la sección también mientras el
  stream del panel está en `ConnectionState.waiting` o `done`, mostrando el
  estado vacío que `LiveFatigueSection` ya soporta («Sin fatiga» / «Sin
  series»); en ningún caso devuelve `SizedBox.shrink()` para esta sección.

### Cabecera en pantallas estrechas (problema 3)

- RF-4: CUANDO el ancho disponible es 320 dp o el título es largo, EL
  SISTEMA muestra el título en una sola línea con elipsis (`Expanded` +
  `maxLines: 1` + `TextOverflow.ellipsis`) y conserva el toggle
  Frente/Espalda visible y operativo, sin `RenderFlex overflow` (cierra
  D-031 de la 017).

### Ciclo de vida (problema 4)

- RF-5: CUANDO `_LiveWorkoutView` se desmonta, EL SISTEMA cancela
  `_fatigueNotifier`, `_clockTimer`, `_now` y remueve el
  `WidgetsBindingObserver`, y marca `_disposed = true`, de modo que
  `localDb.close()` en `tearDownAll` termina sin quedar colgado.

### Tests y cierre

- RF-6: EL SISTEMA mantiene en verde `test/live_fatigue_section_test.dart`
  (literales de record de `FatiguePanel`) con casos de cabecera visible,
  colapso por tap, ancho 320 dp sin excepción y chips con formato (cierra el
  D-033 pendiente de la 017).
- RF-7: EL SISTEMA cubre la regresión con un test en
  `test/live_workout_view_test.dart` que abra una sesión en vivo y verifique
  `find.byType(LiveFatigueSection)` (onstage) con `tester.takeException()`
  nulo; ese test **falla sin el fix**.

## Requisitos no funcionales

- RNF-1: `pubspec.yaml` **sin dependencias nuevas** (AGENTS.md, principio 2).
- RNF-2: **Sin migraciones** drift ni Postgres; sin tocar esquema ni sync.
- RNF-3: Sin `elevation` ni `BoxShadow` (minimalismo Apple); jerarquía por
  tipografía y espacio; targets táctiles ≥ 48 dp.
- RNF-4: Código e identificadores en inglés; documentación y mensajes al
  usuario en español.
- RNF-5: Cierre obligatorio de **cada** tarea con `flutter test` en verde y
  `flutter analyze` sin incidencias (AGENTS.md §Al terminar).
- RNF-6: Sin regresiones en las specs cerradas 001–017: los tests existentes
  siguen en verde (los fallos preexistentes se listan en `plan.md` §6).
- RNF-7: Sin cambios de comportamiento ni visuales en `ViewToggle` ni en el
  mapa de Progreso (solo acotación en el punto de uso).

### Verificación de los RNF

| RNF | Método de verificación |
|---|---|
| RNF-1 | `git diff pubspec.yaml` vacío en el cierre (T-005) |
| RNF-2 | `git diff supabase/migrations/ lib/data/local/tables/ lib/data/local/database.dart` vacío; sin `schemaVersion` nuevo |
| RNF-3 | `grep -rn "BoxShadow\|elevation" lib/ui/` sin incidencias nuevas; targets ≥ 48 dp medidos en el test de cabecera (T-002) |
| RNF-4 | `flutter analyze` sin `avoid_print`/nombres en español en código; mensajes de UI en español revisados en T-002/T-003 |
| RNF-5 | evidencia de cierre por tarea en `tasks.md` (`flutter test` + `flutter analyze`) |
| RNF-6 | baseline de `flutter test` antes/después comparado en `plan.md` §6.3 (T-005) |
| RNF-7 | `git diff lib/ui/widgets/view_toggle.dart` limitado a doc comment; `progress_view.dart` sin cambios |

## Casos límite

- Panel aún no emitido (`waiting`) → cabecera visible con «Sin fatiga».
- Panel emite vacío (`fatigue: {}`, `zones: []`) → cabecera visible, mapa sin
  tiñer y chips «Sin series».
- Ancho 320 dp con título largo → título en elipsis, toggle visible, sin
  desborde.
- Sección colapsada por tap → el cuerpo se oculta pero la cabecera (y el
  toggle) siguen pintándose.
- Desmontar la vista a mitad de sesión → sin timers ni suscripciones
  huérfanas (`dispose` completo).
- Cambiar Frente/Espalda → se limpia la selección si el músculo no es visible
  (`_syncSelection`, comportamiento ya existente).

## Fuera de alcance (018)

- Cualquier migración de esquema drift/Postgres o dependencia nueva.
- Cambios en el cálculo de fatiga, volumen o tendencia (dominio intacto).
- El resto del trabajo documentado de la 017 que **no llegó a implementarse**
  (`formatNumber`, `zoneChipLabel`/`zoneVolumeLabel`, barrido de decimales,
  unidad de los KPIs de `ExerciseInfoView`) → ver Q-018.
- Cambios de comportamiento/visual de `ViewToggle` (reparto de los segmentos)
  → ver Q-017.
- Pantallas nuevas, specs 011 y 013 pendientes, rediseño visual.

## Supuestos y preguntas abiertas

- Q-017: ¿Hacer `ViewToggle` autónomo (sustituir los `Expanded` de
  `_ToggleSegment` por ancho intrínseco) para que no reviente nunca aunque
  alguien lo ponga en un `Row` sin acotar? **Propuesta: no en esta spec** —
  cambiaría el reparto visual de los segmentos (hoy iguales, pasarían a
  según el texto) y el patrón `Flexible` + `FittedBox` ya probado en
  Progreso lo resuelve; queda documentado el contrato en el doc comment.
- Q-018: ¿Qué hacemos con el resto de la 017 documentada como cerrada pero
  sin implementar (`formatNumber`, `zoneChipLabel`, `zoneVolumeLabel`,
  barrido de decimales, `test/live_fatigue_section_test.dart` solo a medias)?
  **Propuesta:** nueva spec 019 de «completar la 017» (no reabrir 018 con
  formato numérico).
- Supuesto: la constitución vive en `AGENTS.md` + `docs/designer.md`
  (`docs/constitucion.md` / `docs/constitution.md` no existen); esta spec
  aplica esas reglas.
- Supuesto: no hay pantalla nueva, por lo que no se genera `DESIGN.md`.

## Decisiones (cerradas)

- **D-034**: spec **nueva 018** en vez de reabrir la 017: la 017 está
  declarada cerrada en `docs/specs/README.md` y su alcance es formato
  numérico/toggle; este bug es una **regresión de layout** introducida por su
  fix del toggle (commit `e2e8c1f`) y necesita trazabilidad propia.
- **D-035**: el fix vive en el **punto de uso**: en la cabecera de
  `LiveFatigueSection`, título con `Expanded` + elipsis y `ViewToggle` dentro
  de `Flexible(child: FittedBox(fit: BoxFit.scaleDown, …))`, replicando el
  patrón ya validado de `progress_view.dart:496-504`. `view_toggle.dart` solo
  recibe un doc comment con su contrato (requiere ancho acotado); **sin cambio
  de comportamiento ni visual** (RNF-7).
- **D-036**: se elimina el gate `if (!fatigueSnap.hasData) → SizedBox.shrink()`
  y se pasa `panel: fatigueSnap.data` (ya nullable en `LiveFatigueSection`):
  la sección pasa a estar siempre presente en la sesión en vivo.
- **D-037**: se añade `dispose()` a `_LiveWorkoutViewState`
  (`_fatigueNotifier`, `_clockTimer`, `_now`, `removeObserver`, `_disposed =
  true`): es prerequisite para que la suite cierre sin colgar `db.close()`
  (evidencia: sonda PROBE C) y arregla el guard muerto de `_disposed`.
- **D-038**: la reparación de `test/live_fatigue_section_test.dart` con
  literales de record (D-033 de la 017, nunca ejecutado) forma parte de esta
  spec: es el fichero de prueba del área que se toca y su fallo de
  compilación impediría el cierre en verde.

## Criterios de finalización

- Al abrir una sesión en vivo aparece la cabecera «Fatiga muscular» con su
  tap, el mapa, los chips y las gráficas, sin excepciones (RF-1, RF-7).
- Ningún ancho entre 320 y 640 dp produce `RenderFlex overflow` ni
  «non-zero flex but unbounded» en la cabecera (RF-2, RF-4).
- La sección no desaparece aunque el panel tarde en emitir (RF-3).
- Al salir de la sesión no quedan timers ni suscripciones (RF-5).
- `test/live_fatigue_section_test.dart` compila y pasa (RF-6).
- `pubspec.yaml` sin dependencias nuevas, sin migraciones y sin sombras.
- `flutter test` completo en verde y `flutter analyze` sin incidencias.
- `docs/specs/README.md` y `memory.md` actualizados con la fila 018.
