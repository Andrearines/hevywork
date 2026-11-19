# Plan 021 — Gráfico de ejercicio y precisión numérica

Companion técnico de `spec.md`. Solo se ejecutan T-001 y T-002 de `tasks.md`.

## 1. Arquitectura de la reparación

### 1.1 Fuente real y puntos del gráfico

```text
RoutineDetailView / resto de entradas
        │  Exercise + AppDatabase + WorkoutRepository
        ▼
ExerciseInfoView
        │  exerciseHistory(exerciseId, página, offset)
        ├──────────────► páginas para tarjetas del historial
        └──────────────► fuente analítica del mismo ejercicio para KPI/gráfico
                              │
                              ▼
                 exerciseProgressPoints(metric)
                              │  dominio actual: warmups/incompletas fuera
                              ▼
                 filterByProgressWindow(points, window, now)
                              │  una sola vez, intervalo cerrado
                              ▼
               0/1 puntos: vacío · 2+: plot + insights
```

1. Corregir primero la entrada `RoutineDetailView`: es la causa verificada de
   repositorio nulo. No resolverlo inventando un repositorio desconectado ni
   ocultando el estado vacío.
2. Hacer testeable la preparación de puntos. Se reutiliza
   `exerciseProgressPoints()` y su enum de dominio, con un adaptador acotado al
   enum de UI si se decide conservar el contrato del widget. No mantener dos
   algoritmos de e1RM/carga/volumen.
3. Eliminar el prefiltrado temporal de `_computePoints()` y dejar solo
   `filterByProgressWindow()` (o mover ese helper puro a dominio sin cambiar su
   contrato público innecesariamente). Capturar `now` una vez por cálculo.
4. En ventana finita: `start = now.subtract(Duration(days: days))`; se admite
   `!date.isBefore(start) && !date.isAfter(now)`. En `all`, devolver los puntos
   sin ese recorte.
5. Mantener la paginación de tarjetas, pero no usar por defecto su primera
   página como sinónimo de «Todo». El implementador puede reutilizar las
   páginas existentes para la fuente analítica o añadir una consulta agregada
   específica del ejercicio si resulta más pequeña y eficiente. La decisión se
   documenta con la prueba de >10 sesiones; no se crean tablas ni sincronización.
6. El test de widget debe bombear el gráfico con dos puntos en su contexto real.
   Si el `Expanded` actual recibe altura no acotada en el sliver, se corrige
   únicamente la restricción de tamaño necesaria; no se rediseña el chart.

### 1.2 Política numérica común

```text
base de datos / dominio: double en kg o cm (sin cambios)
             │
             ├─ valor base kg ─► formatWeightKg ─┐
             ├─ valor base cm ─► formatLengthCm ─┤
             └─ valor ya mostrado ─► formatDisplay├─► texto, máx. 2 decimales
                                                   │
edición: texto visible ─► parse una vez ─► toKg/toCm│ (opcional: signo/miles)
             │                                      │
             └─ _rawKg se conserva si no hay edición┘
```

- `lib/domain/units.dart` es el punto común existente. `formatDisplay` ya
  redondea a centésimas; `formatWeightKg` y `formatLengthCm` ya convierten desde
  la base. No se añade otro formateador con el mismo cometido.
- Si el diagnóstico reproduce un defecto dentro de estas funciones, se corrige
  allí con casos de frontera. Si no, no se toca su algoritmo solo por preferencia
  estética. La política de dos cifras para no enteros (`78.40`) se conserva.
- Los wrappers de signo/miles reciben el texto ya formateado. No convierten otra
  vez el número y no redondean antes que la función común.
- Los conteos enteros no pasan por formateo decimal. Ratio, porcentaje, RPE,
  frecuencia y delta pueden usar `formatDisplay`, conservando su signo/unidad.
- La persistencia a 0.001 kg y los cálculos de e1RM/volumen se mantienen. Las
  conversiones de ida/vuelta se comprueban con tolerancia numérica, nunca con
  cuantización adicional del valor base.

