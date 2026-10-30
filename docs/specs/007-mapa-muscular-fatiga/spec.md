# Spec 007 — Mapa muscular vectorial de fatiga

## Contexto y objetivo
Visualización vectorial del cuerpo donde cada músculo se colorea en una
escala frío→rojo según la fatiga acumulada de las últimas sesiones.

## Usuarios
Mismo perfil.

## Historias de usuario
- H1: Como usuario quiero ver el mapa y saber qué músculos están frescos o
  fatigados para decidir qué entrenar hoy.
- H2: Como usuario quiero que el mapa se actualice solo al sincronizar
  sesiones.

## Requisitos funcionales (EARS)

### Modelo de fatiga (H1)
- RF-1: EL SISTEMA calcula fatiga por `muscle_group` (de los 29 del dataset)
  como suma ponderada de volúmenes recientes:
  `fatiga = Σ (volumen_serie × factor_tipo × decaimiento_temporal)`.
  - `factor_tipo`: normal/failure = 1.0, drop = 0.5, warmup = 0.
  - `decaimiento_temporal`: e^(-días/7) con corte a los 3 días → a partir
    de los 3 días el factor es 0 (recuperación completa; amenda T-15,
    decisión 2026-10-15 del usuario).
- RF-2: EL SISTEMA normaliza 0–1 y mapea a gradiente: 0 = #4A90E9 (frío),
  0.5 = #F5A623 (tibio), 1 = #D0021B (rojo).

### Mapa vectorial (H1)
- RF-3: EL SISTEMA dibuja el mapa con `CustomPainter` + `Path` (SVG
  preprocesado a `Path` en build). **Nada de imágenes raster**.
- RF-4: CADA músculo del SVG tiene `id = muscle_group` normalizado
  (p.ej. `latissimus_dorsi`, `pectoralis_major`, `quadriceps`).
- RF-5: CUANDO no hay datos para un músculo, se dibuja en gris neutro
  `#9B9B9B`.

### Sincronización (H2)
- RF-6: EL CÁLCULO se ejecuta en el dominio (Dart puro, testeable) tras cada
  sync completado y se cachea. La UI solo lee el cache.

## Requisitos no funcionales
- 60 FPS en scroll/zoom del mapa.
- Cálculo < 50 ms para 30 días de historial.

## Casos límite
- Músculos del dataset sin SVG (p.ej. `cardiovascular_system`) → no se
  dibujan.
- Nombres sin normalizar: `lats` vs `latissimus_dorsi`, `traps` vs
  `trapezius`, `spine` vs `lower_back` → **debe resolverse en la 007**.

## Fuera de alcance
- Animación de fatiga en tiempo real durante la serie.
- Mapa 3D / AR.

## Criterios de finalización
- Tests del cálculo de fatiga (unit, sin UI).
- Test de renderizado del `CustomPainter` (golden test).
- `flutter test` + `flutter analyze` verdes.
- Demo manual: 2 semanas de datos → mapa coherente.

## Decisiones arquitectónicas (Cerradas)
- **Normalización Muscular:** Aprobada la creación de una tabla de equivalencias interna en Dart. Los nombres como `lats` y `latissimus_dorsi` se mapearán al mismo ID unificado para vincularse con un único elemento SVG, eliminando solapes sin modificar el asset JSON original.

## Decisiones de la tanda (aprobadas por el usuario)
- **Ubicación en UI:** sección «Fatiga muscular» al inicio del tab Progreso,
  sobre metas y peso, con toggle «Frente / Espalda». No añade navegación: el
  bottom nav conserva sus 4 destinos.
- **Escala de color:** gradiente contiguo con los tres anclas de RF-2
  (0 = `#4A90E9`, 0.5 = `#F5A623`, 1 = `#D0021B`) y gris `#9B9B9B` sin datos
  (RF-5). Esta decisión prevalece sobre las 5 bandas discretas del
  `designer.md` §12.
