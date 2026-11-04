# Spec 016 — Mejoras de la sesión en vivo, adaptación a pantalla y ficha de ejercicio

## Contexto y objetivo

Spec 014 (fatiga en tiempo real) y 015 (ficha de ejercicio) están cerradas.
El usuario pide **8 mejoras** (las 6 originales + 2 añadidas el 2026-11-04)
que no están cubiertas por ninguna spec abierta:

| # | Petición del usuario | Spec que toca hoy |
|---|---|---|
| 1 | Que las notificaciones suenen más fuerte (volumen alto) | 002 (§2, avisos del descanso) |
| 2 | Que las series añadidas o quitadas se guarden correctamente (persistencia en DB) | 001/002 (RF-7/RF-1) |
| 3 | Que la tabla de fatiga muestre también las series de la semana | 007/008 (RF-24) / 014 (RF-7) |
| 4 | Que el mapa muscular en vivo tenga pestaña para ver la parte de atrás | 007/014 (RF-7) |
| 5 | Que la interfaz se adapte a cualquier pantalla (móvil, tablet, rotada) sin importar la configuración del dispositivo | 008 (rediseño) |
| 6 | Que la interfaz se adapte al tamaño real de la pantalla, no al sistema del dispositivo | 008 (rediseño) |
| 7 | Que la ficha del ejercicio (`ExerciseInfoView`) quede **igual al .html** del mockup (la actual le parece «muy feo») | 015 (ficha, cerrada) |
| 8 | Navegar desde la **miniatura** de un ejercicio (sesión en vivo y editor de rutinas) a su ficha de información | 014/004 (miniaturas, sin navegación) |

Diagnóstico inicial (a confirmar en T-001):

- **Notificaciones**: `RestNotifier.alertNow()` (sonido + vibración) **no se
  invoca en ningún sitio**; cuando el descanso llega a cero en primer plano
  solo cambia la etiqueta de la píldora a «LISTO» (`live_workout_view.dart`
  `_restPill`). En segundo plano sí se programa con `zonedSchedule`, pero el
  canal Android `rest_timer` no declara sonido propio ni uso de alarma, así
  que suena por el canal genérico de notificaciones (volumen bajo).
- **Persistencia**: el flujo UI → `WorkoutRepository.logSet/deleteSet/
  updateSet/undoLastSet` → drift + cola sync existe y tiene tests de
  repositorio en verde; hay que **reproducir y acotar** dónde se pierde el
  cambio (T-001) antes de tocar código.
- **Tabla de fatiga en vivo**: `LiveFatigueSection` muestra por zona solo
  `músculo · estado`; `MuscleZoneStats.sets` (series de los últimos 7 días)
  ya se calcula pero **no se pinta** en la sesión en vivo (en Progreso sí).
- **Espalda en vivo**: `MuscleMap` ya soporta `showBack` y Progreso ya tiene
  el toggle `_ViewToggle`; en vivo se pasa `showBack: false` fijo
  (`live_workout_view.dart:334`).
- **Responsivo**: solo hay un test de pantalla estrecha
  (`test/small_screen_layout_test.dart`, 320 dp); no hay breakpoints de
  tablet (designer §4.2 prevé máx. 640 dp centrado) ni aislamiento de la
  escala de texto del sistema.

> No hay pantalla nueva: esta spec **no genera `DESIGN.md`** nuevo. La
> mejora 7 se aplica sobre el mockup ya existente de
> `docs/pantallas/informacion_del_ejerccios/` (`code.html` + `screen.png` +
> `DESIGN.md`, fuente de verdad visual, fidelidad 1:1); el resto de mejoras
> se aplica con los tokens y reglas de `docs/designer.md`.

## Usuarios

Atleta que entrena con la app: usa la sesión en vivo en el móvil (a veces en
tablet o con la pantalla rotada), quiere oír el aviso del descanso sin
mirar el móvil, confiar en que sus series quedan guardadas, ver qué zonas ha
trabajado esta semana y revisar la espalda en el mapa. Además, consulta la
ficha de un ejercicio para ver sus datos y quiere llegar a ella de un toque
desde la miniatura, con un diseño claro y coherente con el mockup.

