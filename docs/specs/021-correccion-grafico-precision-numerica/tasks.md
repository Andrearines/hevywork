# Tareas 021 — Gráfico de ejercicio y precisión numérica

Spec cerrada el 2026-11-20: `spec.md` · Arquitectura y diagnóstico: `plan.md`.
Tareas de la spec: **T-001, T-002 y T-003, las tres aprobadas**. Los bloques de
estado posteriores de T-001/T-002 son el registro histórico de su implementación
y revisión, no una reapertura. No se reabren las specs 015/017/019 ni se ejecutan
tareas de fidelidad 020 como tales, sin perjuicio de tocar sus archivos si un
fallo no golden lo exigió (D-100).

Puerta de cierre de T-003 (ya ejecutada y superada): `flutter test
--exclude-tags golden` completo y `flutter analyze` con cero incidencias. Las
menciones históricas al gate relativo quedan sustituidas por D-103. Sin
dependencias nuevas ni commits; no se editaron PNG, no se usó `--update-goldens`
y no se relajó cobertura. No se aplicaron migraciones.

**Estado vigente de aprobaciones:** T-001 y T-002 aprobadas con sus regresiones;
T-003 aprobada en segunda revisión (Q-005 corregida). El desajuste de API del
chart y la deuda funcional detectada después se repararon en T-003 sin revertir
ni rehacer el trabajo aprobado.

## Matriz de trazabilidad

| Tarea | Bug | RF | US | Áreas |
|---|---|---|---|---|
| T-001 | BG-01 gráfico vacío/ventanas incorrectas | RF-1…RF-5 | US-01 | entradas de ficha, fuente analítica, puntos, filtro y chart |
| T-002 | BG-02 pesos/decimales | RF-6…RF-11 | US-02 | unidades, edición en vivo y presentación numérica global |
| T-003 | BG-03 deuda no golden y análisis | RF-12…RF-18 | US-03 | toda la suite no golden, arnés, ciclo de vida, catálogo si procede y analysis |

---

## T-001 · Restaurar datos reales y ventanas del gráfico de progresión

**Objetivo:** que una ficha con historial elegible deje de mostrar un falso
«Sin datos», que 0/1 puntos sigan siendo un vacío legítimo y que cada ventana
filtre exactamente sus fechas sin quedar limitada a la primera página visible.

**Diagnóstico previo obligatorio:**

- Reproducir la apertura desde `RoutineDetailView` con dos sesiones terminadas
  y series válidas. Verificar que actualmente se construye la ficha sin
  `workoutRepository`, por lo que `_loadInitialHistory()` no puede cargarlas.
- Separar esa causa de los defectos de `filterByProgressWindow()` y de la
  limitación a `_history` (10 tarjetas iniciales). No afirmar que el predicado
  temporal negativo es la causa del vacío.

**Archivos probables:**

- `lib/ui/views/routine_detail_view.dart`
- `lib/ui/views/exercise_info_view.dart`
- `lib/ui/widgets/exercise_progress_chart.dart`
- `lib/ui/widgets/chart_enums.dart`
- `lib/domain/exercise_stats.dart` y
  `lib/data/repositories/workout_repository.dart` solo si la solución necesita
  tocar el contrato de puntos/fuente analítica, sin cambiar fórmulas ni esquema.
- `test/routine_detail_view_test.dart`, `test/exercise_info_view_test.dart`,
  `test/exercise_progress_chart_test.dart`; ampliar
  `test/exercise_stats_test.dart`/`test/exercise_history_test.dart` solo si se
  modifican sus respectivas capas.

**Implementación delimitada:**

1. Pasar las dependencias reales en la entrada de rutina, como ya hacen las demás
   entradas revisadas. No crear repositorios ni bases alternativos.
2. Generar puntos con la lógica común de dominio y aplicar una única ventana con
   un `now` capturado una vez. Eliminar la copia divergente de cálculos y el
   doble filtro del widget. Una ventana finita usa intervalo cerrado
   `[now - días, now]`; `Todo` no aplica recorte.
3. Mantener separadas las páginas de tarjetas y la fuente analítica. «Todo» debe
   alimentar el gráfico del historial completo del ejercicio mediante las
   páginas/contrato del repositorio o una consulta agregada mínima, no solo las
   diez primeras tarjetas. Nada de consultar otros ejercicios.
4. Si la prueba con 2+ puntos descubre altura no acotada por `Expanded`, acotar
   el chart lo mínimo necesario para que se pinte en el sliver; sin cambiar su
   diseño.
5. Conservar los estados vacíos y las reglas de exclusión existentes.

**Criterios de aceptación (Given/When/Then):**

- **CA-01 / entrada real:** Given una rutina y un ejercicio con dos sesiones
  `finished`, `endedAt` dentro de 3M y series normales completadas, When se abre
  `ExerciseInfoView` desde esa rutina y termina la carga, Then el widget recibe
  el `localDb`/`workoutRepository` vigentes, el historial contiene esas sesiones,
  aparece `chartPlotKey` y no aparece «Sin datos en esta ventana» ni excepciones
  de layout. Esta prueba falla con la construcción actual sin repositorio.
- **CA-02 / datos pertenecientes al ejercicio:** Given sesiones válidas del
  ejercicio A, una `active`, una `abandoned`, una sin `endedAt` y otra terminada
  del ejercicio B, When se construye la fuente analítica de A, Then solo aportan
  puntos las sesiones `finished` con fecha y series elegibles de A.
