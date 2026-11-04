# Plan 016 — Mejoras de la sesión en vivo y adaptación a pantalla

Companion técnico de `spec.md`. Orden de ejecución en `tasks.md`.

## 1. Arquitectura de la solución

### 1.1 Bloque A — Aviso audible del descanso (RF-1…RF-4)

```
RestTimer llega a `done`
        │
        ├─ app en primer plano ──► _restPill detecta transición (bandera
        │                          _restAlertedFired) ──► RestNotifier.alertNow()
        │                                                    │
        │                                    ┌───────────────┴───────────────┐
        │                                    ▼                               ▼
        │                     plugin.show(id, details)          fallback SystemSound +
        │                     (mismo canal → sonido alto)        HapticFeedback.vibrate()
        │
        └─ app en segundo plano ──► RestNotifier.scheduleAt(zonedSchedule,
                                     exactAllowWhileIdle, mismos details)
```

- **Canal Android nuevo** `rest_timer_v2` (D-019):
  `AndroidNotificationDetails('rest_timer_v2', 'Descanso', importance:
  Importance.high, priority: Priority.high, playSound: true,
  enableVibration: true, audioAttributesUsage: AudioAttributesUsage.alarm)`.
  Id nuevo porque Android **no reconfigura** canales creados (la config de
  sonido solo se aplica en la creación).
- **iOS/macOS**: `DarwinNotificationDetails(presentAlert: true,
  presentBadge: false, presentSound: true)` (sonido por defecto).
- `alertNow()` pasa de `SystemSound` único a: `plugin.show(...)` con
  `id = _notificationId + 1` (o el mismo, cancelando antes), y en cualquier
  fallo → `SystemSound.play(SystemSoundType.alert)` +
  `HapticFeedback.vibrate()` (RF-4, mismos `catch (_) {}` que hoy).
- La transición a `done` se detecta en `_restPill`/el builder de `_now`
  (que ya tick cada segundo) con una bandera por `endsAt` para emitir
  **una sola vez** (caso límite: pausa/reanudación no re-dispara).

### 1.2 Bloque B — Persistencia de series (RF-5…RF-7)

No hay cambio de esquema ni de API del repositorio hasta que el
diagnóstico (T-001) lo justifique:

```
UI (live_workout_view) ──onLogSet/onUpdateSet/onDeleteSet/onUnconfirm──►
    WorkoutRepository.logSet / updateSet / deleteSet / setSetCompleted /
    undoLastSet  ──►  drift workout_sets (escritura)  ──►  _enqueueRow(sync)
                                        │
                                        ▼
                        watchSets() re-emite ──► tabla se repinta
```

- **T-001 primero**: reproducción con tests extremo a extremo (vista →
  query directa a la BD) y, si aparece la causa, fix mínimo documentado en
  `plan.md` §5. Candidatos a revisar (sin presuponer): excepciones tragadas
  en los callbacks de la vista, operaciones sobre sesión no `active`,
  filas pendientes `completed = false` y orden `orderIndex`.
- **RF-6**: cualquier `SetValidationException` / `SessionNotEditableException`
  ya llega a snackbar en `_EditableSetRow`; el diagnóstico comprueba que
  ningún callback las traga sin avisar.

### 1.3 Bloque C — Series semanales en la tabla de fatiga (RF-8, RF-9)

```
watchFatiguePanel() ──► FatiguePanel{fatigue, zones(List<MuscleZoneStats>), trend}
                                                    │
                        zones[i].sets  (7 días, incluye sesión activa)
                                                    ▼
              LiveFatigueSection: chip de zona «Músculo · N series · X kg»
              ZoneVolumeChart:    etiqueta «N series» + «X kg» (antes «kg×series»)
```

- Sin consulta nueva: `MuscleZoneStats.sets` ya lo calcula
  `muscleZoneStats()` con la ventana de 7 días (RF-24 de la 008).
- Formato en función pura testeable (p. ej.
  `zoneSummaryLine(zone, unitSystem)` en el propio widget o en
  `lib/domain/muscle_fatigue.dart`) → test unitario sin widgets.

### 1.4 Bloque D — Pestaña Frente/Espalda en vivo (RF-10)

