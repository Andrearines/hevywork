# Spec 014 — Miniaturas en el editor, fatiga en tiempo real y optimización

## Contexto y objetivo
Tres bloques aprobados por el usuario que comparten ficheros y una sola
tarea de cierre:

- **A. Miniaturas en el editor de rutinas**: las tarjetas `_draftTile` del
  editor (`lib/ui/views/routine_editor_view.dart`) muestran solo nombre y
  filas de series; el entrenamiento en vivo sí muestra `ExerciseThumb`
  (44 dp) + chips + nombre. Los borradores `_DraftExercise` solo guardan
  `exerciseId` + `name`, así que la miniatura no puede resolverse hoy.
- **B. Fatiga muscular en tiempo real**: la fatiga se recalcula solo en
  cuatro puntos (cierre de sesión, sync, edición de registro pasado y
  apertura de Progreso), nunca al completar series. Progreso fuerza un
  `recalculate()` completo al abrir y `_FatigueSection` relanza
  `weeklyZoneStats()` en cada cambio del mapa. Se pide una sección de
  fatiga dentro de la sesión en vivo que reaccione al completar cada
  serie, Progreso en vía stream y gráficas nuevas (volumen semanal por
  zona y tendencia de fatiga) hechas con `CustomPainter` propios.
- **C. Optimización**: los nueve hallazgos de rendimiento detectados en el
  análisis previo (ver plan.md, tabla hallazgo → tarea), cada uno con su
  tarea y su test.
- **D/E/F**: doc-comentarios `///` en español solo en ficheros tocados
  (aprobado por el usuario, constancia en este documento), reescritura del
  `README.md` en español y mantenimiento de las puertas de la constitución
  (sin dependencias, sin sombras, goldens, `flutter test` +
  `flutter analyze` en verde).

## Usuarios
Mismo perfil. Atleta que entrena con la sesión en vivo abierta y revisa
Progreso durante o después del entrenamiento.

## Historias de usuario
- H1: Como usuario quiero ver la miniatura del ejercicio en el editor de
  rutinas para reconocerlo igual que en la sesión en vivo.
- H2: Como usuario quiero que el mapa muscular y las gráficas de fatiga se
  actualicen al completar cada serie, para ver el efecto del entrenamiento
  mientras entreno.
- H3: Como usuario quiero abrir Progreso sin esperas y con datos
  actualizados, para que la pantalla responda al tocar.
- H4: Como usuario quiero que la app se sienta fluida al escribir pesos y
  reps y al desplazarme por sesiones largas, sin saltos ni cuelgues.

## Alcance (aprobado por el usuario)
- **A** — Miniaturas en el editor con el mismo estilo que el en vivo
  (ExerciseThumb ~44 + chips + nombre) e hidratación de `imagePath` desde
  el catálogo para los `exerciseId` del borrador.
- **B** — Fatiga en tiempo real en la sesión en vivo y en Progreso
  (vía stream), mecanismo tipo Notifier/Observer con recálculo
  incremental/debounced sin dependencias nuevas, y gráficas nuevas
  (volumen semanal por zona, tendencia de fatiga) con `CustomPainter`.
- **C** — Los 9 hallazgos de rendimiento, cada uno como tarea con test.
- **D** — Doc-comentarios `///` en español y patrones de diseño (Observer/
  Notifier; Repository y Strategy solo si encajan sin sobre-ingeniería)
  únicamente en los ficheros tocados por esta spec.
- **E** — `README.md` de la raíz reescrito en español: descripción,
  arquitectura por capas, cómo ejecutar, `--dart-define`, comandos clave,
  estructura de datos, sección de specs y atribución de medios.
- **F** — Sin dependencias nuevas, sin sombras, goldens actualizados si la
  UI cambia, `flutter test` + `flutter analyze` en verde al final.

## Requisitos funcionales (EARS)

### A · Miniaturas en el editor
- RF-1: CUANDO el editor abre una rutina o el usuario añade un ejercicio,
  EL SISTEMA muestra en cada tarjeta la miniatura JPG del catálogo con el
  mismo estilo que la sesión en vivo: `ExerciseThumb` de 44 dp, chips de
  `target`/`muscle_group` y `equipment`, y el nombre.
- RF-2: SI un ejercicio del borrador no existe en el catálogo o no tiene
  `imagePath`, ENTONCES la tarjeta muestra `ThumbFallback` y los chips que
  haya disponibles, sin romper el resto de la fila.
- RF-3: EL SISTEMA hidrata los `Exercise` del catálogo por ids en lote
  (`exercisesByIds`) al cargar el editor y al elegir del buscador, sin
  consultas N+1 por tarjeta.