## Historias de usuario

- H1: Como usuario quiero oír el aviso del descanso fuerte y claro (también
  en primer plano) para no perder la serie por no mirar el móvil.
- H2: Como usuario quiero que las series que añado o quito queden guardadas
  en la base de datos para no perder mi entrenamiento.
- H3: Como usuario quiero ver en la tabla de fatiga cuántas series de la
  semana llevo por zona para dosificar el entrenamiento.
- H4: Como usuario quiero cambiar el mapa muscular de la sesión en vivo a la
  vista de espalda para revisar la musculatura posterior.
- H5: Como usuario quiero que la interfaz se vea bien en cualquier
  pantalla (móvil pequeño, tablet, rotada) sin desbordes.
- H6: Como usuario quiero que la interfaz siga el tamaño real de mi
  pantalla aunque haya cambiado la configuración de fuente o de pantalla
  del sistema.
- H7: Como usuario quiero que la ficha del ejercicio se vea como el diseño
  de referencia (mockup HTML) para leerla con claridad y sin ruido visual.
- H8: Como usuario quiero tocar la miniatura de un ejercicio en la sesión
  en vivo o en el editor de rutinas para abrir su ficha de información.

## Alcance

- Aviso audible en primer plano al terminar el descanso + canal Android de
  alto volumen (nuevo id de canal).
- Diagnóstico y refuerzo de la persistencia de series (sin migración de
  esquema).
- Series semanales visibles en la tabla de la sección de fatiga en vivo y
  etiqueta legible de la gráfica de volumen.
- Toggle Frente/Espalda dentro de `LiveFatigueSection`.
- Helper de breakpoints + ancho máximo de contenido en tablet + acotación de
  la escala de texto del sistema.
- Rediseño de `ExerciseInfoView` con fidelidad 1:1 al `code.html` de
  `docs/pantallas/informacion_del_ejerccios/`, con los KPIs y el gráfico
  conectados a datos reales (hoy pintan vacío).
- Navegación a `ExerciseInfoView` al tocar la miniatura de un ejercicio en
  la sesión en vivo (tarjeta expandida y colapsada) y en el editor de
  rutinas.
- Tests de regresión por mejora y cierre con suite completa.

## Áreas de UI afectadas (A-xxx)

| Área | Fichero | Mejoras |
|---|---|---|
| A-1 · Aviso del descanso | `lib/domain/services/rest_notifier.dart`, `lib/ui/views/live_workout_view.dart` (`_restPill`, `didChangeAppLifecycleState`) | 1 |
| A-2 · Tabla de series en vivo | `lib/ui/views/live_workout_view.dart` (`_ExerciseCard`, `_EditableSetRow`), `lib/data/repositories/workout_repository.dart` | 2 |
| A-3 · Sección de fatiga en vivo | `lib/ui/widgets/live_fatigue_section.dart` | 3, 4 |
| A-4 · Gráfica de volumen semanal | `lib/ui/widgets/zone_volume_chart.dart` | 3 |
| A-5 · Shell y pestañas | `lib/main.dart` (`HevyWorkApp.builder`, `MainNavigator`) | 5, 6 |
| A-6 · Vista Progreso (solo reutilización, sin cambio visual) | `lib/ui/views/progress_view.dart` (`_ViewToggle` → widget compartido) | 4 |
| A-7 · Ficha del ejercicio | `lib/ui/views/exercise_info_view.dart` | 7 |
| A-8 · Miniaturas navegables | `lib/ui/views/live_workout_view.dart` (`ExerciseThumb` expandida/colapsada), `lib/ui/views/routine_editor_view.dart` (`_draftTile`) | 8 |

## Requisitos funcionales (EARS)

