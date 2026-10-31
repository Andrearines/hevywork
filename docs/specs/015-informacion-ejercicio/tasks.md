# Tareas 015 — Ficha de información del ejercicio

Orden de ejecución e iterables. **Cierre obligatorio de cada tarea**:
`flutter test` en verde + `flutter analyze` sin incidencias (AGENTS.md).
Si no pasa, la tarea no está terminada.

> Estado de partida: un implementador trabaja en paralelo en la vista.
> T-001 es la condición previa; si el código de la vista ya existe al
> llegar a T-002/T-003, la tarea se dedica a alinearlo con las RF y
> añadir los tests que falten.

Matriz de trazabilidad:

| Tarea | SCR | RF |
|---|---|---|
| T-001 | — | RF-16 (criterios de datos) |
| T-002 | SCR-1, SCR-2, SCR-3, SCR-9 | RF-1, RF-2, RF-3, RF-4, RF-5 |
| T-003 | SCR-4 | RF-6, RF-7 |
| T-004 | SCR-5 | RF-8, RF-9, RF-10, RF-11 |
| T-005 | SCR-6 | RF-12, RF-13 |
| T-006 | SCR-7 | RF-14, RF-15 |
| T-007 | SCR-8 | RF-17 |
| T-008 | todos | RF-18, RNF-1…RNF-7 |

---

## T-001 · Dominio + repositorio: datos de la ficha
- **Objetivo**: dominio puro `exercise_stats.dart` con KPIs, puntos por
  sesión, delta y frecuencia; `WorkoutRepository.exerciseHistory()`
  paginado (RF-16).
- **Archivos**:
  - crear `lib/domain/exercise_stats.dart`.
  - modificar `lib/data/repositories/workout_repository.dart`
    (`exerciseHistory`).
  - tests: crear `test/exercise_stats_test.dart`; ampliar
    `test/workout_repository_test.dart` (o crear
    `test/exercise_history_test.dart`).
- **Criterio de aceptación**:
  - `exerciseKpis` excluye warmups, incompletas y `reps > 12` para e1RM;
    devuelve `secondBestE1rm` para el chip PR (null si no hay segundo).
  - `topSet` = mayor peso no-warmup completada con sus reps/RIR;
    `maxSessionVolume` usa `setVolumeKg` por sesión; `totalSets` y
    `sessionCount` correctos; con 0 datos todos los campos son null/0 sin
    excepciones.
  - `exerciseProgressPoints` devuelve un punto por sesión con la métrica
    pedida (`e1rm | load | volume`), ordenado por fecha asc.
  - `periodDelta` maneja primer punto 0 (solo Δ absoluto) y lista < 2
    (null); `weeklyFrequency` devuelve 0 sin sesiones (sin NaN/÷0).
  - `exerciseHistory` pagina con limit/offset, ordena `endedAt desc`,
    solo `status = 'finished'` con `endedAt != null`, y solo las series
    del `exerciseId` pedido (warmups incluidas en la fila, marcables).
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-002 · Vista base: identidad, GIF, badges y descanso
- **Objetivo**: `ExerciseInfoView` con SCR-1/SCR-2/SCR-3/SCR-9 y
  navegación desde los dos entry points (RF-1…RF-5).
- **Archivos**:
  - crear `lib/ui/views/exercise_info_view.dart` (context bar, media
    GIF/miniatura, título + badges, descanso, idioma de pasos,
    atribución).
  - modificar `lib/ui/views/catalog_view.dart` y
    `lib/ui/views/routine_detail_view.dart` (navegar a
    `ExerciseInfoView`).
  - tests: crear `test/exercise_info_view_test.dart` (arranque de la
    vista, GIF con `GifCache` inyectada, fallbacks).
- **Criterio de aceptación**:
  - Con `gifPath` + descargador fake OK → se sirve `Image.file`; con
    descargador que falla, sin URL o sin credenciales → miniatura local;
    sin `imagePath` → `ThumbFallback` (RF-2).
  - Miniatura visible de inmediato (no se espera al GIF, RNF-1).
  - Badges de equipo, categoría, target destacado y secundarios en
    español (`muscleLabel`) sin desbordes.
  - Descanso ±15 s 15–300 con claves `rest-detail-minus/plus` (RF-4);
    selector de idioma si hay es/en; atribución visible.
  - `catalog_view` y `routine_detail_view` abren la nueva ficha.
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-003 · Rejilla de KPIs 2×2
- **Objetivo**: SCR-4 con los KPIs del dominio (RF-6, RF-7).
- **Archivos**:
  - modificar `lib/ui/views/exercise_info_view.dart` (sección KPIs).
  - tests: ampliar `test/exercise_info_view_test.dart`.
- **Criterio de aceptación**:
  - 4 tarjetas: 1RM Estimado (+fecha y chip «+X kg PR» solo con segundo
    mejor), Carga Máxima («Top Set · N reps @ RIR n»), Volumen Máx. (con
    nº de sets de esa sesión), Total Series (con nº de sesiones).
  - Pesos en la unidad del perfil (RNF-7).
  - Sin historial: «—» y subtítulos aclaratorios, sin ceros engañosos
    (RF-7). Test con y sin datos.
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-004 · Gráfico de progresión + insights
- **Objetivo**: SCR-5: `ExerciseProgressChart` (CustomPainter, designer
  §7.9), selector de métrica, filtros 1M/3M/6M/1A/Todo, Delta Período y
  Frecuencia Media (RF-8…RF-11).
