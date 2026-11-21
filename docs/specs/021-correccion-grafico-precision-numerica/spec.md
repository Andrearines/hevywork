# Spec 021 — Corrección del gráfico de ejercicio y precisión numérica

**Estado:** cerrada el 2026-11-20; planificada el 2026-11-17 y ampliada el
2026-11-19. T-003 fue aprobada en la segunda revisión (la primera fue
rechazada por Q-005, corregida y validada).
**Tipo:** corrección funcional y saneamiento integral de tests no golden y análisis;
no hay pantallas nuevas ni rediseño.
**Tareas:** T-001, T-002 y T-003 de `tasks.md`, las tres aprobadas. Puerta de
cierre: cinco corridas completas `flutter test --exclude-tags golden` (normal y
semillas 12345, 1, 42, 999) con salida 0 y 725 tests reales en verde cada una,
`flutter analyze` a cero e integridad de PNG/diff. Los ocho casos golden se
excluyeron por etiqueta y no se ejecutaron; ningún PNG fue modificado.

## 1. Contexto

Se reportan dos regresiones que siguen presentes tras las specs 015, 017, 019
y el trabajo de fidelidad de la 020:

1. La progresión de `ExerciseInfoView` muestra «Sin datos en esta ventana»
   aunque existan sesiones terminadas con series del ejercicio.
2. La introducción de un peso exacto, ejemplificada con **40 kg**, termina
   mostrándose como **39.99 kg** en `LiveWorkoutView`, y otras vistas aplican
   políticas de decimales distintas o interpolan valores de coma flotante.
3. Tras aprobarse ambas correcciones, el usuario amplía el alcance: «y de un solo
   arrelgar todo los erroes que den los test ,pero los gold no cuenta» y aclara
   «sin importa que son ajenos». Deben repararse todos los fallos, errores y
   cuelgues no golden y todas las incidencias de `flutter analyze`, aunque sean
   preexistentes, de otras specs, de catálogo o de concurrencia.

El usuario no pide rehacer la ficha, la sesión en vivo ni el sistema visual. Las
correcciones T-001/T-002 se conservan. Los goldens quedan fuera de ejecución y de
cambios, pero todos los demás casos, incluidos los que comparten archivo con un
golden, forman parte de la puerta.

## 2. Diagnóstico de partida verificado

### BG-01 · Gráfico sin datos

- `RoutineDetailView._openExercise()` construye actualmente
  `ExerciseInfoView(exercise: exercise)` sin `database` ni
  `workoutRepository`.
- Con `workoutRepository == null`, `_loadInitialHistory()` retorna sin marcar
  `_historyLoaded`; `_history` permanece vacío y el gráfico recibe esa lista.
  Los demás puntos de entrada revisados (catálogo, sesión en vivo, editor de
  rutinas y lista de rutinas) sí pasan ambas dependencias.
- Hay un segundo defecto independiente en las ventanas:
  `filterByProgressWindow()` usa `pointDate.difference(nowDate).inDays <=
  windowDays`. Para una fecha pasada la diferencia es negativa, por lo que el
  predicado no excluye correctamente lo antiguo y tampoco descarta el futuro.
  **Este defecto no se declara causa del vacío**, pues por sí solo tiende a
  incluir puntos pasados; debe corregirse para que la reparación cumpla las
  ventanas de RF-9 de la 015.
- `_computePoints()` y el `build()` del gráfico aplican dos filtros temporales
  y duplican la lógica de métricas que ya existe en
  `domain/exercise_stats.dart`. Para volumen, la copia del widget puede crear
  un punto cero en una sesión que el dominio omite por no tener series válidas.
- `test/exercise_progress_chart_test.dart` solo crea el widget con una lista
  vacía: no cubre puntos reales, ventanas, límites ni la navegación desde el
  detalle de rutina.
- La paginación visual carga inicialmente 10 sesiones en `_history` y deja la
  siguiente página en `_historyUpcoming`. Una ventana «Todo» no debe presentar
  silenciosamente esa primera página como si fuese todo el historial.

### BG-02 · 40 kg → 39.99 kg y formato global

- En el estado actual de `lib/domain/units.dart`, métrico es identidad:
  `displayWeightKg(40, 'metric') == 40` y
  `toKg(displayWeightKg(40, 'metric'), 'metric') == 40`.
  `formatWeightKg(40, 'metric')` devuelve `40`. Por tanto, el ciclo citado de
  `_EditableSetRow` **no explica por sí solo** un 39.99 con entrada exacta 40
  en métrico. La constante de conversión imperial tampoco puede producir una
  desviación de esa magnitud.
