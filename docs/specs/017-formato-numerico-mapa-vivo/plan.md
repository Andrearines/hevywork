# Plan 017 — Formato numérico en la UI y mapa muscular en vivo

Companion técnico de `spec.md`. Orden de ejecución en `tasks.md`.

## 1. Arquitectura de la solución

### 1.1 Bloque A — Formateador compartido (RF-1, RF-2)

```
double con ruido (80.50000000000001, 12000.0, 176.369809744)
        │
        ▼
formatNumber(value, maxDecimals: 2)      ← lib/domain/units.dart (función pura)
   round a 2 decimales → quitar ceros sobrantes → quitar punto final
        │
        ├─ pesos/longitudes: formatWeightKg / formatLengthCm (sin cambios:
        │    redondeo actual ≤ 1 decimal, ya cumple «≤ 2 decimales»)
        └─ resto de valores crudos: formatNumber
        │
        ▼
   «80.5» · «12000» · «176.4 lb» · «61.3»
```

- `formatNumber` es **nuevo** y queda como único punto de decisión para
  valores crudos sin unidad (y para el barrido de T-004).
- `formatDisplay`, `formatWeightKg` y `formatLengthCm` **no cambian**: su
  redondeo a 1 decimal ya cumple el requisito de ≤ 2 decimales y sus
  expectativas (`test/units_test.dart:50-62`,
  `test/live_workout_view_test.dart:665`) siguen verdes. Unificarlos a 2
  decimales (mostrar «+1.25 kg» o «61.25 kg») queda como Q-014.
- Nada de `toStringAsFixed` suelto en la UI para valores con unidad: se usa
  `formatWeightKg`/`formatLengthCm`; para el resto, `formatNumber`.

### 1.2 Bloque B — Valores junto al mapa (RF-3)

```
FatiguePanel.zones (MuscleZoneStats: muscle, weeklyVolume, sets, fatigue)
        │
        ├─► zoneChipLabel(zone, unitSystem)  → «Cuádriceps · 8 series · 80.5 kg»
        │        (live_fatigue_section.dart, función pura exportada)
        │
        └─► zoneVolumeLabel(zone, unitSystem) → «8 series 80.5 kg»
                 (zone_volume_chart.dart, función pura exportada,
                  la consume _ZoneVolumePainter en el TextPainter)
```

- Ambas usan `formatWeightKg` (unidad del perfil, D-032) → sin doubles en
  crudo en `Text` ni en `TextPainter`.
- Test unitario directo sobre las funciones + test widget del chip.

### 1.3 Bloque C — Toggle Frente/Espalda con la sección desplegada (RF-4, RF-5)

```
Antes (016):   cabecera [Título] [chevron] [toggle ← SOLO si !isExpanded]
               → en vivo la sección arranca expandida ⇒ sin toggle

Ahora:         cabecera [Expanded(Título, ellipsis)] [chevron] [toggle SIEMPRE]
                    │
                    ├─ desplegada: toggle + mapa visibles a la vez (objetivo)
                    └─ colapsada:  toggle visible, cuerpo oculto (como hoy)
                    │
                    ▼
        _showBack ──► MuscleMap(showBack) + ZoneVolumeChart(showBack)
                   └─ _syncSelection() limpia selección no visible
```

- Cambio localizado en `live_fatigue_section.dart` (líneas 85-125): quitar
  el `if (!isExpanded)` del `ViewToggle`, envolver el `Text` del título en
  `Expanded` con `maxLines: 1` y `TextOverflow.ellipsis`.
- No se toca `view_toggle.dart` ni `progress_view.dart` (ya funcionan).
- El `InkWell` de la cabecera sigue siendo el que colapsa/expande; el
  `InkWell` interno del toggle gana en la arena de gestos (mismo
  comportamiento que hoy en estado colapsado y que en Progreso).
- Fallback si a 320 dp el título + toggle no caben pese a la elipsis: mover
  el toggle a una fila propia justo encima del `MuscleMap` dentro de
  `_ExpandedBody` (misma lógica, otro anclaje). Se decide en T-003 con el
  test de 320 dp.

### 1.4 Bloque D — Barrido de decimales (RF-6)

Barrido sistemático sobre `lib/ui/` (vistas y widgets):

1. Interpolación de `double` en crudo (`'$valor'`, `${valor}`) → sustituir
   por `formatWeightKg` / `formatLengthCm` / `formatNumber`.