- **Origen del SVG:** asset propio en el repo (`assets/maps/muscle_map.svg`),
  autoría propia, con `id = músculo canónico` y dos vistas (`front`/`back`).
  Se declara como asset en `pubspec.yaml` y se parsea a `Path` en build
  (RF-3/RF-4), sin licencias externas ni imágenes raster.

## Decisiones de la tanda (implementación)
- **Tabla de equivalencias** (`lib/domain/muscle_fatigue.dart`), dataset →
  canónico: `chest→pectoralis_major`, `lats`/`latissimus dorsi`→
  `latissimus_dorsi`, `traps`/`trapezius`→`trapezius`, `shoulders`→`deltoids`,
  `upper back`→`rhomboids`, `core`→`abdominals`, `soleus→calves`,
  `wrist flexors`/`wrist extensors`/`wrists`→`forearms`. Los grupos sin
  región propia en el SVG se adscriben a la más próxima (amenda de
  ampliación de zonas, decisión 2026-10-18): `hip flexors`→`quads`,
  `rotator cuff`→`deltoids`, `ankles`/`ankle stabilizers`→nueva zona
  canónica `feet` (solo vista frontal), `hands`→nueva zona canónica `hands`
  (frente y espalda). El mapa pasa de 15 a 17 zonas canónicas y todos los
  `muscle_group` del dataset quedan dibujados.
- **Modelo (RF-1):** el repositorio resuelve el volumen crudo
  `weight_kg × reps` de las series **completadas**; el dominio aplica
  `factor_tipo` (normal/failure 1.0, drop 0.5, warmup 0) y el decaimiento
  temporal. Ventana de cálculo: **30 días** (NFR).
- **Normalización (RF-2):** 0–1 relativa al **máximo del mapa**; el músculo
  más cargado vale 1.0 y el resto se escala. Sin datos → mapa vacío (todo
  gris, RF-5).
- **Cache (RF-6):** tabla local `muscle_fatigue`
  (`local_user_id`, `muscle`, `fatigue`, `raw`, `computed_at`; PK
  `local_user_id + muscle`). Es dato derivado: no hay migración remota.
  Recalcula al **cerrar una sesión**, al **completar un sync** (hook
  `onSyncCompleted` del `SyncEngine`) y al **abrir el tab Progreso**.
- **Discrepancia de RF-1 resuelta (amenda T-15, decisión 2026-10-15):** la
  fórmula `e^(-días/7)` a 7 días vale `1/e ≈ 0,368`, no `0.5`. El usuario
  ha elegido **exponencial con corte a los 3 días**:
  `días >= 3 ? 0 : e^(-días/7)` — recuperación total a los 3 días, con la
  curva exponencial solo dentro de la ventana de 0 a 3 días.

## Ampliación 2026-10-18 — secundarios en la fatiga y todas las zonas en
## la lista (peticiones de usuario, plan `plan_desidingIU.md`)

- **Secundarios (RF-1 ampliado):** `FatigueSet` incorpora
  `secondaryMuscles` (nombres del catálogo, resueltos vía `kMuscleAliases`).
  En `rawMuscleFatigue` cada secundario aporta
  `volume × factor_tipo × decaimiento × kSecondaryFatigueFactor (0,5)` con
  el mismo decaimiento que el principal; un músculo repetido como principal
  y secundario de la misma serie solo cuenta una vez.
- **Suelo «Óptimo» de secundarios:** `secondaryCanonicals(...)` devuelve los
  canónicos con aporte secundario vivo dentro de la ventana (factor > 0,
  volumen > 0, decaimiento > 0). En `normalizeMuscleFatigue`, un secundario
  cuyo valor normalizado cae en el tramo «Recuperado» (≤
  `kZoneOptimalThreshold = 0,25`) se eleva a
  `kSecondaryOptimalFloor = 0,3`, que ya es estado «Óptimo» (naranja) según
  `zoneStatusOf`. El valor crudo (`raw`) no se toca.
- **Lista de zonas (RF-35 ampliada):** cuando hay actividad, la tabla de
  zonas muestra las 17 zonas canónicas del mapa (frente y espalda), entrenen
  o no; las que no tienen series muestran «Sin series» y estado Recuperado.
  Sin actividad alguna se conserva el mensaje de estado vacío.