- La presentación actual redondea a dos decimales, no trunca:
  `formatDisplay()` redondea a centésimas y conserva dos cifras para un valor
  no entero. Persistencia redondea por separado a 0.001 kg conforme a la 001;
  ese comportamiento no es formateo y no debe cambiarse en esta spec.
- Queda obligado reproducir el flujo completo (entrada manual, confirmación,
  ajuste rápido, reconstrucción y, cuando aplique, cambio de unidad) y localizar
  el primer momento en que el valor base o el texto deja de ser 40. No se
  cambiará la constante, se truncarán valores ni se «corregirá» el golden sin
  una prueba que reproduzca el defecto.
- Hay formateadores paralelos en `routine_editor_view.dart`,
  `past_workout_editor_view.dart`, `train_view.dart`, `progress_view.dart`,
  `measures_view.dart`, `profile_view.dart`, editores de métricas/objetivos y
  etiquetas del gráfico. Algunos redondean a tres decimales y otros a uno.
- La D-030/Q-014 de la 017 describe un estado que ya no coincide con el
  código: actualmente `formatDisplay`, `formatWeightKg` y `formatLengthCm`
  sí admiten hasta dos decimales y no existe `formatNumber`. La spec activa
  parte del código real, no de esa descripción histórica.
- El test vigente de ajuste rápido aún espera `+1.3 kg`, `61.3` y `63.8`,
  aunque los pasos reales son 1.25 kg y el formateador actual admite 1.25.
  Es una expectativa obsoleta dentro del alcance de esta corrección.

## 3. Historias de usuario

- **US-01:** Como atleta quiero que la ficha use mi historial real para dibujar
  la progresión y que cada ventana incluya solo sus sesiones, para interpretar
  mi evolución sin falsos estados vacíos.
- **US-02:** Como atleta quiero que el peso que introduzco y los valores
  calculados se presenten con una política común y sin artefactos de coma
  flotante, conservando kg/lb y los decimales legítimos, para confiar en lo que
  registro.
- **US-03:** Como responsable del producto quiero que toda la suite no golden
  termine sin fallos ni cuelgues y que el análisis estático quede sin
  incidencias, para aceptar una entrega sin ocultar deuda funcional o de arnés.

## 4. Alcance

### Dentro

- Reparación de la entrega de dependencias al abrir la ficha desde
  `RoutineDetailView` y prueba de integración del camino real.
- Una sola canalización de puntos/métricas y filtrado temporal del gráfico,
  con reloj inyectable en las funciones puras de prueba.
- Consistencia entre la paginación del historial visible y los datos usados
  por el gráfico en «Todo», sin cambiar esquema ni rediseñar la paginación.
- Diagnóstico y corrección de la secuencia que produce 40 → 39.99 en vivo.
- Una política común de presentación numérica apoyada en `lib/domain/units.dart`
  y barrido de pesos, volúmenes, e1RM, longitudes y campos editables en `lib/ui/`.
- Tests unitarios, de repositorio/integración cuando proceda y de widgets que
  fallen sin la corrección; cierre con la puerta de la constitución.
- **T-003:** inventario completo y reparación de todo fallo, error de carga,
  excepción, aborto o cuelgue de tests no golden, sean actuales, preexistentes,
  ajenos, de otras specs, de catálogo o de concurrencia.
- **T-003:** saneamiento de las 55 incidencias iniciales de `flutter analyze` y
  de cualquier otra que aparezca, sin excluir archivos ni suprimir reglas para
  obtener el verde.
- **T-003:** cambios de producción, tests, arnés, catálogo, migraciones o
  concurrencia cuando una evidencia reproducible demuestre que son necesarios.
  Se incluyen expresamente `catalog_patches.dart`, `build_catalog_asset.dart`,
  `exercises.json`, `muscle_fatigue.dart` y la migración local v18 si falla un
  test no golden por su causa.

### Fuera

- Rediseño, fidelidad visual de la 020, cambios cosméticos no exigidos por una
  evidencia o cambios no justificados de fórmulas de e1RM/volumen/fatiga o de la
  precisión de persistencia de 0.001 kg.