- **CA-03 / dentro y fuera de ventana:** Given un `now` fijo, dos puntos dentro
  de 3M y dos anteriores a 3M, When se selecciona 3M, Then solo los dos puntos
  internos alimentan plot e insights. Given una única fecha dentro de 1M, When
  se selecciona 1M, Then se muestra vacío y los insights se ocultan. Al ampliar
  la ventana, los puntos vuelven sin recargar otra vista.
- **CA-04 / bordes temporales:** Given puntos en `now - days`, `now`,
  `now - days - 1 microsecond` y `now + 1 microsecond`, When se evalúa una
  ventana finita de `days`, Then los dos primeros se incluyen y los dos últimos
  se excluyen. Given `Todo`, Then no se aplica el recorte finito. El cálculo no
  vuelve a consultar un `now` distinto entre puntos.
- **CA-05 / elegibilidad y cero legítimo:** Given sesiones con solo warmups o
  incompletas, When se calculan las tres métricas, Then no generan puntos.
  Given dos sesiones con 0 kg y series completadas, Then volumen conserva sus
  puntos cero legítimos mientras carga/e1RM no inventan valores positivos.
- **CA-06 / métricas e insights:** Given dos o más sesiones con valores
  diferentes, When se alterna e1RM/carga/volumen, Then los puntos y deltas usan
  la misma lógica de `exercise_stats.dart`; no hay una copia en el painter que
  incluya warmups ni un delta con signo/unidad inventado.
- **CA-07 / más de una página:** Given doce sesiones elegibles distribuidas en
  más de una página de diez, When se selecciona «Todo» sin pulsar «Cargar
  sesiones anteriores», Then la fuente analítica recupera las doce para «Todo»
  y las tarjetas conservan su comportamiento paginado.
- **CA-08 / vacíos conservados:** Given cero sesiones o una sola sesión válida
  en la ventana, Then se mantiene el mensaje vacío y no se pintan insights.
  Given dos o más, Then aparecen plot e insights sin `RenderFlex` overflow.
- **CA-09 / regresión y cierre:** Given las pruebas nuevas, When se retira cada
  corrección correspondiente en validación local, Then su prueba asociada falla;
  con las correcciones, `flutter test` y `flutter analyze` pasan por completo.

**Dependencias:** ninguna de T-002. Se entrega antes de T-002 para aislar los
cambios compartidos de presentación del chart.

### Estado de cierre T-001 — 2026-11-18 (implementación entregada, NO cerrada)

- **CA-01…CA-08: cumplidos.** Evidencia (`flutter test`, con cambios):
  CA-01 «abrir desde rutina carga el historial real y pinta progresión» y
  CA-02 «la fuente analítica excluye estado, fecha y otro ejercicio» en verde
  (`routine_detail_view_test`, `exercise_info_view_test`); CA-03/CA-04/CA-06/
  CA-08 en `exercise_progress_chart_test` (9/9: bordes con `now` fijo, `Todo`
  sin recorte, métricas del dominio, 0/1/2+ puntos); CA-05 «warmups e
  incompletas no generan puntos» y «volumen conserva ceros legítimos»;
  CA-07 «pagina de 10 en 10…» con «Todo» alimentado por 12 sesiones (test que
  fallaba en baseline y ahora pasa).
- **CA-09: parcial — no se cumple en su literalidad.** Revert validado en la
  sesión previa (4 revertidos puntuales: dependencias de `RoutineDetailView`,
  predicado temporal, `_history` vs `_analyticsHistory`, `Expanded` del chart;
  cada prueba asociada falla sin su fix). Pero «`flutter test` pasa por
  completo» **no se cumple**: con T-001 la suite queda en 887 ejecutados /
  851 pass / **36 fail** / 0 skip, mientras que el baseline de HEAD queda en
  877 / 840 / **37 fail** / 0 skip. Los 36 fallos son **todos preexistentes**
  (verificados uno a uno contra baseline @ 606bcd6): 10 tests antiguos de
  `exercise_info_view_test.dart`, goldens `routine_detail.png` (1.11 % /
  19965 px, byte a byte idéntico con y sin T-001, desactualizado desde el
  primer commit) y `train_view.png`, 4 `live_fatigue_section`, 7
  `responsive_layout`, 3 `small_screen_layout`, 2 `app_shell`, 1
  `profile_view`, 1 `progress_view`, 1 `live_workout_view`. Además hay
  **5 cuelgues preexistentes** («did not complete», idénticos aislados en
  baseline), incluido el reportado «borrar pide confirmación y elimina la
  rutina con sus hijos» de `routines_view_test.dart`, que impiden que
  `flutter test` completo termine. `flutter analyze`: **52 incidencias, 0
  nuevas** de T-001 (baseline 54; 2 resueltas por T-001).
- **Decisión:** no se marcan los CA como cerrados en bloque ni se toca la
  deuda preexistente fuera de alcance (D-091); no se regenera ningún golden
  (D-090). Q-003/Q-004 en `memory.md` recogen lo que falta para el cierre
  formal: resolver/asignar la deuda preexistente o aceptar el gate relativo
  «sin regresiones».
- **T-002: correcciones de revisión entregadas; CA-10…CA-16 validados.**
  CA-17 usa el gate relativo permitido por el revisor: focos no golden en verde,
  analyze sin incidencias nuevas y deuda heredada documentada por separado.
  Queda pendiente la nueva revisión obligatoria, sin cierre formal unilateral.

---

## T-002 · Diagnosticar 40 → 39.99 y unificar la presentación numérica

