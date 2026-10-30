# Plan de Rediseño de UI — hevywork («desidingIU»)

Plan maestro para reformar **todas** las pantallas de la app hasta igualarlas a
las pantallas de referencia de `docs/stitch_gestor_de_rutinas_fitness/`, y para
sustituir el mapa muscular por la librería
[`muscle_mapper`](https://pub.dev/packages/muscle_mapper) (origen:
<https://github.com/suryamolly/muscle_mapper.git>).

Spec rectora: **`docs/specs/008-rediseno-ui/spec.md`** (ampliada con este
plan). Fuente visual: las 6 pantallas Stitch + `obsidian_kinetic/DESIGN.md`.
Sistema de diseño: `docs/designer.md`. Constitución: `docs/constitucion.md`.

---

## 1. Panorama completo (estado actual)

### 1.1 Lo que ya está implementado (commit `rediseno`, spec 008 Fase 1)

| Área | Estado |
|---|---|
| `TrainView` (tab Entrenar) | Panel con toggle Registro/Historial, calendario mensual (`training_calendar.dart`), cluster de métricas y feed de historial. |
| `LiveWorkoutView` | Tarjeta de sesión, tabla de series con columna PREVIO (`previous_sets.dart`), steppers, `RestTimerPill` flotante, hoja de progresión. |
| `ProfileView` | Header, grid de 3 métricas (`profile_stats.dart`), objetivos, PRs, ajustes y logout. `ProfileRepository` + sync a `profiles`. |
| Componentes compartidos | `PillToggle`, `StatPill`, `MetricCluster`, `SectionHeader`, `FilterChipBar`, `RestTimerPill`, `WeightTrend`, `HevyAppBar`, `HevyBottomNav`. |
| Progreso | Sección de fatiga con `MuscleMap` propio (SVG + `CustomPainter`), objetivos, medidas con Δ, sparkline de peso. |
| Dominio puro | `training_calendar`, `previous_sets`, `profile_stats`, `muscle_fatigue`, `goals`, `body_metrics`. |

### 1.2 Brechas frente a los mockups Stitch (lo que falta)

| Pantalla | Brecha principal |
|---|---|
| **Shell global** | El nav inferior es una barra anclada; Stitch usa una **pill flotante** redondeada. Falta igualar paddings y safe areas por pantalla. |
| **Entrenar · Registro** | Falta módulo de descanso en la tarjeta de sesión (+30 s / saltar), badges de músculo/equipo, píldora «Sesión previa», ajuste rápido ±1,25 / ±2,5 kg, RIR cíclico, ejercicio siguiente colapsado. |
| **Entrenar · Historial** | Falta banner «Sesión en curso» con Reanudar, selector de mes con fase macro, leyenda del calendario (P/T/L/U + descanso activo), racha, grid 2×2 de métricas, tarjetas de sesión con PRs y tonelaje, CTA «Registrar entrenamiento pasado». |
| **Rutinas** | Faltan header con CTA «Nueva», indicador de ciclo semanal, chips de filtro por categoría, metadata de rutina (migración `0008`), tarjeta activa con desglose de sesiones, tarjeta «Explorar plantillas» (spec 010). |
| **Progreso** | Faltan tarjeta de peso con **meta y proyección**, grid de composición (% grasa / masa magra, spec 009), sección «Distribución Muscular» **interactiva** con lista de 15 zonas y leyenda, «Evolución de Medidas» multi-métrica, fotos de progreso (009), callout de dispositivos (011). |
| **Mapa muscular** | Implementación propia (parser SVG + `CustomPainter`); debe migrar a `muscle_mapper`. |

### 1.3 Specs dependientes (sin implementar)

- **009** fotos de progreso + composición corporal (`image_picker`).
- **010** plantillas comunitarias (catálogo público + importar).
- **011** dispositivos BLE y HRV (`flutter_blue_plus`, `health`).

Este plan construye **la UI completa de sus secciones con estado vacío**, para
que las pantallas ya queden iguales a los mockups y cada spec solo tenga que
enchufar los datos.

---

## 2. Decisiones cerradas (2026-10-10)

1. **`muscle_mapper ^1.2.0` desde pub.dev** con los assets incluidos
   (`DefaultAnatomyProvider(style: AnatomyStyle.minimal)`). Se elimina
   `assets/maps/muscle_map.svg`, el parser SVG y `MuscleMapPainter`.
   Aprobación de dependencia registrada en la spec 008; la constitución §2 se
   actualiza al implementarse (T-0).
2. **Escala de fatiga frío → rojo** (constitución §8 y designer §12),
   implementada con `muscleColors` del paquete. Sin cambios en la fórmula de
   la spec 007.
3. **Fidelidad total a los mockups salvo sombras**: layout, tipografía,
   colores, radios, icons y textos idénticos a Stitch; cero `elevation` y
   cero `BoxShadow` (constitución §7, spec 008 RF-2). La profundidad va por
   capas tonales y bordes hairline.
4. **Secciones sin datos = aspecto final + estado vacío** (fotos 009,
   composición 009, plantillas 010, dispositivos/HRV 011, «Registrar
   entrenamiento pasado»). Sin placeholders de texto provisional.
5. **Ubicación**: este plan vive en la raíz; las tasks van aquí; la spec 008
   se amplía con los nuevos RF y `docs/specs/README.md` se actualiza.

---

## 3. Mapa muscular con `muscle_mapper`

### 3.1 Adaptador de dominio

El dominio de la 007 no cambia: `muscle_fatigue.dart` sigue exponiendo
`Map<String, double>` con los 15 músculos canónicos. Se crea
`lib/ui/widgets/muscle_map.dart` (reescrito) como **adaptador** que traduce a
los enums del paquete:

| Músculo canónico (dominio) | Vista(s) | `Muscle`/`MuscleGroup` del paquete |
|---|---|---|
| `pectoralis_major` | Frente | Chest (`upper-pectoralis`, `mid-lower-pectoralis`) |
| `deltoids` | Frente + Espalda | Front Deltoids + Rear Deltoid (mismo valor) |
| `biceps` | Frente | Biceps |
| `triceps` | Espalda | Triceps |
| `forearms` | Frente + Espalda | Forearms (`wrist-flexors/extensors` + `forearms-post`) |
| `abdominals` | Frente | Abs |
| `obliques` | Frente | Obliques |
| `quadriceps` | Frente | Quads |
| `hamstrings` | Espalda | Hamstrings |
| `glutes` | Espalda | Glutes |
| `calves` | Frente + Espalda | Calves (`gastrocnemius`, `soleus`) |
| `latissimus_dorsi` | Espalda | Lats |
| `trapezius` | Frente + Espalda | Traps (`upper-trapezius`, `traps-middle`, `lower-trapezius`) |
| `rhomboids` | Espalda | Upper Back |
| `lower_back` | Espalda | Lower Back |

Los nombres exactos de los enums se confirman contra el paquete en T-8.1; los
grupos sin región (ankles, hands, hip flexors, rotator cuff…) siguen fuera del
mapa (caso límite de la 007).

### 3.2 Pintado

- `muscleColors`: color por músculo = `fatigueColor(valor)` (frío → rojo,
  ya existe); sin dato → gris neutro `#292A2D` con borde `#444748`.
- `muscleIntensities`: fijo para los músculos con dato; el color carga la
  información. `baseColor`: gris neutro del mockup.
- `onMuscleTapped`: selecciona/deselecciona un músculo y sincroniza la fila
  resaltada de la lista de 15 zonas (y al revés: tocar la fila resalta el
  mapa). El detalle mostrado (series semanales, estado) sale del dominio.
- Se eliminan el parser de SVG, `MuscleMapPainter` y los goldens antiguos;
  se regeneran goldens frente/espalda/vacío con el widget nuevo.

### 3.3 Sección «Distribución Muscular» (Progreso)

Igual al mockup: header con fuego, subtítulo «Volumen semanal y estado de
fatiga», toggle pill Frente/Espalda, leyenda (Alto / Óptimo / Recuperado +
«15 ZONAS»), panel del mapa, hint «Interactivo» y lista scrolleable de 15
filas (nombre EN + subtítulo ES + series + chip de estado).

---

## 4. Tasks

Cada task cierra con `flutter test` y `flutter analyze` en verde
(constitución §6). Ninguna fase avanza con la anterior en rojo.

### Fase A — Cimientos del shell

- [x] **T-0: Dependencia y constitución**
  - `muscle_mapper: ^1.2.0` en `pubspec.yaml` (pub.dev); verificar
    resolución y licencia MIT.
  - Actualizar `docs/constitucion.md` §2 (aprobado en spec 008).
  - `docs/specs/README.md`: fila 008 con las decisiones nuevas.
- [x] **T-1: Nav inferior pill flotante + shell**
  - `HevyBottomNav` pasa a pill flotante redondeada (`surfaceContainer` 90 %,
    blur 24, borde hairline, **sin sombra**) con los 4 destinos y el activo
    en `primary`; safe area inferior.
  - `HevyAppBar` idéntico al mockup (marca + título de sección + avatar 32 dp,
    blur 24 sobre `surface` 80 %).
  - Paddings de contenido por pantalla según mockup (pb 20/24/28).
  - Tests: `app_shell_test.dart` actualizado (labels, destinos, sin sombras).
- [x] **T-2: Tokens alineados al mockup**
  - Radios según Stitch (4 / 8 / 12 dp) en tema y componentes.
  - `HevyColors` (surfaceBright, oliveAccent) ya registrado; revisar inputs,
    chips y botones secundarios contra el HTML.
  - Tests: `app_shell_test.dart` (tema, fuentes, cero elevation/BoxShadow).

### Fase B — Entrenar

- [x] **T-3: Modo Registro en vivo al 100 %**
  - Tarjeta de sesión: label «SESIÓN EN CURSO», título, cronómetro pill,
    módulo de descanso (+30 s, saltar) y acciones Añadir ejercicio / Terminar.
  - Tarjeta de ejercicio: chips de músculo y equipo, píldora «Sesión previa»,
    tabla SER/PREVIO/KG/REPS/RIR/OK, ajuste rápido ±1,25 / ±2,5 kg, RIR
    cíclico, «Añadir serie», ejercicio siguiente colapsado.
  - Píldora de descanso flotante con dot pulsante y +30 s (ya existe;
    se restila).
  - Conservar claves de test y paridad funcional con la spec 002 (RF-17).
  - Tests: `live_workout_view_test.dart` (+ casos de steppers y RIR cíclico).
  - Nota: el label de la píldora flotante es «DESCANSO ACTIVO» (el módulo de
    la tarjeta usa «DESCANSO»); las acciones viven en la tarjeta y el botón
    se llama «Terminar». Los tests de esta vista usan un viewport de
    800×900 porque el hit-test de slivers falla con filas pegadas al borde
    superior tras `ensureVisible`.
- [x] **T-4: Modo Historial y calendario**
  - Banner «Sesión en curso» + Reanudar; selector de mes con fase macro.
  - Calendario con estados (entrenado con letra, descanso activo, hoy,
    futuro, mes anterior), leyenda y tooltips.
  - Racha, grid 2×2 (sesiones, adherencia, descanso activo, volumen mes),
    feed con badge de PRs, duración/series/tonelaje y highlights.
  - «Exportar CSV» (dominio `data_export.dart` ya existe) y CTA «Registrar
    entrenamiento pasado» con estado vacío/modal aún sin implementar.
  - Tests: `train_view_test.dart` (estados, calendario, banner, feed).

### Fase C — Rutinas

- [x] **T-5: Metadata de rutina (datos)**
  - Drift: `routines.category/level/goal/target_days` nullable +
    `schemaVersion` 13 (la 12 la ocupa `prefer_rpe`); migración
    `supabase/migrations/0008_routine_metadata.sql`
    (columnas nullable, RLS intacta); `sync_payload` las empuja.
  - `RoutineRepository` acepta y expone la metadata; rutinas existentes sin
    metadata no muestran huecos.
  - Nota: el `onUpgrade` ya es idempotente (`_addColumnIfMissing` /
    `_createTableIfMissing`) por el incidente «duplicate column name:
    prefer_rpe»; una BD local que una versión WIP hubiera llevado a v13 se
    abre sin más cambios porque los pasos se guardan contra el esquema real.
  - Tests: migración 11→13, repository, payload, `buildRemoteRow`.
- [x] **T-6: UI de rutinas al 100 %**
  - Header «PLANIFICACIÓN / Mis Rutinas» + CTA blanca «Nueva».
  - Card de ciclo semanal (sesiones completadas + dots).
  - Chips de filtro por categoría (Todas/PPL/Torso-Pierna/Fuerza).
  - Tarjeta activa con franja de acento, badge «En curso», matriz de
    métricas y desglose de sesiones; tarjetas secundarias con nivel,
    descripción, pills de métricas y «Último uso».
  - Tarjeta «Explorar Biblioteca de Plantillas» → enlace a spec 010 con
    estado vacío.
  - Tests: `routines_view_test.dart` (+ filtros, ciclo, metadata).
  - Nota: el desglose agrupa los ejercicios por enfoque (Empuje /
    Tracción / Pierna / Core) en `lib/domain/routine_overview.dart` y
    reparte los días según `target_days`; el editor gana una sección
    plegable «Planificación» (categoría/nivel/objetivo/días) porque es la
    única fuente posible de la metadata (RF-18).

### Fase D — Progreso

- [x] **T-7: Tarjeta de peso con meta y proyección** (hecho: dominio puro
  `weight_progress.dart` con `weeklyRateKg`/`movingAverageKg`/`projectToGoal`/
  `kgDeltaLabel`; `WeightTrend` con meta discontinua, media móvil, segmento
  proyectado y leyenda; tarjeta «PESO CORPORAL» con pill de ritmo mensual,
  «Meta: …», chips 30/90/365 y timeline; 384/384 + analyze limpio)
- [x] **T-8: Mapa muscular con `muscle_mapper`** (hecho: adaptador en
  `lib/domain/muscle_map_adaptor.dart` + `muscleColors` frío→rojo, parser y
  painter propios eliminados, goldens regenerados; sección «Distribución
  Muscular» con toggle pill, leyenda por rango, contador de zonas, hint
  «Interactivo» y lista de 15 filas sincronizada con taps del mapa; 385/385 +
  analyze limpio, sin desbordes a 320 dp @1.3)
  - T-8.1: adaptador (tabla §3.1), `muscleColors` frío→rojo, `baseColor`
    neutro, eliminación de parser/painter/asset propio y regeneración de
    goldens.
  - T-8.2: sección «Distribución Muscular» completa: toggle, leyenda,
    contador de zonas, panel interactivo, lista de 15 filas sincronizada con
    taps del mapa.
  - Tests: `muscle_map_test.dart` reescrito (adaptador + widget + goldens),
    `progress_view_test.dart` (interacción mapa ↔ lista).
- [x] **T-9: Evolución de medidas y medidas corporales**
  - Gráfico multi-métrica (Pecho/Cintura/Brazos/Cuádriceps) con pills de
    serie, ejes semanales y stat boxes (ratio cintura/pecho, crecimiento
    acumulado) — `CustomPainter` (designer §7.9), sin dependencias.
  - Lista de medidas estilo mockup (icono, valor + Δ, colores por dirección).
  - Tests: dominio de series + `progress_view_test.dart`.
- [x] **T-21: Composición corporal con estimación US Navy** (spec 009,
  RF-1/RF-3/RF-4)
  - `body_metrics` gana `body_fat_pct` y `lean_mass_kg` (drift
    `schemaVersion` 15 + `0009_body_composition.sql`); editor con % grasa
    validado (0–70) y masa magra opcional.
  - Perfil: `sex` y `height_cm` en «Configuración de Atleta», sincronizados
    en el payload de `profiles`.
  - Dominio puro `body_composition.dart`: ecuación US Navy (hombres con
    cuello/cintura/altura; mujeres añaden cadera), masa magra derivada y
    composición por registro con manual sobre estimado.
  - Grid de composición con valores reales, Δ y etiqueta «Estimado · US
    Navy»; tests de dominio, repositorio, editor, perfil y vista.
  - Compuerta: 5xx tests en verde y `flutter analyze` sin incidencias.

- [x] **T-10: Secciones dependientes con estado vacío**
  - Grid de composición (% grasa, masa magra) → estado vacío + enlace a la
    spec 009.
  - Fotos de progreso (grid 3 columnas, pill de comparación) → estado vacío
    + enlace a la spec 009.
  - Callout «Báscula y Caliper Conectados» → estado sin dispositivos +
    enlace a la spec 011.
  - Tests: `progress_view_test.dart` (estados vacíos).

### Fase E — Perfil

- [x] **T-11: Ajustes y exportación**
  - Filas «Unidades», «Ajustes de RIR y RPE», «Exportar datos» (CSV con
    `share_plus`: aprobar en spec 008 y constitución §2 en esta task),
    «Dispositivos» (enlace spec 011) y logout.
  - Ajuste de unidades respetando kg en base y lb solo al mostrar.
  - Tests: `profile_view_test.dart` (+ ajustes, exportación).

### Fase F — Ampliaciones (2026-10-15, petición del usuario)

Orden de ejecución: T-13 → T-20 → T-18 → T-17 → T-15 → T-14 → T-16 → T-19
(cerrarán antes la T-11; la T-12 queda al final).

- [x] **T-13: Bug del mapa dorsales ↔ isquios**
  - Reproducción con taps en las 15 zonas (fila de zonas y silueta, frente
    y espalda); corregir el intercambiado y revisar el resto de zonas.
  - Hipótesis: selección invisible sobre músculos con color de fatiga
    (prioridad de `muscleColors` en `muscle_mapper`) y/o hit-test por bbox.
  - Tests: `progress_view_test.dart` (15 zonas, ambos sentidos).

- [x] **T-20: Acceso con correo (Supabase Auth)**
  - Ampliación de la spec 001: `signInWithPassword` / `signUp` en
    `AuthService` con `_claimLocalData` al entrar y errores traducidos.
  - UI: diálogo de correo + contraseña en la fila de cuenta de Perfil
    (hoy deshabilitada sin sesión); habilitar provider Email en Supabase.
  - Tests: servicio con cliente falso + diálogo.

- [x] **T-18: Stat «Descanso» del panel Entrenar**
  - Sustituir el `—` por los días reales desde la última sesión («X d»)
    con estado vacío sin sesiones. Amend RF-8 de la spec 008.
  - Tests: `train_view_test.dart`.

- [x] **T-17: Gráficos de medidas con datos reales**
  - Diagnóstico: la DB real tiene 0 registros en `body_metrics`; verificar
    que el editor guarda (test de regresión) y validar la serie con la
    forma real de los datos.
  - Tests: `body_metric_editor_view_test.dart` + `progress_view_test.dart`.

- [x] **T-15: Recuperación muscular a los 3 días**
  - Curva elegida por el usuario: `days >= 3 ? 0 : e^(−días/7)`
    (exponencial con corte a 3) en `fatigueDecayFactor`.
  - Amendamento en la spec 007 + actualización de la regla 3 de este plan.
  - Tests: `muscle_fatigue_test.dart` (a los 3 días vale 0).

- [x] **T-14: Borrar sesiones del historial**
  - Borrado por tarjeta en el historial de Entrenar con confirmación,
    borrado del workout y cola de sync. Amend de la spec 002.
  - Tests: `workout_repository_test.dart` + `train_view_test.dart`.

- [x] **T-16: Unidades globales (visualización y edición)**
  - Nuevo dominio `lib/domain/units.dart`: kg↔lb, cm↔in, formateadores y
    pasos (1,25 kg ↔ 2,5 lb); kg/cm siempre en la base.
  - Aplicación: `progress_view`, `weight_trend`, `stat_pill`,
    `live_workout_view`, `train_view`, `body_metric_editor`,
    `goal_editor`, `routine_editor`. Amends de las specs 006 y 008.
  - Tests unit de conversión + pantallas en imperial.
  - Ampliaciones del usuario (2026-10-18): mapa muscular de 15 a 17 zonas
    (manos y pies; todos los `muscle_group` del dataset dibujados), medida
    «Glúteos» (`hip`) en el registro y corrección de `band squat row`
    (id 1003) a `muscle_group: glutes`. Compuerta: 456 tests + analyze
    limpio.

- [x] **T-19: Fotos de progreso (spec 009, parte fotos)**
  - `image_picker` + compresión <500 KB, tabla drift `progress_photos`,
    migración remota `0010_progress_photos.sql` (RLS + bucket privado),
    cola de subida, grid, comparador y zoom.
  - Tests: repositorio + widget de la sección Fotos. Compuerta: 475 tests
    en verde y `flutter analyze` sin incidencias (2026-10-19); los tests de
    widget de fotos se estabilizaron con desmontaje que drena los timers de
    drift, settles sin `pumpAndSettle` (imágenes reales) y espera activa del
    IO con `runAsync`.

  **Peticiones nuevas del usuario (2026-10-18, incluidas en esta tanda):**
  1. Secundarios en la fatiga del mapa: `FatigueSet` lleva `secondaryMuscles`;
     cada secundario aporta `volumen × factor_tipo × decaimiento × 0,5` y,
     mientras el aporte esté en ventana, los secundarios por debajo del
     umbral Óptimo (0,25) se elevan a 0,3 (estado «Óptimo», naranja).
     Implementado en `lib/domain/muscle_fatigue.dart` +
     `lib/data/repositories/fatigue_repository.dart` (dos constructores de
     sets), con tests en `muscle_fatigue_test` y `fatigue_repository_test`.
  2. Pantalla de medidas aparte: `lib/ui/views/measures_view.dart` aloja
     «Medidas Corporales» y «Evolución de Medidas» movidas de
     `progress_view`; en Progreso queda una entrada compacta «Medidas» que
     navega. Tests en `measures_view_test`; `progress_view_test` adaptado.
  3. Lista de zonas con todos los músculos: con actividad, la tabla de
     Distribución Muscular muestra las 17 zonas canónicas (entrenen o no);
     sin series, «Sin series» + Recuperado; sin actividad, mensaje vacío.
     Implementado en `progress_view.dart`; test RF-24/RF-6 ajustados.

- [x] **T-22: Plantillas comunitarias (spec 010)**
  - Migración `0011_community_templates.sql` con `templates`,
    `template_days`, `template_exercises` y `template_sets` (lectura
    pública, sin `user_id`) y seed idempotente de 6 programas curados.
  - Cache local en drift (`schemaVersion` 16) y `TemplateRepository`:
    refresco transaccional, búsqueda/filtro y detalle con catálogo resuelto.
  - `TemplatesView` + `TemplateDetailView`; la tarjeta «Explorar plantillas»
    abre la biblioteca. Importación clona una rutina (o una por día si es
    programa) y omite ejercicios ausentes avisando.
  - Tests de repositorio, vista y migración local v15→v16.

### Fase Cierre

- [x] **T-12: Revisión de fidelidad y compuertas**
  - Comparación 1:1 de las 6 pantallas contra sus `screen.png` (layout,
    textos, colores, radios, states).
  - Todos los estados cubiertos: cargando, vacío, error y sin conexión.
  - Golden tests de pantallas clave; `flutter test` en verde y
    `flutter analyze` sin incidencias.
  - Hecho (2026-10-19): cabecera de Progreso con chip de rango y «Nueva
    Medida» (fuera de la tarjeta), orden de secciones alineado al mockup
    (peso → composición → fatiga → metas → medidas → fotos → callout),
    golden `progress_empty.png`; Rutinas, Entrenar y Perfil ya coincidían
    (ciclo activo, filtros, desglose, métricas, PR, ajustes). Estados: carga
    y vacío presentes en cada sección; «sin conexión» es el modo normal
    (local-first) y los errores de red se muestran al entrar y al subir
    fotos. Compuerta: 477 tests en verde y `flutter analyze` sin
    incidencias.

---

## 5. Reglas de ejecución

1. La spec 008 manda; si aparece una decisión nueva, se detiene y se pregunta
   (constitución §1).
2. Sin sombras ni `elevation` en ningún widget nuevo (constitución §7).
3. El mapa se dibuja con `muscle_mapper` (vectorial, assets incluidos); la
   fórmula de fatiga de la 007 lleva el corte a los 3 días:
   `días >= 3 ? 0 : e^(−días/7)` (amenda T-15, decisión 2026-10-15 del
   usuario).
4. El esquema remoto solo cambia con `0008_routine_metadata.sql`; el local,
   con la `schemaVersion` 12 y sus tests de migración.
5. Nada de fotos/composición/plantillas/dispositivos con datos reales en este
   plan: solo su UI con estado vacío hasta las specs 009–011.
6. Código e identificadores en inglés; mensajes al usuario y docs en español.