- Dependencias nuevas, localización de separadores decimales o una nueva pantalla
  de ajustes. Las migraciones drift/Postgres no están previstas; solo se permiten
  si un fallo real no golden demuestra que son imprescindibles y T-003 documenta
  antes la causa, la migración concreta y su cumplimiento de la constitución.
- Reabrir o rehacer el trabajo aprobado de T-001/T-002 o las tareas completadas
  de 015, 017, 019 o 020. Sí se pueden tocar sus archivos para reparar una deuda
  no golden sin revertir comportamiento válido.
- Ejecutar goldens como gate, editar, regenerar o borrar PNG, usar
  `--update-goldens`, o excluir tests no golden que compartan archivo con ellos.
- Borrar tests, introducir skips, relajar aserciones o cambiar expectativas sin
  demostrar que el comportamiento anterior era obsoleto o que el arnés era
  defectuoso.

## 5. Requisitos funcionales

### Gráfico (BG-01)

- **RF-1:** CUANDO se abre `ExerciseInfoView` desde cualquier entrada de
  producción, EL SISTEMA proporciona la base local y el repositorio de la misma
  instalación; en particular `RoutineDetailView` no abre una ficha con el
  repositorio nulo.
- **RF-2:** CUANDO hay al menos dos sesiones elegibles en la métrica y ventana
  elegidas, EL SISTEMA pinta el gráfico y sus insights en vez de «Sin datos»;
  cada punto procede de una sesión `finished` con `endedAt` y series elegibles
  para esa métrica.
- **RF-3:** EL SISTEMA calcula los puntos mediante la lógica común de dominio
  (sin warmups ni series incompletas; e1RM conserva sus reglas) y aplica una
  única ventana temporal. Una ventana finita incluye `inicio <= fecha <= ahora`;
  «Todo» no aplica ese recorte.
- **RF-4:** SI la selección produce cero o un punto, ENTONCES se conserva el
  estado vacío y se ocultan los insights. Una serie de peso corporal/volumen
  cero no se convierte por error en e1RM o carga positiva.
- **RF-5:** CUANDO el historial supera una página, EL SISTEMA no limita la
  ventana «Todo» a las diez primeras sesiones visibles sin indicarlo. La carga
  progresiva de tarjetas permanece separada de la fuente analítica y acotada al
  `exerciseId`.

### Números y edición (BG-02)

- **RF-6:** CUANDO el usuario introduce exactamente 40 en métrico y confirma,
  EL SISTEMA conserva 40 kg en la base local y presenta `40 kg` en el campo y
  los resúmenes correspondientes tras confirmar y reconstruir la vista; nunca
  presenta `39.99 kg` como resultado de ese flujo.
- **RF-7:** EL SISTEMA centraliza la presentación en `formatDisplay` para
  valores ya en unidad de pantalla, `formatWeightKg` para valores base kg y
  `formatLengthCm` para valores base cm. Las funciones de signo o separadores
  de miles pueden envolver estas funciones, pero no vuelven a redondear ni
  interpolan el `double` de partida.
- **RF-8:** LA PRESENTACIÓN redondea como máximo a dos decimales y elimina
  artefactos binarios, sin imponer enteros a valores con decimales legítimos.
  Los conteos enteros (series, reps, RIR) permanecen enteros. No se altera el
  valor almacenado solo para embellecer la UI.
- **RF-9:** EN EDICIÓN, EL SISTEMA conserva el valor base mientras el usuario
  no lo modifica, interpreta el texto manual una sola vez en la unidad visible
  y realiza el ajuste rápido en esa misma unidad antes de convertir a kg. Un
  cambio de unidad no aplica conversiones acumulativas al texto ya mostrado.
- **RF-10:** LOS PESOS, volúmenes y e1RM base kg se convierten a lb únicamente
  para presentar/editar en imperial, con la unidad `lb`; en métrico usan `kg`.
  Volumen y e1RM se calculan con el `double` de dominio y se redondean solo al
  final, no con el texto ya redondeado.
- **RF-11:** EL BARRIDO cubre `Text`, `TextPainter` y controladores editables
  de `lib/ui/`. No quedan interpolaciones crudas ni formateadores locales
  paralelos para pesos, volúmenes, e1RM o longitudes, independientemente de si
  redondeaban a uno o tres decimales. El resto de valores decimales presentados
  usa el enfoque común o un wrapper permitido por RF-7, con máximo dos cifras.

### Saneamiento integral no golden (BG-03)