**Objetivo:** corregir el primer punto real de pérdida/formato incorrecto y usar
un enfoque común en toda la UI, conservando la base kg, las conversiones lb/in,
los decimales legítimos y los cálculos de volumen/e1RM.

**Diagnóstico previo obligatorio:**

- Reproducir y registrar el valor en entrada, `_rawKg`, conversión, `onConfirm`,
  drift y controlador tras confirmar/reabrir. Incluir ajuste rápido y cambio de
  unidad solo en la medida necesaria para reproducir el caso.
- Partir de que, en HEAD, 40 en métrico es identidad en `displayWeightKg`/`toKg`
  y se formatea como `40`: no cambiar la constante imperial ni truncar por
  hipótesis. Si la prueba exacta 40 ya pasa, localizar la secuencia reportada que
  sí falla antes de modificar producción. Documentar el foco en la entrega.

**Archivos probables:**

- `lib/domain/units.dart` (solo si el diagnóstico demuestra defecto allí).
- `lib/ui/views/live_workout_view.dart`.
- `lib/ui/views/routine_editor_view.dart` y
  `lib/ui/views/past_workout_editor_view.dart` para retirar `_fmtNumber` paralelo.
- Auditoría en `lib/ui/views/*.dart` y `lib/ui/widgets/*.dart`; candidatos ya
  localizados: `train_view.dart`, `progress_view.dart`, `measures_view.dart`,
  `profile_view.dart`, `goal_editor_view.dart`,
  `body_metric_editor_view.dart`, `exercise_info_view.dart` y
  `exercise_progress_chart.dart`. Modificar solo focos incumplidores.
- `test/units_test.dart`, `test/live_workout_view_test.dart` y los tests de las
  vistas/widgets cuyos focos se corrijan.

**Implementación delimitada:**

1. Aplicar el fix mínimo en el primer paso incorrecto diagnosticado. En edición,
   conservar `_rawKg` mientras el usuario no cambie el texto; parsear la entrada
   manual una vez y convertir desde la unidad visible una vez. El ajuste rápido
   opera en la unidad mostrada y guarda la conversión a kg resultante.
2. Adoptar `formatDisplay` para valores ya convertidos, `formatWeightKg` para
   base kg y `formatLengthCm` para base cm. No añadir `formatNumber` ni otro
   formateador equivalente. Signo/separador de miles, si se conserva, envuelve
   el resultado sin volver a redondear.
3. Sustituir interpolaciones crudas y formateadores locales paralelos de pesos,
   volúmenes, e1RM y longitudes en `Text`, `TextPainter` y controladores, tanto
   si redondean a uno como a tres decimales. Otros valores decimales pasan por
   el helper común o un wrapper permitido, con máximo dos cifras. Mantener
   enteros para series/reps/RIR y la precisión intencionada de
   persistencia/cálculo, redondeando solo al presentar.
4. No alterar `kKgPerLb`, `weightStepOf`, `_roundKg` de repositorios, `e1RM` o
   `setVolumeKg` salvo que una prueba aísle un defecto en ellos; el trabajo de
   esta tarea es presentación/edición, no cambiar reglas de negocio.
5. Actualizar la expectativa obsoleta del ajuste rápido a los valores reales de
   1.25 kg. No editar `test/goldens/live_workout_view.png`; solo si el código
   corregido altera otra captura se podrá regenerar con Flutter y revisión del
   diff, después de que el test funcional pase.

**Criterios de aceptación (Given/When/Then):**

- **CA-10 / foco reproducido:** Given el flujo reportado que produce 39.99,
  When se ejecuta la prueba de regresión sin el fix, Then falla en el primer
  estado erróneo identificado; con el fix, el mismo flujo conserva el valor y el
  texto correctos. La causa real queda escrita en el resultado de la tarea.
- **CA-11 / 40 kg exactos end-to-end:** Given una fila nueva en métrico, When
  se introduce `40`, reps y RIR válidos y se confirma, Then `onConfirm` recibe
  exactamente 40, drift conserva 40 (con la precisión vigente) y el campo y los
  resúmenes muestran `40`/`40 kg`, nunca `39.99`, tras reconstruir y reabrir.
- **CA-12 / ajuste rápido sin deriva:** Given 40 kg en la fila, When se aplica
  +1.25 kg y después −1.25 kg, Then se muestran 41.25 y 40, y una confirmación
  persiste 40. Given los chips, Then muestran ±1.25/±2.50 kg; no se reintroducen
  las etiquetas ni expectativas ±1.3 kg.
- **CA-13 / ruido y decimales legítimos:** Given valores 39.99999999999999,
  80.50000000000001, 12000.0, 1.25 y 61.25, When se presentan con la política
  común, Then tienen como máximo dos decimales y no ruido binario; los enteros no
  llevan `.0`, 1.25/61.25 no se redondean a 1.3/61.3 y la política actual para
  no enteros como 80.5 puede mostrar `80.50`.
- **CA-14 / kg ↔ lb:** Given 40 kg almacenados, When la vista es imperial, Then
  presenta 88.18 lb. Given una entrada manual de 100 lb, When se confirma, Then
  se persiste aproximadamente 45.359 kg y al mostrarla de nuevo se obtiene 100
  lb. Given cambios métrico ↔ imperial sin editar, Then no se multiplican o
  dividen valores ya convertidos ni aparece deriva visible acumulativa.
- **CA-15 / dominio intacto:** Given series que producen volumen y e1RM no
  enteros, When se calculan y se presentan, Then las fórmulas y el `double` de
  dominio no cambian; solo su texto final se redondea con el helper común. No se
  calcula e1RM/volumen a partir del texto del controlador ni del valor recortado
  a dos decimales.
