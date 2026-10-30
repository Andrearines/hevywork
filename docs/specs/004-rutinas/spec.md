# Spec 004 — Rutinas y plantillas

## Contexto y objetivo
El usuario quiere definir una rutina (plantilla de entrenamiento) y luego
instanciarla sesión a sesión, con progresión opcional.

## Usuarios
Mismo perfil.

## Historias de usuario
- H1: Como usuario quiero crear una rutina con ejercicios, series objetivo y
  orden.
- H2: Como usuario quiero "iniciar sesión desde rutina" y que se precarguen
  los ejercicios.
- H3: Como usuario quiero progresión automática (ej. +2.5 kg si logré todas
  las series objetivo la semana pasada).

## Requisitos funcionales (EARS)

### Plantillas (H1, H2)
- RF-1: CUANDO el usuario crea una rutina, EL SISTEMA guarda `routine`
  (nombre, descripción, `created_at`), `routine_exercises` (ejercicio,
  `order_index`, series_objetivo, reps_objetivo, RIR_objetivo, peso_sugerido).
- RF-2: CUANDO el usuario pulsa "Entrenar esta rutina", EL SISTEMA crea un
  `workout` con `routine_id` y clona los `routine_exercises` a
  `workout_exercises` con `target_sets`, `target_reps`, `target_rir`,
  `suggested_weight_kg`.

### Progresión (H3)
- RF-3: CUANDO se cierra una sesión nacida de una rutina, EL SISTEMA evalúa
  si se cumplieron los objetivos (todas las series objetivo completadas con
  RIR ≤ objetivo). SI sí, ENTONCES sugiere `peso_sugerido + 2.5 kg` para la
  próxima instancia (configurable por ejercicio).
- RF-4: EL USUARIO puede aceptar, ignorar o sobrescribir la sugerencia.

## Requisitos no funcionales
- Rutinas sincronizan igual que workouts (misma cola, mismo RLS).

## Casos límite
- Rutina sin ejercicios → no se puede iniciar.
- Ejercicio de la rutina borrado del catálogo local → aviso y opción de
  sustituir.

## Fuera de alcance
- Periodización compleja (mesociclos, deloads automáticos).
- Compartir rutinas entre usuarios.

## Criterios de finalización
- Tests de creación, instanciación.
- `flutter test` + `flutter analyze` verdes.

## Decisiones arquitectónicas (Cerradas)
- **Alcance de Rutinas:** Se enfoca en que el usuario cree sus propias plantillas personalizadas y elija los ejercicios, series y repeticiones a voluntad. La progresión es manual o basada en la sesión anterior, sin programas complejos automatizados.

## Decisiones aprobadas en la tanda (cerrando la duda "plantilla vs programa")
- **Criterio de "objetivo cumplido" (RF-3):** al menos `target_sets` series
  completadas sin contar los calentamientos, y cada una de las primeras
  `target_sets` series completadas con `reps >= target_reps` y
  `rir <= target_rir`. Las series extra sobre lo previsto no se evalúan.
- **Persistencia de la sugerencia (RF-4):** Aceptar escribe el nuevo peso en
  el `suggested_weight_kg` de la rutina (la progresión persiste semana a
  semana, H3); Ignorar no cambia nada; Sobrescribir guarda el valor que
  elija el usuario. La sugerencia se muestra en una hoja al cerrar la sesión
  nacida de la rutina, ejercicio por ejercicio.
- **Configuración por ejercicio (RF-3):** interruptor `auto_progress`
  (activo por defecto) en cada ejercicio de la rutina. Apagado, ese
  ejercicio nunca genera sugerencia (pesos fijos: máquinas, peso corporal...).