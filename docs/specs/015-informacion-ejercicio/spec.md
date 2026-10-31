# Spec 015 — Ficha de información del ejercicio

## Contexto y objetivo
La app abre hoy la ficha del ejercicio con `ExerciseDetailView`
(`lib/ui/views/exercise_detail_view.dart`): media, chips, pasos e/inglés,
ajuste de descanso y atribución. Es una ficha de catálogo, sin datos del
propio atleta.

El usuario pide la pantalla **«informacion_del_ejercicios»** con fidelidad
1:1 al set de Stitch en `docs/pantallas/informacion_del_ejerccios/`
(`DESIGN.md`, `code.html`, `screen.png`), con una diferencia explícita:
donde el mockup no muestra media, la app debe mostrar el **GIF real del
ejercicio** servido desde `gifPath` con la caché existente
(`gifCache.ensureCached` + `gifUrl()` de `lib/domain/media.dart`) y
fallback a la miniatura local empaquetada.

La nueva ficha convierte el detalle de catálogo en una **analítica del
ejercicio para el atleta**: KPIs de fuerza, progresión temporal, cues
técnicos, activación muscular, historial de sesiones y CTA de acción.

> Nota de proceso: un implementador ya está trabajando en el código de la
> vista en paralelo. Esta spec es la **referencia de aceptación**: RF y
> criterios mandan sobre el diseño de clases del código entregado.

## Usuarios
Atleta que entrena con hevywork: abre un ejercicio desde el catálogo o
desde una rutina y quiere saber, sin salir de la ficha, cuánto mueve, cómo
ha progresado, cómo se ejecuta y qué hizo la última vez.

## Historias de usuario
- H1: Como usuario quiero ver el GIF real del ejercicio al abrir la ficha
  (y su miniatura si estoy sin red), para reconocer la ejecución al
  instante.
- H2: Como usuario quiero ver mis KPIs del ejercicio (1RM, carga máxima,
  volumen máximo y series totales) de un vistazo, para decidir qué poner
  hoy.
- H3: Como usuario quiero ver la progresión del ejercicio (1RM, carga o
  volumen) en 1M/3M/6M/1A/Todo, para comprobar que estoy mejorando.
- H4: Como usuario quiero leer los cues técnicos y ver la activación
  muscular del ejercicio, para ejecutarlo con intención.
- H5: Como usuario quiero revisar el historial de sesiones con mis series,
  para recordar qué hice la última vez y con qué RIR.
- H6: Como usuario quiero añadir el ejercicio a mi sesión (o iniciar una)
  desde la propia ficha, para actuar sin navegar.

## Alcance (a confirmar con el usuario; ver Decisiones)
- Pantalla nueva `ExerciseInfoView` que sustituye a `ExerciseDetailView`
  en los dos puntos de entrada actuales (catálogo y detalle de rutina).
- GIF real vía caché existente con fallback a miniatura local.
- Identidad: título, badges de equipo/categoría/músculos (target
  destacado, etiquetas en español).
- Rejilla 2×2 de KPIs calculados del historial local del usuario.
- Gráfico de progresión con selector de métrica y ventana (CustomPainter
  propio, patrón `weight_trend.dart`).
- Sección «Biomecánica & Cues Técnicos» plegable con los pasos del
  catálogo + barra de activación muscular.
- Historial de sesiones paginado con tabla de series de la más reciente.
- CTA inferior fijo «Añadir a Rutina o Iniciar Sesión».
- Conservación del ajuste de descanso 15–300 s (regresión de la 002).

## Inventario de secciones de pantalla (SCR)
Basado en `screen.png` / `code.html` de
`docs/pantallas/informacion_del_ejerccios/`:

- SCR-1 · Context bar: volver, «Base de Datos / Detalle de Ejercicio»,
  favorito (oculto v1), «Más opciones» (oculto v1).
- SCR-2 · Identidad: título + badges anatómicos (equipo, categoría,
  target destacado, secundarios).
- SCR-3 · Media: **GIF real del ejercicio** (diferencia explícita sobre
  el mockup) con fallbacks de RF-2.
- SCR-4 · Rejilla KPI 2×2: 1RM Estimado (+chip PR), Carga Máxima,
  Volumen Máx., Total Series.
- SCR-5 · Gráfico de progresión: selector de métrica, filtros de
  ventana, sparkline, insights Delta Período y Frecuencia Media.
- SCR-6 · Biomecánica & Cues Técnicos (plegable) + Distribución de
  activación muscular.