### Notificaciones del descanso (mejora 1)
- RF-1: CUANDO el temporizador de descanso alcanza el estado `done` con la
  app en primer plano, EL SISTEMA emite un aviso audible + vibración
  **exactamente una vez** por descanso. (Hoy no suena nada: `alertNow()` no
  se invoca.)
- RF-2: EL SISTEMA usa un canal de notificación de alto volumen:
  Android `Importance.high` + `Priority.high`, `playSound: true`,
  `enableVibration: true` y `audioAttributesUsage:
  AudioAttributesUsage.alarm` (stream de alarma, volumen independiente del
  multimedia), con **id de canal nuevo** porque Android no reconfigura un
  canal ya creado; iOS/macOS `presentSound: true` con el sonido por defecto.
  Los mismos `NotificationDetails` se usan para programar y para mostrar.
- RF-3: CUANDO la app pasa a segundo plano con un descanso en curso, EL
  SISTEMA lo programa con `zonedSchedule` en el instante exacto con los
  detalles de RF-2, y lo cancela al reanudar (comportamiento de la 002
  conservado).
- RF-4: SI el plugin de notificaciones no está disponible, la plataforma no
  lo soporta o el permiso fue denegado, ENTONCES el aviso degrada a
  `SystemSound` + vibración sin excepciones propagadas y sin romper el
  descanso ni la sesión.

### Persistencia de series (mejora 2)
- RF-5: CUANDO el usuario añade, confirma, edita, deshace o borra una serie
  en la sesión en vivo, EL SISTEMA persiste el cambio en `workout_sets`
  (drift) y encola la mutación a la cola de sync; una lectura posterior
  (stream `watchSets` o query directa) devuelve exactamente ese cambio.
- RF-6: SI una operación de serie falla (validación de datos, sesión no
  editable), ENTONCES no se escribe nada en la BD y el error se muestra en
  snackbar; nunca hay escritura parcial ni fallo silencioso.
- RF-7: EL SISTEMA conserva las series pendientes (`completed = false`,
  precargadas desde la rutina) tras reiniciar la app, con los mismos valores
  de peso, reps, RIR, tipo e `orderIndex`.

### Series de la semana en la tabla de fatiga (mejora 3)
- RF-8: EL SISTEMA muestra en la sección de fatiga de la sesión en vivo, por
  cada zona visible, las **series de los últimos 7 días** junto al volumen
  semanal y el estado, con formato «`N series · X kg`» (español, unidad del
  perfil), incluida la sesión activa (mismo criterio de ventana que
  `weeklyZoneStats`, RF-24 de la 008 / RF-5 de la 014).
- RF-9: EL SISTEMA muestra en la gráfica de barras de volumen semanal el
  recuento de series y el volumen con etiquetas legibles en español
  (sustituye el texto ambiguo «`kg×series`» actual).

### Vista de espalda en vivo (mejora 4)
- RF-10: EL SISTEMA muestra en la sección de fatiga de la sesión en vivo un
  control Frente/Espalda (por defecto **Frente**) que cambia la vista del
  `MuscleMap` y la de la gráfica de zonas; al cambiar de vista se limpia la
  selección de músculo si la zona elegida no es visible en esa vista
  (mismo criterio que `_syncSelection` de Progreso).

### Adaptación a pantalla (mejoras 5 y 6)
- RF-11: EL SISTEMA adapta el layout al **ancho real de pantalla**: ancho
  < 600 dp → móvil (margen horizontal 16 dp, gutter 12 dp); ancho ≥ 600 dp →
  tablet (margen 24 dp, gutter 16 dp, contenido centrado con ancho máximo
  640 dp, designer §4.2). La app no presenta desbordes (`RenderFlex`
  overflow) ni solapes con la pill de navegación en retrato, horizontal
  (pantalla rotada) ni tablet.
- RF-12: EL SISTEMA deriva el layout del **tamaño real de pantalla**
  (`MediaQuery.sizeOf` / `LayoutBuilder`) y **acota la escala de texto del
  sistema** a un rango definido, de modo que la configuración del
  dispositivo (tamaño de fuente / pantalla) no altera la retícula: con escala
  1.0, 1.3 y 2.0 el layout base es el mismo y no hay desbordes.
