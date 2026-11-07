# Plan 018 — Sección de fatiga invisible en la sesión en vivo

Spec: [`spec.md`](spec.md) · Tareas: [`tasks.md`](tasks.md)

## 1. Diagnóstico (árbol de causas)

```
Síntoma: en LiveWorkoutView no aparece la sección de fatiga (cabecera, tap, mapa)
│
├─ [CAUSA RAÍZ] Cabecera de LiveFatigueSection es un Row(spaceBetween) con
│  hijos no flexibles → ViewToggle recibe maxWidth: infinity
│  └─ ViewToggle = Container → Row(mainAxisSize: min) → Expanded×2
│     └─ «RenderFlex children have non-zero flex but incoming width
│        constraints are unbounded» (flex.dart: Expanded = FlexFit.tight)
│        └─ la excepción sube por toda la cadena hasta
│           RenderSliverToBoxAdapter → el sliver queda con
│           geometry.visible == false → NO SE PINTA
│           (Viewport solo visita slivers visibles, viewport.dart:351)
│
├─ [REGRESIÓN] commit e2e8c1f (T-007 · M de la 017) quitó `if (!isExpanded)`
│  → el toggle pasa a renderizarse siempre dentro del Row
│  (antes la sección arrancaba expandida y el toggle no se pintaba: sin
│   excepción, pero tampoco toggle → bug P2 de la 017)
│
├─ [CONTEXTO] Progreso no falla: progress_view.dart:496-504 envuelve su
│  toggle en Flexible + FittedBox(scaleDown) → ancho acotado
│
└─ [AGRAVANTES]
   ├─ gate `!hasData → SizedBox.shrink()` (live_workout_view.dart:332-336):
   │  si el panel no emite, tampoco hay cabecera
   ├─ título sin Expanded/ellipsis (D-031 de la 017 incompleto)
   ├─ sin dispose() en _LiveWorkoutViewState → suscripciones abiertas y
   │  db.close() colgado en tests (observado)
   └─ test/live_fatigue_section_test.dart no compila (32 errores) → el único
      test capaz de cazar la regresión estaba roto
```

### Causas descartadas (evidencia)

| Hipótesis | Evidencia |
|---|---|
| `watchFatiguePanel()` no emite | sonda puntual: emite `(fatigue: {}, trend: [], zones: [])`, sin error ni `DONE` |
| `_profile()` (`getSingle`, `localProfiles id=1`) lanza | 1 fila `id=1`; Progreso (mismo `_profile()`) se ve |
| Caché `muscle_fatigue` vacío/corrupto | Progreso OK; el panel emite sin excepción |
| `_zonesAndTrend`/`muscleZoneStats`/`fatigueTrend` lanzan | lectura de `muscle_fatigue.dart:299-331` y `fatigue_trend.dart`: sin `firstWhere`/`single`/índices |
| `StreamBuilder` no recibe datos | instrumentación: `active`, `hasData=true`, `error=null` |

Resultado del barrido: **el fallo es de layout, no de datos.**

## 2. Arquitectura de la solución

### 2.1 Bloque A — Cabecera sin flex sin acotar (RF-1, RF-2, RF-4)

`lib/ui/widgets/live_fatigue_section.dart` (líneas 97-124):

```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Expanded(                                  // antes: Text a secas
      child: Text(
        isExpanded ? 'Fatiga muscular' : 'Fatiga: $peakLabel',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ),
    Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 24),
    Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Flexible(                         // acota el ancho del toggle
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: ViewToggle(showBack: _showBack, onChanged: ...),
        ),
      ),
    ),
  ],
)
```

- `Flexible` reparte el espacio restante y entrega a `FittedBox` un ancho
  **finito** → `ViewToggle` deja de recibir `infinity` → desaparece la
  excepción.
- `FittedBox(scaleDown)` conserva el tamaño intrínseco del pill cuando hay
  sitio (misma estética que en Progreso).
- `Expanded` en el título cierra el D-031 pendiente (elipsis a 320 dp).
- `lib/ui/widgets/view_toggle.dart`: solo doc comment con el contrato
  («requiere ancho acotado; envolver en `Flexible` + `FittedBox`»), sin
  cambios de comportamiento (RNF-7, Q-017).

### 2.2 Bloque B — Sección siempre presente (RF-3)

`lib/ui/views/live_workout_view.dart:329-347`:

