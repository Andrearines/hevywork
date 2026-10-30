# Spec 012 — Registro de entrenamientos pasados

## Contexto y objetivo
Permite registrar una sesión que ya se realizó en una fecha pasada para que
aparezca en el historial, el calendario y alimente la fatiga y las metas,
con el mismo formato de datos que una sesión cerrada en vivo.

## Usuarios
Mismo perfil.

## Historias de usuario
- H1: Como usuario quiero registrar rápido una sesión repetida eligiendo una
  rutina existente y la fecha en la que la hice.
- H2: Como usuario quiero añadir ejercicios manuales con sus series cuando
  la sesión no viene de ninguna rutina.

## Requisitos funcionales (EARS)

### Entrada
- RF-1: CUANDO el usuario pulsa «Registrar entrenamiento pasado», EL
  SISTEMA abre el editor de sesión pasada con la fecha por defecto de hoy.
- RF-2: CUANDO el origen elegido es una rutina, EL SISTEMA clona sus
  ejercicios y series al borrador con los valores planificados (kg, reps,
  RIR y tipo de serie) para que el usuario los ajuste antes de guardar.
- RF-3: CUANDO el origen es manual, EL SISTEMA abre el buscador del
  catálogo (spec 003) y precarga 3 series por ejercicio añadido.

### Guardado
- RF-4: CUANDO el usuario guarda, EL SISTEMA crea la sesión directamente
  con `status = 'finished'`, `started_at` = fecha + hora de inicio y
  `ended_at` = `started_at` + duración indicadas, y todas sus series con
  `completed = true`.
- RF-5: EL SISTEMA valida antes de guardar: al menos un ejercicio, al menos
  una serie por ejercicio, las reglas de la RF-7 de la 001 (tipo de serie
  admitido, reps ≥ 1, peso ≥ 0, RIR 0–10) y que la hora de inicio no sea
  futura.
- RF-6: CUANDO se guarda una sesión pasada, EL SISTEMA recalcula fatiga y
  metas, igual que al cerrar una sesión en vivo.
- RF-7: La sesión pasada queda sujeta a la inmutabilidad de la RF-4 de la
  002: no admite edición; para corregirla se borra del historial y se
  registra de nuevo.
- RF-8: EL SISTEMA sincroniza la sesión con las tablas y columnas
  existentes, sin migración ni columnas nuevas.

## Requisitos no funcionales
- Los pesos se guardan en kg y se muestran/entran en la unidad global del
  perfil (spec 008, RF-29).
- Una sola transacción para workout + ejercicios + series; la cola de
  sincronización se encola tras confirmar.

## Casos límite
- Fecha de hoy con hora futura → al elegir la fecha se ajusta la hora a la
  actual (redondeada a 5 min) y al guardar se valida.
- Ejercicio de la rutina fuera del catálogo → se omite, igual que en
  `startWorkoutFromRoutine`.
- Rutina sin ejercicios disponibles → mensaje y no se clona nada.
- Cambiar de rutina con borrador no vacío → confirmación antes de
  reemplazar.
- Borrador vacío al guardar → error accionable, no se crea nada.
- Varias sesiones el mismo día → permitidas, como en vivo.

## Fuera de alcance
- Editar el horario real de fin (`ended_at` se estima con la duración).
- Notas de sesión y selector de tipo de serie en la UI (el tipo se clona de
  la rutina o es `normal` en el origen manual).
- Borrado del formulario: el borrado de sesiones ya existe en el historial.

## Criterios de finalización
- Tests del repositorio (creación atómica, payload, validaciones) y del
  editor (validaciones, clonación desde rutina).
- `flutter test` + `flutter analyze` verdes.

## Decisiones (Cerradas) — 2026-10-25
- **Entrada:** el CTA existente del modo historial (`train_view.dart`)
  deja de abrir el diálogo «aún no disponible» y navega al editor.
- **Formulario a pantalla completa** (patrón `BodyMetricEditorView`): el
  volumen de ejercicios y series no cabe en un diálogo ni en un bottom
  sheet con scroll propio.
- **Cuándo:** fecha (hoy por defecto, `firstDate` 2000-01-01, `lastDate`
  hoy), hora de inicio (`showTimePicker`, 17:00 por defecto) y duración en
  minutos (`TextField` numérico, 60 por defecto, rango 1–720). Como el
  registro manual no conoce el horario real, hora y duración son
  estimaciones editables; el día civil del `ended_at` es el que muestran
  historial, calendario y rachas.
- **Origen dual:** rutina existente (bottom sheet con `watchRoutines`;
  clona con `routineSetId` y copia `routine.name` a `workouts.name`) o
  manual (picker del catálogo, `routineSetId` nulo, nombre nulo).
- **Series:** la UI edita kg, reps y RIR; el tipo de serie se clona de la
  rutina o nace `normal`. Sin descanso (no aplica tras cerrar) ni
  progresión automática.
- **Sin migración:** no hay columnas nuevas; `started_at`, `ended_at`,
  `routine_id`, `name` y `routine_set_id` ya existen en local y remoto.
- **Efectos:** tras guardar se llama a `fatigueRepository.recalculate()` y
  `goalRepository.recalculate()`; el resto (feed, «series previas»,
  calendario, racha) ya lee por `ended_at` y no necesita cambios.