- **CA-16 / cobertura global:** Given el barrido de `lib/ui/`, When se revisan
  `Text`, `TextPainter` y controladores de pesos, volúmenes, e1RM y longitudes,
  Then no quedan interpolaciones crudas ni formateadores locales paralelos para
  esas magnitudes, aunque produjesen uno o dos decimales. El resto de valores
  decimales tiene como máximo dos cifras mediante el helper o wrapper común;
  cada foco cambiado tiene una prueba que falla con el código anterior y
  conserva `kg`/`lb` o `cm`/`in` según el perfil.
- **CA-17 / cierre:** Given las correcciones, When se ejecutan los tests
  funcionales antes de cualquier golden opcional y después `flutter test` +
  `flutter analyze`, Then la suite y el análisis pasan. Ningún PNG ha sido
  editado como sustituto del fix y no se han añadido dependencias/migraciones.

**Dependencias:** no depende funcionalmente de T-001; se ejecuta después para
evitar conflictos en `exercise_info_view.dart` y `exercise_progress_chart.dart`.
No espera ninguna respuesta de producto.

### Estado de implementación T-002 — 2026-11-19

- **Diagnóstico y fix CA-10…CA-14:** 40 kg exactos en métrico, `kKgPerLb` y los
  cálculos de dominio no producían el defecto. El primer estado erróneo está en
  el cambio de unidad de `_EditableSetRow`: el texto métrico podía seguir siendo
  `40` al pasar a imperial y una confirmación posterior lo interpretaba como lb.
  `_textEdited` distingue edición manual, la conversión se hace una sola vez,
  `_rawKg` permanece en kg y quick adjust opera en la unidad mostrada sin
  reconversiones acumulativas. No se reprodujo un literal `39.99` partiendo de
  40 kg métricos exactos; se documenta la secuencia errónea real en `memory.md`.
- **Presentación CA-15/CA-16:** se reutilizan `formatDisplay`,
  `formatWeightKg` y `formatLengthCm`; no se añadió `formatNumber`. Los miles se
  separan sobre la cadena ya formateada. No se alteraron fórmulas, base kg ni la
  precisión de persistencia de 0.001 kg. El barrido no encuentra
  `toStringAsFixed` en `lib/ui`; los porcentajes enteros conservan `round()`.
- **Pruebas dirigidas:** arnés consolidado CA-10…CA-14 **1/1**; units + goals +
  chart **47/47**; body metric + goal editor + measures **24/24**; train sin
  golden **12/12**; focos de profile **3/3**, progress **4/4**, RPE de exercise
  info **1/1** y resumen de routine detail **1/1**. Los focos de routine editor,
  past workout y `weight_trend` también pasan. CA-15 conserva los doubles de
  dominio y CA-16 cubre todos los focos de presentación modificados.
- **Reversión CA-10:** al retirar temporalmente solo el fix de live workout, el
  arnés falla con `Expected: '88.18'`, `Actual: '40'`; restaurado el archivo,
  vuelve a pasar **1/1**. La restauración se comprobó byte a byte.
- **CA-17 parcial:** los intentos globales no golden, seguidos de 16 lotes y
  repeticiones individuales, registraron **638 tests reales completados: 605
  pass y 33 fail**. Cinco suites abortan después en `tearDownAll` con
  `Cannot close sink while adding stream` y dejan casos sin cargar; por ello el
  total no es una ejecución completa ni es aritméticamente comparable con el
  agregado histórico 887/851/36. No apareció una nueva firma atribuible a los
  cambios de T-002 en lo ejecutado; los focos afectados se validaron dirigidos.
  Persisten el fallo de CA-01/CA-02 por el estado heredado de T-001, la deuda
  previa y los cuelgues documentados, fuera del alcance de esta tarea.
- **Análisis:** `flutter analyze` reporta **55 incidencias**: las 52 históricas,
  los dos errores de API de `test/exercise_progress_chart_test.dart` y el aviso
  de `_analyticsHistory`, estos tres vinculados al estado heredado de T-001.
  Ninguna incidencia nueva apunta a los cambios de T-002.
- **Goldens excluidos explícitamente:** no se ejecutaron los ocho tests con
  `matchesGoldenFile`, ni se editó, regeneró o borró ningún PNG; no se usó
  `--update-goldens`. Tampoco se ejecutaron los nueve tests del chart con el
  desajuste de API heredado. Los goldens no se tratan como bloqueo ni como
  validación de T-002.
- **Cierre:** CA-10…CA-16 quedan cumplidos; CA-17 no cumple literalmente la
  suite/análisis en verde. T-002 no se marca formalmente completada y la 021
  permanece activa. Q-003/Q-004 siguen abiertas. Sin dependencias, migraciones,
  commits ni cambios de dominio/persistencia añadidos por T-002.

### Iteración correctora tras revisión — 2026-11-19

- **Serie existente con doble cambio de unidad:** la regresión siembra una serie
  pendiente de 40 kg, la edita a 50, alterna métrico→imperial→métrico y confirma.
  Antes del fix falló con `Expected: '50'`, `Actual: '40'`; después conserva 50
  en controlador y drift. `didChangeDependencies` ya no restaura `widget.set`
  cuando `_rawKg` contiene la base editada convertida.