- SCR-7 · Historial de Sesiones: tarjeta expandida con tabla de series,
  tarjetas condensadas, «Cargar sesiones anteriores», estado vacío.
- SCR-8 · CTA inferior sticky «Añadir a Rutina o Iniciar Sesión».
- SCR-9 · Conservados de la ficha actual: ajuste de descanso ±15 s,
  selector de idioma de pasos, atribución.

## Requisitos funcionales (EARS)

### Identidad, media y descanso
- RF-1: CUANDO el usuario abre la ficha desde el catálogo o desde el
  detalle de una rutina, EL SISTEMA muestra `ExerciseInfoView` con el
  diseño Obsidian Kinetic de `docs/pantallas/informacion_del_ejerccios/`
  (context bar, título + badges, KPIs, gráfico, biomecánica, historial y
  CTA).
- RF-2: CUANDO el ejercicio tiene `gifPath` y hay URL configurada
  (`gifUrl(gifPath) != null`), EL SISTEMA muestra el GIF real servido
  desde la caché `gifCache.ensureCached(exerciseId, gifPath)`; MIENTRAS se
  descarga, o si no hay URL/red, o si la descarga falla, muestra la
  miniatura local `thumbAsset(imagePath)`; sin ninguna de las dos,
  `ThumbFallback`. La miniatura se pinta al instante (sin bloquear la
  apertura en la descarga del GIF).
- RF-3: EL SISTEMA muestra el título del ejercicio y badges de `equipment`,
  `bodyPart`, `target` (destacado) y `secondaryMuscles`; las etiquetas
  musculares se presentan en español (`muscleLabel`) y los pesos en la
  unidad del perfil (`UnitSystemScope`).
- RF-4: EL SISTEMA conserva el ajuste de «Descanso por defecto» 15–300 s
  con stepper ±15 s (RF-5 de la 002), incluidas las claves
  `rest-detail-minus` / `rest-detail-plus`.
- RF-5: EL SISTEMA muestra la atribución del dataset cuando existe y el
  selector de idioma de los pasos si hay más de un idioma (es preferente).

### KPIs
- RF-6: EL SISTEMA presenta una rejilla 2×2 con: **1RM Estimado** (mejor
  e1RM del usuario con la fórmula existente Epley `e1RM()`, con fecha y
  chip «+X kg PR» = mejora sobre el segundo mejor e1RM; sin segundo mejor,
  sin chip), **Carga Máxima** (top set: peso × reps @ RIR), **Volumen
  Máx.** (mayor volumen en una sola sesión con `setVolumeKg`) y **Total
  Series** (serie completadas del ejercicio + nº de entrenamientos que lo
  contienen).
- RF-7: SI el ejercicio no tiene series completadas, ENTONCES cada KPI
  muestra un marcador de vacío («—») y su subtítulo aclaratorio, sin
  excepciones ni ceros engañosos.

### Gráfico de progresión
- RF-8: EL SISTEMA muestra un gráfico de progresión con selector de
  métrica («1RM Estimado» / «Carga Máx (kg)» / «Volumen») y filtro de
  ventana (1M, 3M, 6M, 1A, Todo; 3M por defecto), dibujado con
  `CustomPainter` propio según designer §7.9 (línea, área con gradiente,
  guías punteadas, punto final destacado; sin dependencias de charts).
- RF-9: Cada punto del gráfico es una sesión `finished` que contiene el
  ejercicio, fechado por `endedAt`, con el valor de la métrica de esa
  sesión (mejor e1RM / carga máxima / volumen). Los filtros de ventana y
  métrica recalculan también los insights.
- RF-10: EL SISTEMA muestra bajo el gráfico dos insights: **Delta
  Período** (Δ absoluto y % entre el primer y el último punto de la
  ventana; si el primero es 0, solo Δ absoluto) y **Frecuencia Media**
  (sesiones de la ventana ÷ (días de la ventana ÷ 7), 1 decimal).
- RF-11: SI la ventana elegida tiene menos de dos puntos, ENTONCES el
  gráfico muestra su estado vacío (mensaje) y los insights se ocultan.

### Biomecánica, cues y activación
- RF-12: EL SISTEMA muestra «Biomecánica & Cues Técnicos» como sección
  plegable (por defecto desplegada) con los pasos de
  `exercise_instructions` numerados (01, 02, …) en el idioma disponible
  (es preferente; fallback al primer idioma; switch si hay varios, como la
  ficha actual). Sin pasos: mensaje «Sin instrucciones disponibles».
