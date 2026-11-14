# Tareas 020 — fidelidad-mockups

Spec: `spec.md` · Plan: `plan.md`
Estados: `pendiente` · `en curso` · `hecha`
Cierre de cada tarea: `flutter test` + `flutter analyze` en verde
(constitución §4). No se commitea nada sin orden (constitución §4).

---

## F0 — Auditoría

- [ ] **T-001** — Auditoría por pantalla: comparar cada vista actual contra
  su `screen.png` y producir un checklist de diferencias (estructura,
  color, tipografía, espaciado, bordes) para SCR-01…06. El checklist alimenta
  las tareas siguientes y se adjunta al cierre de cada fase.
  → US-01…US-06 · FR-03…FR-08 · SCR-01…SCR-06

## F1 — Base compartida

- [ ] **T-002** — Extraer tokens de diseño en `lib/ui/theme/`: colores
  Obsidian Kinetic, escala de espaciado, radios y roles tipográficos
  (sin `elevation` ni `BoxShadow`). Ajustar los componentes compartidos
  (`hevy_app_bar`, `hevy_bottom_nav`, `section_header`, chips, cards) para
  consumirlos.
  → US-07 · FR-01 · SCR-01…SCR-06 · NFR-01
- [ ] **T-003** — Aplicar los roles tipográficos de `docs/DESIGN.md`
  (Space Grotesk en títulos/métricas con `tabular-nums`, Geist en texto
  operativo) usando **las familias ya existentes** en `pubspec.yaml` /
  `assets/fonts/`. **Sin archivos de fuente nuevos ni dependencias**
  (D-062, cierre de Q-021).
  → US-07 · FR-02 · NFR-03 · D-062

## F2 — SCR-01 Rutinas (`RoutinesView`)

- [ ] **T-004** — Alinear `lib/ui/views/routines_view.dart` al mockup
  `docs/pantallas/rutinas_y_programas/screen.png`: cabecera, chips de
  filtro, tarjeta de rutina activa con desglose de sesiones, cards de
  rutinas, CTA de biblioteca y nav inferior. Checklist de T-001 a cero.
  → US-01 · FR-03 · SCR-01 · CA-01
- [ ] **T-005** — Golden de SCR-01 (`test/goldens/routines_golden_test.dart`)
  con estado «con datos»; dejarlo en verde con baseline local (D-063).
  → US-01 · FR-10 · CA-01 · D-063

## F3 — SCR-02 Entrenar (`TrainView`)

- [ ] **T-006** — Alinear `lib/ui/views/train_view.dart` al mockup
  `entrenar_historial_con_sesi_n_activa/screen.png`: banner de sesión
  activa con «Reanudar», calendario mensual, racha, grid de stats,
  sesiones recientes y CTA de registro pasado.
  → US-02 · FR-04 · SCR-02 · CA-02
- [ ] **T-007** — Golden de SCR-02 en verde (baseline local, D-063).
  → US-02 · FR-10 · CA-02 · D-063

## F4 — SCR-03 Registro en vivo (`LiveWorkoutView`)

- [ ] **T-008** — Alinear `lib/ui/views/live_workout_view.dart` al mockup
  `entrenar_registro_en_vivo/screen.png`: cabecera de sesión en curso con
  descanso, acciones Añadir/Terminar, tabla de series
  SET/PREV/KG/REPS/RIR/OK con fila activa y completadas, ajuste rápido,
  ejercicio colapsable y pill de descanso flotante. **Conservar toda la
  lógica de las specs 016/017/018** (toggle Frente/Espalda, fatiga en vivo,
  breakpoints, timer).
  → US-03 · FR-05 · SCR-03 · CA-03
- [ ] **T-009** — Golden de SCR-03 en verde; verificar que
  `live_workout_view_test`, `live_fatigue_section_test`,
  `rest_timer_test` y `screen_breakpoints_test` siguen en verde.
  → US-03 · FR-10 · CA-03 · NFR-05 · D-063

## F5 — SCR-04 Progreso/Medidas (`ProgressView`, `MeasuresView`)

- [ ] **T-010** — Alinear `lib/ui/views/progress_view.dart` (y
  `measures_view.dart` como subpantalla) a los mockups
  `progreso_y_medidas/screen.png` y
  `progreso_mapa_muscular_espalda_gr_ficos/screen.png`: tarjeta de peso
  corporal con gráfico, grasa estimada/masa magra, Distribución Muscular
  con toggle Frente/Espalda sobre **mapa vectorial `CustomPainter`**,
  evolución de medidas, medidas corporales, fotos de progreso y card de
  báscula. **Secciones con funcionalidad real (D-061/FR-11):**
  «Evolución de Medidas» se alimenta de los registros reales del usuario
  (reutilizar/extender `MeasureEvolution`) y «Báscula y Caliper
  Conectados» refleja y gestiona el estado real de conexión con lo
  disponible hoy — **sin placeholder «próximamente» ni estado vacío de
  relleno**. **El BLE real queda supeditado a la spec 011
  (`flutter_blue_plus`) y no se añade ninguna dependencia en la 020**
  (D-064, NFR-03 sin enmendar).
  → US-04 · FR-06 · FR-11 · SCR-04 · CA-04 · NFR-02 · NFR-03 · D-061 · D-064
