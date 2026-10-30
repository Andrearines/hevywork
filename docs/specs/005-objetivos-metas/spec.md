# Spec 005 — Objetivos y metas

## Contexto y objetivo
El usuario quiere fijar metas (peso corporal, fuerza, volumen, constancia)
y ver su progreso.

## Usuarios
Mismo perfil.

## Historias de usuario
- H1: Como usuario quiero poner "llegar a 80 kg en press de banca a 5 reps".
- H2: Como usuario quiero "entrenar 4 días/semana durante 3 meses".
- H3: Como usuario quiero ver un dashboard con mis metas y % de cumplimiento.

## Requisitos funcionales (EARS)

### Tipos de meta (H1, H2)
- RF-1: EL SISTEMA soporta metas de tipo: `bodyweight`, `strength` (e1RM en
  ejercicio concreto), `volume` (semanal/mensual por músculo/ejercicio),
  `consistency` (sesiones/semana).
- RF-2: CUANDO el usuario crea una meta, EL SISTEMA guarda `goal` con
  `type`, `target_value`, `deadline` (nullable), `metric_ref` (ejercicio_id
  o muscle_group), `status ∈ {active, achieved, abandoned}`.

### Seguimiento (H3)
- RF-3: MIENTRAS hay metas `active`, EL SISTEMA recalcula el progreso al
  cerrar cada sesión y al sincronizar.
- RF-4: CUANDO `current_value ≥ target_value` (o ≤ para pérdida de peso),
  EL SISTEMA marca `achieved` y notifica.

## Requisitos no funcionales
- Cálculo en background, < 200 ms por sesión cerrada.

## Casos límite
- Meta de fuerza con ejercicio que ya no está en el catálogo → meta
  inalcanzable, aviso.
- Plazo pasado sin lograr → `abandoned` automático.

## Fuera de alcance
- IA para sugerir metas realistas.
- Metas compartidas / retos entre amigos.

## Criterios de finalización
- Tests de tipos de meta, recálculo y transiciones de estado.
- `flutter test` + `flutter analyze` verdes.

## Decisiones arquitectónicas (Cerradas)
- **Alcance MVP:** Todos los tipos de metas descritos formarán parte de la versión inicial (Fuerza, Constancia, Volumen y Peso Corporal).

## Decisiones de la tanda (aprobadas por el usuario)
- **Peso corporal:** se incorporó a la 005 una tabla mínima `body_weight`
  (fecha + kg), local y remota; la dirección de la meta sale del punto de
  partida (`baseline` = último peso al crearla): objetivo menor que el inicio
  es pérdida, y se logra con `current ≤ target`; sin punto de partida se
  asume subir (RF-4). **Nota (spec 006):** `body_weight` fue consolidada en el
  registro diario `body_metrics` (peso + medidas + notas); las metas de peso
  siguen leyendo el último peso con `weight_kg` no nulo.
- **Constancia:** ventana móvil de 7 días (`kConsistencyWindowDays`);
  cuenta las sesiones completadas con `ended_at` dentro de la ventana.
- **Volumen:** `period ∈ {weekly, monthly}` solo para volumen, con ventanas
  de 7 y 30 días; suma `peso × reps` de las series completadas sin
  calentamientos y con dropsets al 50 % (mismo criterio que `WorkoutManager`).
- **Fuerza:** mejor e1RM histórico del ejercicio (series completadas, sin
  calentamientos), sin ventana temporal.
- **Recálculo:** `current_value` se persiste y se recalcula al cerrar sesión,
  al abrir la app / el tab Progreso y tras registrar peso. Los estados
  `achieved`/`abandoned` son definitivos (no se revierten al editar valores
  distintos; solo la edición explícita de la meta la reactiva).
- **Progreso de pérdida:** el % cierra la brecha desde `baseline`
  (`1 − (current − target) / (baseline − target)`), en vez de `current / target`.
- **Notificación (RF-4):** snackbar in-app al cerrar sesión («¡Meta lograda!»
  / «¡N metas logradas!») y banner «¡Metas logradas!» en el dashboard. Sin
  notificación del sistema.
- **Gestión:** crear + editar + borrar. Editar reactiva la meta (`status`
  vuelve a `active` y `current_value` a `null`) y refresca `baseline` en las
  de peso.