```
progress_view._ViewToggle  ──extraer──►  lib/ui/widgets/view_toggle.dart
                                                        ▲
LiveFatigueSection (dueña de _showBack) ──usa────────────┘
        │
        ├─ MuscleMap(showBack: _showBack)
        ├─ ZoneVolumeChart(showBack: _showBack)
        └─ limpieza de selección si la zona no es visible
           (kFrontCanonicals / kBackCanonicals, patrón _syncSelection)
```

- `live_workout_view.dart:334` deja de pasar `showBack: false` fijo (D-023).
- La selección compartida entre mapa y chips ya existe
  (`_selectedMuscle`); se añade el mismo filtro de visibilidad que Progreso.
  `kFrontCanonicals`/`kBackCanonicals` (hoy en `progress_view.dart`) se
  mueven a `lib/ui/widgets/muscle_map.dart` para que la sección en vivo no
  dependa de un fichero de vista.

### 1.5 Bloque E — Adaptación a pantalla (RF-11…RF-13)

```
MediaQuery.sizeOf(context) ──► screenBreakpointOf(width)
                                    │
                    ┌───────────────┴────────────────┐
                    ▼                                ▼
              phone (<600 dp)                  tablet (≥600 dp)
              margin 16, gutter 12             margin 24, gutter 16,
                                               maxWidth 640 centrado
```

- **Helper puro** `lib/ui/layout/screen_breakpoints.dart` (D-024):
  `enum ScreenClass { phone, tablet }`,
  `ScreenClass screenClassOf(double width)`,
  `const kTabletBreakpoint = 600`, `kContentMaxWidth = 640`,
  `horizontalMarginOf(screenClass)`, `gutterOf(screenClass)` → testeable sin
  widgets (RNF-7).
- **Aplicación** en `MainNavigator` (cuerpo centrado con
  `ConstrainedBox(maxWidth: 640)`) y en las vistas de pantalla completa que
  lo necesiten; **no** en `MaterialApp.builder` (D-025) para no afectar a
  bottom sheets (`exercise_picker`, `past_workout_editor_view`) y diálogos.
- **Escala de texto acotada** (RF-12) en el `builder` de `MaterialApp`:

  ```dart
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: MediaQuery.of(context).textScaler.clamp(
        minScaleFactor: 1.0, maxScaleFactor: 1.3),   // tope: Q-009
    ),
    child: UnitSystemScope(...),
  )
  ```

  (Verificar en implementación la API vigente: `MediaQuery
  .withClampedTextScaling` si el SDK la expone; si no, `copyWith` +
  `TextScaler.clamp`. El tope es una constante → cambiar a 1.0 si el
  usuario pide ignorar por completo la escala del sistema.)

### 1.6 Bloque F — Rediseño de la ficha del ejercicio (RF-14, RF-15)

Fuente de verdad visual: `docs/pantallas/informacion_del_ejerccios/`
(`code.html` + `screen.png` + `DESIGN.md`). No hay pantalla nueva ni
`DESIGN.md` que generar.

```
code.html (secciones)                 ExerciseInfoView (hoy)
─────────────────────────             ─────────────────────────────
Context bar (volver, rótulo,          AppBar con nombre + botón de
  favorito*, más opciones*)             idioma
Identidad: h1 + tags píldora          Badges rectos (radius 4) tras el
                                        media; nombre solo en el AppBar
(rejilla 2×2 KPI con icono,          KPIs con borde, sin icono ni
  métrica grande, chip PR)             métrica grande; `ExerciseKpis.empty`
Gráfico + filtros + insights          Gráfico con `sessions: const []`
                                        y callbacks que no cambian estado
Biomecánica plegable + activación     ExpansionTile + activación en zona
  con leyenda de puntos                aparte, leyenda sin puntos %
Historial con fila PR resaltada       Historial sin resaltar PR ni
  y cabecera con recuento               recuento; sin insights de fila
CTA flotante con icono, texto         CTA plano en bottomNavigationBar
  «Añadir a Rutina o Iniciar Sesión»   con texto según estado
```

- **Orden final (D-026)**: context bar → identidad (h1 + tags) → media
  GIF real (SCR-3, no aparece en el mockup) → KPIs 2×2 → gráfico + insights
  → biomecánica + activación → historial → descanso/idioma/atribución
  (SCR-9) → CTA flotante.
- **Conservado sin cambio de RF**: GIF real con `gifCache`/`gifUrl` y
  fallbacks (RF-2 de la 015), claves `rest-detail-minus`/`rest-detail-plus`,
  selector de idioma de pasos, atribución, estados vacíos.