```dart
StreamBuilder<FatiguePanel>(
  stream: _fatiguePanel,
  builder: (context, fatigueSnap) => SliverToBoxAdapter(
    child: LiveFatigueSection(
      panel: fatigueSnap.data,        // nullable: ya soportado por el widget
      onPanelChanged: (panel) {},
      showBack: _showBack,
    ),
  ),
)
```

Se elimina el `if (!fatigueSnap.hasData) return SizedBox.shrink()`.
`LiveFatigueSection` ya tolera `panel == null` (`live_fatigue_section.dart:70-73`:
fatigue/zones/trend vacíos + «Sin fatiga»).

### 2.3 Bloque C — Ciclo de vida (RF-5)

`lib/ui/views/live_workout_view.dart` — añadir en `_LiveWorkoutViewState`:

```dart
@override
void dispose() {
  _disposed = true;
  WidgetsBinding.instance.removeObserver(this);
  _clockTimer?.cancel();
  _now.dispose();
  _fatigueNotifier?.dispose();   // el notifier ya tiene dispose() async (spec 014)
  _restNotifier.cancel();        // fire-and-forget (ya existe, línea 93)
  super.dispose();
}
```

`FatigueNotifier.dispose()` existe y es `async` (Bug 4 de la 014); se llama
sin `await` desde `dispose()` de State (patrón de Flutter) — ver R-3.

### 2.4 Bloque D — Tests (RF-6, RF-7)

- `test/live_fatigue_section_test.dart`: reescribir con literales de record
  `(fatigue: …, zones: …, trend: …)` en lugar de `FatiguePanel(...)` y
  añadir: cabecera visible con toggle, tap de colapso, ancho 320 dp sin
  excepción (`tester.takeException()` nulo) y chips con formato.
- `test/live_workout_view_test.dart`: test de regresión que abra una sesión
  en vivo y exija `find.byType(LiveFatigueSection)` onstage +
  `tester.takeException() == null` (hoy: 0 widgets + 13 excepciones → el
  test falla sin el fix).

## 3. Ficheros a crear

- `docs/specs/018-seccion-fatiga-invisible/spec.md`
- `docs/specs/018-seccion-fatiga-invisible/plan.md`
- `docs/specs/018-seccion-fatiga-invisible/tasks.md`
- (sin `DESIGN.md`: no hay pantalla nueva)

## 4. Ficheros a modificar

| Fichero | Cambio | RF |
|---|---|---|
| `lib/ui/widgets/live_fatigue_section.dart` | `Expanded`+ellipsis en el título; `Flexible`+`FittedBox` en el toggle | RF-1, RF-2, RF-4 |
| `lib/ui/widgets/view_toggle.dart` | solo doc comment del contrato | RF-2 |
| `lib/ui/views/live_workout_view.dart` | quitar el gate `hasData`; añadir `dispose()` | RF-3, RF-5 |
| `test/live_fatigue_section_test.dart` | reescribir (record literal) + casos de cabecera/320 dp | RF-6 |
| `test/live_workout_view_test.dart` | test de regresión de visibilidad | RF-7 |
| `docs/specs/README.md` | fila 018 | cierre |
| `memory.md` | bitácora, D-034…D-038, Q-017/Q-018 | cierre |

**Sin** cambios en: `pubspec.yaml`, `supabase/migrations/`, esquema drift,
`lib/domain/*` (cálculo de fatiga intacto), `progress_view.dart`.

## 5. Orden de ejecución y fases

| Fase | Tarea | Objetivo |
|---|---|---|
| 1 | T-001 | Fix de layout de la cabecera (Bloque A) + doc del contrato |
| 2 | T-002 | Reparar `live_fatigue_section_test.dart` y cubrir cabecera/320 dp (Bloque D, RF-6) |
| 3 | T-003 | Quitar el gate `hasData` y añadir el test de regresión en vivo (Bloque B, RF-7) |
| 4 | T-004 | `dispose()` completo de `_LiveWorkoutViewState` + test de cierre (Bloque C, RF-5) |
| 5 | T-005 | Cierre: suite completa, analyze, `README.md`, `memory.md` |

Cada fase cierra con `flutter test` + `flutter analyze` en verde (AGENTS.md).

## 6. Estrategia de tests

### 6.1 Nuevos