### B · Fatiga en tiempo real
- RF-4: CUANDO se completa, descompleta, edita o borra una serie (sesión
  en vivo o registro pasado) o cambia una fila de `workouts`,
  EL SISTEMA programa un recálculo del caché `muscle_fatigue` con debounce
  de 750 ms que coalesce los eventos en un solo recálculo.
- RF-5: EL recálculo incluye además de las sesiones `finished` de los
  últimos 30 días la sesión `active`, fechando sus series por
  `startedAt ?? endedAt`, de modo que el mapa refleja la sesión en curso.
- RF-6: EL recálculo es incremental: solo se escriben las filas cuyo
  `fatigue`/`raw` cambió (upsert por diff dentro de transacción); si nada
  cambia, no hay escrituras ni emisiones a los streams.
- RF-7: EL SISTEMA añade una sección «Fatiga» dentro de
  `live_workout_view` con mapa muscular vectorial (`MuscleMap`), lista de
  zonas, gráfica de volumen semanal por zona y gráfica de tendencia de
  fatiga; la sección es visible por defecto, plegable, y cada widget se
  actualiza al completar cada serie a través de un único stream.
- RF-8: EL SISTEMA convierte Progreso a vía stream: una única fuencia
  `watchFatiguePanel` (fatiga + zonas semanales + tendencia) alimenta
  `_FatigueSection`; al abrir Progreso NO se fuerza `recalculate()`, solo
  `ensureFresh()` si la caché no existe o su `computedAt` supera 30 min;
  desaparece el relanzamiento de `weeklyZoneStats()` en `didUpdateWidget`.
- RF-9: EL SISTEMA ofrece dos gráficas nuevas dibujadas con
  `CustomPainter` propios (sin dependencias, patrón de `weight_trend.dart`
  con `shouldRepaint` correcto): barras de volumen semanal por zona y
  sparkline de tendencia de fatiga de los últimos 14 días.
- RF-10: EL SISTEMA mantiene los puntos de recálculo existentes
  reencaminados al notifier: al cerrar sesión → `flush()` inmediato y
  await; tras sync → `flush()`; al editar registro pasado → `markDirty()`
  (debounced). El cálculo de dominio no cambia (ventanas, umbrales,
  normalización de la 007).

### C · Optimización (hallazgos H1–H9)
- RF-11 (H1): EL SISTEMA no ejecuta `setState` de la fila completa por
  tecla en `_EditableSetRow`: el chip RIR se actualiza con
  `ValueListenableBuilder` y la asignación de `_rawKg` no reconstruye.
- RF-12 (H2): EL SISTEMA no ejecuta efectos secundarios dentro de
  `build()` de `live_workout_view` (asignaciones y `addPostFrameCallback`
  se mueven a suscripciones en `initState`).
- RF-13 (H3): EL SISTEMA mantiene un único `AutomaticKeepAliveClientMixin`
  por ejercicio (en `_ExerciseCardState`) y lo elimina de
  `_EditableSetRowState`, conservando el texto escrito sin confirmar al
  desplazarse.
- RF-14 (H4): EL SISTEMA presenta la sesión en vivo con un único
  `StreamBuilder` (streams de workout, ejercicios y series combinados con
  un helper propio `combineLatest`).
- RF-15 (H5): `ExerciseThumb` lee el ratio con
  `MediaQuery.devicePixelRatioOf(context)` en lugar de `MediaQuery.of`.
- RF-16 (H6): ver RF-8 (Progreso sin recálculo obligatorio al abrir y sin
  relanzamiento por cambio del mapa).
- RF-17 (H7): `routines_view` agrupa las 7 suscripciones en una sola
  reconstrucción coalescida por frame (helper testeable), en lugar de 7
  `setState` independientes.
- RF-18 (H8): `muscle_map` memoiza el mapa de colores e intensidades y no
  lo reconstruye en cada `build` si no cambian sus entradas.
- RF-19 (H9): `exercise_detail_view` decodifica la imagen grande con
  `cacheWidth`/`cacheHeight` acotados al tamaño mostrado.

### D · Doc-comentarios
- RF-20: EL SISTEMA documenta con doc-comentarios `///` en español, en
  inglés para identificadores, los ficheros tocados por esta spec y deja
  constancia en plan.md de que el usuario aprobó comentarios pese a la
  constitución.

### E · README
- RF-21: EL SISTEMA (repo) presenta un `README.md` en español con:
  descripción, arquitectura por capas, cómo ejecutar, `--dart-define`,
  comandos clave, estructura de datos, sección de specs y atribución de
  medios (© Gym visual).

