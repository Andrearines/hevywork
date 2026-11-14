# DESIGN.md — alineación con mockups `docs/pantallas/`

Documento de diseño de la spec `020-fidelidad-mockups`. Fuente primaria de
estilo: `docs/pantallas/obsidian_kinetic/DESIGN.md` (Obsidian Kinetic) y los
mockups HTML/PNG de `docs/pantallas/`. Donde la spec 008 (Stitch) difiera de
estos mockups, **mandan los mockups nuevos** (D-053).

## 1. Inventario de pantallas (SCR)

| SCR | Mockup | Vista Flutter | Ruta aprox. |
|---|---|---|---|
| SCR-01 | `rutinas_y_programas/` | `RoutinesView` | `/routines` |
| SCR-02 | `entrenar_historial_con_sesi_n_activa/` | `TrainView` | `/train` |
| SCR-03 | `entrenar_registro_en_vivo/` | `LiveWorkoutView` | sesión activa |
| SCR-04 | `progreso_y_medidas/` + `progreso_mapa_muscular_espalda_gr_ficos/` | `ProgressView` (y `MeasuresView` como subpantalla de medidas) | `/progress` |
| SCR-05 | `perfil_y_objetivos_del_atleta/` | `ProfileView` | `/profile` |
| SCR-06 | `informacion_del_ejerccios/` | `ExerciseInfoView` | ficha de ejercicio |

## 2. Design tokens (Obsidian Kinetic)

### Colores
| Token | Valor | Uso |
|---|---|---|
| `surface` / canvas | `#121316` | fondo de app |
| `surface-1` | `#1E2024` | tarjetas, contenedores (borde 1px `#32353B`) |
| `surface-2` | `#282A2F` | inputs, chips seleccionados, filas activas |
| `tonal-border` | `#32353B` | bordes hairline 1px, pistas de progreso |
| `text-primary` | `#FFFFFF` | números, títulos, CTA primario |
| `text-secondary` | `#E4E4E7` | estados activos, labels de lectura |
| `text-muted` | `#9E9EA7` | labels, unidades, estados inactivos |
| `accent-olive` | `#849386` | hitos positivos, PRs completados (uso mínimo) |

Reglas: nunca fondos de color detrás de números grandes; preferir contraste e
iconografía discreta a badges saturados.

### Tipografía
- **Space Grotesk**: títulos, timers, métricas, reps/peso, deltas. Siempre
  `tabular-nums` en valores que cambian (temporizadores, contadores).
- **Geist**: texto operativo, inputs, columnas de tablas, navegación.
- Roles: `display-lg` 44/48, `headline-lg` 32/38, `headline-md` 20/26,
  `metric-xl` 36/40, `metric-md` 22/26, `body-lg` 16/24, `body-md` 14/20,
  `label-md` 12/16 (+0.04em), `label-sm` 11/14 (+0.06em), `caption` 10/14.
- Micro-labels de medición en mayúsculas con tracking positivo.

### Espaciado y radios
- Margen de pantalla `16px`, gutter `12px`; escala 4/8/12/20/32px.
- Radii: micro `4px`, componente `8px`, contenedor `16px`, bottom-sheet
  `24px`, pill `9999px`.

### Elevación
- Sin sombras de profundidad: estratificación tonal + borde 1px `#32353B`.
  (Compatible con la constitución: sin `elevation` ni `BoxShadow`.)

## 3. Componentes clave
- **CTA primario**: relleno `#FFFFFF`, texto `#121316`, alto 48px, radius 8px.
- **CTA secundario**: fondo `#1E2024`, borde 1px `#32353B`, texto blanco.
- **Tabla de series**: cabecera 28px, 11px uppercase `#9E9EA7`
  (SET/PREV/KG/REPS/RIR/OK); fila 44px; fila activa con fondo `#1E2024`
  radius 6px e inputs `#282A2F`; fila completada en `#9E9EA7`.
- **Steppers numéricos**: 40–44px, fondo `#282A2F`, borde `#32353B`.
- **Chips/filtros**: fondo `#1E2024`, borde `#32353B`, pad 6×12; seleccionado
  fondo `#282A2F`, borde `#E4E4E7`.
- **Cards**: fondo `#1E2024`, borde 1px `#32353B`, radius 16px, pad 16px.
- **Pill de descanso flotante**: alto 40px, fondo `#1E2024`, borde `#32353B`,
  radius pill.
- **Nav inferior**: 4 destinos (ENTRENAR, RUTINAS, PROGRESO, PERFIL), icono +
  label uppercase; pill activa según spec 008.

## 4. Responsive
- Móvil: grid fluido 4 columnas, margen 16px.
- Tablet ≥640dp: contenido centrado con máximo 640dp (regla ya fijada en la
  spec 016; se conserva).
- `textScaler` acotado (spec 016; se conserva).

## 5. Estados por pantalla
Cada SCR-01…06 debe tener estado **vacío**, **carga**, **error** y **éxito**
con datos reales, usando los mismos tokens. Los mockups solo muestran el
estado «con datos»; los demás estados se alinean en estilo, no en contenido.

## 6. Exclusiones de assets
- **Miniaturas de ejercicio y GIFs actuales se conservan tal cual** en todas
  las pantallas (D-052). No se sustituyen por assets del mockup.
- Los datos de los mockups («Carlos Mendoza», «78.4 kg»…) son referencia de
  maquetación; en pantalla van datos reales del usuario (D-054).

## 7. Accesibilidad
- Contraste mínimo AA sobre fondos oscuros; targets táctiles ≥44px.
- Labels de iconos con semántica; sin dependencias nuevas para lograrlo.

## 8. Fuera de alcance
- Vistas sin mockup (`RoutineEditorView`, `TemplatesView`, `CatalogView`,
  `GoalEditorView`, `BodyMetricEditorView`, `PastWorkoutEditorView`,
  `TemplateDetailView`, `RoutineDetailView`) no se tocan salvo efectos
  controlados del cambio de theme compartido.
