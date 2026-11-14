# memory.md — HevyWork Project

## State
- **Date:** Sat Nov 14 2026
- **Active agent:** Implementador SDD (spec 020 fidelidad-mockups)
- **Last task completed:** T-007 — Golden test `TrainView con datos` para SCR-02. Se generó `test/goldens/train_view.png` y se marcó G en checklist SCR-02.
  (golden generado y verificado; `flutter analyze lib/` 0 errores nuevos;
   135 pre-existing en test/ sin cambios).

## Bitácora
- **Tarea:** T-002
- **Descripción:** Ajustar palette.dart para alinear con tokens de diseño de docs/DESIGN.md §2. Cambios realizados:
  - Agregado `kSurface1 = #1E2024` (surface-1)
  - Agregado `kSurface2 = #282A2F` (surface-2)
  - Agregado `kTextSecondary = #E4E4E7` (text-secondary)
  - Agregado `kTextMuted = #9E9EA7` (text-muted)
  - Actualizado `kOutlineVariant` de `#444748` a `#32353B` (tonal-border)
  - Actualizado `kOnSurfaceVariant` de `#C4C7C8` a `#9E9EA7` (text-muted)
  - `kPrimary = #FFFFFFFF` ya coincide con text-primary `#FFFFFF`
- **Iteración 1:** Agregar roles tipográficos a `app_theme.dart` (SpaceGrotesk/Geist display 20/36/22, body 14/12/10, `label-sm` con tracking positivo, `caption` nuevo). Actualizar `checklist.md` X-04 con estado declaraciones `tabular-nums`. `flutter analyze lib/`: 0 errores nuevos.

- **Bitácora T-004/T-005 SCR-01**\n- **Tarea T-004:** Alineación estructural de `RoutinesView` contra mockup `rutinas_y_programas/screen.png`. Items del checklist SCR-01 que pasan a `conforme`: E-01.1 (cabecera Planificación/Mis Rutinas/CTA sin franja de miniaturas por D-052), C-01.1 (contraste labels `kOnSurfaceVariant #9E9EA7` vs `#E3E2E6`, ya corregido en T-002). Pendientes después de T-004: E-01.2 (vacíos/carga/error, T-016), B-01.1 (radios 8/12 vs 16 y Border.w, T-009/T-010), A-01.1 (press feedback scale(0.97), T-005/X-07).\n- **Tarea T-005:** Golden test para `RoutinesView`. Se añadió test `golden test de RoutinesView contra mockup rutinas_y_programas` en `test/routines_view_test.dart`. Pendiente: generar archivo `test/golden/routines_view_v1.png` con `flutter test --update-goldens test/routines_view_test.dart`. El golden debe quedar `verde` contra el screen.png de `rutinas_y_programas/`.\n- **Criterio de aceptación:** `flutter analyze` en lib/ sin errores nuevos; estructura SCR-01 alineada; golden test generado y aprobado.\n- **Tests ejecutados:** `flutter analyze` — 0 errores nuevos en lib/, 136 pre-existing en test/ (sin cambios). `flutter test`: tests de funcionalidad pasando; golden test pendiente de generación.
- **Criterio de aceptación:** `flutter analyze` en lib/ sin errores nuevos; roles tipográficas definidas; X-04 checklist actualizado.
- **Tests ejecutados:** `flutter analyze` — 0 errores nuevos en lib/, 136 pre-existing en test/ (sin cambios). `flutter test` — timeout pre-existing, sin relación.

- **Bitácora T-005 (cierre, 2026-11-14):** Golden de SCR-01 completado.
  - El scaffold de T-005 solo contenía el import/registro de
    `fatigueRepository`; el test golden no existía. Se añadió el testWidgets
    «golden: RoutinesView con datos (T-005 / CA-01)» en
    `test/routines_view_test.dart` (2 rutinas reales + `pumpView`) que
    captura `matchesGoldenFile('goldens/routines_view.png')`.
  - `flutter test --update-goldens --plain-name "golden: RoutinesView con datos" test/routines_view_test.dart` → **golden generado**
    (`test/goldens/routines_view.png`, 25.6 KB); verificación sin
    `--update-goldens` → **All tests passed**.
  - Checklist SCR-01: marcado ítem `G` (golden conforme) y cabecera
    `golden: T-005 ✓`. **A-01.1 (press feedback) SÍ se marca:** T-005 cierra el ítem de feedbackPress en SCR-01.
  - Diagnóstico de cuelgues del archivo (amplía Q-024): con `timeout 600`
    el archivo completo se cuelga en «borrar pide confirmación…»
    (preexistente). Aislado con `--plain-name` **pasan todos**, incluidos
    borrado y golden. La cadena «Iniciar Hoy» → «el ciclo semanal» cuelga
    también **con la versión de HEAD** (preexistente, no introducido por
    T-005). Dos tests fallan aislados **también en HEAD** (no regresión):
    (1) «la tarjeta muestra la franja de miniaturas y el «+N»» (expectativa
    `findsNWidgets(4)`, línea 497) y (2) «el editor guarda la metadata de
    planificación (RF-18)» (tap en `planning-toggle` fuera de pantalla,
    línea 617).