- **RF-12:** CUANDO se ejecuta toda la selección no golden, EL SISTEMA de pruebas
  descubre y completa cada caso unitario, funcional y de widget, incluidos los
  que comparten archivo con goldens, sin fallos, errores de carga, skips nuevos,
  suites abortadas ni tests que no completen.
- **RF-13:** LA EXCLUSIÓN se aplica únicamente a los casos que invocan
  `matchesGoldenFile`, individualmente y mediante la etiqueta `golden`; nunca a
  todo un grupo o archivo. Los ocho casos inventariados inicialmente quedan
  etiquetados y los PNG permanecen intactos.
- **RF-14:** CADA CORRECCIÓN parte de una reproducción y una causa raíz
  documentadas. Una modificación de expectativas o del arnés exige evidencia de
  comportamiento obsoleto o defecto del arnés; no se borran tests, se añaden
  skips, se aumentan timeouts para ocultar cuelgues ni se relajan aserciones.
- **RF-15:** LOS TEMPORIZADORES, streams, suscripciones, notifiers, observadores,
  bases de datos y demás recursos terminan correctamente su ciclo de vida en
  producción y pruebas. `Cannot close sink while adding stream`, timers
  pendientes y cierres incompletos se corrigen en su origen, no se ignoran.
- **RF-16:** LAS REGRESIONES de T-001/T-002 permanecen vigentes. En particular,
  se restaura la coherencia del chart con `now`, `progressChartPoints`,
  `_analyticsHistory` y `chart-plot`, conservando dominio, ventanas, paginación y
  formato numérico aprobados.
- **RF-17:** `flutter analyze` termina con **0 issues** en producción y tests,
  incluidos errores, warnings e infos, sin `ignore` globales, exclusiones nuevas
  ni desactivación de reglas para ocultar deuda.
- **RF-18:** CUALQUIER ARCHIVO puede entrar en la corrección si una prueba no
  golden lo vincula con el fallo, incluidos catálogo, aliases, asset, v18,
  sincronización y trabajo de otras specs. No se revierten cambios concurrentes
  ni válidos; toda migración necesaria queda previamente delimitada y registrada.

## 6. Requisitos no funcionales

- **RNF-1:** Sin dependencias nuevas ni commits. No se prevén migraciones ni
  cambios de RLS/sync; solo se permiten si RF-18 demuestra que son necesarios y
  se documentan conforme a la constitución. El catálogo sí puede modificarse
  cuando una prueba no golden demuestre su implicación.
- **RNF-2:** El filtro temporal y las políticas de formato/conversión son puras
  y se prueban con fechas y valores deterministas; nada de comparar contra
  `DateTime.now()` repetidamente dentro de un mismo cálculo.
- **RNF-3:** La reparación mantiene las claves y contratos existentes siempre
  que sea posible, no introduce rediseño y conserva `CustomPainter`.
- **RNF-4:** Las consultas analíticas siguen acotadas por ejercicio y usuario;
  no se carga el historial completo de otros ejercicios.
- **RNF-5:** Al terminar T-003 se ejecuta `flutter test --exclude-tags golden`
  completo y `flutter analyze`; la selección no golden debe terminar en verde y
  el análisis con cero incidencias. Los timeouts y lotes sirven para diagnosticar
  cuelgues, no para declarar éxito con suites incompletas. No se usa el antiguo
  gate relativo.

## 7. Casos límite de aceptación

- Cero/una sesión elegible → vacío legítimo; dos o más → gráfico.
- Fecha exactamente al inicio o exactamente `now` → incluida; anterior al
  inicio o futura en ventana finita → excluida; «Todo» → sin ventana finita.
- Solo warmups/incompletas → sin puntos; cero kg puede aportar volumen cero,
  pero no carga/e1RM positivos.
- Más de diez sesiones → «Todo» no equivale a la primera página.
- 40 kg exactos, ida y vuelta de ajuste rápido y reapertura → 40 kg; valores
  cercanos como 39.99999999999999 se presentan sin ruido a la precisión UI.
- 1.25 kg/61.25 → no se redondean a 1.3/61.3; 80.50000000000001 → 80.50 bajo
  la política actual; 12000.0 → 12000.
- 40 kg en imperial → 88.18 lb; entrada 100 lb → aproximadamente 45.359 kg en
  persistencia y 100 lb al mostrarla de nuevo; cambios de unidad sin deriva
  acumulativa.
