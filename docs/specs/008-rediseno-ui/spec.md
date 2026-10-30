# Spec 008 — Rediseño de UI (Obsidian Kinetic → pantallas Stitch)

## Contexto y objetivo
La app implementa 001–007 con una UI funcional pero alejada de los mockups de
referencia. Esta spec define el rediseño de las 4 pestañas y de las vistas de
detalle/editor, la creación de la pestaña **Perfil** (hoy `SoonView`) y la
metadata de rutina necesaria para las tarjetas. **No cambia** la lógica de
dominio de 001–007 salvo donde se indica.

Fuente visual: `docs/stitch_gestor_de_rutinas_fitness/` y
`obsidian_kinetic/DESIGN.md`. Sistema de diseño: `docs/designer.md`.

## Usuarios
Mismo perfil.

## Historias de usuario
- H1: Como usuario quiero que todas las pantallas coincidan con el mockup
  Obsidian Kinetic (jerarquía, componentes, densidad).
- H2: Como usuario quiero una pestaña Perfil con mis datos, métricas, PRs y
  ajustes.
- H3: Como usuario quiero que Entrenar sea un panel (sesión activa,
  calendario, historial) y no el catálogo.
- H4: Como usuario quiero registrar series viendo mi sesión previa y con
  steppers rápidos.
- H5: Como usuario quiero tarjetas de rutina ricas (categoría, nivel,
  frecuencia, desglose).

## Requisitos funcionales (EARS)

### A. Sistema de componentes (H1)
- RF-1: EL SISTEMA expone widgets de presentación reutilizables en
  `lib/ui/widgets/`: `filter_chip_bar.dart`, `section_header.dart`,
  `metric_cluster.dart`, `stat_pill.dart`, `rest_timer_pill.dart`,
  `pill_toggle.dart`. Sin lógica de negocio dentro.
- RF-2: EL SISTEMA mantiene el minimalismo: cero `elevation` y cero
  `BoxShadow` (constitución §7); jerarquía por tipografía y espacio.
- RF-3: EL SISTEMA usa el icono `Icons.monitoring` para el destino Progreso
  del bottom nav (hoy `show_chart`). El bottom nav conserva 4 destinos.
- RF-4: EL SISTEMA respeta los targets táctiles ≥ 48 × 44 dp (designer §11).

### B. Entrenar — panel e historial (H3)
- RF-5: EL SISTEMA sustituye el destino Entrenar (índice 0) por un panel
  `TrainView` con toggle **Registro / Historial**.
- RF-6: SI existe una sesión `active`, ENTONCES el panel muestra una tarjeta
  de sesión activa con acción «Reanudar» (reutiliza la lógica de la 002).
- RF-7: EL SISTEMA muestra un **calendario mensual** navegable con un marcador
  por día entrenado (letra de la rutina o punto) y selector de mes.
- RF-8: EL SISTEMA muestra un cluster de métricas: sesiones totales,
  adherencia, volumen del mes y descanso/racha (designer: `metric_cluster`).
  El descanso muestra los días transcurridos desde la última sesión («X d»);
  sin sesiones, queda vacío («—»). (amenda T-18)
- RF-9: EL SISTEMA muestra un **feed de historial**: tarjeta por sesión con
  duración, nº de series, tonelaje y ejercicios destacados.
- RF-10: EL SISTEMA mueve el buscador de ejercicios (`CatalogView`, spec 003)
  a una **pantalla propia** accesible desde un icono de catálogo/búsqueda en
  el header de Entrenar. La lógica de búsqueda y filtros (003) no cambia.
- RF-11: EL SISTEMA calcula calendario, racha y agregados en el dominio puro
  (`lib/domain/training_calendar.dart`), testeable sin widgets.

### C. Registro en vivo (H4)
- RF-12: EL SISTEMA muestra una tarjeta de resumen con título de sesión,
  cronómetro y módulo de descanso (+30 s / saltar) y las acciones
  Añadir ejercicio / Terminar.
- RF-13: CADA tarjeta de ejercicio muestra badges de músculo y equipo y una
  píldora «Sesión previa: X kg × Y».
- RF-14: LA TABLA de series muestra las columnas `PREVIO`, `KG`, `REPS`,
  `RIR` y `✓`; `PREVIO` sale del último peso×reps×RIR del mismo ejercicio en
  una sesión completada anterior (dominio puro, `previous_sets.dart`).
- RF-15: EL SISTEMA ofrece steppers rápidos de ±1,25 kg y ±2,5 kg y un RIR
  cíclico (tocar incrementa, largo decrementa) sobre los valores existentes.