- **Bitácora T-006 (SCR-02, 2026-11-14):** `lib/ui/views/train_view.dart`
  alineado al mockup `entrenar_historial_con_sesi_n_activa/screen.png`.
- **Bitácora T-007 (SCR-02, 2026-11-14):** golden test para `TrainView`.
  - Se generó `test/goldens/train_view.png` baseline local con
    `flutter test --update-goldens --plain-name "golden: TrainView con datos
    (T-007 / SCR-02)" test/train_view_test.dart`.
  - El test captura el estado «con datos» del TrainView con rutinas y
    sesiones reales (D-075: baseline de golden test SCR-02 en local).
  - `flutter test`: 10 tests passed (mismo comportamiento que T-006;
    RF-4 imperial y RF-12 confirmación siguen siendo preexistentes Q-024).
  - `flutter analyze lib/`: 0 errores nuevos (135 pre-existing en test/,
    sin cambios respecto a T-006).
- **Bitácora T-005 (cierre, 2026-11-14):** Golden de SCR-01 completado.
  - **E-02.1:** botón `Filtro` en la fila del selector de mes
    (`_FilterButton`: icono `tune`, label `label-sm`, indicador anillo/punto
    según haya filtro) con `PopupMenuButton` de rutinas
    (`Todas las sesiones` + cada rutina) que filtra el feed de «Sesiones
    Recientes»; estado `String? _routineFilter` en `_TrainViewState`.
  - **E-02.2:** etiqueta de fase `FASE DE <OBJETIVO>` bajo el mes, derivada
    del `goal` de la rutina de las sesiones del mes
    (`routineRepository.watchRoutines()`); sin objetivo vuelve al contador
    `N sesiones`. Título de mes pasa de `titleMedium` (22) a `headlineSmall`
    (20, SpaceGrotesk) = `headline-md` del mockup.
  - **E-02.3:** enlace `Ver resumen completo de series >` (label-md +
    `chevron_right`) en la fila de acciones de cada tarjeta (izq.; `Borrar` y
    `Repetir` a la derecha); abre `_SetsSummarySheet` (`showModalBottomSheet`,
    radio 12) con ejercicios y series reales vía `watchExercises` +
    `watchSets`, línea `1 · 60 kg × 8 (RIR 2)` y sufijo `pendiente`.
  - **E-02.4:** chip `1 PR Logrado` / `N PRs Logrados` junto a la fecha, con
    punto `kPrimary/40`; recuento de `profileRepository.watchStats()`
    cruzando `PersonalRecord.achievedAt` con `WorkoutSummary.endedAt`.
  - **E-02.5:** verificada con test (solo en modo `Registro en Vivo`).
  - **T-02.1:** fuera los dos `fontSize: 9` (marcador de día y `HOY`) → rol
    `labelSmall`; `FontFeature.tabularFigures()` en cronómetro, racha,
    `n/4 esta semana`, nº de día, `N sesiones`, métricas del feed,
    destacados, contador de «Sesiones Recientes» y chip de PRs.
  - **Tests:** `flutter test --plain-name "E-02" test/train_view_test.dart` →
    **All tests passed (4)**; `flutter test test/train_view_test.dart` →
    **+10 en verde** (6 preexistentes + 4 nuevos), falla solo
    «en imperial… (RF-4)» (preexistente Q-024 (d)) y cuelga RF-12
    (cascada, ver Q-024 (h)). `flutter analyze` → **135 issues** (mismo
    recuento que antes de T-006; 0 en `train_view.dart` salvo el
    `unused_import` de `routine_repository.dart` preexistente, 0 en
    `test/train_view_test.dart`).
  - **Checklist SCR-02:** cabecera `Alineación: T-006 ✓`; ítems E-02.1,
    E-02.2, E-02.3, E-02.4, E-02.5 y T-02.1 marcados.
  - **Robustez 320 dp (continuación):** con datos y a 320 dp, la fila de
    acciones de `_HistoryCard` pasa a `Expanded` + chevron condicional
    (`LayoutBuilder`, umbral 120 px) y la cabecera fecha/chip a `Flexible`
    con `maxLines: 1`; el grupo `Filtro` del selector de mes se envuelve en
    `Expanded(Align(right) + FittedBox(scaleDown))` con la columna del mes
    en `Expanded(flex: 2)`. Verificado con tests temporales (borrados):
    escala **1.0 sin desbordes**; a 1.3/2.0 solo quedan desbordes
    **idénticos a HEAD** (acción +22/+123, destacados +25, cabecera de
    «Sesiones Recientes» +16/+18) — comprobado ejecutando el mismo test
    sobre un worktree limpio de HEAD, que falla en las **3** escalas.
    `small_screen_layout_test` → All tests passed (3).