- Porcentajes, RPE, frecuencia y deltas conservan signo y decimales útiles con
  un máximo de dos cifras cuando se someten al barrido.
- Un archivo con casos golden y no golden ejecuta todos estos últimos; la
  exclusión por etiqueta no reduce su cobertura.
- Un test individual que termina pero deja un timer, una suscripción o un cierre
  de base pendiente no se considera verde.
- Una corrida por lotes con archivos omitidos o abortados no sustituye la
  ejecución global completa exigida al final.

## 8. Decisiones

- **D-085:** Se crea la 021 como spec activa de dos tareas, en lugar de reabrir
  la 015/017 o mezclar los bugs con la fidelidad de la 020.
- **D-086:** La corrección del gráfico distingue causa de vacío (fuente de
  datos/dependencias) de defectos de ventana y paging. Se reutiliza el dominio
  y un único filtro; no se afirma que el predicado temporal explique el vacío.
- **D-087:** Partiendo del código vigente, se consolidan `formatDisplay`,
  `formatWeightKg` y `formatLengthCm`; no se añade `formatNumber`. Esta
  decisión sustituye la descripción técnica histórica de D-030/Q-014 para esta
  reparación y conserva decimales legítimos como 1.25.
- **D-088:** No se cambia la precisión de persistencia de la 001 ni las
  fórmulas de dominio. La conversión sucede en el límite de edición y el
  redondeo de dos decimales es de presentación.
- **D-089:** Un golden nunca es la solución. Solo se regenera mediante Flutter
  si una corrección real modifica una captura existente, tras revisar el diff
  y con tests funcionales previos.
- **D-099:** La ampliación del usuario sustituye el cierre administrativo con
  gate relativo que solo se había propuesto y nunca se escribió. La deuda se
  repara ahora en T-003 dentro de la propia 021 para mantener una única entrega;
  D-085 queda como decisión histórica de alcance inicial y la spec permanece
  activa.
- **D-100:** «Sin importa que son ajenos» elimina la exclusión por procedencia.
  Todo fallo no golden está dentro, sea de otra spec, catálogo, concurrencia o
  preexistente. No se crea una spec separada de saneamiento.
- **D-101:** Para esta entrega D-101 restringe D-089: los goldens no se ejecutan
  como gate y no se editan, regeneran o borran PNG. Los casos golden se etiquetan
  individualmente con `golden` para usar `--exclude-tags golden`; no se etiqueta
  un archivo o grupo completo y no se añade `skip`.
- **D-102:** No se obtiene el verde borrando cobertura, relajando aserciones,
  aumentando timeouts o cambiando expectativas sin evidencia. Cada fix requiere
  reproducción, causa raíz y regresión; las actualizaciones de tests obsoletos o
  de arnés quedan justificadas individualmente.
- **D-103:** La única puerta de cierre vigente es toda la selección no golden
  completada en verde y `flutter analyze` con cero incidencias. Los lotes y
  watchdogs diagnostican; no sustituyen la corrida global ni permiten ignorar
  suites abortadas.
- **D-104:** Se conservan T-001/T-002 y cualquier trabajo concurrente válido; no
  se revierte, resetea ni commitea. No se añaden dependencias. Una migración
  solo procede tras demostrar su necesidad con un test no golden y registrar su
  delimitación antes de aplicarla, conforme a la constitución.

## 9. Preguntas abiertas

No hay preguntas de producto abiertas que bloqueen T-003. Q-003 queda resuelta
por D-099/D-100: la deuda se repara ahora dentro de 021/T-003. Q-004 queda
resuelta por D-103: no se adopta el gate relativo propuesto; se exige la puerta
no golden y de análisis completa. Si aparece una expectativa cuyo comportamiento
correcto no pueda derivarse de las specs o del contrato vigente, se abrirá una
pregunta concreta antes de cambiarla, sin decidirla por conveniencia del test.

## 10. Criterio de finalización

T-001 y T-002 conservan su aprobación y sus regresiones. T-003 cumple todos sus
Given/When/Then de `tasks.md`: inventario completo, solo los ocho casos golden
iniciales excluidos por etiqueta, toda la selección no golden ejecutada y en
verde sin cuelgues ni omisiones, `flutter analyze` con cero incidencias y PNG
intactos. No se modifica ningún PNG ni se crea ningún commit. Si la puerta no
pasa, T-003 y la spec permanecen activas y el bloqueo queda explícito.