- RF-16: EL SISTEMA muestra el descanso como **píldora flotante** sobre el
  contenido, con indicador pulsante y +30 s, sin alterar `RestTimer` /
  `RestNotifier` (spec 002).
- RF-17: EL SISTEMA conserva las claves de test actuales
  (`set-weight-*`, `set-check-*`, `rest-*`) y la paridad funcional con la 002.

### D. Rutinas (H5)
- RF-18: EL SISTEMA añade a `routine` columnas nullable: `category`, `level`,
  `goal`, `target_days` (drift + migración `0008_routine_metadata.sql`).
- RF-19: EL SISTEMA muestra header con CTA «Nueva», un indicador de ciclo
  semanal y chips de filtro por categoría (Todas / PPL / Torso-Pierna /
  Fuerza).
- RF-20: CADA tarjeta de rutina muestra badge «En curso» (si hay un workout
  `active` con ese `routine_id`), matriz de métricas (frecuencia, volumen
  medio, objetivo), **desglose de sesiones** derivado de los músculos de sus
  ejercicios y botones Iniciar + ajustes.
- RF-21: EL SISTEMA muestra una tarjeta secundaria «Explorar plantillas» que
  enlaza al navegador de plantillas (spec 010).
- RF-38: EL SISTEMA abre una **pantalla de detalle de rutina de solo lectura**
  desde el botón «Ver detalle» de las tarjetas secundarias y desde la acción
  de detalle de la tarjeta destacada (amenda 2026-10-22).
- RF-39: EL SISTEMA muestra en **cada tarjeta de la lista de Rutinas** una
  franja de miniaturas de sus ejercicios (los primeros cuatro y, si quedan
  más, un contador «+N») (amenda 2026-10-22).

## Ampliación 2026-10-22 — detalle de rutina (RF-38)

Petición del usuario (2026-10-22): poder ver los ejercicios de una rutina y
abrir el detalle de cada uno desde la lista de Rutinas.

### Decisiones

- **Pantalla nueva, no un editor:** `RoutineDetailView` es de solo lectura.
  El editor (`RoutineEditorView`) se conserva tal cual y se alcanza desde la
  acción de lápiz del detalle, que recarga el detalle al volver.
- **Ficha reutilizada:** al tocar un ejercicio se abre la
  `ExerciseDetailView` existente (GIF, insignias de musculatura y equipo,
  descanso, instrucciones). No se duplica contenido.
- **Resumen de series:** cada fila muestra `n series · reps · RIR · peso`,
  colapsando los rangos variables («8-12 reps»). El peso va en la unidad del
  perfil (spec 006) y las series de peso corporal no lo muestran.
- **Acciones:** «Iniciar Hoy» invoca el mismo arranque que la lista; los
  callbacks viven en `RoutinesView` para no duplicar la lógica de negocio.
- **Estados:** carga, lista vacía («Esta rutina aún no tiene ejercicios») y
  ejercicio fuera del catálogo (fila no pulsable con «No se incluirá al
  iniciar»), coherente con el caso límite de la 004.
- **Esencia visual:** superficies planas sin `elevation` ni `BoxShadow`,
  jerarquía por tipografía y espacio, bordes hairline, radios 12/8 y los
  tokens de color existentes. Se añade un golden
  (`test/goldens/routine_detail.png`).

## Ampliación 2026-10-22 (bis) — miniaturas en las tarjetas (RF-39)

Petición del usuario (2026-10-22): que se muestre la imagen de los
ejercicios en las rutinas.

### Decisiones

- **Alcance:** la lista de Rutinas (`RoutinesView`); la pantalla de detalle
  ya mostraba las miniaturas (RF-38).
- **Franja reutilizable:** `_ExerciseThumbStrip` usa el widget existente
  `ExerciseThumb` (44 dp, radio 8) y muestra los primeros cuatro ejercicios
  de la rutina; el resto se resume en un contador «+N» con la forma de una
  miniatura. Sin datos (`imagePath` nulo) cae al icono de respaldo ya
  definido.
- **Datos sin tocar el repositorio:** la vista ya recibía los objetos
  `Exercise` de todas las rutinas vía `watchRoutineCatalog()` (ordenado por
  `orderIndex`); se filtran por `routine.id` con `_exercisesOf`.
- **Accesibilidad:** se usa `Wrap` en lugar de `Row` para no desbordar en
  móvil estrecho ni con texto escalado; las miniaturas se envuelven en una
  segunda línea en vez de cortarse.