- **Archivos**:
  - crear `lib/ui/widgets/exercise_progress_chart.dart`.
  - modificar `lib/ui/views/exercise_info_view.dart` (sección gráfico).
  - tests: crear `test/exercise_progress_chart_test.dart` (+ golden
    `test/goldens/exercise_progress_chart.png`); ampliar
    `test/exercise_info_view_test.dart` (cambio de métrica/ventana).
- **Criterio de aceptación**:
  - Línea + área con gradiente + guías punteadas + punto final
    destacado; sin `BoxShadow`; `shouldRepaint` correcto.
  - Cambiar métrica y ventana recalcula puntos e insights (test que
    verifica cambio de etiquetas/puntos).
  - < 2 puntos → estado vacío del gráfico e insights ocultos (RF-11).
  - Delta: Δ absoluto y %; con primer punto 0 solo Δ absoluto.
    Frecuencia: sesiones ÷ semanas con 1 decimal; 0 sesiones → 0.
  - Golden generado y en verde.
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-005 · Biomecánica & Cues + activación muscular
- **Objetivo**: SCR-6 (RF-12, RF-13).
- **Archivos**:
  - modificar `lib/ui/views/exercise_info_view.dart` (secciones cues y
    activación).
  - tests: ampliar `test/exercise_info_view_test.dart`.
- **Criterio de aceptación**:
  - Sección plegable desplegada por defecto con pasos numerados 01, 02…;
    es preferente con fallback; switch si hay dos idiomas; sin pasos →
    «Sin instrucciones disponibles».
  - Barra de activación: target como «Foco Principal» (70 %), los
    secundarios repartiendo el 30 % con leyenda en español; sin
    secundarios → un solo segmento. Targets ≥ 48 dp en la cabecera
    plegable (RNF-3).
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-006 · Historial de sesiones paginado
- **Objetivo**: SCR-7 (RF-14, RF-15).
- **Archivos**:
  - modificar `lib/ui/views/exercise_info_view.dart` (sección
    historial).
  - tests: ampliar `test/exercise_info_view_test.dart`.
- **Criterio de aceptación**:
  - Página de 10; «Cargar sesiones anteriores (N más)» pagina con
    `exerciseHistory` (offset) y desaparece al agotar.
  - Tarjeta más reciente expandida: nombre (fallback «Sesión» + fecha),
    fecha relativa, volumen total, tabla SET / KG × REPS / RIR / EST.
    1RM, «(Cal.)» en warmups, ★ en el set del mejor e1RM histórico, pie
    con RIR medio. Las anteriores condensadas («N sets completados ·
    Top: …»).
  - Sin sesiones → estado vacío con llamada al CTA.
  - Sin desbordes en 375 dp (RNF-3); pesos en unidad del perfil.
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-007 · CTA «Añadir a Rutina o Iniciar Sesión»
- **Objetivo**: SCR-8 (RF-17).
- **Archivos**:
  - modificar `lib/ui/views/exercise_info_view.dart` (bottom bar
    sticky).
  - tests: ampliar `test/exercise_info_view_test.dart`.
- **Criterio de aceptación**:
  - Botón primario blanco 48 dp, sticky sobre el safe area, sin
    sombras, `Semantics(button)`.
  - Con sesión activa: `addExercise` + snackbar «¡Añadido a la sesión
    activa!»; sin sesión: `startWorkout` + `addExercise` + snackbar
    «Sesión iniciada con el ejercicio». Tras el tap hay exactamente una
    sesión activa (RF-19 de la 001). Tests de ambos caminos.
- **Cierre**: `flutter test` + `flutter analyze` en verde.

## T-008 · Cierre: goldens, retirada de la ficha antigua y hoja de ruta
- **Objetivo**: RF-18, RNF-1…RNF-7 y puerta final de la spec.
- **Archivos**:
  - `test/exercise_detail_view_test.dart` y
    `lib/ui/views/exercise_detail_view.dart`: retirar si Q-1 confirma
    sustitución total (decisión: sustituir; constancia aquí al cierre).
  - `test/goldens/*` (regenerar `routine_detail.png` si T-002/T-006 lo
    cambió; revisar diff visual).
  - `docs/specs/README.md` (fila 015 → ✅ con decisiones clave).
  - `docs/designer.md` (§13 fila de la pantalla; §7.15 si procede).
- **Criterio de aceptación**:
  - `pubspec.yaml` sin dependencias nuevas.
  - Goldens revisados (solo diffs esperados).
  - `flutter test` completo en verde; `flutter analyze` sin incidencias.
  - Fila 015 y designer actualizados.
- **Cierre**: `flutter test` + `flutter analyze` en verde. **Fin de la
  spec 015.**

## Preguntas abiertas que bloquean decisiones de UI (no de código base)
- Q-1: sustitución total vs. convivencia con `ExerciseDetailView`
  (decisión provisional: sustituir; T-008 la confirma).
- Q-3: heurística de activación 70/30 aceptada (T-005 la implementa;
  reversible a «sin porcentajes» con un cambio de presentación).
- Q-4/Q-5: «añadir a rutina» y filtros del historial → v2.