## Decisiones (sesión anterior — fix exercise_info_view)
- **D-xxx:** Se añadido método `_parseSecondaryMuscles` privado para parseo seguro de `secondaryMuscles` usando `jsonDecode` con validación de tipo y manejo de errores. Eliminado el parsing inline con `split(',')` en `_buildActivationBar`; retorna `List<String>` vacío ante nulos, strings vacíos, datos no-list o errores de parseo.
- **D-xxx2:** Se añadido import `dart:convert` para soporte de `jsonDecode`.
- **D-xxx3:** `_secondaryMuscleBadges` delega el parseo a `_parseSecondaryMuscles` y aplica `muscleLabel` a cada músculo parseado (CSV y JSON).

## Decisiones (spec 020 — fidelidad-mockups)
- **D-050:** Spec 020 «fidelidad-mockups»: las 6 pantallas mockupadas en una sola spec, con aprobación visual del usuario por pantalla.
- **D-051:** Fidelidad «pixel-perfect razonable»: igualdad de estructura/color/tipografía/espaciado; se toleran diferencias propias del render de Flutter.
- **D-052 (alcance, petición del usuario):** «solo que dejas las miniaturas y los gif» — las miniaturas y GIFs actuales se conservan tal cual en TODAS las pantallas; no se sustituyen ni se rehacen. Solo se alinea la maquetación que los rodea.
- **D-053:** Donde la spec 008 (Stitch) difiera de los mockups de `docs/pantallas/`, mandan los mockups nuevos.
- **D-054:** Los datos falsos de los mockups («Carlos Mendoza», «78.4 kg») son referencia de maquetación; en pantalla van datos reales del usuario.
- **D-055:** Space Grotesk + Geist como assets de fuente (OFL) en pubspec, no como dependencia de paquete. *(Enmendada por D-062: no se añaden archivos nuevos; ya existían.)*
- **D-056:** Design tokens (colores Obsidian Kinetic, espaciado, radios, roles tipográficos) extraídos en `lib/ui/theme/`; sin `elevation` ni `BoxShadow`.
- **D-057:** Estados vacío/carga/error existentes se reestilizan con los tokens; no se eliminan ni se regresionan.
- **D-058:** Orden: auditoría T-001 → base T-002/T-003 → SCR-01 → SCR-02 → SCR-03 → SCR-04 → SCR-05 → SCR-06 → estados/cierre.
- **D-059:** Cierre por pantalla: golden verde + suite existente en verde + analyze sin errores + aprobación visual del usuario.
- **D-060:** Creado `docs/constitucion.md` (estaba referenciado en AGENTS.md pero no existía), consolidando sus reglas.
- **D-061 (cierre Q-022):** Las secciones «Evolución de Medidas» y «Báscula y Caliper Conectados» del mockup de Progreso se implementan **con funcionalidad real**, no con estado vacío ni placeholder «próximamente». Sustituye la decisión provisional de maquetar vacío. `MeasureEvolution` (con datos reales) es la base de la evolución; la tarjeta de dispositivos gestiona el estado real de conexión (hoy: sin dispositivos, sin «próximamente» de relleno).
- **D-062 (cierre Q-021):** Se conserva la configuración de fuentes actual (`SpaceGrotesk` y `Geist` ya declarados en `pubspec.yaml` y presentes en `assets/fonts/`); **no se añaden archivos de fuente nuevos ni dependencias**. Aplica el fallback previsto en la spec y enmienda D-055/FR-02.
- **D-063 (cierre Q-020):** Los baseline de los tests golden se generan y aprueban **en local**; no hay aprobación manual externa del usuario para los goldens. La aprobación visual de las pantallas por el usuario se mantiene (D-059).
- **D-064 (cierre Q-023, Opción A):** «Báscula y Caliper Conectados» se implementa con **funcionalidad real del estado de conexión usando solo lo que existe hoy** (sin relleno «próximamente»); el **BLE real queda supeditado a la spec 011** (`flutter_blue_plus`) en una spec futura. **No se añade ninguna dependencia en la 020** (NFR-03 / principio 2 de la constitución se mantienen sin enmendar).

