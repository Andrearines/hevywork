# Checklist de fidelidad — spec 020 (T-001)

Auditoría de cada vista activa contra su mockup `screen.png`, con referencia a
los tokens de `docs/DESIGN.md` §2–§3. Cada ítem alimenta las tareas indicadas
al final de la línea. Sin cambios de código: este documento es la entrada de
T-004, T-006, T-008, T-010, T-012 y T-014, y de la base T-002/T-003.

**Leyenda:** `T-0xx` = pendiente en esa tarea · `aceptado` = desviación
justificada que no se corrige · `conforme` = verificado igual al mockup.

**Categorías:** `E` estructura · `C` color · `T` tipografía · `S` espaciado ·
`B` bordes · `A` animación.

---

## X — Transversal (aplica a los 6 SCR)

### C · tokens de color
- [ ] X-01 · Valores de `lib/app/theme/palette.dart` que difieren de los tokens
      de `docs/DESIGN.md` §2: `text-muted` `#9E9EA7` vs `kOnSurfaceVariant`
      `#9E9EA7` (palette.dart:14, etiquetas y unidades más claras que en el
      mockup); `tonal-border` `#32353B` vs `kOutlineVariant` `#444748`
      (palette.dart:19, usado en hevy_app_bar.dart:53 y hevy_bottom_nav.dart:56);
      `surface-1` `#1E2024` vs `kSurfaceContainer` `#1F1F23`; `surface-2`
      `#282A2F` vs `kSurfaceContainerHigh` `#292A2D`; `text-primary` `#FFFFFF`
      vs `kOnSurface` `#E3E2E6`. `accent-olive` sí coincide
      (`kOliveAccent #849386`). — T-002
- [ ] X-02 · Tres widgets de gráfico traen su **propia paleta clara** en vez
      del tema oscuro: `exercise_progress_chart.dart:15-20`,
      `zone_volume_chart.dart:23-28` y `fatigue_trend_chart.dart:18-23` definen
      `kOnSurface #18181B` (texto casi negro), `kPrimary #0061A8` (azul) y
      `kSurface #E4E6EB` sobre el canvas `#121316`. A su lado, los gráficos son
      líneas y etiquetas blancas/grises sobre oscuro.
      Afecta a SCR-04 (peso, evolución) y SCR-06 (progresión 1RM). —
      T-002, T-010, T-014
- [x] X-03 · `exercise_info_view.dart` consume colores usando tokens `palette.k*` (85 referencias tras migrar de `ThemeColors.*`). Import cambiado de `../theme/colors.dart` como `ThemeColors` a `../../app/theme/palette.dart` como `palette` en T-002 iteración 2. Mismo valores de diseño, acoplamiento reducido al actualizar tokens. — T-002 iteración 2.

### T · tipografía
- [ ] X-04 · Los roles existen en `lib/app/theme/app_theme.dart` (SpaceGrotesk 20/36/22 para display, Geist 14/12/10 para body, D-068 cumplida) pero las vistas fijan `fontSize` literales. `live_workout_view` SÍ declara `tabular-nums` en 9 sitios (usando `FontFeature.tabularFigures()`) y `exercise_info_view` SÍ en 4 sitios; `routines_view`, `train_view`, `progress_view`, `profile_view` NO declaran `tabular-nums` a pesar de que DESIGN §2 lo exige para timers, contadores, reps y peso. — T-003 y T-004/006/010/012 (T-008 conserva el ya existente)
### S · espaciado · B · bordes
- [ ] X-05 · Radios fuera de la escala `4/8/16/24/999` (DESIGN §2): las vistas
      usan 6, 12 y 20 — `routines` 8×8 y 12×4; `train` 8×11 y 12×6;
      `live_workout` 8×8, 6×4, 12×4; `progress` 12×7 y 999×4;
      `exercise_info` 4×1. **No aparece el radio de contenedor 16 px** que el
      mockup aplica a todas las tarjetas. — T-009 y tareas de alineación