- **CA-11 reforzada:** el primer caso confirma 40 kg con una repetición y RIR 0,
  de modo que volumen y 1RM del resumen son ambos 40 kg. Desmonta y reabre el
  **mismo** `workoutId`, comprueba identidad de la serie, drift, controlador,
  dos valores `40` y dos unidades `kg` en los resúmenes, y ausencia de `39.99`.
- **Formato live:** las expectativas son `62.50` y `60 → 62.50 kg`; no se
  reintroduce ±1.3 kg. El stepper ejecuta sus pasos pero el test termina con un
  timer pendiente de `FatigueNotifier`; la progresión se detiene antes porque
  no encuentra «Terminar». Son fallos de arnés/deuda separados, no diferencias
  `62.5` frente a `62.50`, y no se repararon por estar fuera de los hallazgos.
- **Dispositivos:** `DevicesCallout` se expone solo con `@visibleForTesting`
  para probar el componente conservado sin insertarlo en la pantalla. Su peso
  base kg se convierte con `displayWeightKg`; grasa corporal y unidad `%` quedan
  independientes. La regresión falló antes en imperial al no encontrar
  `88.18 lb`; ahora comprueba métrico `40 kg`, imperial `88.18 lb`, `20 %`
  inalterado y ausencia de `40 lb`.
- **Resultados de esta iteración:** fase roja de doble toggle y dispositivos
  reproducida; `test/t002_precision_test.dart` **1/1**; lote T-002 + units +
  chart **18/18**; progreso dirigido (dispositivos, medidas, peso métrico e
  imperial y composición) **5/5**. Los dos tests dirigidos de live quedan
  documentados arriba con sus fallos preexistentes independientes.
- **Análisis y goldens:** `flutter analyze` mantiene **55 incidencias, 0 nuevas**.
  No se ejecutaron goldens ni se modificó ningún PNG; no se usó
  `--update-goldens`.
- **Estado para nueva revisión:** CA-10…CA-16 validados tras estas regresiones.
  CA-17 se considera validado con el gate relativo explícitamente permitido por
  el revisor (sin suite completa verde ni goldens, sin nuevas incidencias y con
  fallos heredados separados). T-002 queda lista para revisión obligatoria, no
  marcada unilateralmente como aprobada.

---

## T-003 · Reparar de una vez toda la deuda no golden y sanear el análisis

**Objetivo:** que la selección completa de tests no golden termine sin fallos,
errores de carga, suites abortadas, cuelgues ni omisiones, y que
`flutter analyze` termine con cero incidencias, conservando T-001/T-002 y sin
usar goldens ni estrategias que maquillen la cobertura.

**Decisiones aplicables:** D-099 (misma spec 021, sin cierre administrativo),
D-100 (ajena o preexistente no implica exclusión), D-101 (goldens etiquetados,
nunca ejecutados ni regenerados), D-102 (reproducción y causa raíz), D-103
(puerta completa no golden + analyze a cero), D-104 (sin dependencias/commits y
migración solo con evidencia). El usuario amplió el alcance después de aprobar
T-001/T-002; no hay pregunta de producto pendiente.

**Dependencias:** conserva las aprobaciones y regresiones de T-001 y T-002. No
las reabre ni las reimplementa; T-003 puede tocar sus archivos para corregir la
deuda posterior sin revertir comportamiento válido. No depende de una nueva
respuesta del usuario. La semilla y la infraestructura de Flutter ya instaladas
son suficientes.

**Ámbito de archivos:** no hay lista cerrada. Pueden modificarse `lib/**`,
`test/**`, arnés compartido, `tool/`, catálogo (`catalog_patches.dart`,
`build_catalog_asset.dart`, `assets/exercises.json`), `muscle_fatigue.dart`,
v18, repositorios, sync y archivos de otras specs si una prueba no golden lo
demuestra. `pubspec.yaml` y `pubspec.lock` no se tocan. Un cambio de esquema
remoto exige migración nueva en `supabase/migrations/`; el local exige
`schemaVersion` de drift, regeneración y pruebas. No se crea commit ni se
limpia/resetea trabajo ajeno.

### Inventario de partida y fase 0

El inventario sirve para medir la reparación, no como resultado aceptable ni
como sustituto del descubrimiento dinámico:

- **Suite:** 65 archivos `test/**/*_test.dart`; históricamente T-001 registró
  36 fallos (de los que 2 eran goldens, por lo que 34 no golden) y 5 cuelgues.
  La corrida T-002 quedó incompleta en 638 completados/605 pass/33 fail, con
  cinco suites abortadas por `Cannot close sink while adding stream`; esos
  números no son comparables y no definen el objetivo.
- **Goldens:** 8 casos en 6 archivos. Solo esos casos se etiquetan
  individualmente; los archivos mixtos conservan todos sus demás tests.
- **Análisis:** 55 incidencias iniciales (2 errores, 31 warnings, 22 infos):
  dominio 1; vistas 23 (`exercise_detail_view` 1, `exercise_info_view` 5,
  `live_workout_view` 4, `profile_view` 1, `progress_view` 10,
  `routine_editor_view` 1, `train_view` 1); widgets 19
  (`exercise_progress_chart` 6, `fatigue_trend_chart` 5,
  `live_fatigue_section` 1, `zone_volume_chart` 7); tests 12
  (`exercise_detail_view_test` 1, `exercise_info_view_test` 2,
  `exercise_progress_chart_test` 2, `live_fatigue_section_test` 1,
  `live_workout_view_test` 1, `responsive_layout_test` 2,
  `routine_detail_view_test` 1, `screen_breakpoints_test` 1,
  `zone_volume_chart_test` 1).

Antes de tocar producción:

