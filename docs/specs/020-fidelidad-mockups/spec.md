# Spec 020 — fidelidad-mockups

**Estado:** aprobada en entrevista (pendiente de implementación)
**Fecha:** 2026-11-09
**Actualización:** 2026-11-09 — cierres Q-020/Q-021/Q-022/Q-023 (D-063/D-062/D-061/D-064).
**Precedente:** specs 008 (rediseño UI), 016/017/018 (sesión en vivo),
019 (ficha de ejercicio). Esta spec no las reabre: respeta sus decisiones y
solo cambia la maquetación visual declarada abajo.

## 1. Contexto

Existen mockups HTML+PNG en `docs/pantallas/` (6 pantallas, con la guía de
estilo Obsidian Kinetic en `docs/pantallas/obsidian_kinetic/DESIGN.md`).
El usuario quiere que las pantallas Flutter sean **idénticas** a esos
mockups. El estado actual de las vistas está **bastante cerca**, así que la
spec trabaja sobre ajuste fino, no reconstrucción.

## 2. Alcance

### 2.1 Pantallas incluidas (SCR)

| SCR | Mockup | Vista |
|---|---|---|
| SCR-01 | `rutinas_y_programas/` | `RoutinesView` |
| SCR-02 | `entrenar_historial_con_sesi_n_activa/` | `TrainView` |
| SCR-03 | `entrenar_registro_en_vivo/` | `LiveWorkoutView` |
| SCR-04 | `progreso_y_medidas/` + `progreso_mapa_muscular_espalda_gr_ficos/` | `ProgressView` (+ `MeasuresView` como subpantalla) |
| SCR-05 | `perfil_y_objetivos_del_atleta/` | `ProfileView` |
| SCR-06 | `informacion_del_ejerccios/` | `ExerciseInfoView` |

### 2.2 Dentro de alcance
- Maquetación: estructura, orden de secciones, colores, tipografía,
  espaciados, radios, bordes y jerarquía, según `docs/DESIGN.md`.
- Design tokens unificados en `lib/ui/theme/` (FR-01).
- Tipografía: se conserva la configuración de fuentes actual
  (`SpaceGrotesk` y `Geist` ya declaradas en `pubspec.yaml`); **sin archivos
  de fuente nuevos ni dependencias** (FR-02, D-062).
- Estados vacío / carga / error de las 6 vistas, con el mismo estilo nuevo.
- Secciones funcionales de Progreso: «Evolución de Medidas» y «Báscula y
  Caliper Conectados» con funcionalidad real (FR-11, D-061).
- 6 tests golden, uno por pantalla.

### 2.3 Fuera de alcance
- **Miniaturas y GIFs actuales: se conservan tal cual en todas las
  pantallas** (D-052). No se sustituyen por assets del mockup.
- Vistas sin mockup (`RoutineEditorView`, `TemplatesView`, `CatalogView`,
  `GoalEditorView`, `BodyMetricEditorView`, `PastWorkoutEditorView`,
  `TemplateDetailView`, `RoutineDetailView`): no se tocan, salvo efectos
  controlados del cambio de theme compartido.
- Lógica de negocio, datos, repositorios, sync, esquema local/remoto
  (ver `docs/db.md`: sin migraciones). *Excepción:* FR-11 (D-061) exige
  funcionalidad real en las secciones de Progreso mencionadas, resuelta
  reutilizando componentes/estado existentes; no implica migraciones ni
  repositorios nuevos.
- Funcionalidad de las specs 016/017/018/019 (ya cerrada): se conserva.

## 3. Decisiones (D)