- [ ] X-06 · Bordes hairline inconsistentes: hay 22 `Border.all` en `lib/` —
      14 con `kSurfaceContainerHighest #343538` y 11 excepciones:
      `hevy_bottom_nav.dart:56` (`kOutlineVariant` α 0.4),
      `train_view.dart:214` (`kOutlineVariant` α 0.3), `train_view.dart:529`
      (`kPrimary`, día activo), `live_workout_view.dart:749`
      (`kSurfaceContainerLowest`), `live_workout_view.dart:2155`
      (`kOnSurfaceVariant`), `exercise_info_view.dart:345`
      (`ThemeColors.kOnSurface` α 0.3), `progress_view.dart:1669`
      (`kOliveAccent`) y `live_fatigue_section.dart:252` (color dinámico,
      ancho 1.5). En las 6 vistas auditadas hay 16 (10 con
      `kSurfaceContainerHighest` + 6 de las excepciones) y
      **`routines_view.dart` (0) y `profile_view.dart` (0) no usan `Border.all`**.
      El mockup y DESIGN §3 piden borde 1px `#32353B` en todas las cards. —
      T-002 y tareas de alineación

### A · animación (deuda de estilo)
- [ ] X-07 · No existe **press feedback** `scale(0.97)` en ninguna vista ni
      widget (`grep scale(0.9` sin resultados). Solo hay 3 curvas declaradas en
      las 6 vistas + widgets (`metric_cluster.dart:121` `easeInOut`,
      `progress_view.dart:749/837` `easeOut`) y 7 `duration` en total; ninguna
      declara propiedades de transición concretas (riesgo de `all`). Pendiente
      aplicar `cubic-bezier(0.23,1,0.32,1)`, duraciones <300 ms y transiciones
      de propiedades exactas en los componentes que toque cada pantalla. — T-005,
      T-007, T-009, T-011, T-013, T-015 (goldens) y T-017

### conforme (verificado, sin acción)
- [x] C-NAV · Nav inferior: 4 destinos y orden **idénticos** al mockup
      (`hevy_bottom_nav.dart:19-24`: ENTRENAR, RUTINAS, PROGRESO, PERFIL),
      pill flotante con blur, radio 999, labels `labelSmall`. — conforme
- [x] C-APPBAR · App bar de shell = mockup (marca + divisor + título + avatar):
      `hevy_app_bar.dart` y `main.dart:370-375`; títulos `Entrenar`, `Rutinas`,
      `Progreso`, `Perfil`. El icono de catálogo solo en Entrenar
      (`main.dart:374`) es adición de la spec 008 (RF-10) → aceptado. — conforme
- [x] C-FUENTES · `SpaceGrotesk` y `Geist` declarados en `pubspec.yaml:43-61`
      con sus pesos y usados por `app_theme.dart`; D-062 cumplida (familias
      reales, sin archivos nuevos). — conforme
- [x] C-NFR01 · Sin `BoxShadow` en vistas; las 5 apariciones de `elevation`
      en `lib/` son `elevation: 0` (`app_theme.dart:152,164,204` y
      `exercise_info_view.dart:1220`) o un comentario (`view_toggle.dart:44`).
      — conforme

---

## SCR-01 — Rutinas y programas · `RoutinesView` · mockup `rutinas_y_programas/screen.png`
Alineación: **T-004** ✓ · golden: **T-005** ✓ · estados: **T-016**.

### conforme
- [x] G · Golden de SCR-01 generado en verde con estado «con datos»:
      `test/goldens/routines_view.png` (baseline local, D-063), capturado por
      `test/routines_view_test.dart` («golden: RoutinesView con datos
      (T-005 / CA-01)»). Revalida E-01.1: la franja de miniaturas (D-052)
      queda reflejada en el baseline. — T-005
- [x] E · Cabecera `PLANIFICACIÓN` / `Mis Rutinas` / subtítulo + CTA blanco
      `Nueva` (routines_view.dart:321,330,339,358; `kPrimary` blanco sobre
      `kOnPrimary` = texto oscuro, igual que el mockup).
- [x] E · Tarjeta de ciclo `Ciclo Activo: Semana N` + `$done de $goal
      sesiones completadas esta semana` + puntos de paginación (465,473).