- **Datos reales (D-027)**: `_buildKpiGrid` usa `exerciseKpis(_history)`
  en lugar de `ExerciseKpis.empty`; `ExerciseProgressChart` recibe
  `sessions: _history`; `onMetricChanged`/`onWindowChanged` actualizan
  `_selectedMetric`/`_selectedWindow` antes del `setState`. Los insights
  Delta Período / Frecuencia Media salen de los mismos cálculos de
  `lib/domain/exercise_stats.dart` (reutilizar, no duplicar).
- **Tipografía**: Space Grotesk (h1, métricas) y Geist (texto) — ya
  declaradas en `pubspec.yaml` y en `app_theme.dart`; solo hay que
  aplicarlas donde hoy se usan `TextStyle` genéricos.
- **Textos**: cabecera de tabla «KG × REPS» (RF-15 de la 015, prevalece
  sobre «PESO × REPS» del mockup); CTA con el texto único del mockup.
- **Ocultos** (fuera de alcance 015): estrella de favorito, badge
  «Tier S · 1RM», botón «Filtrar», «Más opciones».

### 1.7 Bloque G — Navegación desde la miniatura (RF-16)

```
live_workout_view.dart
  _ExerciseCard (expandida, thumb ~línea 1383)      ─┐
  _CollapsedExerciseCardContent (~línea 1666)        ├─► GestureDetector
routine_editor_view.dart                             │     onTap →
  _draftTile bloque superior (~línea 720)           ─┘     Navigator.push(
                                                          ExerciseInfoView(
                                                            exercise,
                                                            database: localDb,
                                                            workoutRepository:
                                                              workoutRepository))
```

- Envoltorio con `GestureDetector` en los tres puntos de llamada (D-028):
  no se toca `exercise_thumb.dart` (compartido con catálogo y detalle).
- En la tarjeta **colapsada** el `GestureDetector` del contenedor
  (`Key('expand-…')`) está en un ancestro: el gestor interno de la
  miniatura gana en la arena de gestos → navega sin expandir; al volver,
  la tarjeta sigue colapsada.
- `database: localDb` y `workoutRepository: workoutRepository` son
  globales de `main.dart` (ya importado en ambas vistas) → la ficha abre
  con pasos, historial, KPIs y CTA funcionales.
- Opcional ligado a Q-012: aplicar el mismo par de argumentos en
  `catalog_view.dart:265` y `routine_detail_view.dart:346`.

## 2. Ficheros a crear

| Ruta | Contenido |
|---|---|
| `lib/ui/layout/screen_breakpoints.dart` | `ScreenClass`, `kTabletBreakpoint`, `kContentMaxWidth`, `screenClassOf`, `horizontalMarginOf`, `gutterOf`. |
| `lib/ui/widgets/view_toggle.dart` | `ViewToggle` (Frente/Espalda), extraído de `progress_view._ViewToggle`. |
| `test/responsive_layout_test.dart` | Matriz de tamaños × pestañas × escala: sin excepciones de render ni solapes con la pill. |
| `test/live_fatigue_section_test.dart` | Sección en vivo: render, «N series · X kg», toggle Frente/Espalda, estados vacíos. |
| `test/rest_notifier_test.dart` | Detalles de notificación (canal, importancia, uso de alarma) extraídos a función pura + fallback sin plugin. |

## 3. Ficheros a modificar