- RF-13: EL SISTEMA muestra la barra de «Distribución de activación» con
  el músculo objetivo como «Foco Principal» y los `secondaryMuscles`
  repartidos como segmentos, con leyenda en español. Reparto heurístico
  (ver supuesto Q-3): target 70 %, secundarios el resto a partes iguales;
  sin secundarios, barra de un solo segmento.

### Historial de sesiones
- RF-14: EL SISTEMA lista las sesiones `finished` que contienen el
  ejercicio, más reciente primero, **paginadas** (10 por página con botón
  «Cargar sesiones anteriores (N más)»); sin sesiones: estado vacío con
  llamada a usar el CTA.
- RF-15: La tarjeta de la sesión más reciente muestra nombre (fallback
  «Sesión» + fecha si `workouts.name` es null), fecha relativa, volumen
  total de la sesión con ese ejercicio y una tabla de series con columnas
  SET / KG × REPS / RIR / EST. 1RM; las warmups se marcan «(Cal.)», la
  serie con el mejor e1RM histórico del ejercicio lleva ★, y el pie
  resume el RIR medio (10 − RIR = RPE si se muestra como RPE). Las
  sesiones anteriores se muestran condensadas (resumen «N sets
  completados · Top: kg × reps»).
- RF-16: EL SISTEMA excluye de KPIs, gráfico e insights las series sin
  completar y los calentamientos, y las series con `reps > 12` no aportan
  e1RM (mismos criterios que `e1RM()`, `setVolumeKg()` y
  `personalRecords()`).

### CTA
- RF-17: CUANDO el usuario pulsa «Añadir a Rutina o Iniciar Sesión»,
  EL SISTEMA: con sesión activa, añade el ejercicio a ella
  (`WorkoutRepository.addExercise`) y confirma con snackbar; sin sesión
  activa, inicia una nueva con el ejercicio (`startWorkout` +
  `addExercise`) y navega/avisa. Nunca crea dos sesiones activas (RF-19
  de la 001).

### Mantenimiento
- RF-18: EL SISTEMA mantiene `pubspec.yaml` sin dependencias nuevas, sin
  `elevation` ni `BoxShadow`, con goldens regenerados si la UI cambia, y
  cierra con `flutter test` + `flutter analyze` en verde (AGENTS.md).

## Requisitos no funcionales
- RNF-1: La apertura de la ficha es instantánea: la miniatura local se
  pinta de inmediato y el GIF se resuelve en segundo plano
  (`FutureBuilder` sobre el `Future<File?>`, patrón de la ficha actual).
- RNF-2: El historial es paginado y las queries del KPI/gráfico están
  acotadas al `exerciseId`; nada de cargar todas las series en memoria de
  la UI.
- RNF-3: Targets táctiles ≥ 48 dp y contraste AA (designer §11);
  `Semantics` en estrella de PR, pestañas, ventana y CTA.
- RNF-4: Código e identificadores en inglés; documentación y mensajes al
  usuario en español (AGENTS.md §Estilo).
- RNF-5: Los cálculos de KPIs, serie temporal, delta y frecuencia viven
  en dominio puro Dart (testeable sin widgets ni Supabase).
- RNF-6: Sin migraciones de esquema (drift ni Postgres): se usan
  `exercises`, `exercise_instructions`, `workouts`,
  `workout_exercises` y `workout_sets` existentes.
- RNF-7: Pesos en kg en la base; conversión a lb solo al mostrar
  (lib/domain/units.dart).

## Casos límite
- Ejercicio sin ninguna serie → KPIs «—», gráfico en estado vacío,
  historial vacío, CTA activa. Nunca divisiones por cero en frecuencia.
- Sin `SUPABASE_URL` / sin credenciales → `gifUrl()` null → miniatura
  local.
- Sin red y sin caché del GIF → miniatura local; con caché → GIF offline.
- `gifPath` null o `imagePath` null → ThumbFallback.
- Serie con `reps > 12` o `weightKg <= 0` → sin e1RM (no cuenta para PR
  ni gráfico 1RM).
- Sesión solo de calentamientos → se trata como «sin datos» para KPIs.
- `secondaryMuscles` null/vacío → barra de activación de un segmento.
- Ventana sin puntos o con un solo punto → estado vacío del gráfico.
- Tabla de series en pantallas estrechas → columnas sin desbordes (Wrap /
  scroll horizontal si hace falta).