### 1.3 Diagnóstico obligatorio de 40 → 39.99

Antes del cambio funcional, T-002 añade una prueba mínima o un arnés equivalente
que registre estos estados en orden:

1. Texto introducido y `_rawKg` antes de confirmar.
2. `displayWeightKg` y `toKg` en la confirmación.
3. `weightKg` recibido por `onConfirm` y persistido en drift.
4. Texto del controlador tras confirmar y tras desmontar/volver a montar.
5. Las mismas observaciones en una ida y vuelta +1.25/−1.25 kg y, si hace falta
   para reproducir, al alternar métrico/imperial.

El primer paso cuya salida sea incorrecta identifica el foco. En métrico el paso
2 es matemáticamente identidad; por eso no se propone de antemano cambiar
`kKgPerLb`, redondear a enteros o truncar. Si el caso exacto ya pasa en HEAD, se
amplía la reproducción al flujo aún no cubierto hasta encontrar el foco real y
se deja constancia en el resultado de la tarea.

## 2. Archivos probables

| Archivo | Cambio previsto | Tarea |
|---|---|---|
| `lib/ui/views/routine_detail_view.dart` | Pasar `localDb` y `workoutRepository` a la ficha | T-001 |
| `lib/ui/views/exercise_info_view.dart` | Separar fuente analítica de páginas visibles si hace falta; mantener carga real | T-001 |
| `lib/ui/widgets/exercise_progress_chart.dart` | Usar puntos de dominio, una ventana, métricas elegibles y tamaño válido | T-001, T-002 |
| `lib/ui/widgets/chart_enums.dart` | Intervalo temporal correcto e inyección de `now`; o adaptación al helper de dominio | T-001 |
| `lib/domain/exercise_stats.dart` | Solo si hace falta exponer/reutilizar preparación de puntos; no cambiar fórmulas | T-001 |
| `lib/data/repositories/workout_repository.dart` | Solo si la fuente analítica necesita una consulta propia; siempre por `exerciseId` | T-001 |
| `lib/domain/units.dart` | Punto común; corregir solo si la causa queda demostrada aquí | T-002 |
| `lib/ui/views/live_workout_view.dart` | Foco reproducido de edición/ajuste rápido y textos | T-002 |
| `lib/ui/views/routine_editor_view.dart`, `past_workout_editor_view.dart` | Sustituir `_fmtNumber` paralelo por el enfoque común | T-002 |
| `lib/ui/views/{train,progress,measures,profile,goal_editor,body_metric_editor}_view.dart` | Auditoría y focos de formato/unidad encontrados | T-002 |
| `lib/ui/widgets/*.dart` | Auditoría de `Text`, `TextPainter` y formateadores paralelos | T-002 |
| `test/routine_detail_view_test.dart` | Regresión de apertura con datos y dependencias | T-001 |
| `test/exercise_info_view_test.dart` | Integración con sesiones reales y fuente/paginación | T-001 |
| `test/exercise_progress_chart_test.dart` | 0/1/2+ puntos, métricas, ventanas, bordes y >10 | T-001 |
| `test/exercise_stats_test.dart`, `test/exercise_history_test.dart` | Solo si se toca dominio/repo | T-001 |
| `test/units_test.dart` | 40 exacto, ruido, 1.25, kg/lb e ida/vuelta | T-002 |
| `test/live_workout_view_test.dart` | Regresión 40 kg persistida/pintada y ajuste rápido actual | T-002 |
| Tests de vistas/widgets modificados | Regresión de cada foco global corregido | T-002 |
| `docs/specs/README.md`, `memory.md` | Estado y resultado real al cierre | Coordinación |

No se editan directamente `test/goldens/*.png`. No se modifica `pubspec.yaml`.

## 3. Secuencia y dependencias

1. **T-001 — gráfico:** fuente real → dominio/ventana → paginación analítica →
   regresión widget/integración → puerta completa.