1. Registrar `HEAD`, `git status` y el conjunto/hash de todos los PNG de `test/`
   en un directorio fuera del repo. No alterar ninguno. Si `HEAD` cambia durante
   la ejecución, descartar esa corrida y repetirla sobre una sola instantánea.
2. Añadir `tags: ['golden']` solo a las declaraciones que contienen
   `matchesGoldenFile`: `train_view_test.dart` (1), `muscle_map_test.dart` (3,
   incluido el caso «sin datos…» que no lleva «golden:» en el título),
   `routines_view_test.dart` (1), `routine_detail_view_test.dart` (1),
   `progress_view_test.dart` (1) y `live_workout_view_test.dart` (1). No se
   etiqueta un `group`, se renombra un test ni se añade `skip`.
3. Verificar que las ocho llamadas siguen dentro de casos etiquetados, que no
   aparece una novena sin etiquetar y que `flutter test --exclude-tags golden`
   descubre casos no golden en cada uno de los seis archivos. Las incidencias de
   análisis en el cuerpo de esos casos se corrigen sin ejecutarlos ni cambiar
   PNG/matcher.
4. Crear el manifiesto ordenado de los 65 paths. Cada archivo se ejecuta por
   separado para el diagnóstico, con concurrencia 1 y un watchdog diagnosticado
   de 180 s, guardando JSON fuera del repo. El watchdog no es timeout de test ni
   criterio de éxito: salida 124/137, JSON sin `done` o tests sin `testDone`
   significan «incompleto». Se puede repetir con un watchdog mayor solo para
   distinguir arranque lento de cuelgue; nunca se usa `--ignore-timeouts` ni se
   relaja un timeout para ocultarlo.
5. Registrar por archivo y por caso: firma, último evento, pass/fail/incompleto,
   causa preliminar y archivo implicado. `--plain-name` sirve para reproducir un
   caso no golden, nunca como puerta final. Los lotes solo son admisibles si el
   JSON demuestra que ningún path del manifiesto desapareció.

### Paquetes de causa y archivos iniciales

La clasificación es un punto de partida: la causa definitiva debe demostrarse
antes del cambio.

| Paquete | Firma/causa a investigar | Archivos iniciales |
|---|---|---|
| A · Chart y T-001 | Errores `now` y `progressChartPoints`; `_analyticsHistory`; CA-02 sin `chart-plot`. Restaurar API/comportamiento aprobado, sin borrar tests. | `lib/ui/widgets/exercise_progress_chart.dart`, `chart_enums.dart`, `lib/ui/views/exercise_info_view.dart`, `lib/domain/exercise_stats.dart`; `test/exercise_progress_chart_test.dart`, `exercise_info_view_test.dart`, `routine_detail_view_test.dart` |
| B · Cierre asíncrono | Cinco abortos `Cannot close sink while adding stream`: exercise_info, live_workout, profile, progress, routines. Comprobar streams/subscriptions de drift, globals del arnés, cierre de BD, observers, `FatigueNotifier` y `RestNotifier`. | Vistas/repository asociados, `lib/domain/use_cases/fatigue_notifier.dart`, `lib/domain/services/rest_notifier.dart`, `lib/main.dart` y los cinco tests; también `app_shell_test.dart` por su reanudación incompleta |
| C · Borrado de rutina | «borrar pide confirmación y elimina la rutina con sus hijos» no completa. Aislar animación/frame, stream, cascada del repositorio, diálogo y cierre; no sustituir la espera por timeout mayor. | `lib/ui/views/routines_view.dart`, `lib/data/repositories/routine_repository.dart`, `test/routines_view_test.dart`; sync solo con traza |
| D · Live workout | Stepper con timer de `FatigueNotifier`; progresión sin «Terminar»; fallo e1RM y casos que no completan. Determinar si el CTA está ausente, no visible o el arnés no alcanza el estado. | `lib/ui/views/live_workout_view.dart`, `workout_manager.dart`, notifiers, `test/live_workout_view_test.dart`, `test/t002_precision_test.dart` |
| E · Contratos no golden | Exercise_info 10 antiguos; live_fatigue 4; responsive 7; small_screen 3; app_shell 2; profile 1; progress 1; live_workout 1; catalog_patches/migration con void. Comparar con spec antes de tocar expectativas. | Vistas/widgets homónimos y tests correspondientes, `screen_breakpoints.dart`, `main.dart`, `profile_view.dart`, `progress_view.dart` |
| F · Catálogo/v18 | Ahora permitido si un fallo no golden lo vincula. Verificar 1.324 ejercicios, `muscle_group = secondary_muscles[0]`, aliases y conformidad asset/parche; migrar solo con evidencia. | `lib/data/catalog_patches.dart`, `tool/build_catalog_asset.dart`, `assets/exercises.json`, `lib/domain/muscle_fatigue.dart`, `lib/data/local/database.dart`; tests de catálogo/migración |
| G · Orden/concurrencia | Fallos intermitentes, estado global y cierres que solo aparecen en global. Repetir caso aislado, archivo y global; una pasada aislada no prueba cierre. | Los que indique la traza; sin exclusión por procedencia |

### Reglas de corrección

1. Reproducir primero. Si el defecto es de producción, añadir o conservar una
   regresión que falla sin el fix. Si el arnés o la expectativa está obsoleto,
   documentar el contrato, la firma anterior y por qué la nueva aserción sigue
   protegiendo el requisito; no cambiar el valor esperado al observado.