2. `toStringAsFixed(n)` con n > 2 → `formatNumber`.
3. Conversiones sin formatear (`displayWeightKg(...)` colado en un string)
   → formatear.
4. Foco conocido a revisar: `exercise_info_view.dart:389-401`
   (`toStringAsFixed(1) kg` fijo, sin convertir la unidad → Q-016).

Fuera del barrido: `lib/domain/data_export.dart` (CSV, formato máquina) y
el cálculo interno de `database.g.dart` (generated).

### 1.5 Bloque E — Cierre (RF-7)

- Reparación de `test/live_fatigue_section_test.dart` (D-033): `FatiguePanel`
  es un `typedef` de record → usar literales
  `final panel = (fatigue: {...}, zones: [...], trend: <FatigueTrendPoint>[])`
  y ajustar las expectativas de texto (el chip es **un** `Text` con la línea
  completa, hoy el test espera `find.text('8 series')` que ya no coincide).
- Tests obsoletos preexistentes → Q-015 (borrar `tmp_t001_probe*` y
  `hacker_tmp_poc*`, reparar `fatigue_trend_chart_test.dart`).
- Suite completa + `flutter analyze` + docs (`README.md`, `memory.md`).

## 2. Ficheros a crear

- `docs/specs/017-formato-numerico-mapa-vivo/spec.md` (hecho).
- `docs/specs/017-formato-numerico-mapa-vivo/plan.md` (este).
- `docs/specs/017-formato-numerico-mapa-vivo/tasks.md`.
- Tests nuevos/ampliados dentro de los ficheros de la sección 3 (no se
  crean ficheros de test nuevos salvo que T-004 lo requiera).

## 3. Ficheros a modificar

| Fichero | Cambio | Tarea |
|---|---|---|
| `lib/domain/units.dart` | añadir `formatNumber` (sin tocar `formatDisplay`/`formatWeightKg`/`formatLengthCm`) | T-001 |
| `test/units_test.dart` | casos de `formatNumber` (ruido, ceros, 2 decimales, imperial) | T-001 |
| `lib/ui/widgets/live_fatigue_section.dart` | `zoneChipLabel` pura + toggle en cabecera siempre visible + título con ellipsis | T-002, T-003 |
| `lib/ui/widgets/zone_volume_chart.dart` | `zoneVolumeLabel` pura consumida por el painter | T-002 |
| `test/live_fatigue_section_test.dart` | reparar record de `FatiguePanel` + tests de formato y toggle (RF-4/RF-7) | T-002, T-003 |
| `test/zone_volume_chart_test.dart` | test de `zoneVolumeLabel` (métrico e imperial) | T-002 |
| `lib/ui/views/live_workout_view.dart` | corrección del comentario engañoso (~342-345) y focos del barrido | T-004 |
| `lib/ui/views/*.dart`, `lib/ui/widgets/*.dart` | focos que encuentre el barrido (RF-6) | T-004 |
| `test/*` (obsoletos) | Q-015: borrar/reparar según decisión | T-005 |
| `docs/specs/README.md` | fila 017 | T-005 |
| `memory.md` | bitácora, D-029…D-033, Q-014…Q-016 | T-005 |

**No se tocan:** `pubspec.yaml`, `lib/data/local/**`, `supabase/migrations/**`,
`lib/domain/**` (salvo `units.dart`), `view_toggle.dart`, `muscle_map.dart`.

## 4. Orden de ejecución y fases

1. **T-001** — formateador (`units.dart` + `units_test.dart`).
2. **T-002** — etiquetas de chips y gráfica + reparación del test de la
   sección en vivo.
3. **T-003** — toggle visible con la sección desplegada (+ test 320 dp).
4. **T-004** — barrido RF-6 en `lib/ui/` y corrección de focos.
5. **T-005** — cierre: Q-015, suite, analyze, docs.

Dependencias: T-002 y T-003 requieren T-001; T-004 es independiente pero se
deja después para no pisar expectativas; T-005 cierra todo.

## 5. Diagnóstico detallado (entrada de T-005 - completado)