2. **T-002 — números:** reproducción del primer valor erróneo → fix mínimo →
   auditoría/adopción del enfoque común → regresiones métrico/imperial → puerta.

No hay dependencia funcional entre ambos bugs. Se recomienda T-001 antes de
T-002 porque comparten `exercise_info_view.dart` y
`exercise_progress_chart.dart`; también evita mezclar el diagnóstico de datos
con cambios de formato. No se ejecuta la spec 020 ni tareas antiguas de 015/017.

## 4. Estrategia de pruebas

### T-001

- **Puro:** tabla de fechas relativas a un `now` fijo para 1M/3M/6M/1A/Todo;
  inicio y `now` incluidos, anterior/futuro excluidos en ventana finita.
- **Dominio:** dos sesiones válidas generan dos puntos ordenados; solo
  warmup/incompleta no genera puntos; volumen cero no inventa carga/e1RM.
- **Repositorio/integración:** dos sesiones `finished` del ejercicio aparecen al
  abrir desde `RoutineDetailView`; otra sesión activa/abandonada o de otro
  ejercicio no se incorpora. Más de diez sesiones alimenta «Todo» sin pulsar
  «Cargar sesiones anteriores».
- **Widget:** 0 y 1 punto mantienen vacío sin insights; 2 puntos muestran
  `chartPlotKey` y no «Sin datos» ni excepciones. Cambiar métrica/ventana
  recalcula. El test falla con la entrada actual sin repositorio.

### T-002

- **Unidades:** `formatWeightKg(40, metric) = 40`; ruido binario redondeado a
  centésimas; 40 kg = 88.18 lb; 100 lb persiste aprox. 45.359 kg; 1.25/61.25
  permanecen; cero y valores enteros sin `.0`.
- **Widget en vivo:** introducir 40, reps/RIR y confirmar produce exactamente
  40 en drift y `40` visible tras reconstruir; ningún nodo muestra 39.99.
  Ida/vuelta de ajuste rápido conserva 40; los chips son ±1.25/±2.50 kg (o
  ±2.5/±5 lb) y no ±1.3 kg.
- **Efectos secundarios:** volúmenes/e1RM se calculan con valores de dominio,
  no con texto redondeado; los tests de fórmulas se mantienen sin cambios de
  expectativa matemática.
- **Cada foco del barrido:** prueba unitaria o widget con métrico e imperial
  cuando la unidad sea relevante. No se reescriben expectativas solo para
  aceptar una regresión; la actualización de `+1.3` a `+1.25` sí está justificada
  por `weightStepOf` y el requisito de decimales legítimos.
- **Puerta:** `flutter test` y `flutter analyze` completos. Los fallos previos
  ajenos se registran con prueba y no se declaran corregidos ni se ocultan.

## 5. Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| Arreglar solo el texto vacío y seguir sin datos | Integración desde `RoutineDetailView` con BD real |
| Corregir una ventana y romper «Todo» | Tabla pura con `now` fijo y prueba de más de una página |
| Cargar sesiones de otros ejercicios | Repositorio acotado a `exerciseId`; prueba con segundo ejercicio |
| Maquillar 39.99 en UI mientras drift guarda otro valor | Aserción tanto en persistencia como en controlador |
| Conversiones repetidas pierden precisión | Conservar base sin edición, parse único y prueba de cambio de unidad |
| Unificar formatos eliminando decimales útiles | Casos 1.25/61.25 y prohibición de redondeo global a enteros |
| Actualizar PNG en vez del código | D-089: goldens solo consecuencia revisada, nunca el fix |
| Suite preexistente en rojo | Resultados explícitos; tarea no completada si la puerta no pasa |

## 6. Sin entregables adicionales

No proceden `DESIGN.md`, `docs/db.md`, `docs/api.md` ni carpetas nuevas de app:
no hay UI nueva, cambios de datos ni API. La constitución vigente es
`docs/constitution.md` junto con `AGENTS.md` (este último manda si difieren).