### F · Mantenimiento
- RF-22: EL SISTEMA mantiene `pubspec.yaml` sin cambios de dependencias,
  sin `elevation`/`BoxShadow`, con goldens regenerados si la UI cambia, y
  cierra con `flutter test` + `flutter analyze` en verde.

## Requisitos no funcionales
- RNF-1: Completar una serie no debe bloquear la UI; el recálculo corre
  después del debounce, con una sola ejecución como máximo cada 750 ms.
- RNF-2: La actualización visible en la sección en vivo y en Progreso se
  produce en ≤ ~1,5 s tras completar la serie (debounce + consulta local).
- RNF-3: Cero dependencias nuevas (constitución §2): sin Riverpod, sin
  paquetes de charts, sin `rxdart` ni `async` — la combinación de streams
  es un helper propio de ~30 líneas.
- RNF-4: El mapa sigue siendo vectorial y la escala frío→rojo (§8); el
  valor lo calcula el dominio, no el widget.
- RNF-5: Tests como puerta (§6): cada tarea cierra con `flutter test` en
  verde y `flutter analyze` sin incidencias.
- RNF-6: Minimalismo tipo Apple, sin sombras (§7); jerarquía por
  tipografía y espacio; targets táctiles ≥ 48 dp y contraste AA en la
  sección en vivo.
- RNF-7: Código e identificadores en inglés; mensajes y docs en español
  (§11).
- RNF-8: El catálogo sigue saliendo solo del asset (§9); la hidratación de
  miniaturas no crea tablas ni endpoints.

## Casos límite
- Varias series completadas seguidas (rafalada) → un solo recálculo
  (coalescing del debounce).
- Cierre de sesión con un recálculo pendiente → `flush()` cancela el
  temporizador y ejecuta inmediato; no se pierde el resultado.
- Ejercicio del borrador ausente del catálogo (asset antiguo) →
  `ThumbFallback` y chips vacíos; nunca excepción.
- Sesión `active` abandonada o restaurada → al cambiar de estado se
  dispara `workouts` → dirty → recálculo con el nuevo estado.
- Recálculo sin cambios de valores → sin escrituras, sin emisiones, sin
  rebuilds en Progreso (dato vacío o idéntico).
- Progreso abierto tras días sin usar la app → `ensureFresh()` detecta
  `computedAt` viejo y recalcula una vez en segundo plano.
- App relanzada con sesión activa marcada → el mapa incluye esas series
  fechadas por `startedAt` hasta que se cierre o abandone.
- Sesión con 0 series completadas → sección en vivo con estados vacíos
  (mensaje y mapa sin datos), sin gráficas rotas.
- Pantalla baja → la sección en vivo arranca desplegada pero es plegable
  a una cabecera compacta para no tapar la tabla de series.

## Fuera de alcance (014)
- Spec 011 (integraciones BLE/HRV): sigue pendiente, no se toca.
- Nuevas dependencias de cualquier tipo (constitución §2).
- Cambios de esquema: ni migración drift ni migración Postgres; se usan
  `muscle_fatigue`, `workouts` y `workout_sets` existentes.
- Historial persistente de fatiga: la tendencia se deriva de las sesiones
  de los últimos 14 días, sin tabla nueva.
- Notificaciones, recomendaciones de descanso o alertas de sobrecarga.
- Pantallas no listadas en el alcance (train, perfil, catálogo, fotos…).
- Corregir la anidación de `StreamBuilder` de `progress_view` (4 anidados)
  más allá del bloque de fatiga que esta spec reescribe.

## Decisiones (Cerradas) — 2026-10-27
- **Spec nueva (014)** en vez de ampliar la 007/008: los tres bloques
  comparten `fatigue_repository`, `live_workout_view` y una sola tarea de
  cierre con goldens.
- **`FatigueNotifier` (Observer/Notifier)** en
  `lib/domain/use_cases/fatigue_notifier.dart`: clase pura Dart (sin
  Flutter), constructor con `List<Stream<void>> sources`, `recalculate`
  inyectable y `delay` configurable (750 ms en producción, corto en
  tests). Se suscribe a `db.tableUpdates` de `workout_sets` y `workouts`
  (escucha cualquier escritura, venga del repositorio o del sync) y
  expone `markDirty()` y `flush()`. Sin dependencias: `dart:async` y
  `ChangeNotifier` no hacen falta para la UI, que se entera por los
  streams de drift.