- [x] E · Chips de filtro con contador `Todas ($total)` (524).
- [x] E · Tarjeta destacada: chip `EN CURSO` (822), `Frecuencia Nx` (653),
      métricas `Frecuencia`/`Volumen Medio`/`Objetivo` (611-613),
      `DESGLOSE DE SESIONES` (726), filas numeradas (890),
      `Iniciar Hoy (…)` (762,767), icono `Editar rutina` (776), menú `...`
      (1203-1215).
- [x] E · Tarjetas de biblioteca: label de categoría en mayúsculas, título,
      descripción, `Wrap` de pills (`$avg series / sesión`, 1063-1069), pie con
      `Último uso …` (dominio, routine_overview.dart:210-216) + `Ver detalle`
      (1092,1112).
- [x] E · Fila `Explorar Biblioteca de Plantillas` (1260,1267).

### diferencias
- f[x] E-01.1 · El mockup no muestra franja de miniaturas en las tarjetas de
      biblioteca; la app añade `_ExerciseThumbStrip` (1127). — **aceptado**
      (D-052: miniaturas y GIFs se conservan); solo se revalida en T-005.
- [ ] E-01.2 · Estado vacío (`_EmptyRoutines`, 386-409: «Aún no tienes
      rutinas» + `Nueva rutina`) y estados de carga/error no existen en el
      mockup: reestilizar con tokens sin regresión funcional. — T-016
- [x] C-01.1 · Contraste de labels (`kOnSurfaceVariant #9E9EA7` vs
      `#9E9EA7`) afecta a «PLANIFICACIÓN», pies de tarjeta y metadata. — T-002/T-005
- [ ] B-01.1 · Tarjetas sin `Border.all` (X-06) y radios 8/12 en vez de 16
      (X-05); el pie de la tarjeta secundaria sí dibuja divisor interno con
      `kSurfaceContainerHighest` (1085-1089). — T-002, T-009
- [ ] T-01.1 · `fontSize: 14` y `18` literales en la vista (X-04) en cabecera
      y estados; `letterSpacing: 0.8` manual en vez de rol `label-sm`. — T-003/T-006
- [x] A-01.1 · Sin press feedback ni transición al abrir menú/CTA. — T-005, X-07

---

## SCR-02 — Entrenar (histórico + sesión activa) · `TrainView` · mockup `entrenar_historial_con_sesi_n_activa/screen.png`
Alineación: **T-006** ✓ · golden: **T-007** ✓ · estados: **T-016**.

### conforme
- [x] E · Toggle de dos modos `Registro en Vivo` / `Historial & Calendario`
      (111,116) — el mockup muestra los dos como botones separados.
- [x] E · Tarjeta de sesión activa con `SESIÓN EN CURSO` (233), cronómetro y
      `Reanudar` (277).
- [x] E · Selector de mes (335) + calendario (418) con leyenda `Completado`
      (484) y `P · T · L · U` (495).
- [x] E · Banner de racha `$streak semanas` + `RACHA CONTINUA DE ADHERENCIA`
      + `$thisWeek/$weeklyGoal esta semana` (635-671).
- [x] E · Clúster de 4 métricas `Sesiones` / `Adherencia` / `Descanso activo` /
      `Volumen mes` (711-723).
- [x] E · `Sesiones Recientes` con contador y `Exportar CSV` (1002,1045);
      tarjetas con `DURACIÓN`/`SERIES`/`TONELAJE` (789-799), línea de destacado
      `peso × reps (RIR n)` (826-829) y `Repetir` (893); CTA final
      `Registrar entrenamiento pasado` (1098).

### diferencias
- [x] E-02.1 · Botón `Filtro` en la fila del selector de mes
      (`_FilterButton`: icono `tune` + label `label-sm` + indicador de estado)
      con menú de rutinas (`Todas las sesiones` + cada rutina) que filtra el
      feed de sesiones recientes; el calendario, la racha y el clúster siguen
      describiendo el periodo completo. — T-006
- [x] E-02.2 · Etiqueta de fase bajo el mes: `FASE DE <OBJETIVO>` derivada
      del `goal` de la rutina de las sesiones del mes (p. ej.
      `FASE DE HIPERTROFIA`); sin datos de objetivo se mantiene el contador
      `N sesiones`. — T-006