- RF-13: EL SISTEMA conserva en todos los tamaños los requisitos de
  accesibilidad: targets táctiles ≥ 48 dp donde ya existían, contraste AA y
  textos con `overflow`/`maxLines` donde el espacio es estrecho.

### Rediseño de la ficha del ejercicio (mejora 7)
- RF-14: CUANDO el usuario abre `ExerciseInfoView`, EL SISTEMA muestra la
  ficha con **fidelidad 1:1** al mockup
  `docs/pantallas/informacion_del_ejerccios/code.html`: context bar (botón
  volver, rótulo centrado «Base de Datos / Detalle de Ejercicio»),
  identidad (h1 con el nombre + tags en píldora con el target destacado),
  rejilla KPI 2×2 (etiqueta mayúscula + icono, métrica grande con unidad,
  subtítulo, chip PR), gráfico con selector de métrica, filtros
  1M/3M/6M/1A/Todo e insights **Delta Período** y **Frecuencia Media**,
  «Biomecánica & Cues» en tarjeta plegable con chevron y filas numeradas
  sobre superficie `low`, «Distribución de activación» con leyenda de
  puntos y porcentajes, historial con cabecera con recuento y **fila PR
  resaltada**, y CTA inferior flotante con icono. Tipografías Space Grotesk
  (títulos y métricas) y Geist (texto) según el `DESIGN.md` de la carpeta.
  Donde el mockup no muestra contenido que la 015 exige (GIF real, SCR-3;
  descanso, idioma y atribución, SCR-9) se conserva en el orden fijado en
  D-026. Ocultos: favorito, badge «Tier», «Filtrar» y «Más opciones»
  (fuera de alcance de la 015). Sin `elevation` ni `BoxShadow`.
- RF-15: EL SISTEMA muestra en la ficha **datos reales del usuario**: la
  rejilla KPI se calcula con `exerciseKpis(_history)` y el gráfico recibe
  `_history`, recalculando curva e insights al cambiar métrica o ventana
  (cierra RF-6…RF-11 de la 015, que hoy pintan `ExerciseKpis.empty` y
  `sessions: const []`). Sin series, se mantienen los estados vacíos de la
  015 («—» + subtítulo; estado vacío del gráfico).

### Navegación desde miniaturas (mejora 8)
- RF-16: CUANDO el usuario toca la miniatura (`ExerciseThumb`) de un
  ejercicio en la sesión en vivo (tarjeta expandida o colapsada) o en el
  editor de rutinas, EL SISTEMA navega a `ExerciseInfoView` de ese
  ejercicio pasando `database` y `workoutRepository` (historial, KPIs y CTA
  funcionan). El resto de la tarjeta conserva su comportamiento actual
  (expandir/colapsar en vivo; reordenar y sus controles en el editor); en
  la tarjeta colapsada el toque en la miniatura navega y **no** expande.

## Requisitos no funcionales

- RNF-1: `pubspec.yaml` **sin dependencias nuevas** (AGENTS.md, principio
  2). Todo se resuelve con `flutter_local_notifications`, `SystemSound`,
  `HapticFeedback` y widgets de Flutter ya disponibles.
- RNF-2: **Sin migraciones** drift ni Postgres: se usan `workout_sets`,
  `workouts` y `muscle_fatigue` tal y como están.
- RNF-3: Sin `elevation` ni `BoxShadow`; jerarquía por tipografía y espacio
  (designer §6). Sin goldens rotos: se regeneran solo los afectados.
- RNF-4: Código e identificadores en inglés; documentación y mensajes al
  usuario en español.
- RNF-5: Cierre obligatorio de **cada** tarea con `flutter test` en verde y
  `flutter analyze` sin incidencias (AGENTS.md §Al terminar).