- **Recálculo incremental con diff**: `recalculate()` calcula el mapa
  completo de 30 días (join acotado, barato) pero escribe por diff en
  transacción: solo inserta/actualiza/borra filas cuyo `fatigue`/`raw`
  cambió. Ventaja doble: menos escrituras y cero emisiones espurias a
  `watchFatigue` cuando nada cambia (ataca H6 de raíz). Recálculo
  completo solo en los checkpoints ya existentes.
- **Sesión activa incluida**: `status in ('finished','active')` con
  timestamp `endedAt ?? startedAt`; solo puede haber una sesión activa
  (regla de la 001), así que el coste es nulo y el mapa refleja la serie
  recién completada.
- **Progreso en vía stream**: `watchFatiguePanel()` =
  `combineLatest2(watchFatigue(), join de 7 días + tendencia)` con helper
  propio `lib/data/util/combine_latest.dart` (prohibido `rxdart`/`async`).
  `ensureFresh({maxAge: 30 min})` sustituye al `recalculate()` de la
  apertura; `_FatigueSection` recibe el panel completo y ya no relanza
  `weeklyZoneStats()` en `didUpdateWidget` (H6 cerrado aquí).
- **Debounce 750 ms** (ventana 500 ms–1 s aprobada): suficiente para
  coalescer rafales de series y por debajo del umbral perceptible de
  actualización (RNF-2).
- **Hidratación de miniaturas sin tocar el modelo de datos**:
  `_DraftExercise` guarda la referencia `Exercise` del catálogo en memoria
  (cargada con el nuevo `CatalogRepository.exercisesByIds`); no se añade
  `imagePath` a `RoutineExerciseDraft` ni viaja por sync.
- **Chips compartidos**: se extrae `_ExerciseChips` de
  `live_workout_view` a `lib/ui/widgets/exercise_chips.dart`
  (`ExerciseChips` público) y lo usan la tarjeta en vivo y el tile del
  editor: un solo estilo, cero duplicación.
- **Sección en vivo visible por defecto y plegable**: el usuario pide ver
  la actualización al completar series; plegarla a una cabecera compacta
  evita que domine pantallas bajas (nueva UI, no del mockup, como la 013).
- **Gráficas nuevas con `CustomPainter`**: `ZoneVolumeChart` (barras
  horizontales de volumen semanal por zona, top 6) y `FatigueTrendChart`
  (sparkline 0–1 de los últimos 14 días con área y punto final, guías
  punteadas §7.9 del designer). Las dos se reutilizan en Progreso dentro
  de `_FatigueSection`, sin duplicación de widgets.
- **Tendencia de fatiga derivada, no persistida**: función de dominio
  `fatigueTrend(sets, days, now, muscle?)` que evalúa `muscleFatigue` por
  día (pico global o de una zona) — cero migraciones.
- **H3 con criterio de UX**: el `AutomaticKeepAliveClientMixin` se
  conserva solo en `_ExerciseCardState` (una tarjeta = un mixin) y se
  elimina de las filas; las filas viven dentro de la tarjeta, así que su
  estado y el texto sin confirmar siguen vivos al desplazarse.
- **Aprobación de usuario para comentarios y comportamiento**: la
  constitución prohíbe comentarios en el código (AGENTS.md) y exige
  `docs/constitucion.md`; el usuario aprobó explícitamente doc-comentarios
  `///` en español en los ficheros tocados por la 014 y la nueva sección
  en vivo visible por defecto y plegable. Este documento deja constancia
  (principio 1: la spec manda sobre la regla general).
- **Orden de tareas**: entorno (T-000) → A (T-001) → B (T-002…T-007) →
  C (T-008…T-015) → D (T-016) → E (T-017) → F (T-018), cada una cerrando
  con `flutter test` + `flutter analyze` en verde.

## Criterios de finalización
- Tarjetas del editor con miniatura + chips + nombre idénticas en estilo a
  las de la sesión en vivo (incluye `ThumbFallback`).
- Sección en vivo con mapa, zonas y las dos gráficas actualizándose tras
  completar una serie (test widget con debounce corto).
- Progreso sin `recalculate()` obligatorio al abrir, actualizado por
  stream y sin relanzamientos por toque en el mapa.
- Nueve hallazgos H1–H9 corregidos, cada uno con su test (ver tabla
  hallazgo → tarea en plan.md y tasks.md).
- `README.md` reescrito en español con los apartados pedidos.
- Doc-comentarios `///` en español en los ficheros tocados.
- Goldens actualizados (`muscle_map_*`, `progress_empty` y los nuevos de
  las gráficas) y `flutter test` + `flutter analyze` verdes.