2. No borrar tests, añadir skips, convertir aserciones precisas en comprobaciones
   débiles, capturar/descartar excepciones, desactivar reglas del analyzer ni
   añadir `ignore_for_file`/exclusiones nuevas. No se usan goldens como sustituto
   de un fix.
3. Corregir la causa raíz de recursos: streams, timers, notifiers, observers y
   BD deben cerrar limpiamente. No ignorar el error de sink ni alargar timeouts.
4. Mantener las invariantes numéricas y de dominio de T-001/T-002. Los cambios
   de UI exigidos por fallos no golden son reparaciones funcionales mínimas, no
   rediseño ni fidelidad de la 020.
5. Solo tocar catálogo o esquema con evidencia. Si no hay alternativa más
   pequeña, documentar antes el fallo, la razón técnica y la migración exacta;
   respetar RLS/`user_id`, `schemaVersion`, `build_runner` y una migración
   remota por tarea. Actualizar la documentación de datos correspondiente.
6. Registrar en `memory.md` cada causa, cambio, regresión y decisión nueva,
   incluidas las correcciones de expectativa y cualquier excepción de esquema.

### Criterios de aceptación (Given/When/Then)

- **CA-18 / exclusión golden exacta:** Given 8 casos con `matchesGoldenFile` en
  6 archivos y un manifiesto de 65 archivos, When se etiquetan solo esos casos y
  se ejecuta con `--exclude-tags golden`, Then ninguno de los 8 se inicia, todos
  los casos no golden de esos archivos se descubren y completan, no hay `skip`
  nuevo y los PNG conservan su conjunto y hashes.
- **CA-19 / inventario sin pérdidas:** Given las firmas históricas y un
  manifiesto ordenado, When se ejecuta cada archivo bajo watchdog diagnóstico y
  se recopila su JSON, Then cada path queda contabilizado una vez con `done`,
  pass/fail o incompleto, y ninguna suite abortada ni archivo ausente se trata
  como verde.
- **CA-20 / causa y regresión:** Given cada fallo del inventario, When se aplica
  su corrección, Then existe una firma roja previa o la evidencia de obsolescencia
  descrita en CA-20-bis, una causa documentada y una regresión verde; ninguna
  expectativa se relajó al valor defectuoso.
- **CA-20-bis / expectancias:** Given una expectativa o arnés cuestionado, When
  se actualiza, Then la spec o el contrato vigente demuestra la obsolescencia o
  el defecto del arnés, la nueva aserción conserva la garantía original y el
  cambio queda justificado por caso en `memory.md`.
- **CA-21 / chart y T-001:** Given los dos errores de `now` y
  `progressChartPoints` y el aviso de `_analyticsHistory`, When se repara el
  contrato, Then `test/exercise_progress_chart_test.dart` compila y pasa, el
  `chart-plot` reaparece con historial real y las regresiones CA-01…CA-09 siguen
  vigentes sin volver al cálculo duplicado ni a la fuente paginada como «Todo».
- **CA-22 / ciclo de vida:** Given las cinco firmas `Cannot close sink while
  adding stream` y los cuelgues/terminaciones con timer pendiente, When se
  corrigen productor y arnés, Then las suites terminan sin ese mensaje, sin
  timers/suscripciones pendientes y sin tests «did not complete», tanto aisladas
  como en la ejecución global.
- **CA-23 / borrado de rutina:** Given una rutina con ejercicios y series hijas,
  When se confirma su borrado y se bombea, Then la espera termina, la rutina y
  sus hijos desaparecen de la BD y del estado de la vista, y la aserción
  original sigue comprobando la cascada; no hay frame ni stream pendiente de
  forma indefinida.
- **CA-24 / sesión en vivo:** Given el stepper y la progresión de la sesión,
  When se ejecutan sus tests no golden, Then no queda timer de
  `FatigueNotifier`, se encuentra «Terminar» y el flujo llega a su estado final,
  conservando 40/50 kg, 62.50 y las regresiones T-002 sin `39.99`.
- **CA-25 / contratos históricos:** Given los fallos no golden inventariados de
  exercise_info, live_fatigue, responsive, small_screen, app_shell, profile,
  progress y live_workout, When se corrigen, Then pasan sus tests con las
  expectativas derivadas de las specs y del comportamiento vigente, sin borrar
  casos ni sustituir comprobaciones precisas por genéricas.
- **CA-26 / catálogo y esquema:** Given una firma que vincula un fallo con
  catálogo, aliases, asset o v18, When se corrige, Then se preservan las
  invariantes del catálogo y las reglas de migración, y el test causante pasa.
  Given esa evidencia no existe, Then esos archivos permanecen sin cambios.
- **CA-27 / análisis:** Given las 55 incidencias iniciales y cualquier nueva,
  When termina T-003, Then `flutter analyze` devuelve salida 0 y cero
  incidencias de error, warning o info en producción y tests, sin ignores,
  exclusiones ni desactivación de reglas.
- **CA-28 / puerta global:** Given todos los paquetes reparados y la exclusión
  por tags, When se ejecuta `flutter test --exclude-tags golden` con concurrencia
  normal y una segunda vez con semilla fija registrada, Then ambas terminan por
  sí mismas con salida 0, sin cuelgues, sin omisiones y sin golden ejecutado; el
  JSON verifica `done.success`, igualdad de tests iniciados/terminados y cobertura
  del manifiesto de suites. Ningún watchdog forma parte de esta puerta.
- **CA-29 / integridad de entrega:** Given el snapshot inicial, When se declara
  la tarea terminada, Then no hay PNG creado, borrado ni modificado, no se usó
  `--update-goldens`, no hay `skip` nuevo, dependencias, commits ni migración no
  autorizada, y T-001/T-002 siguen aprobadas y sus guardias en verde.