| Ruta | Cambio | RF |
|---|---|---|
| `lib/domain/services/rest_notifier.dart` | Canal `rest_timer_v2` (RF-2), `alertNow()` con `plugin.show` + fallback (RF-1/RF-4), detalles compartidos programar/mostrar. | 1–4 |
| `lib/ui/views/live_workout_view.dart` | Disparo único de `alertNow()` al llegar a `done` (bandera por `endsAt`); quitar `showBack: false` fijo; envolver los dos `ExerciseThumb` en `GestureDetector` → ficha (D-028). | 1, 10, 16 |
| `lib/ui/views/routine_editor_view.dart` | Envolver el `ExerciseThumb` del bloque superior de `_draftTile` → ficha (D-028). | 16 |
| `lib/ui/views/exercise_info_view.dart` | Rediseño 1:1 al `code.html` (context bar, orden D-026, KPIs, gráfico+insights, biomecánica, historial con PR resaltado, CTA) + datos reales (D-027). | 14, 15 |
| `lib/data/repositories/workout_repository.dart` | Solo si T-001 halla la causa del fallo de persistencia (fix mínimo). | 5–7 |
| `lib/ui/widgets/live_fatigue_section.dart` | Toggle Frente/Espalda (D-023), limpieza de selección, resumen semanal por zona. | 8, 10 |
| `lib/ui/widgets/zone_volume_chart.dart` | Etiqueta con series + volumen (antes «kg×series»). | 9 |
| `lib/ui/views/progress_view.dart` | Usar `ViewToggle` compartido; reimportar `kFrontCanonicals`/`kBackCanonicals` desde `muscle_map.dart` (sin cambio visual). | 10 |
| `lib/ui/widgets/muscle_map.dart` | Recibe `kFrontCanonicals`/`kBackCanonicals` (movidas desde `progress_view.dart`). | 10 |
| `lib/main.dart` | Acotación de `textScaler` en `builder`; ancho máximo de contenido en `MainNavigator`. | 11, 12 |
| `test/small_screen_layout_test.dart` | Ampliar a la matriz de escala (1.0/1.3/2.0) y a horizontal. | 11, 12 |
| `test/live_workout_view_test.dart` | Tests de persistencia extremo a extremo + aviso del descanso + navegación a la ficha desde la miniatura (expandida y colapsada). | 1, 5–7, 16 |
| `test/routine_editor_view_test.dart` | Navegación a la ficha desde la miniatura del `_draftTile` (y ThumbFallback sin crash). | 16 |
| `test/exercise_info_view_test.dart` | Fidelidad al mockup (context bar, orden de secciones, CTA) + KPIs/gráfico con datos reales + insights; mantener verdes los casos de la 015 (RNF-9). | 14, 15 |
| `test/zone_volume_chart_test.dart` | Etiqueta nueva (texto esperado). | 9 |
| `test/progress_view_test.dart` | Regresión del toggle tras extraerlo. | 10 |
| `docs/specs/README.md` | Fila 016 (8 mejoras, T-001…T-009). | — |
| `memory.md` | Bitácora + decisiones D-018…D-028 + preguntas Q-007…Q-013. | — |

## 4. Orden de ejecución y fases

| Fase | Tareas | Contenido |
|---|---|---|
| 0 | T-001 | Diagnóstico de persistencia (bloque B) — primero porque puede descubrir un fix real. |
| 1 | T-002 | Notificaciones de alto volumen (bloque A). |
| 2 | T-003 | Series semanales en la tabla de fatiga (bloque C). |
| 3 | T-004 | Toggle Frente/Espalda en vivo (bloque D). |
| 4 | T-005 + T-006 | Breakpoints y aislamiento de escala del sistema (bloque E). |
| 5 | T-008 + T-009 | Rediseño de la ficha (bloque F) y navegación desde miniaturas (bloque G) — añadidas el 2026-11-04; independientes de las fases 0–4. |
| 6 | T-007 | Cierre: goldens, suite completa, README y memory (abarca las 9 tareas). |

Cada tarea cierra con `flutter test` + `flutter analyze` en verde
(RNF-5).

## 5. Diagnóstico de la persistencia (entrada de T-001)

Hipótesis a descartar, en orden (sin darlas por buenas):

1. **H-p1**: la vista traga una excepción y no hay feedback (RF-6).
2. **H-p2**: la operación se rechaza por `_requireActive` (sesión no
   `active` tras restaurar) y el error no llega al usuario.
3. **H-p3**: las filas precargadas (`completed = false`) no sobreviven al
   reinicio (query/orderIndex).
4. **H-p4**: el cambio sí se escribe pero la UI no lo refleja (stream
   `watchSets` no re-emite) → el usuario ve «que no se guardó».
5. **H-p5**: el cambio se pierde solo en la cola de sync (remoto), no en la
   local.

Cada hipótesis se confirma/descarta con un test; el resultado se documenta
aquí (§5) y en `memory.md` antes de cualquier fix.

## 6. Estrategia de tests