- `zoneStatusOf` referencia la constante `kZoneOptimalThreshold` (0,25) en
  lugar del literal.

## Ampliación 2026-10-22 — estados por rol y antigüedad (spec 007)

Petición del usuario (2026-10-22): que el músculo **principal** de cada
ejercicio se marque en rojo «Alto» **sin importar su volumen** y que los
**secundarios** arranquen en «Óptimo». Sustituye a la normalización relativa
al máximo del mapa (RF-2) como fuente del estado de una zona; el volumen
crudo se conserva para el desglose semanal.

### Requisitos funcionales nuevos (EARS)

- RF-25: EL SISTEMA clasifica cada músculo canónico por su **rol** (principal
  / secundario) y por la **antigüedad** de su último aporte:
  - **Principal:** «Alto» (rojo) durante los dos primeros días tras la
    sesión, «Óptimo» (naranja) en el tercero y «Recuperado» (azul) a partir
    de los tres días.
  - **Secundario:** «Óptimo» (naranja) durante los dos primeros días y
    «Recuperado» (azul) a partir de ahí.
- RF-26: EL SISTEMA ignora el volumen para clasificar al principal: una
  serie ligera, de drop o de peso corporal mantiene al músculo principal en
  «Alto».
- RF-27: EL SISTEMA eleva a «Alto» un secundario cuyo volumen normalizado
  supera `kZoneHighThreshold` (0,75), y su estado nunca baja de «Óptimo»
  mientras tenga aporte vivo en su ventana.
- RF-28: EL SISTEMA **reinicia el reloj** de un músculo cada vez que vuelve a
  entrenarse en el mismo rol; el estado final de un músculo es el mayor de
  sus dos roles (`max(principal, secundario)`).
- RF-29: EL SISTEMA cuenta las series de **peso corporal** (peso 0, reps > 0)
  para determinar el rol, aunque su volumen crudo sea 0.
- RF-30: EL SISTEMA dibuja en azul frío («Recuperado», valor 0) los
  músculos con actividad en la ventana de cálculo aunque su estado sea
  recuperado; los nunca entrenados siguen en gris neutro (RF-5).
- RF-31: EL SISTEMA deja de aplicar el suelo «Óptimo» de secundarios
  (`kSecondaryOptimalFloor`); la regla de RF-27 lo sustituye.

### Decisiones de la ampliación

- **Valores de estado (RF-2 con anclas):** el estado de una zona es uno de
  los tres valores exactos del gradiente: `kHighValue` (1,0 = rojo),
  `kOptimalValue` (0,5 = naranja) y `kRecoveredValue` (0,0 = azul frío).
  El gradiente continuo sigue disponible para el volumen, pero el estado es
  discreto por definición de rol.
- **Ventanas (RF-25):** `kPrimaryHighDays = 2`,
  `kPrimaryRecoverDays = 3` y `kSecondaryRecoverDays = 2`. La recuperación
  total coincide con el corte del decaimiento (RF-1).
- **Reposicionamiento de RF-1/RF-2:** `rawMuscleFatigue` y
  `normalizeMuscleFatigue` se conservan, pero solo para el volumen crudo y
  para decidir si un secundario supera el umbral alto (RF-27). El estado de
  la zona sale de `muscleRoles` + `primaryFatigueValue` +
  `secondaryFatigueValue`.
- **Umbral alto (RF-27):** se extrae `kZoneHighThreshold = 0,75` (antes
  literal en `zoneStatusOf`) para que RF-24 y RF-27 compartan constante.
- **API del dominio:** desaparece `secondaryCanonicals` y el parámetro
  `secondaryFloor` de `normalizeMuscleFatigue`; aparecen `muscleRoles`,
  `primaryFatigueValue` y `secondaryFatigueValue`.

## Ampliación 2026-10-22 (bis) — el primario real es `target` (spec 007)