- RNF-6: Sin regresiones en las specs 001, 002, 007, 008, 014 y 015: los
  tests existentes siguen en verde.
- RNF-7: Cálculos y reglas de layout en código testeable sin widgets
  (breakpoints en dominio puro, formato de series en función pura).
- RNF-8: Sin sobrecostes de render: el nuevo toggle y las etiquetas no
  añaden reconstrucciones por tecla (hereda H1 de la 014).
- RNF-9: **Regresión de la 015**: tras el rediseño, los RF-1…RF-17 de la
  ficha siguen cubiertos; `test/exercise_info_view_test.dart` se mantiene
  en verde (solo se ajustan expectativas de presentación justificadas,
  conservando claves `rest-detail-minus`/`rest-detail-plus`,
  `history-load-more` y los textos de pasos, badges, historial y estado
  vacío).

## Casos límite

- Permiso de notificación denegado o plataforma sin soporte (Linux) →
  fallback de RF-4, sin excepciones en la UI.
- Canal `rest_timer` ya existente en el dispositivo con la configuración
  vieja → se usa un **id nuevo** (`rest_timer_v2`), si no Android ignora el
  cambio de sonido.
- El descanso termina justo al pasar a segundo plano (o viceversa) → un
  solo aviso, no dos (bandera de disparo por descanso).
- Descansos consecutivos → el id de notificación se reutiliza/limpia para no
  acumular avisos pendientes.
- Borrar/editar serie con la fila en `busy` o con sesión no `active` →
  RF-6: snackbar, sin escritura.
- Añadir serie con valores inválidos (reps 0, peso negativo, RIR > 10) →
  `SetValidationException` → snackbar, la BD no cambia.
- Zona con 0 series en la semana → «Sin series», sin divisiones por cero.
- Pantalla de 320 dp con escala de texto 2.0 → clamp de RF-12 evita el
  desborde.
- Tablet horizontal (1024 dp) → contenido de 640 dp centrado, sin que las
  gráficas se estiren hasta perder legibilidad.
- Sesión activa sin zonas (sin series) → estados vacíos actuales intactos.
- Miniatura tocada en la tarjeta colapsada en vivo → navega a la ficha y
  **no** expande la tarjeta; al volver, la tarjeta sigue colapsada (el
  `GestureDetector` interno gana en la arena de gestos).
- Miniatura `ThumbFallback` (sin `imagePath`) en el editor → es tocable y
  no navega (no hay ejercicio hidratado); nunca crash.
- Ficha abierta desde la miniatura con `database`/`workoutRepository` →
  pasos, historial, KPIs y CTA funcionan igual que desde el catálogo.
- Ejercicio sin series → KPIs «—», gráfico en estado vacío, insights
  ocultos (RF-7/RF-11 de la 015), sin divisiones por cero.
- CTA del mockup con texto único «Añadir a Rutina o Iniciar Sesión» → con
  sesión activa solo añade; sin sesión, crea una (snackbar actual).

## Fuera de alcance (016)

- Sonido de notificación personalizado con asset propio (Q-007): se usa el
  sonido del sistema en la corriente de alarma.
- Control del volumen del sistema desde la app (AudioManager /
  `setStreamVolume`): requiere código nativo y no es posible sin
  dependencias nuevas.
- Cualquier migración de esquema drift/Postgres o dependencia nueva.
- Rediseño visual de vistas **distintas** de `ExerciseInfoView` (solo
  adaptación y mejoras puntuales); la ficha sí se rediseña en la mejora 7.
- Favoritos, badge «Tier», «Filtrar» y «Más opciones» de la ficha: siguen
  ocultos (fuera de alcance de la 015, Q-2).
- Pantallas nuevas, favoritos, spec 011 (dispositivos/HRV) y 013: no se
  tocan.
- Cambios en Progreso más allá de reutilizar el toggle (ya muestra series
  semanales, Q-010).

## Supuestos y preguntas abiertas