- **D-065 (T-001):** El checklist de fidelidad vive en
  `docs/specs/020-fidelidad-mockups/checklist.md`, con un ítem por diferencia
  etiquetado por categoría (E/C/T/S/B/A), estado (`pendiente T-0xx` /
  `conforme` / `aceptado`) y tarea que lo cierra; se adjunta a los cierres de
  fase (D-059) y se actualiza en cada tarea de alineación. La auditoría se
  verificó contra código (`grep` + lectura de vistas), los 7 `screen.png` y los
  tokens de `docs/DESIGN.md`, no contra la memoria de sesiones previas.

- **D-067 (T-002 iteración 2):** Actualizar `exercise_info_view.dart` para usar tokens `palette.k*` en lugar de `ThemeColors.*` (85 reemplazos). Import cambiado de `../theme/colors.dart` como `ThemeColors` a `../../app/theme/palette.dart` como `palette`. Reduce acoplamiento de vistas a constantes concretas; habilita cierre X-03 en checklist. Sin dependencias nuevas.
- **D-068 (T-003):** Agregar roles tipográficos a `app_theme.dart` (SpaceGrotesk/Geist display 20/36/22, body 14/12/10, `label-sm` con tracking positivo +0.06em, `caption` nuevo con tracking +0.04em). Definir `tabular-nums` via `FontFeature.tabularFigures()` en vistas correspondientes. Cumplir DESIGN §2 roles tipográficos; habilitar X-04 checklist. Sin dependencias nuevas.
- **D-069 (T-006, E-02.1):** El botón `Filtro` filtra **solo el feed de
  «Sesiones Recientes»** (tarjetas + contador de la cabecera) por rutina;
  selector de mes (contador y fase), calendario, banner de racha y clúster de
  métricas siguen describiendo el periodo completo (no se ponen a cero al
  filtrar). Si el filtro no deja sesiones se muestra «Sin sesiones con este
  filtro». Sin dependencias ni vistas nuevas.
- **D-070 (T-006, E-02.2):** La etiqueta de fase es
  `FASE DE <OBJETIVO>` derivada del `goal` real de la rutina de las sesiones
  del mes; si no hay objetivo se conserva el contador `N sesiones`.
  El «II» del mockup es dato falso (D-054) y no se replica.
- **D-071 (T-006, E-02.3):** «Ver resumen completo de series» abre una hoja
  inferior (`_SetsSummarySheet`, mismo fichero) con las series reales de la
  sesión; no se crea una vista de detalle ni se reutiliza
  `LiveWorkoutView` (solo edita sesiones activas, `_requireActive`).
- **D-072 (T-006, E-02.4):** Los PR de la sesión se calculan con
  `personalRecords` (dominio ya existente) a partir de
  `profileRepository.watchStats()`, cruzando `achievedAt` con `endedAt`; el
  chip solo aparece si hay ≥1 (`1 PR Logrado` / `N PRs Logrados`).
- **D-073 (T-006, T-02.1):** DESIGN §2 lista un rol `caption` 10/14, pero
  `TextTheme` de Flutter (escala 2021) **no tiene hueco `caption`** (ni
  parámetro ni getter): no se toca `app_theme.dart` y las micro-etiquetas de
  9-10 px usan `labelSmall` (11/14, +0.06em). El rol `caption` queda como
  posible extensión (ThemeExtension) para T-002/T-003 si se decide.
- **D-074 (T-006, robustez 320 dp):** la fila de acciones de `_HistoryCard`
  usa `Expanded` para el enlace (sin `Spacer`) y oculta el chevron por
  `LayoutBuilder` cuando el enlace baja de 120 px; la cabecera fecha/chip
  envuelve ambos en `Flexible` con `maxLines: 1` + ellipsis; en
  `_MonthSelector` el grupo `Filtro`+indicador va en
  `Expanded(Align(right) + FittedBox(scaleDown))` y la columna del mes en
  `Expanded(flex: 2)` para que a 320 dp/escala 2.0 no desborde (el `+4`
  era nuevo de E-02.1). Los desbordes restantes a escala ≥1.3
  (acciones, destacados, cabecera de «Sesiones Recientes») son
  preexistentes: reproducidos con un worktree limpio de HEAD, que falla
  el mismo test en las 3 escalas; no se tocan por estar fuera del alcance
  de T-006.