- [ ] **T-011** — Golden de SCR-04 en verde (baseline local, D-063);
  cubrir en el golden y en `progress_view_test`/`measures_view_test` que
  las secciones de FR-11 muestran datos/estado real. Si se aprueba también
  la variante Espalda, documentarlo.
  → US-04 · FR-10 · FR-11 · CA-04 · D-061 · D-063

## F6 — SCR-05 Perfil (`ProfileView`)

- [ ] **T-012** — Alinear `lib/ui/views/profile_view.dart` al mockup
  `perfil_y_objetivos_del_atleta/screen.png`: cabecera de atleta con
  stats, Objetivos Actuales con barras de progreso, Récords Personales,
  Configuración de Atleta. **Conservar** lo ya fijado en la spec 013
  (avatar, pestañas de récords, borrado de fotos).
  → US-05 · FR-07 · SCR-05 · CA-05
- [ ] **T-013** — Golden de SCR-05 en verde (baseline local, D-063);
  `profile_view_test` y `profile_stats_test` en verde.
  → US-05 · FR-10 · CA-05 · D-063

## F7 — SCR-06 Ficha de ejercicio (`ExerciseInfoView`)

- [ ] **T-014** — Alinear `lib/ui/views/exercise_info_view.dart` al mockup
  `informacion_del_ejerccios/screen.png`: cabecera con chips, KPIs,
  tabs de gráfico, Biomecánica & Cues, distribución de activación,
  historial de sesiones y CTA inferior. **No sustituir ni rehacer el GIF ni
  las miniaturas actuales** (D-052); conservar lo fijado en las specs 015 y
  019.
  → US-06 · FR-08 · SCR-06 · CA-06 · D-052
- [ ] **T-015** — Golden de SCR-06 en verde; verificar explícitamente en
  el checklist que el GIF/miniatura siguen intactos (CA-06);
  `exercise_info_view_test` en verde (baseline local, D-063).
  → US-06 · FR-10 · CA-06 · D-052 · D-063

## F8 — Estados y cierre

- [ ] **T-016** — Reestilizar con los tokens de T-002 los estados vacío,
  carga y error de las 6 vistas (sin regresiones funcionales). **Excepción:**
  las secciones de FR-11 (Evolución de Medidas, Báscula/Caliper) muestran
  siempre estado real, no estado vacío de relleno (D-061).
  → US-07 · FR-09 · FR-11 · SCR-01…SCR-06 · CA-07 · D-061
- [ ] **T-017** — Cierre técnico: `flutter test` completo en verde,
  `flutter analyze` sin errores, `grep` de NFR-01 (`BoxShadow`/`elevation`)
  sin apariciones nuevas y NFR-03 (sin dependencias nuevas en
  `pubspec.yaml`).
  → NFR-01, NFR-03, NFR-04, NFR-05 · CA-08
- [ ] **T-018** — Cierre documental: actualizar `docs/specs/README.md`
  (fila 020), `memory.md` (decisiones D-050…D-065, cierres Q-020…Q-023)
  y registrar las aprobaciones visuales del usuario por pantalla.
  → CA-08 · D-059

---

## Matriz de trazabilidad

### SCR → tareas
| SCR | Tareas |
|---|---|
| SCR-01 | T-001, T-002, T-004, T-005, T-016 |
| SCR-02 | T-001, T-002, T-006, T-007, T-016 |
| SCR-03 | T-001, T-002, T-008, T-009, T-016 |
| SCR-04 | T-001, T-002, T-010, T-011, T-016 |
| SCR-05 | T-001, T-002, T-012, T-013, T-016 |
| SCR-06 | T-001, T-002, T-014, T-015, T-016 |

### FR → tareas
| FR | Tareas |
|---|---|
| FR-01 | T-002, T-016 |
| FR-02 | T-003 |
| FR-03 | T-001, T-004 |
| FR-04 | T-001, T-006 |
| FR-05 | T-001, T-008 |
| FR-06 | T-001, T-010 |
| FR-07 | T-001, T-012 |
| FR-08 | T-001, T-014 |
| FR-09 | T-016 |
| FR-10 | T-005, T-007, T-009, T-011, T-013, T-015 |
| FR-11 | T-010, T-011, T-016 |

### US → SCR
US-01→SCR-01 · US-02→SCR-02 · US-03→SCR-03 · US-04→SCR-04 ·
US-05→SCR-05 · US-06→SCR-06 · US-07→transversal