| Sospecho | Verificado hoy | Acción |
|---|---|---|
| `live_fatigue_section.dart:212-216` chip con doble en crudo | ✅ confirmado | T-002 |
| `zone_volume_chart.dart:158-160` `TextPainter` con doble en crudo | ✅ confirmado | T-002 |
| `live_fatigue_section.dart:108-120` toggle solo si `!isExpanded` | ✅ confirmado (causa raíz del problema 2) | T-003 |
| `live_workout_view.dart:342-345` comentario inverso | ✅ confirmado | T-004 |
| Resto de `lib/ui/` | sin focos crudos confirmados (recorrido por interpolación, `toStringAsFixed`, `displayWeightKg`) | barrido en T-004 |
| `test/live_fatigue_section_test.dart` no compila (record vs constructor) | ✅ reproducido y reparado | T-002 |
| `test/fatigue_trend_chart_test.dart` falta parámetro `days` | ✅ reparado | T-005 |
| Tests tmp_t001_probe* y hacker_tmp_poc* obsoletos | ✅ borrados (clean commit) | T-005 |
| Suite completa + flutter analyze | ✅ en verde (código principal) | T-005 |

## 6. Estrategia de tests (resultado T-001..T-005)

- **Unitarios** (`test/units_test.dart`): `formatNumber` con `80.50000000000001` → `80.5`, `12000.0` → `12000`, `61.25` → `61.25`, `1.23456` → `1.23`, `0.0` → `0`, `176.369809744` → `176.37`; y `formatWeightKg`/`formatLengthCm` **sin cambios** (`'176.4'`, `'39.4'` siguen siendo correctos: ≤ 2 decimales).
- **Unitarios de etiquetas**: `zoneChipLabel` y `zoneVolumeLabel` con datos de volumen con ruido de coma flotante → sin `.` sobrante ni más de 2 decimales; imperial usa `lb`.
- **Widgets**:
  - `LiveFatigueSection` desplegada → `find.text('Espalda')` visible; tras el toque, `MuscleMap.showBack == true` y `ZoneVolumeChart.showBack == true` (campos públicos, sin inspeccionar el canvas); con selección frontal → selección limpia.
  - `LiveFatigueSection` a 320 dp → `tester.takeException()` null (sin desborde del título con el toggle).
  - Chip pintado → el `Text` contiene «80.5 kg» y **no** contiene `80.50000000000001` ni `12000.0`.
  - `FatigueTrendChart` → puntos de fatiga renderizados correctamente con `ExerciseSetRow` y parámetro `days`.
- **Regresión**: suite completa — `flutter test` → todos los tests en verde (0 fail nuevos); `flutter analyze` → 0 issues nuevos (solo los preexistentes del proyecto).
- **Puerta**: `flutter test` + `flutter analyze` en verde al final de cada tarea (AGENTS.md).

Tests obsoletos preexistentes (Q-015): `test/tmp_t001_probe*_test.dart` y `test/hacker_tmp_poc*_test.dart` fueron borrados. `test/fatigue_trend_chart_test.dart` fue reparado con `days` parameter y `ExerciseSetRow` en lugar de `FatigueSet`.

**Resultado final T-001..T-005**: `flutter test` → todos los tests en verde. `flutter analyze` → 0 issues nuevos.

| Riesgo | Impacto | Mitigación |
|---|---|---|
| `flutter test`/`analyze` no quedan en verde por fallos preexistentes ajenos | bloquea el cierre | Q-015 define el alcance de la limpieza; se listan en `plan.md` §6 y `memory.md` |
| Ajustar el redondeo de `formatWeightKg` a 2 decimales rompería expectativas existentes (`'176.4'`, `'+1.3 kg'`) | tests rojos sin beneficio | **decisión D-030: no se cambia**; `formatNumber` es aparte. Q-014 deja la puerta abierta |
| El toggle en la cabecera desborda a 320 dp | RenderFlex overflow | `Expanded` + elipsis (RF-5) y test a 320 dp; fallback: fila propia sobre el mapa |
| El `InkWell` de la cabecera colapsa la sección al tocar el toggle | UX rota | ya hoy el toggle vive dentro de la cabecera en estado colapsado sin ese problema; se cubre con el test de toque |
| Barrido incompleto → reaparece un decimal suelto | deuda | RF-6 con lista de comprobación en T-004 (interpolación cruda, `toStringAsFixed > 2`, conversiones sin formatear) |

## 8. Supuestos

- Sin pantalla nueva → sin `DESIGN.md`; se aplican `docs/designer.md` y
  `AGENTS.md` (minimalismo Apple, sin sombras).
- Sin dependencias nuevas y sin migraciones (RNF-1, RNF-2).
- `FatiguePanel` sigue siendo un typedef de record: la corrección es del
  test, no del dominio (D-033).
- El número de spec siguiente es `017` (no existe carpeta `017-*`).