| ID | Decisión |
|---|---|
| D-050 | Las 6 pantallas en una sola spec (020), con aprobación visual del usuario por pantalla. |
| D-051 | Fidelidad «pixel-perfect razonable»: igualdad de estructura/color/tipografía/espaciado; se toleran diferencias propias del render de Flutter. |
| D-052 | **Miniaturas y GIFs existentes se conservan sin cambio en todas las pantallas**; solo se alinea la maquetación que los rodea. |
| D-053 | Donde la spec 008 (Stitch) difiera de los mockups de `docs/pantallas/`, **mandan los mockups nuevos**. |
| D-054 | Los datos de los mockups son referencia de maquetación; en pantalla van datos reales del usuario. |
| D-055 | Space Grotesk + Geist se añaden como assets de fuente en `pubspec.yaml` (assets, no dependencia de paquete nueva). *Enmendada por D-062: no se añaden archivos de fuente nuevos.* |
| D-056 | Design tokens (colores, tipografía, espaciado, radios) se extraen en `lib/ui/theme/` y las 6 vistas los consumen; sin `elevation` ni `BoxShadow`. |
| D-057 | Los estados vacío/carga/error existentes se reestilizan con los mismos tokens; no se eliminan ni se regresionan. |
| D-058 | Orden de implementación: SCR-01 → SCR-02 → SCR-03 → SCR-04 → SCR-05 → SCR-06, precedido por auditoría (T-001) y base de theme (T-002/T-003). |
| D-059 | Criterio de cierre por pantalla: golden verde + suite existente en verde + `flutter analyze` sin errores + aprobación visual del usuario. |
| D-060 | Se crea `docs/constitucion.md` consolidando las reglas de `AGENTS.md` (archivo referenciado que no existía). |
| D-061 | Cierre de Q-022: las secciones «Evolución de Medidas» y «Báscula y Caliper Conectados» del mockup de Progreso se implementan **con funcionalidad real**, no con estado vacío ni placeholder «próximamente». |
| D-062 | Cierre de Q-021: se conserva la configuración de fuentes actual (`SpaceGrotesk` y `Geist` ya declaradas en `pubspec.yaml`); **no se añaden archivos de fuente nuevos ni dependencias** (enmienda de D-055 y de FR-02). |
| D-063 | Cierre de Q-020: los baseline de los tests golden se generan y aprueban **en local**; no hay aprobación manual externa del usuario para los goldens (la aprobación visual de las pantallas por el usuario se mantiene vía D-059). |
| D-064 | Cierre de Q-023 (Opción A): «Báscula y Caliper Conectados» se implementa con **funcionalidad real del estado de conexión usando solo lo que existe hoy** (sin relleno «próximamente»); el **BLE real queda supeditado a la spec 011** (`flutter_blue_plus`) en una spec futura. **No se añade ninguna dependencia en la 020** (NFR-03 / principio 2 de la constitución se mantienen sin enmendar). |
| D-065 | La auditoría T-001 se entrega como `checklist.md` en esta spec: un ítem por diferencia, etiquetado por categoría (E/C/T/S/B/A), con estado (`pendiente T-0xx` / `conforme` / `aceptado`) y la tarea que lo cierra; el check se adjunta al cierre de cada fase (D-059) y alimenta T-004…T-014. Cada ítem está verificado contra el código, los mockups de `docs/pantallas/` y `docs/DESIGN.md`, no contra memoria previa. |

## 4. Historias de usuario (US)

- **US-01** — Como usuario, quiero que la pantalla de Rutinas se vea
  idéntica al mockup `rutinas_y_programas` para planificar con la misma
  claridad visual del diseño. → SCR-01
- **US-02** — Como usuario, quiero que Entrenar (histórico + sesión activa)
  se vea idéntica al mockup `entrenar_historial_con_sesi_n_activa` para
  revisar mi progreso con el diseño previsto. → SCR-02
- **US-03** — Como usuario, quiero que el registro en vivo se vea idéntico
  al mockup `entrenar_registro_en_vivo` para registrar series con la
  maquetación de la tabla prevista. → SCR-03
- **US-04** — Como usuario, quiero que Progreso (peso, composición, mapa
  muscular frente/espalda, medidas y fotos) se vea idéntico a los mockups
  `progreso_y_medidas` y `progreso_mapa_muscular_espalda_gr_ficos`. → SCR-04
- **US-05** — Como usuario, quiero que Perfil (objetivos, récords,
  configuración) se vea idéntico al mockup `perfil_y_objetivos_del_atleta`.
  → SCR-05
- **US-06** — Como usuario, quiero que la ficha de ejercicio se vea
  idéntica al mockup `informacion_del_ejerccios` **conservando el GIF y las
  miniaturas actuales**. → SCR-06
- **US-07** — Como usuario, quiero que todas las pantallas compartan el
  mismo sistema visual (tokens, tipografías, estados) para que la app
  resulte coherente. → transversal