- [x] E-02.3 · Cada tarjeta remata con `Ver resumen completo de series >`
      (label-md + `chevron_right`); abre `_SetsSummarySheet`, una hoja
      inferior con ejercicios y sus series reales (`watchExercises` +
      `watchSets`), formato `1 · 60 kg × 8 (RIR 2)` con marca `pendiente`. — T-006
- [x] E-02.4 · Chip `N PRs Logrados` (puntito + chip `surfaceContainerHigh`)
      junto a la fecha; el recuento sale de `profileRepository.watchStats()`
      contando los `PersonalRecord` cuyo `achievedAt` coincide con `endedAt`
      de la sesión. — T-006
- [x] E-02.5 · `_NewSessionCard` verificada: solo se renderiza en el modo
      `Registro en Vivo` (test «el modo Registro conserva la tarjeta Nueva
      sesión»); no se goldeneará fuera de estado. — T-006 (verificado), T-016
- [x] G · Golden de SCR-02 generado en verde con estado «con datos»:
      `test/goldens/train_view.png` (baseline local, D-075), capturado por
      `test/train_view_test.dart` («golden: TrainView con datos
      (T-007 / SCR-02)»). — T-007
- [ ] E-02.6 · Estados vacío (`_EmptyHistory`, 964-969) y carga/error. — T-016
- [ ] C-02.1 · Tarjetas del clúster sin borde uniforme (X-06) y labels con
      `kOnSurfaceVariant` (X-01). — T-002, T-007
- [x] T-02.1 · `fontSize: 9` literal ×2 (558,569) sustituidos por el rol
      `labelSmall` (+0.06em); `tabular-nums` (`FontFeature.tabularFigures()`)
      declarado en cronómetro, contadores de racha/semana, nº de día del
      calendario, métricas del feed, destacados, contador de «Sesiones
      Recientes» y chip de PRs. El rol `caption` 10/14 de DESIGN §2 no tiene
      hueco en `TextTheme` (escala 2021 de Flutter): esas micro-etiquetas
      usan `labelSmall`. — T-003, T-006
- [ ] B-02.1 · Radios 6/8/12 vs 16 del contenedor (X-05). — T-009
- [ ] A-02.1 · Sin transición al alternar `Registro en Vivo` / `Historial`
      ni press feedback en `Repetir`/`Exportar CSV`. — T-007, X-07

---

## SCR-03 — Registro en vivo · `LiveWorkoutView` · mockup `entrenar_registro_en_vivo/screen.png`
Alineación: **T-008**, golden: **T-009**, estados: **T-016**.

### conforme
- [x] E · Cabecera de sesión `SESIÓN EN CURSO` (522) con `AppBar('Entrenar')`
      (282).
- [x] E · Bloque `DESCANSO` con controles −15 s / +30 s / saltar (653-716) y
      pill `DESCANSO ACTIVO` (741).
- [x] E · Acciones `Añadir ejercicio` (1000) y `Terminar` (1013).
- [x] E · Tarjeta de ejercicio con `Sesión previa: n kg × n reps (@ RIR n)`
      (1352-1365), cabecera de tabla `PREVIO`/`REPS` (1537,1554), fila colapsada
      con `$planned series programadas` + `OBJETIVO RIR n` (1760,1767),
      `Ajuste Rápido:` (2026) y `Añadir serie` (2064).