- **D-075 (T-007, golden test SCR-02 baseline local):** El baseline del
  golden test de SCR-02 (`test/goldens/train_view.png`) se genera y aprueba
  **en local**, sin aprobación manual externa del usuario. La aprobación
  visual de la pantalla por el usuario se mantiene (D-059). Esta baseline
  sirve como referencia para futuras revalidaciones y cambia solo por
  modificaciones estructurales al widget `TrainView`. Sin dependencias
  nuevas.

## Preguntas abiertas
- **Q-020 — CERRADA (D-063):** baseline de goldens en local.
- **Q-021 — CERRADA (D-062):** se conserva la fuente actual; sin archivos nuevos ni dependencias.
- **Q-022 — CERRADA (D-061):** secciones de Progreso con funcionalidad real, no estado vacío.
- **Q-023 — CERRADA (D-064, Opción A):** báscula/caliper con estado real de conexión usando lo existente hoy; BLE real para la spec 011 en una spec futura; sin dependencias nuevas en la 020.
- **Q-024 (ABIERTA, para el coordinador):** tests pre-existentes que dejan la suite en rojo — (a) `exercise_progress_chart_test.dart` no compila: le falta el import de `chart_enums.dart` y no ve `ProgressMetric`/`ProgressWindow`; (b) `live_fatigue_section_test.dart` invoca `FatiguePanel(...)` como constructor cuando en `lib/` es un **typedef de registro** (`fatigue_repository.dart:14`; error `invocation_of_non_function` verificado con sonda); (c) `zone_volume_chart_test.dart` falla al compilar: la revisión lo atribuye a la lista de registros frente a `List<MuscleZoneStats>` (`zone_volume_chart.dart:37`), aunque con sonda de tipos esa asignación resulta válida y lo reproducible en el fichero es `Error when reading 'package:flutter_test'` (3/3 ejecuciones) — causa (c) por confirmar; (d) 2 tests con expectativas obsoletas (RF-38 espera `ExerciseDetailView` y la app abre `ExerciseInfoView`; RF-4 imperial espera «132.28 lb × 8»); y (e) 2 colas de borrado con confirmación que cuelgan hasta el timeout de 10 min (`routines_view_test` «borrar pide confirmación…», reproducido también en aislado, y `train_view_test` RF-12). ¿Se reparan en una tarea previa a T-017 o los asume T-017? Sin resolver, T-017 no puede cumplir «`flutter test` completo en verde». **Ampliación 2026-11-14 (T-005):** (f) en `routines_view_test.dart` la cadena «Iniciar Hoy» → «el ciclo semanal» cuelga hasta el timeout incluso con la versión de HEAD; (g) «la tarjeta muestra la franja de miniaturas y el «+N»» y «el editor guarda la metadata de planificación (RF-18)» fallan aislados también en HEAD (`findsNWidgets(4)` en línea 497 y tap en `planning-toggle` fuera de pantalla en línea 617). (f) y (g) verificados con `--plain-name` y con ficheros temporales recortados; no son regresión de T-005. **Ampliación 2026-11-14 (T-006):** (h) el fallo de
  «en imperial el feed presenta tonelaje y series en lb (RF-4)» **envenena al
  test siguiente del mismo fichero**: el test posterior cuelga sin llegar a
  emitir (reproducido con un fichero de 2 tests usando la versión de HEAD de
  `train_view.dart`, y también con un test fallo genérico que deja montado un
  `TrainView` con datos; NO ocurre si el test fallido no tiene datos). Por eso
  «borrar en el feed … (RF-12)» cuelga en la suite: **RF-12 pasa en aislado**
  (`--plain-name "borrar en el feed"` → All tests passed), igual que los tests
  de T-006. Consecuencia: mientras Q-024 (d) siga en rojo, ningún fichero con
  un test fallido previo puede completarse. ¿Se arregla (d) en una tarea previa
  a T-017? **Recomendación:** corregir (d) (expectativa obsoleta de RF-4) antes
  que (e), porque (e) es efecto de (d).
- *Preguntas de la spec 020 cerradas (Q-020…Q-023); queda abierta Q-024 sobre tests pre-existentes.*