| Bloque | Test | Tipo |
|---|---|---|
| A | `rest_notifier_test.dart`: detalles del canal (id, importancia, `playSound`, uso de alarma), `scheduleAt`/`cancel` no lanzan sin plugin. | unitario |
| A | `live_workout_view_test.dart`: con el descanso llegando a `done`, se dispara el aviso una sola vez (callback inyectado / mock del plugin). | widget |
| B | `workout_repository_test.dart`: add → query directa, delete → fuera, pendientes tras «reiniciar» (nueva instancia), encolado de sync. | repositorio |
| B | `live_workout_view_test.dart`: añadir/borrar serie en la UI → fila presente/ausente en la BD. | widget |
| C | `live_fatigue_section_test.dart`: chip con «N series · X kg», sin series → «Sin series». | widget |
| C | `zone_volume_chart_test.dart`: etiqueta nueva + `shouldRepaint` sin cambios. | unitario/widget |
| D | `live_fatigue_section_test.dart`: toggle cambia `showBack`, limpia selección invisible. | widget |
| D | `progress_view_test.dart`: regresión tras extraer `ViewToggle`. | widget |
| E | `responsive_layout_test.dart`: 320/360/375/412/768/1024/1366 dp × retrato/horizontal × escala 1.0/1.3/2.0 → `tester.takeException() == null`, pill sin tapar contenido, tablet centrado a 640 dp. | widget |
| E | `screen_breakpoints` unitario: fronteras 599/600/640/1024. | unitario |
| F | `exercise_info_view_test.dart`: orden de secciones y context bar, KPIs con datos reales («—» sin sesiones), insights al cambiar métrica/ventana, CTA con texto del mockup, sin `BoxShadow`/`elevation`; regresión de los casos de la 015. | widget |
| G | `live_workout_view_test.dart`: tap en miniatura expandida → `ExerciseInfoView` + back; tap en miniatura colapsada → ficha sin expandir y tarjeta colapsada al volver. | widget |
| G | `routine_editor_view_test.dart`: tap en miniatura del tile → ficha; `ThumbFallback` sin ejercicio → sin crash. | widget |

## 7. Riesgos

| Riesgo | Mitigación |
|---|---|
| Android no cambia el sonido de un canal ya creado | Id de canal nuevo `rest_timer_v2` (D-019). |
| El aviso suene dos veces (foreground + scheduled) | Cancelar la programada al reanudar (ya se hace) + bandera de disparo único. |
| El clamp de escala rompe tests existentes que asumen escala libre | Ajustar `small_screen_layout_test.dart` en la misma tarea (T-006). |
| Centrar el contenido a 640 dp rompe bottom sheets/dialogos | Aplicar solo en el shell y vistas de pantalla completa (D-025). |
| El diagnóstico de persistencia no encuentre causa reproducible | Se dejan los tests extremo a extremo como red de seguridad y se documenta en Q-008; no se refactoriza «por si acaso». |
| Goldens afectados por el cambio de etiquetas/toggle | Regenerar solo los tocados y revisar el diff (T-007). |
| El rediseño de la ficha rompe los tests de la 015 (textos, claves, orden) | RNF-9: conservar claves y textos de aceptación; actualizar solo expectativas de presentación justificadas y revisarlas caso a caso (T-008). |
| Conectar KPIs/gráfico a datos reales cambia estados vacíos y tamaños de tarjeta | Mantener los estados vacíos de la 015 («—» + subtítulo, estado vacío del gráfico) y probar con 0, 1 y N sesiones (T-008). |
| Tocar la miniatura de la tarjeta colapsada dispara también el expand | `GestureDetector` interno gana en la arena de gestos; test que verifica «navega y no expande» (T-009). |
| La ficha abierta desde la miniatura queda sin datos (historial/CTA mudos) | Pasar `database: localDb` y `workoutRepository: workoutRepository` en el push (D-028); Q-012 propone lo mismo en los dos puntos de entrada existentes. |

## 8. Supuestos

- Sin dependencias nuevas ni migraciones (RNF-1, RNF-2).
- `flutter_local_notifications` ya está en `pubspec.yaml` (se usó en la
  002); no se toca su versión.
- Los datos de fatiga semanal ya están calculados; no hay query nueva.
- Tope de escala de texto: 1.3 (Q-009; una constante si el usuario pide
  1.0).
- Las tipografías del mockup (Space Grotesk, Geist) ya están en
  `pubspec.yaml` y en `app_theme.dart`: el rediseño no añade assets ni
  dependencias.
- No hay golden de `ExerciseInfoView` (los existentes son mapa muscular,
  detalle de rutina y progreso): la fidelidad se verifica con tests de
  widget, sin ficheros nuevos de golden.