### diferencias
[- [x] E-03.1 · El mockup muestra la nav inferior; `LiveWorkoutView` es ruta
      propia sin `bottomNavigationBar` (solo `AppBar`). Decidir si se mantiene
      la sesión a pantalla completa (recomendado por la naturaleza de la ruta)
      o se monta la pill. — T-008
[- [x] E-03.2 · La app añade la fila de métricas `VOLUMEN` / `SERIES` /
      `1RM MAX` (551-558) que el mockup no muestra. — T-008
[- [x] E-03.3 · El mockup concentra descanso `01:43 +30s` dentro de la tarjeta
      de sesión; la app separa un panel de descanso con estados
      `LISTO / EN PAUSA / DESCANSO ACTIVO` (741) y avisos de progresión
      sugerida (848-863, 2341-2444). — T-008
[- [x] E-03.4 · Estados vacío (`Añade tu primer ejercicio…`, 354), carga
      (`Cargando sesión...`, 243) y error (`Sesión no encontrada`, 255). — T-016
[- [x] C-03.1 · Fila de series completadas y check en `kSurfaceContainerHighest`
      vs fila activa; validar contraste AA con los tokens de T-002. — T-002/T-009
- [ ] T-03.1 · Mayor carga de `fontSize` literal de las 6 vistas (14×10, 12×6,
      20×4, 16×3, 10×3, 11×1; X-04). El `tabular-nums` **ya está declarado en
      esta vista** en 9 sitios (617, 665, 780, 926, 1946, 1963, 2087, 2195,
      2416) y en `exercise_info_view.dart` en 4 (397, 438, 586, 1138): T-008 lo
      conserva y lo extiende a lo que retoque; T-003 lo lleva al resto de
      vistas. — T-003, T-008
[- [x] B-03.1 · Radios 6/8/12 y pills 999; falta el 16 de contenedor (X-05). —
      T-009
[- [x] A-03.1 · Marca de serie completada sin transición de propiedades
      exactas; controles `Terminar`/`Añadir serie` sin press `scale(0.97)`. —
      T-009, X-07

---

## SCR-04 — Progreso (y medidas) · `ProgressView` (+ `MeasuresView`) · mockups
`progreso_y_medidas/screen.png` y `progreso_mapa_muscular_espalda_gr_ficos/screen.png`
Alineación: **T-010**, golden: **T-011**, estados: **T-016**.

### conforme
- [x] E · Fila de rango `Últimos 30 días` + `Nueva Medida` (286-355) al inicio.
- [x] E · Tarjeta `PESO CORPORAL` con pill de delta mensual (1045,1297) y
      `Meta: …` (1116); tarjetas `GRASA ESTIMADA` (1922) y `MASA MAGRA` (1936).
- [x] E · Bloque `Distribución Muscular` + `Volumen semanal y estado de
      fatiga` (476,484), toggle `Frente`/`Espalda` (717,722), leyenda
      `Alto (16-20)` / `Óptimo (12-15)` / `Recuperado` + `$count ZONAS`
      (644-655), etiqueta `Interactivo` (575) y filas de zona con `$sets series`
      (864).
- [x] E · `Fotos de Progreso` (2387) y callout `Báscula y Caliper Conectados`
      (3049).

### diferencias
- [ ] E-04.1 · El orden real es: `_headerRow()` **`Mis metas`** (272,277) →
      rango → peso → composición → fatiga → **sección de metas con
      `_GoalCard`** (1703) → medidas → fotos → dispositivos → **barra `Nueva
      meta`** (378). Los mockups no llevan «Mis metas», ni la sección de metas,
      ni la barra de nueva meta en Progreso. — T-010
- [ ] E-04.2 · El mockup muestra **dentro de Progreso** la lista «Medidas
      Corporales» (Pecho/Torso, Brazo, Cintura, Cuádriceps, Pantorrilla con
      deltas) y, en la variante b, la sección «Evolución de Medidas» con sus
      pills y stats (`Ratio Cintura/Pecho`, `Crecimiento muscular`). La app
      solo pone una tarjeta-enlace `_MeasuresEntry` «Medidas» (1188-1241) que
      abre `MeasuresView`, donde viven ambas secciones
      (`measures_view.dart:99`, `measure_evolution.dart:86`). Reubicar según
      mockup manteniendo la funcionalidad real (D-061). — T-010
- [ ] E-04.3 · Leyenda `Recuperado (≤10)` (648) frente a `Recuperado (<10 s)`
      del mockup; texto a ajustar. — T-010
- [ ] E-04.4 · La variante b proyecta `Próx 15 Mar` con leyenda
      `Registrado / Tendencia / Meta / Ritmo -300g` y chip
      `Déficit -300 kcal/día`; la tarjeta actual solo pinta la serie real +
      meta. Evaluar alcance: ¿proyección en T-010 o fuera de alcance? — T-010
- [ ] E-04.5 · Estados vacío («Pésate cada mañana…», 1159; «Termina sesiones…»,
      589), carga (`Cargando...`, 159) y error. — T-016
- [ ] C-04.1 · Gráfico de peso y de evolución con la paleta clara local
      (X-02): etiquetas `#18181B` sobre `#121316` y acento azul `#0061A8`. —
      T-002, T-010
- [ ] C-04.2 · Escala del mapa muscular (frío→rojo) y badges `Alto`/`Óptimo`:
      contrastar con `#9E9EA7`/`#849386` de DESIGN §2. — T-002, T-010
- [ ] T-04.1 · `fontSize` literal 12×8, 10×8, 11×6, 13×5 (X-04); micro-labels
      de medición sin tracking positivo consistente. — T-003, T-010
- [ ] S/B-04.1 · Cards con radio 12 y `EdgeInsets.all(16)` (11 usos) frente a
      radio 16 + borde 1px de DESIGN §3; sin `Border.all` en varias secciones
      (X-05, X-06). — T-009, T-010
- [ ] A-04.1 · Cambio `Frente`/`Espalda` y sección de zonas con
      `Curves.easeOut` genérico (749,837) sin duración/propiedad explícita. —
      T-011, X-07

---

## SCR-05 — Perfil y objetivos · `ProfileView` · mockup `perfil_y_objetivos_del_atleta/screen.png`
Alineación: **T-012**, golden: **T-013**, estados: **T-016**.

### conforme
- [x] E · Cabecera de atleta con avatar editable (`_Header`, 493), stats,
      secciones `Objetivos` (472), `Récords personales` (474) y
      `Configuración de Atleta` (476).
- [x] E · Objetivos con porcentaje (`${…} %`, 725) y barra
      (`_GoalTile`, 700-737: `LinearProgressIndicator` alto 6, radio 4,
      `kPrimary` sobre `kSurfaceContainerHigh`).
- [x] E · Filas de configuración del mockup presentes: `Unidades de medida`
      (1023), `Ajustes de RIR y RPE` (1041), `Exportar datos` (1049),
      `Dispositivos` (1055), más `Sexo` (1029), `Altura` (1035) y
      `Cerrar sesión` (1068) en `kError`. — conforme
- [x] C · `Cerrar sesión` en rojo de error, como el mockup.

### diferencias
- [ ] E-05.1 · El mockup integra las 3 stats (`142 SESIONES`,
      `98.4 t VOLUMEN TOTAL`, `18 SEM. RACHA`) **dentro** de la tarjeta de
      atleta; la app las saca a una sección propia `Tus métricas` (470) con
      `_Metrics` (615-646). Reagrupar sin perder datos. — T-012
- [ ] E-05.2 · Título de sección `Objetivos` (472) vs `Objetivos Actuales` del
      mockup. — T-012 (texto)
- [ ] E-05.3 · Los récords llevan toggle `Este mes`/`Histórico` (769,770) y el
      mockup muestra la etiqueta `1RM ESTIMADO` a la derecha. **Conservar las
      pestañas de récords** (spec 013, encargo explícito de T-012) y añadir la
      etiqueta si encaja. — T-012
- [ ] E-05.4 · Chip `ATLETA PRO · Nivel Avanzado` del mockup vs `Nivel $level`
      (594) y `Atleta` (559) rellenable: aproximar copy sin inventar datos
      (D-054). — T-012
- [ ] E-05.5 · Estados vacío (`_EmptyHint`, 1179), carga y error. — T-016
- [ ] B-05.1 · `profile_view.dart` no usa `Border.all` (0): filas de
      `Configuración de Atleta` sin divisor hairline como en el mockup
      (X-06). — T-012
- [ ] T-05.1 · `SectionHeader` usa solo `titleMedium` (`section_header.dart:23`)
      sin `label-md` tracking para los rótulos en mayúsculas del mockup
      (`CONFIGURACIÓN DE ATLETA`). — T-003, T-012
- [ ] S-05.1 · Espaciado de secciones fijo `top: 24 / bottom: 12`
      (`section_header.dart:15`) vs escala 4/8/12/20/32 con gutter 12 del
      mockup. — T-009, T-012
- [ ] A-05.1 · Sin press `scale(0.97)` en filas navegables ni en los toggles
      de métricas. — T-013, X-07

---

## SCR-06 — Ficha de ejercicio · `ExerciseInfoView` · mockup `informacion_del_ejerccios/screen.png`
Alineación: **T-014**, golden: **T-015**, estados: **T-016**.

### conforme
- [x] E · Cabecera con `Volver` (137), rótulos `BASE DE DATOS` /
      `Detalle de Ejercicio` (146,155), favorito y más opciones (167,173).
- [x] E · 4 KPIs con sus textos de apoyo: `Basado en Epley · fecha` (498),
      `Top Set · n reps @ RIR n` (506), `Récord en 1 sesión (n sets)` (514),
      `n entrenamientos reg.` (522); chips `+n kg PR` (494).
- [x] E · Tabs y ventanas del gráfico (`1RM Estimado`/`Carga Máxima`…,
      609-640; ventanas `1M/3M/6M/1A/Todo` en `exercise_progress_chart.dart`).
- [x] E · `Biomecánica & Cues Técnicos` (664), `Distribución de activación` +
      `Foco Principal:` (711,719) con leyenda de porcentajes (752,792).
- [x] E · `Historial de Sesiones` + `n registros` (812,821), tabla
      `PESO × REPS` / `EST. 1RM` (1090,1106), `RPE Promedio:` (899),
      `Cargar sesiones anteriores (n más)` (1208) y CTA
      `Añadir a Rutina o Iniciar Sesión` (1368, `bottomNavigationBar` en 241).

### diferencias
- [ ] E-06.1 · El mockup lleva fila de chips de tags (`Barra Olímpica`,
      `Compuesto`, `Pectoral Mayor`, `Tríceps Braquial`, `Deltoides Ant.`) y
      chip `TIER S · 1RM` junto al título; no existen en la vista (sin
      resultados de `TIER`/`Barra Olímpica` en `lib/`). — T-014
- [ ] E-06.2 · El mockup **no** muestra el stepper `Descanso por defecto`
      `−15 s / +15 s` que sí está en la vista (430-455). Mantener por
      funcionalidad y justificar en T-015. — T-014 (decisión), aceptado si se
      conserva
- [ ] E-06.3 · El mockup enseña además la nav inferior bajo el CTA; la vista
      reserva `bottomNavigationBar` para la barra CTA (241). Decidir si la pill
      convive con la CTA. — T-014
- [ ] C-06.1 · Constantes `ThemeColors.*` en toda la vista (X-03) y gráfico de
      progresión con paleta clara local (X-02). — T-002, T-014
- [ ] T-06.1 · 13×`fontSize: 11`, 6×10, 5×12, 4×14 literales (X-04); cues
      numerados (`01/02/03`) sin rol tipográfico propio. — T-003, T-014
- [ ] B-06.1 · Radio de vista 4×1 y cards con `kSurfaceContainer` sin borde
      uniforme; falta radio 16 (X-05, X-06). — T-009, T-014
- [ ] E-06.4 · Estados vacío (`Aún no hay sesiones con este ejercicio`, 855;
      `Sin instrucciones disponibles`, 679), carga (`Cargando…`, 1207) y error.
      — T-016
- [ ] A-06.1 · Tabs y ventanas del gráfico sin transición declarada; CTA sin
      press feedback. — T-015, X-07
- [x] D-052 · GIF y miniaturas (`exercise_thumb.dart`, `gif_cache.dart`) siguen
      intactos: verificar de nuevo en T-015 (CA-06).

---

## Uso del checklist en los cierres de fase

- T-002 (tokens) cierra X-01, X-02, X-06; T-003 cierra X-03 y X-04 (rol de
  tipografía y `tabular-nums` en `routines`/`train`/`progress`/`profile`);
  T-008 conserva el `tabular-nums` ya declarado en `live_workout_view.dart` y
  `exercise_info_view.dart` y lo extiende a lo que retoque.
- T-006 cierra en SCR-02 los ítems E-02.1, E-02.2, E-02.3, E-02.4, E-02.5
  (verificado) y T-02.1; T-007 cierra el golden (G) y revalida C-02.1/A-02.1.
- Cada par `alineación + golden` (T-004/T-005 … T-014/T-015) debe dejar a cero
  los ítems de su SCR y los transversales que le correspondan; T-016 cierra los
  ítems de estado vacío/carga/error.
- T-017 revalida X-07 (animación) junto a NFR-01/NFR-03/NFR-04.