## 5. Requisitos funcionales (FR)

- **FR-01** — Tokens de diseño centralizados en `lib/ui/theme/`: colores
  Obsidian Kinetic (`#121316`, `#1E2024`, `#282A2F`, `#32353B`, `#FFFFFF`,
  `#E4E4E7`, `#9E9EA7`, `#849386`), roles tipográficos, escala de
  espaciado (4/8/12/16/20/32) y radios (4/8/16/24/pill). US-07
- **FR-02** — Se conserva la configuración de fuentes actual
  (`SpaceGrotesk` y `Geist` ya declaradas en `pubspec.yaml` y presentes en
  `assets/fonts/`); **no se añaden archivos de fuente nuevos ni
  dependencias** (D-062). Los roles tipográficos de `docs/DESIGN.md`
  (Space Grotesk en títulos/métricas con `tabular-nums`, Geist en texto
  operativo) se aplican sobre esas familias existentes en las 6 vistas.
  US-07
- **FR-03** — `RoutinesView` iguala el mockup SCR-01 (cabecera, chips de
  filtro, tarjeta de rutina activa con desglose, cards, CTA biblioteca,
  nav inferior). US-01
- **FR-04** — `TrainView` iguala el mockup SCR-02 (banner de sesión activa,
  calendario mensual, racha, stats grid, sesiones recientes, CTA registrar
  pasado). US-02
- **FR-05** — `LiveWorkoutView` iguala el mockup SCR-03 (cabecera sesión
  en curso + descanso, tabla de series SET/PREV/KG/REPS/RIR/OK con fila
  activa, ajuste rápido, ejercicio colapsable, pill de descanso flotante).
  US-03
- **FR-06** — `ProgressView`/`MeasuresView` igualan los mockups SCR-04
  (peso corporal + gráfico, grasa/masa, distribución muscular con toggle
  Frente/Espalda sobre mapa vectorial, evolución de medidas, medidas
  corporales, fotos, card de báscula). US-04
- **FR-07** — `ProfileView` iguala el mockup SCR-05 (cabecera de atleta
  con stats, objetivos con barras de progreso, récords personales,
  configuración de atleta). US-05
- **FR-08** — `ExerciseInfoView` iguala el mockup SCR-06 (KPIs, tabs de
  gráfico, biomecánica/cues, distribución de activación, historial de
  sesiones, CTA inferior) **sin tocar GIF ni miniaturas**. US-06
- **FR-09** — Cada una de las 6 vistas conserva sus estados vacío, carga y
  error, reestilizados con los tokens de FR-01. US-07
- **FR-10** — 6 tests golden (uno por SCR) capturando el estado «con
  datos» de cada pantalla, en verde. US-07
- **FR-11** — Las secciones «Evolución de Medidas» y «Báscula y Caliper
  Conectados» de SCR-04 se implementan **con funcionalidad real, no como
  estado vacío ni placeholder «próximamente»** (D-061): la evolución se
  alimenta de los registros reales de medidas del usuario y la tarjeta de
  dispositivos refleja y gestiona el estado real de conexión con lo
  disponible hoy — **el BLE real queda para la spec 011 y no se añaden
  dependencias en la 020** (D-064). US-04

## 6. Requisitos no funcionales (NFR)

- **NFR-01** — Sin `elevation` ni `BoxShadow` en el código nuevo/modificado
  (constitución §1). *Verificación:* `grep -rn "BoxShadow\|elevation" lib/ui`
  sin apariciones nuevas + revisión en code review.
- **NFR-02** — Mapa muscular siempre `CustomPainter` vectorial, nunca
  imágenes (constitución §1). *Verificación:* inspección de
  `lib/ui/widgets/muscle_map.dart` + review.
- **NFR-03** — Sin dependencias de paquete nuevas; las fuentes son assets
  (constitución §2). *Verificación:* diff de `pubspec.yaml` sin nuevos
  `dependencies`.
- **NFR-04** — `flutter test` completo en verde y `flutter analyze` sin
  errores antes de cerrar cada tarea (constitución §4). *Verificación:*
  ejecución de ambos comandos.