- Q-007: ¿Se quiere un **sonido propio** para el aviso del descanso (asset
  raw en Android / bundle en iOS) en lugar del sonido del sistema? Propuesta:
  por ahora sistema en stream de alarma (sin asset, sin dependencias); si se
  quiere un timbre propio, añade una tarea futura.
- Q-008: **Causa raíz** del fallo de persistencia de la mejora 2: el flujo
  actual parece correcto y está testeado a nivel de repositorio. T-001
  reproduce el caso, identifica la causa y la documenta; mientras tanto se
  asume que el refuerzo son tests de extremo a extremo (vista → BD) y la
  eliminación de cualquier fallo silencioso (RF-6).
- Q-009: ¿«No al sistema del dispositivo» significa **acotar la escala de
  fuente** del sistema (propuesta de RF-12: clamp a un rango) o también
  ignorar el «tamaño de pantalla/densidad» que fija el sistema? Se propone
  acotar solo la escala de texto y basar los breakpoints en píxeles reales
  vía `MediaQuery.sizeOf`; si el usuario quiere ignorar el textScale por
  completo (1.0 fijo), cambiar el tope del clamp es un cambio de una línea.
- Q-010: ¿La tabla con series de la semana debe tocarse también en
  Progreso? Ya las muestra (`_ZoneRow`): propuesta **no tocar** (solo vivo).
- Q-011: ¿Extraer `_ViewToggle` de Progreso a un widget compartido
  `lib/ui/widgets/view_toggle.dart`? Propuesta: **sí** (mismo patrón que
  `ExerciseChips` en la 014, D-015).
- Q-012: Los puntos de entrada actuales de la ficha (`catalog_view.dart:265`
  y `routine_detail_view.dart:346`) construyen `ExerciseInfoView(exercise: …)`
  **sin** `database` ni `workoutRepository` → pasos, historial, KPIs y CTA
  no funcionan desde catálogo ni desde detalle de rutina. ¿Unificarlos en
  T-009 pasando `database: localDb, workoutRepository: workoutRepository`
  (globales de `main.dart`)? Propuesta: **sí** (cambio de una línea por
  punto de entrada, misma corrección que la navegación nueva).
- Q-013: ¿El área tocable es **solo la miniatura** (literal de la
  petición) o también los chips/nombre en el editor? Propuesta: solo la
  miniatura en las tres ubicaciones (D-028); ampliar a la fila de cabecera
  es un cambio trivial si se pide.
- Supuesto: la constitución vive en `AGENTS.md` + `docs/designer.md`
  (`docs/constitucion.md` no existe); esta spec aplica esas reglas.
- Supuesto: no hay DESIGN.md nuevo porque no hay pantalla nueva; los
  criterios visuales salen de `docs/designer.md` (§3, §4.2, §6, §11).

## Decisiones (cerradas)

- **D-018**: spec **nueva 016** en vez de ampliar 002/007/008/014: son seis
  mejoras transversales con puerta propia de tests.
- **D-019**: canal de notificación **nuevo id `rest_timer_v2`** con
  `audioAttributesUsage: AudioAttributesUsage.alarm` (Android no reconfigura
  canales existentes; reutilizar `rest_timer` no cambiaría el sonido).
- **D-020**: aviso en primer plano con `plugin.show()` usando los mismos
  detalles (mismo canal → mismo volumen alto) + vibración, con `SystemSound`
  como fallback; una sola vez por descanso (bandera en la vista).
- **D-021**: persistencia sin cambios de esquema: primero **diagnóstico
  (T-001)**, luego refuerzo con tests extremo a extremo; cualquier fix se
  documenta en `plan.md` §5 y en `memory.md`.
- **D-022**: series semanales de la tabla en vivo salen de
  `MuscleZoneStats.sets` (ya lo entrega `watchFatiguePanel`), sin consulta
  nueva ni cambio de ventana (7 días, incluye sesión activa).