Diagnóstico de un bug de datos del catálogo, reportado al comprobar que los
glúteos no se marcaban. El campo `muscle_group` del dataset **no es el
músculo primario**: en 1323 de 1324 ejercicios su valor coincide con
`secondary_muscles[0]`, es decir, con el primer secundario. El músculo
primario real es el campo `target`.

Consecuencia observable antes de la corrección: la app iluminaba en rojo el
primer secundario y descartaba el objetivo. Un press de banca encendía los
tríceps y no el pecho; un curl de bíceps, el antebrazo y no el bíceps; una
sentadilla o un puente de glúteos no encendían los glúteos (su `target` es
`glutes`, pero su `muscle_group` es `quadriceps`/`hamstrings`). Afectaba a
1321 de 1324 ejercicios.

### Requisitos funcionales nuevos (EARS)

- RF-32: EL SISTEMA determina el músculo **primario** de una serie a partir
  del campo `target` del ejercicio, y no de `muscle_group` (RF-4 queda
  corregido).
- RF-33: EL SISTEMA resuelve el vocabulario `target` mediante
  `kTargetMuscleAliases`, distinto al de `kMuscleAliases` (que pasa a
  alimentar solo a los secundarios): `pectorals` en vez de `chest`, `delts`
  en vez de `shoulders`, `quads` en vez de `quadriceps`, `abs` en vez de
  `abdominals`.
- RF-34: EL SISTEMA adscribe los objetivos sin región propia en el SVG a la
  más próxima (`abductors` → glúteos, `adductors` → cuádriceps,
  `levator scapulae` → trapecio, `serratus anterior` → oblicos) y descarta
  `cardiovascular system`, que no es un músculo.

### Decisiones de la ampliación

- **Alcance:** es una corrección de dato, no un rediseño. El modelo de
  estados por rol (RF-25 a RF-31) no cambia; solo cambia de qué columna
  sale el primario.
- **`muscle_group` no se borra:** la columna se conserva en la BD local y en
  el catálogo porque alimenta los filtros de ejercicios (`ExerciseDimension`)
  y las metas por grupo muscular. Deja de usarse como fuente del primario en
  la fatiga.
- **Vocabulario separado:** se mantiene `kMuscleAliases` para el vocabulario
  de `secondary_muscles` (que sí usa `chest`, `shoulders`, `quadriceps`…) y
  se añade `kTargetMuscleAliases` para el de `target`. Unificarlos en un
  solo mapa ocultaría que son dos léxicos distintos del dataset.
- **Cobertura:** 1277 de 1324 ejercicios quedan con primario dibujable; los
  47 restantes son cardio (29) y músculos sin zona propia ya adscritos
  (aductores, abductores, serrato, escápula).

## Ampliación 2026-10-24 — los secundarios nunca suben a «Alto»

Petición del usuario (2026-10-24): un músculo que solo recibe trabajo
secundario no debe ponerse rojo por acumular volumen; debe quedarse en
naranja («Óptimo») mientras esté dentro de su ventana de recuperación.

- **RF-27 queda sustituido:** EL SISTEMA mantiene en «Óptimo»
  (`kOptimalValue`) a un músculo secundario durante los dos primeros días
  de su ventana, con independencia de su volumen, y lo pasa a «Recuperado»
  (`kRecoveredValue`) a partir de los dos días. Ningún secundario alcanza
  `kHighValue`.
- **Solo el primario puede ser «Alto»:** se conserva
  `max(principal, secundario)`. Si un músculo fue principal y secundario,
  el estado del principal manda y puede seguir rojo por ese rol.
- **API del dominio:** `secondaryFatigueValue` recibe solo `ageDays`.
  `normalizeMuscleFatigue` se retira porque ya no decide ningún estado; el
  volumen crudo sigue disponible en `rawMuscleFatigue` para el cache.
- **Cache:** la migración local 17 vacía `muscle_fatigue` para que no
  sobrevivan valores rojos calculados con la regla anterior.
- **UI:** sin cambios de tokens ni de escala. El valor `0,5` sigue
  pintando `kFatigueWarm` (#F5A623) y la fila muestra «Óptimo».