- **NFR-05** — Responsive conservado: ≤640 dp centrado en tablet y
  `textScaler` acotado (specs 016/018). *Verificación:* tests existentes
  `screen_breakpoints_test`, `small_screen_layout_test`,
  `responsive_layout_test` en verde.
- **NFR-06** — Contraste mínimo AA en textos sobre fondos oscuros.
  *Verificación:* revisión de pares de color de `docs/DESIGN.md` §2 en el
  checklist por pantalla.

## 7. Criterios de aceptación (Given/When/Then)

- **CA-01 (SCR-01)** — *Given* la app con datos de rutinas reales,
  *when* abro `/routines`, *then* la pantalla coincide con
  `docs/pantallas/rutinas_y_programas/screen.png` en estructura, colores,
  tipografía y espaciado (checklist sin diferencias sin justificar), su
  golden está en verde y no hay regresiones en `routines_view_test`.
- **CA-02 (SCR-02)** — *Given* una sesión activa y historial con datos,
  *when* abro Entrenar, *then* coincide con
  `entrenar_historial_con_sesi_n_activa/screen.png`, golden verde,
  `train_view_test` en verde.
- **CA-03 (SCR-03)** — *Given* una sesión en vivo en curso, *when* abro el
  registro en vivo, *then* coincide con `entrenar_registro_en_vivo/screen.png`
  (incluida la tabla de series y la fila activa), golden verde,
  `live_workout_view_test` + `live_fatigue_section_test` en verde.
- **CA-04 (SCR-04)** — *Given* datos de peso/medidas/fotos y fatiga,
  *when* abro Progreso (Frente y Espalda), *then* coincide con ambos
  mockups de progreso, **«Evolución de Medidas» muestra la evolución real
  del usuario y «Báscula y Caliper Conectados» refleja el estado real de
  conexión (sin placeholder «próximamente»)** (FR-11), golden verde,
  `progress_view_test` + `measures_view_test` en verde.
- **CA-05 (SCR-05)** — *Given* perfil con objetivos y récords, *when* abro
  Perfil, *then* coincide con `perfil_y_objetivos_del_atleta/screen.png`,
  golden verde, `profile_view_test` en verde.
- **CA-06 (SCR-06)** — *Given* la ficha de un ejercicio con GIF/miniatura,
  *when* la abro, *then* la maquetación coincide con
  `informacion_del_ejerccios/screen.png` **y el GIF/miniatura siguen siendo
  los actuales**, golden verde, `exercise_info_view_test` en verde.
- **CA-07 (transversal)** — *Given* cualquiera de las 6 vistas en estado
  vacío/carga/error, *when* se renderiza, *then* usa los tokens de FR-01 y
  no muestra sombras (NFR-01).
- **CA-08 (cierre)** — *Given* todas las tareas ejecutadas, *when* corro
  la suite completa, *then* `flutter test` y `flutter analyze` en verde y
  el usuario aprueba visualmente las 6 pantallas (D-059).

## 8. Preguntas (estado al 2026-11-09)

- **Q-020 — CERRADA (D-063)** — Baseline de los golden tests: se generan
  y aprueban **en local**; no hay aprobación manual externa del usuario
  para los goldens.
- **Q-021 — CERRADA (D-062)** — Fuentes Space Grotesk + Geist: se
  **conserva la fuente actual** (`SpaceGrotesk` y `Geist` ya están en
  `pubspec.yaml` y `assets/fonts/`); no se añaden archivos de fuente nuevos
  ni dependencias. Aplica el fallback previsto en la spec.
- **Q-022 — CERRADA (D-061)** — Secciones «Evolución de Medidas» y
  «Báscula y Caliper Conectados»: se implementan **con funcionalidad real**,
  no con estado vacío (antes: decisión provisional de maquetar vacío;
  sustituida).
- **Q-023 — CERRADA (D-064, Opción A)** — Conexión BLE de báscula/caliper:
  la tarjeta se implementa con **funcionalidad real del estado de conexión
  usando solo lo que existe hoy** (sin relleno «próximamente»); el BLE real
  queda supeditado a la spec 011 (`flutter_blue_plus`) en una spec futura.
  **No se añade ninguna dependencia en la 020** (NFR-03 / principio 2 se
  mantienen sin enmendar la constitución).