- **D-023**: toggle frente/espalda **dentro** de `LiveFatigueSection` (dueña
  del estado), extrayendo `_ViewToggle` a `lib/ui/widgets/view_toggle.dart`
  compartido con Progreso; `live_workout_view` deja de pasar `showBack`
  fijo.
- **D-024**: breakpoints en helper puro `lib/ui/layout/screen_breakpoints.dart`
  (phone/tablet, márgenes, ancho máximo 640 dp) + acotación de `textScaler`
  en el `builder` de `MaterialApp` (`main.dart`), testeable sin widgets.
- **D-025**: el ancho máximo de contenido de tablet se aplica en el shell
  (`MainNavigator`) y en las vistas de pantalla completa, no de forma global
  vía `MaterialApp.builder`, para no alterar bottom sheets y diálogos.
- **D-026**: fuente de verdad visual de la mejora 7 =
  `docs/pantallas/informacion_del_ejerccios/{code.html,screen.png,DESIGN.md}`
  (fidelidad 1:1, sin `DESIGN.md` nuevo). Orden de secciones: context bar →
  identidad (h1 + tags) → media GIF real (SCR-3, no está en el mockup) →
  KPIs → gráfico + insights → biomecánica + activación → historial →
  descanso/idioma/atribución (SCR-9) → CTA flotante. Se conserva la
  cabecera de tabla «KG × REPS» de la 015 (RF-15) pese a «PESO × REPS» del
  mockup; el CTA pasa al texto único del mockup «Añadir a Rutina o Iniciar
  Sesión»; favorito, tier, «Filtrar» y «Más opciones» siguen ocultos.
- **D-027**: los KPIs y el gráfico se conectan a `_history`
  (`exerciseKpis(_history)`, `sessions: _history`) y los callbacks de
  métrica/ventana actualizan `_selectedMetric`/`_selectedWindow`; hoy están
  hardcodeados a vacío (`ExerciseKpis.empty`, `sessions: const []`,
  callbacks que solo hacen `setState`), así que el rediseño cierra de paso
  RF-6…RF-11 de la 015.
- **D-028**: la navegación de la mejora 8 envuelve `ExerciseThumb` con un
  `GestureDetector` en los tres puntos (tarjeta expandida y colapsada de
  `live_workout_view.dart`, bloque superior de `_draftTile` en
  `routine_editor_view.dart`) en lugar de tocar el widget compartido, y
  navega con `ExerciseInfoView(exercise: …, database: localDb,
  workoutRepository: workoutRepository)` (globales de `main.dart`). En la
  tarjeta colapsada el gestor interno gana en la arena: la miniatura
  navega y el resto de la tarjeta sigue expandiendo.

## Criterios de finalización

- El descanso suena en primer plano y el canal de Android está en stream de
  alarma (RF-1…RF-4), con fallback sin permisos.
- Toda operación de serie en vivo queda reflejada en la BD con test extremo
  a extremo y sin fallos silenciosos (RF-5…RF-7).
- La tabla de fatiga en vivo muestra «N series · X kg» por zona y la
  gráfica tiene etiquetas legibles (RF-8, RF-9).
- El mapa en vivo alterna Frente/Espalda conservando la selección válida
  (RF-10).
- Matriz de tamaños (320–1366 dp, retrato/horizontal, escala 1.0/1.3/2.0)
  sin desbordes, con tablet a 640 dp centrado (RF-11…RF-13).
- La ficha coincide con el `code.html` de la carpeta de referencia
  (estructura, orden, tipografía, sin sombras), con GIF real y SCR-9
  conservados (RF-14).
- KPIs, gráfico e insights de la ficha muestran datos reales del usuario
  con sus estados vacíos (RF-15).
- Tocar la miniatura en la sesión en vivo o en el editor abre la ficha del
  ejercicio con sus repositorios (RF-16).
- `pubspec.yaml` sin dependencias nuevas, sin migraciones y sin sombras.
- `flutter test` completo en verde y `flutter analyze` sin incidencias.
- `docs/specs/README.md` y `memory.md` actualizados con la fila 016.