- **Esencia visual:** planas, sin `elevation` ni `BoxShadow`, con el mismo
  radio y tokens que el resto de thumbs.

### E. Progreso y medidas (H1)
- RF-22: EL SISTEMA reorganiza `ProgressView`: chip de rango (30/90/365),
  tarjeta de peso con línea de meta y proyección, sección de fatiga muscular,
  evolución multi-métrica y lista de medidas con iconos y deltas.
  - **Enmienda 2026-10-19 (T-12, fidelidad 1:1):** la cabecera de
    `ProgressView` aloja el chip de rango («Últimos 30 días / 90 días /
    Último año») y la acción «Nueva Medida»; el selector ya no vive dentro de
    la tarjeta de peso. El orden de secciones sigue al mockup: peso,
    composición, distribución muscular, metas, entrada «Medidas», fotos y
    callout. Golden `test/goldens/progress_empty.png`.
- RF-23: LA TARJETA de peso extiende `weight_trend.dart` con la meta activa
  (spec 005) y una proyección simple; sin nuevas dependencias.
- RF-24: LA SECCIÓN de fatiga muscular usa toggle pill Frente/Espalda, leyenda
  por rango, contador de zonas y volumen semanal junto al estado (reutiliza
  `MuscleMap`; la fórmula de fatiga de la 007 no cambia). La **silueta
  vectorial** (frente/espalda) se alinea con las pantallas Stitch y el
  gradiente continuo del `designer.md` §12.
- RF-25: LA LISTA de medidas se reestiliza con iconos Material Symbols y Δ vs
  el registro anterior (comportamiento de la 006 intacto).
- **Ampliación 2026-10-18 — pantalla de medidas propia:** «Medidas
  Corporales» y «Evolución de Medidas» salen de `ProgressView` a
  `MeasuresView` (`lib/ui/views/measures_view.dart`), una pantalla propia
  con app bar «Medidas» y `+` para nuevo chequeo; `ProgressView` conserva
  una entrada compacta «Medidas» que navega a ella. La edición y el borrado
  de chequeos siguen en la tabla de registros de Progreso. RF-22, RF-25 y
  RF-37 se mantienen intactos en la nueva pantalla.

### F. Perfil (H2)
- RF-26: EL SISTEMA sustituye el `SoonView` de Perfil por `ProfileView`, con
  header (avatar, nombre, nivel derivado), grid de 3 métricas (sesiones,
  volumen total, racha), lista de objetivos y **lista de PR** (mejor e1RM por
  ejercicio, spec 005/001).
- RF-27: EL SISTEMA añade `ProfileRepository` sobre `local_profiles`
  (`displayName`, `unitSystem`) y sincroniza `username`/`avatar_url` a la
  tabla remota `profiles` por la cola (`sync_payload.dart` ya soporta
  `profiles`). Sin migración remota nueva.
- RF-28: EL SISTEMA calcula stats y PR en el dominio puro
  (`lib/domain/profile_stats.dart`), testeable sin widgets.
- RF-29: LA LISTA de ajustes incluye unidades (metric/imperial), preferencia
  RIR/RPE (local, `local_profiles.prefer_rpe`) y «Exportar datos» (CSV de
  workouts/body_metrics con `share_plus`). La selección de unidades es
  global: inyectada por `UnitSystemScope` sobre el `Navigator`, gobierna la
  presentación **y la edición** en todas las pantallas (Progreso, Entrenar,
  sesión en vivo, editores de registro/meta/rutina). `kg`/`cm` siguen siendo
  la base de almacenamiento (dominio `lib/domain/units.dart`: kg↔lb, cm↔in,
  formateadores y pasos 1,25 kg ↔ 2,5 lb). (amenda T-16)
- RF-30: LA LISTA de ajustes incluye «Dispositivos» (báscula/caliper y HRV),
  que enlaza a la spec 011; y el botón de cerrar sesión (`AuthService.signOut`).

### G. Datos (H3–H5)
- RF-31: EL ESQUEMA local sube `schemaVersion` a 12 con
  `local_profiles.prefer_rpe` (Fase 1). La metadata de rutina
  (`routine.category/level/goal/target_days`) subirá el esquema en la Fase 4.
- RF-32: EL ESQUEMA remoto cambia solo con
  `supabase/migrations/0008_routine_metadata.sql` (columnas nullable, RLS
  intacta). Sin más migraciones en esta spec.