- Pulsar CTA con sesión activa → solo añade; sin sesión → crea una.

## Fuera de alcance (015)
- Favoritos (la estrella del mockup): sin tabla, sin sync; el botón se
  oculta (Q-2).
- Badge «TIER S · 1RM»: el catálogo no tiene campo tier; se omite.
- Botón «Filtrar» del historial y «Más opciones» del context bar: se
  ocultan en v1 (la ventana se controla con los filtros del gráfico).
- «Añadir a **Rutina**…» como acción sobre una rutina existente: v1 solo
  sesión activa/nueva (Q-4).
- Cues anatómicos específicos por ejercicio más allá de las instrucciones
  del dataset.
- Cualquier migración drift/Postgres o dependencia nueva.
- Spec 011 (dispositivos/HRV): sigue pendiente, no se toca.

## Supuestos y preguntas abiertas
- Q-1 (decisión propuesta: sí): ¿`ExerciseInfoView` **sustituye** a
  `ExerciseDetailView` en catálogo y detalle de rutina, o conviven ambas?
  Se propone sustituir (una sola ficha; conserva descanso, pasos y
  atribución).
- Q-2: ¿Se quiere favoritos en una iteración futura? Requiere tabla
  drift + remota + sync (spec propia).
- Q-3: No existen porcentajes EMG reales en el dataset. Se asume reparto
  heurístico target 70 % / secundarios 30 % a partes iguales para la barra
  de activación. ¿Aceptado, o prefieres la barra sin porcentajes?
- Q-4: ¿El CTA debe ofrecer en v2 «añadir a una rutina existente»
  (abriendo el editor con el ejercicio preseleccionado)?
- Q-5: ¿Filtrar el historial por algo más allá de la ventana del gráfico
  (p. ej. por rutina)?
- Supuesto: la constitución vive hoy en `AGENTS.md` +
  `docs/designer.md` (`docs/constitucion.md` no existe en el repo); esta
  spec aplica esas reglas (sin dependencias, sin sombras, tests como
  puerta).
- Supuesto: un implementador trabaja en la vista en paralelo; los
  nombres/archivos de este plan se ajustan si el código ya entregado
  difiere, pero las RF son la norma de aceptación.

## Decisiones (Cerradas)
- **Spec nueva (015)** en vez de ampliar la 001/003: la pantalla añade
  analítica de datos propios del atleta y una vista compleja; convive con
  la 003 (buscador) y la 004 (rutinas) sin tocarlas.
- **Sustitución de la ficha** (Q-1): los puntos de entrada
  `catalog_view.dart` y `routine_detail_view.dart` pasan a
  `ExerciseInfoView`; el ajuste de descanso y la atribución se conservan
  para no introducir regresiones en la 002/001.
- **Dominio nuevo** `lib/domain/exercise_stats.dart`: cálculos puros
  (KPIs, puntos por sesión, delta, frecuencia) reutilizando `e1RM()`,
  `setVolumeKg()` y criterios de `personalRecords()` (sin warmups, sin
  incompletas, `reps <= 12`).
- **Consulta paginada en `WorkoutRepository`** (junto a
  `previousSets()`): sesiones del ejercicio con sus series, ordenadas por
  `endedAt` desc, con offset/límite; una sola query uniendo
  `workout_sets` + `workout_exercises` + `workouts` (status `finished`).
- **Gráfico con `CustomPainter` propio** (patrón `weight_trend.dart` /
  designer §7.9): sin dependencias de charts (AGENTS.md); los filtros de
  métrica y ventana son estado local de la vista.
- **Heurística 70/30** para la activación muscular (Q-3) documentada como
  supuesto, no como dato real.
- **En paralelo**: la implementación de la vista ya está en marcha; esta
  spec fija los criterios de aceptación y la tarea de tests correspondiente.

## Criterios de finalización
- La ficha abre desde catálogo y detalle de rutina con el diseño de la
  carpeta de referencia y el GIF real (o fallbacks de RF-2).
- KPIs, gráfico con 3 métricas × 5 ventanas, delta y frecuencia calculan
  sobre datos reales del usuario, con estados vacíos.
- Historial paginado con tabla de series, warmups marcadas y ★ de PR.
- CTA añade a la sesión activa o inicia una sesión con el ejercicio.
- Descanso, pasos e/inglés y atribución siguen funcionando (sin
  regresiones de 001/002).
- `flutter test` en verde (con los tests nuevos de esta spec) y
  `flutter analyze` sin incidencias.
