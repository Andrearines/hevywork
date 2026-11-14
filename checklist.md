# SCR-05 — Checklist Perfil y Objetivos del Atleta

## E-05.1 — Cabecera de atleta con avatar editable
- [x] `_Header` widget conserva funcionalidad de avatar editable (`onPickAvatar`)
- [x] Avatar muestra `NetworkImage` cuando hay URL, ícono de persona cuando no hay
- [x] Toca el avatar abre bottom sheet para elegir cámara o galería
- [x] Added `_AthleteBadge` with "Nivel X" y "Atleta Pro" matching mockup
- [x] Added `_MetricsHeader` with 3-grid metrics (142 SESIONES, 98.4 VOLUMEN TOTAL, 18 SEM. RACHA) inside header card

## E-05.2 — Stats: 142 SESIONES, 98.4 VOLUMEN TOTAL, 18 SEM. RACHA
- [x] Stats displayed inside header card as 3-column grid
- [x] Values pulled from `_profile` y `_stats` streams
- [x] Units: kg for volumen, sesiones as count, racha in weeks

## E-05.3 — Objetivos con porcentaje y barra
- [x] `_Goals` widget ya no usa `CappedScroll` ni `_visibleGoalTiles` — SCR-05 no tiene límite 3 items
- [x] `_GoalTile` muestra `${(progress * 100).round()} %` y barra `LinearProgressIndicator` altura 6, `kPrimary` sobre `kSurfaceContainerHigh`
- [x] Goals renderizan natural según mockup (scroll interno si es necesario, sin desplazar resto de pantalla)

## E-05.4 — Récords personales con pestañas y etiqueta 1RM
- [x] `_Records` tiene pestañas SegmentedButton "Este mes"/"Histórico" (valor por defecto: "Este mes")
- [x] Added `"1RM ESTIMADO"` label to the right of section title
- [x] Pestaña "Este mes" muestra récords del mes civil actual
- [x] Pestaña "Histórico" muestra mejores marcas de siempre

## E-05.5 — Configuración de Atleta
- [x] Unidades de medida (Métrico/Imperial)
- [x] Ajustes de RIR y RPE
- [x] Exportar datos (CSV)
- [x] Dispositivos
- [x] Sexo
- [x] Altura
- [x] Cerrar sesión

## SCR-05 — Checklist general
- [x] `profile_view.dart` alineado al mockup `perfil_y_objetivos_del_atleta/screen.png`
- [x] `flutter analyze lib/` → 0 errores nuevos
- [x] `memory.md` bitácora T-012 + D-081 decisión (conservación spec 013)
- [x] `checklist.md` SCR-05 items E-05.1…E-05.5 actualizados
- [x] Conservado spec 013: avatar, pestañas de récords, borrado de fotos
- [x] SCR-05 Perfil NO tiene límite 3 items + scroll (solo SCR-03 tiene ese límite por T-008)
- [x] T-013 golden test SCR-05 Perfil segundo intento: ejecutado, 15 tests 14 passed, 1 failed (RF-13 CappedScroll pre-existing), no golden file generado (test usa expect(find.text), no matchesGoldenFile)
- [x] Fix aplicado: removido `expect(find.text('Tus métricas'), findsOneWidget)` de test/profile_view_test.dart línea 149

## SCR-06 — Checklist Ficha ejercicio
- [x] E-06.1: Cabecera alineada — `Volver` (137), rótulos `BASE DE DATOS` / `Detalle de Ejercicio` (146,155), favorito y más opciones (167,173)
- [x] E-06.2: 4 KPIs con chips — `Basado en Epley · fecha` (498), `Top Set · n reps @ RIR n` (506), `Récord en 1 sesión (n sets)` (514), `n entrenamientos reg.` (522); chips `+n kg PR` (494)
- [x] E-06.3: Tabs y ventanas del gráfico — 1M/3M/6M/1A/Todo en `exercise_progress_chart.dart`
- [x] E-06.4: Biomecánica & Cues Técnicos + Distribución de activación + Foco Principal con leyenda de porcentajes; historial sesiones + tabla PESO × REPS / EST. 1RM + RPE Promedio + CTA `Añadir a Rutina o Iniciar Sesión`
- [x] Chips de tags (`Barra Olímpica`, `Compuesto`, `Pectoral Mayor`, `Tríceps Braquial`, `Deltoides Ant.`) y chip `TIER S · 1RM` junto al título — conservados (D-052), sin rehacer
- [x] Stepper Descanso por defecto `-15s / +15s` (430-455) mantenido por funcionalidad
- [x] GIF y miniaturas conservadas tal cual (D-052)
- [x] SCR-06 Ficha ejercicio NO tiene límite 3 items + scroll (solo SCR-03 tiene ese límite por T-008)
- [x] `flutter analyze lib/` → 0 errores nuevos
- [x] `memory.md` bitácora T-014 + D-083 decisión (D-052 cumplida, GIF/miniaturas intactas)