## Requisitos no funcionales
- 60 FPS en listas y calendario; sin reconstrucciones innecesarias.
- Responsive 320–430 dp de ancho, con safe areas (notch/gesture bar).
- Paridad funcional con 001–007: ningún RF previo se rompe.

## Casos límite
- Sin sesiones: calendario vacío y panel con estado vacío claro.
- Rutina sin metadata: las tarjetas muestran solo lo derivable (sin huecos).
- Perfil sin cuenta: stats/PR locales; ajustes de sync deshabilitados con aviso.
- Sesión activa y catálogo abierto a la vez: al reanudar se cierra el catálogo.

## Fuera de alcance (008)
- Fotos de progreso y composición corporal → spec 009.
- Plantillas comunitarias → spec 010.
- Báscula/caliper por Bluetooth y HRV → spec 011.
- Búsqueda semántica, favoritos, IA.

## Criterios de finalización
- Golden tests de las pantallas y componentes rediseñados.
- Tests unit de `training_calendar`, `previous_sets`, `profile_stats`.
- Migración drift 12 con test de upgrade; `flutter test` + `flutter analyze`
  verdes.

## Decisiones arquitectónicas (Cerradas)
- El bottom nav conserva **4 destinos**; el catálogo pasa a pantalla propia
  (RF-10), sin quinto destino.
- La metadata de rutina se añade como columnas **nullable** para no romper
  rutinas existentes ni el `claim_local_data`.
- El perfil se persiste en `local_profiles` y se **empuja** a `profiles`; el
  avatar procede de `auth` y no se inventan campos nuevos en remoto.

## Dudas abiertas
- Nivel del atleta (derivado por nº de sesiones) por confirmar umbrales.

---

## Ampliación 2026-10-10 — plan `plan_desidingIU.md`

Plan maestro en la raíz del repo. Decisiones cerradas con el usuario y
nuevos requisitos funcionales que esta spec absorbe:

### Decisiones cerradas
1. **Mapa muscular con `muscle_mapper ^1.2.0`** (pub.dev; origen
   <https://github.com/suryamolly/muscle_mapper.git>, licencia MIT).
   Dependencia aprobada aquí (constitución §2; la lista se actualiza al
   implementarse, T-0). Se usan sus assets incluidos
   (`DefaultAnatomyProvider(style: AnatomyStyle.minimal)`); se eliminan
   `assets/maps/muscle_map.svg`, el parser SVG propio y `MuscleMapPainter`.
2. **Escala de fatiga frío → rojo** (constitución §8, designer §12),
   aplicada con `muscleColors`; la fórmula de la 007 no cambia.
3. **Fidelidad total a los mockups salvo sombras**: layout, tipografía,
   colores, radios, iconos y textos idénticos a Stitch; cero `elevation` y
   cero `BoxShadow` (RF-2 y constitución §7 siguen vigentes).
4. **Secciones de las specs 009–011 se muestran con su aspecto final y
   estado vacío** (fotos, composición, plantillas, dispositivos, «Registrar
   entrenamiento pasado»), hasta que cada spec enchufe los datos.
5. El nav inferior pasa a **pill flotante** redondeada según los mockups.

### Requisitos funcionales nuevos (EARS)
- RF-33: EL SISTEMA dibuja el mapa muscular con `muscle_mapper ^1.2.0`
  mediante un adaptador que traduce los 15 músculos canónicos del dominio
  (spec 007) a los `Muscle`/`MuscleGroup` del paquete; el dominio de fatiga
  no cambia.
- RF-34: EL SISTEMA colorea cada músculo con `fatigueColor(valor)`
  (frío → rojo) vía `muscleColors`, con base neutra `#292A2D` y borde
  `#444748` para las zonas sin dato.
- RF-35: SI el usuario toca un músculo del mapa o una fila de la lista de
  zonas (17 desde la ampliación de la 007), ENTONCES ambos se resaltan de
  forma sincronizada (`onMuscleTapped` ↔ lista).
- RF-36: EL SISTEMA iguala a los mockups el shell (nav pill flotante, app
  bar) y los tokens de radio (4/8/12 dp), sin sombras.
- RF-37: CADA sección sin datos de implementación propia muestra su aspecto
  final con estado vacío y enlace a la spec correspondiente (009, 010, 011).

### Criterios de finalización adicionales
- Goldens del mapa regenerados con `muscle_mapper` (frente/espalda/vacío).
- Comparación 1:1 de las 6 pantallas contra sus `screen.png` (T-12).
- `flutter test` en verde y `flutter analyze` sin incidencias al cierre.