| Test | Qué verifica | Falla sin el fix |
|---|---|---|
| `live_fatigue_section_test` · cabecera en `Scaffold` | sin excepción de layout y toggle presente | sí (mismo `RenderFlex` no acotado) |
| `live_fatigue_section_test` · 320 dp | título en elipsis, sin overflow | sí (desbordes) |
| `live_fatigue_section_test` · tap cabecera | colapsa/expande el cuerpo | — |
| `live_workout_view_test` · sección visible | `find.byType(LiveFatigueSection)` onstage + `takeException()` nulo | sí (0 widgets + 13 excepciones) |
| `live_workout_view_test` · desmontaje | `dispose` sin timers/suscripciones pendientes | sí (hoy no hay `dispose`) |

### 6.2 Regresión de specs cerradas

`flutter test` completo; sin tocar dominio ni esquema, el riesgo de regresión
se concentra en los tests de UI de la sesión en vivo.

### 6.3 Fallos preexistentes conocidos (baseline, ejecución 2026-11-07)

Ejecución de referencia: `flutter test` → **248 pass / 6 fail** antes de que
dos tests se colgaran 10 minutos y cortaran la suite:

| # | Fichero / test | Fallo | Relación con la 018 |
|---|---|---|---|
| 1 | `test/live_fatigue_section_test.dart` | no compila (32 errores: `FatiguePanel(...)` usado como constructor) | **lo repara T-002** (RF-6) |
| 2 | `test/routines_view_test.dart` «Iniciar Hoy instancía la sesión… (RF-2)» | `LateInitializationError: Field 'fatigueRepository' has not been initialized` en `live_workout_view.dart:91` | candidato a 1 línea en el `setUpAll` (T-003) |
| 3 | `test/routines_view_test.dart` «borrar pide confirmación y elimina la rutina con sus hijos» | **timeout de 10 minutos** (colgue) | candidato a T-004 (`dispose`/suscripciones abiertas) |
| 4 | `test/train_view_test.dart` «historial borrar en el feed pide confirmación… (RF-12)» | **timeout de 10 minutos** (colgue) | preexistente (diálogo de confirmación), fuera de alcance salvo que T-004 lo resuelva |
| 5 | `test/routine_detail_view_test.dart` «la ficha del ejercicio abre su detalle completo (RF-38)» | aserción | preexistente, fuera de alcance |
| 6 | `test/train_view_test.dart` «historial en imperial… (RF-4)» | aserción (unidades) | preexistente, fuera de alcance |

- `test/tmp_*` y `test/hacker_tmp_poc*` → **ya borrados** en el commit
  `1fb0cb5 clean` (Q-015 resuelto en el repositorio, pendiente de reflejarlo
  en `memory.md`).
- Nota: la ejecución se cortó tras **dos timeouts de 10 min**
  (`routines_view_test` y `train_view_test`), por lo que los tests de
  ficheros posteriores (p. ej. `weight_trend_*`, `workout_*`) no llegaron a
  correr en este baseline; T-005 repite la suite completa y exige **no
  empeorar** estas cifras.

## 7. Riesgos

| # | Riesgo | Mitigación |
|---|---|---|
| R-1 | `Flexible`+`FittedBox` altere el aspecto del pill frente al actual | mismo patrón que `progress_view.dart:496-504`; test de golden/visual manual a 320 y 411 dp |
| R-2 | Quitar el gate muestre la sección con datos vacíos durante un frame | `LiveFatigueSection` ya soporta `panel == null` (estado vacío «Sin fatiga»); RF-3 lo cubre con test |
| R-3 | `FatigueNotifier.dispose()` es `async` y no se puede esperar en `State.dispose()` | se dispara sin `await`; el notifier ya tolera dispose en vuelo (Bug 4 de la 014: espera `_inFlight` con timeout de 1 s) |
| R-4 | El `dispose()` nuevo rompa tests que desmontan la vista a mitad | patrón estándar `dispose`; se ejecuta la suite completa en T-005 |
| R-5 | Fallos preexistentes enmascaren la puerta en verde | baseline registrado en §6.3 antes de empezar; solo se exige no empeorar |

## 8. Supuestos

- La constitución vive en `AGENTS.md` + `docs/designer.md`
  (`docs/constitucion.md` no existe).
- No hay pantalla nueva → no se genera `DESIGN.md` (precedente: 017).
- Proyecto Flutter: no aplican carpetas `api/`/`web/`; el código vive en
  `lib/` y `test/`.
- El usuario reproduce el bug en app real; el fix se valida en app real y en
  los tests widget.