- **CA-30 / cierre honesto:** Given los resultados reales, When se documenta en
  `memory.md` y este archivo, Then constan comandos, semilla, recuentos
  dinámicos, causas, archivos tocados y decisiones. Si falta una sola condición,
  T-003 y la spec 021 permanecen activas y el bloqueo se describe sin aplicar un
  cierre administrativo.

**Entrega al implementador:** una sola tarea T-003 con fases internas 0 → A…G →
puerta; no se entregan las reparaciones individuales como aprobaciones
independientes. El revisor debe poder reconstruir cada firma roja y su regresión
verde desde `memory.md`.

### Estado final T-003 — 2026-11-20 · APROBADO en segunda revisión

**Veredicto:** el revisor devolvió **APROBADO** en la iteración 2. T-003 y la
spec 021 quedan **cerradas formalmente**. CA-18…CA-30 están cerrados.
**Historial de revisiones de T-003 (2 iteraciones):**
1. Iteración 1 — **RECHAZADO** por Q-005: se había elegido la semilla `999`
   sin corregir el overflow de 18 px en `width=320`, que aparecía con las
   semillas `12345`/`1`/`42`.
2. Iteración 2 — **APROBADO**: Q-005 corregida en origen en `hevy_app_bar.dart`
   con regresión determinista, y puerta reproducida en cinco corridas. Sin
   hallazgos bloqueantes ni mayores. Dos observaciones menores y opcionales
   (el test Q-005 se define dentro del bucle de anchos y el `addTearDown` está
   al final del test) **no se aplican**: no son condiciones de aprobación.

- **CA-18…CA-27: cerrados.** Ocho casos golden etiquetados en seis archivos y
  ninguno iniciado; 65 archivos cubiertos; causa/regresión de cada paquete en
  `memory.md`; chart y T-001/T-002 restaurados; ciclo de vida y BD corregidos
  (`combineLatest.onCancel` síncrono, `FatigueNotifier.cancel`); borrado, live,
  contratos y expectativas obsoletas reparados; catálogo/v18 sin cambios por no
  existir firma que los vincule; Q-005 corregida en origen (ver más abajo);
  `flutter analyze` a cero.
- **Q-005 / CA-20, CA-22, CA-25, CA-28, G — causa y fix:** el revisor rechazó
  elegir la semilla `999` porque en `12345`/`1`/`42` `width=320 dp` daba
  `RenderFlex overflowed by 18 px`. Traza completa: `Row` de
  `lib/ui/widgets/hevy_app_bar.dart:33`, `BoxConstraints(w=296,h=64)`. Causa:
  el logo `Image.asset(height:32)` mide 0 px sin caché y 32 px con caché; el
  grupo izquierdo no era `Flexible`, así que el título no podía encogerse y el
  `Row` desbordaba 18 px a 320 dp solo cuando la imagen ya estaba cargada (el
  orden por defecto lo enmascaraba con el logo a 0 px). Fix: envolver el grupo
  en `Flexible` y fijar `width: 32` al logo. Regresión determinista nueva en
  `responsive_layout_test.dart` («width=320 sin overflow con la imagen en
  caché»): calienta el logo a 412 dp y bombea a 320 dp; falla con 18 px sin el
  fix y pasa con él. Sin timeout/skip/tolerancia/relajación.
- **CA-28 / puerta global: cerrada y reproducible.** 5 corridas completas
  `flutter test --exclude-tags golden` salida 0 — normal + semillas `12345`,
  `1`, `42`, `999` — con **725 tests reales en verde** cada una. JSON
  `q005_gate_{normal,12345,1,42,999}.json`: `done.success=true`,
  `testStart=testDone=834`, 109 eventos `hidden` del runner (65 `loading
  <file>` + 44 hooks `(setUpAll)/(tearDownAll)`), 834−109=725 tests reales, 0
  fallos, 0 skips, 65/65 suites, 8 goldens no iniciados. Sin watchdog.
- **Reconciliación de recuentos:** `testStart`/`testDone` del JSON incluyen los
  artefactos ocultos del runner; el reporter expandido (`+N`) cuenta solo
  tests reales. 834−725=109 y el JSON previo 827−718=109 (misma diferencia:
  65 loading + 44 hooks). Se verificó por IDs/nombres que ninguno de los 8
  casos golden aparece en `testStart` y que no hay `skipped: true`.
- **CA-29 / integridad: cerrado.** PNG con hashes idénticos, sin
  `--update-goldens`, sin `skip:` nuevo, sin dependencias/commits/migraciones;
  HEAD `01eafa9`; `git diff --check` limpio. Guardias T-001/T-002 **54/54**.
- **CA-30 / cierre honesto: cerrado.** Comandos, semillas, recuentos y decisiones
  D-105…D-110 documentados en `memory.md`. El revisor no pudo ejecutar tests
  ni acceder a `/tmp`: se registran aquí los resultados reales y esa
  limitación de revisión. *(Histórico: en la iteración 1 se decía «se entrega
  para nueva aprobación formal; no se cierra unilateralmente»; tras la
  aprobación de la iteración 2 el cierre es formal y ya no está pendiente.)*
- **Cierre formal:** T-001, T-002 y T-003 aprobadas; spec 021 cerrada el
  2026-11-20. Sin dependencias, commits ni migraciones; PNG intactos; goldens
  excluidos y no ejecutados.
