# Spec 006 — Peso y medidas corporales

## Contexto y objetivo
Registro histórico de peso corporal y circunferencias para correlacionar con
entrenamiento y metas.

## Usuarios
Mismo perfil.

## Historias de usuario
- H1: Como usuario quiero pesarme cada mañana y ver la tendencia.
- H2: Como usuario quiero medir brazos, cintura, muslos, pecho y ver deltas.

## Requisitos funcionales (EARS)

### Registro (H1, H2)
- RF-1: CUANDO el usuario añade un registro, EL SISTEMA guarda `body_metric`
  con `date`, `weight_kg` (nullable), `measures_json` (mapa
  `muscle_group → cm`, nullable), `notes`.
- RF-2: EL SISTEMA permite editar/borrar registros del mismo día (idempotente
  por `date + user_id`).

### Visualización
- RF-3: EL SISTEMA muestra gráfica de peso (línea, 30/90/365 días) y tabla
  de medidas con Δ vs registro anterior.

### Unidades globales (amenda T-16, decisión 2026-10-16)
- RF-4: EL SISTEMA presenta peso y medidas en la unidad global del perfil
  (spec 008, RF-29): `lb`/`in` en imperial y `kg`/`cm` en métrico. La
  conversión se aplica tanto al mostrar (tarjeta de peso, tendencia,
  registros, deltas, medidas y evolución) como al editar en el editor de
  registro. `kg` y `cm` siguen siendo siempre la base de almacenamiento: la
  entrada en imperial se convierte al guardar.

## Requisitos no funcionales
- Datos sincronizan igual que workouts.

## Casos límite
- Dos registros mismo día → el último gana (upsert por `date`).
- Peso en lb → conversión a kg al guardar, lb solo al mostrar.

## Fuera de alcance
- ~~Fotos de progreso y impedancia bioeléctrica / % grasa.~~ **Reasignados a
  la spec 009** (fotos de progreso y composición corporal) por la decisión de
  la tanda del rediseño. Esta spec mantiene peso y medidas.

## Criterios de finalización
- Tests de upsert, gráfica y deltas.
- `flutter test` + `flutter analyze` verdes.

## Decisiones arquitectónicas (Cerradas)
- **Medidas:** Se guardarán valores absolutos en `cm` de todas las medidas principales (Cuello, Pecho, Brazo, Cintura, Pierna/Muslo, Pantorrilla, Glúteos). Los deltas (crecimiento/pérdida) se calcularán on-the-fly en la vista. La medida de glúteos (id `hip`, amenda 2026-10-18) alimenta la ecuación femenina del método US Navy de la spec 009.

## Decisiones de la tanda (aprobadas por el usuario)
- **Tabla única `body_metrics`:** en vez de ampliar `body_weight` (005), se
  crea un único registro diario `body_metrics` con `weight_kg` (nullable),
  `measures_json` (mapa `medida → cm`) y `notes`. La migración 0007 consolida
  los pesos previos de `body_weight` (una fila por `(user, día)`) y descarta la
  tabla. `body_weight` queda fuera del esquema local y remoto.
- **Editar/borrar cualquier registro** (RF-2): no solo el del día de hoy;
  la PK compuesta `(local_user_id, date)` hace el upsert por fecha (el último
  del día gana).
- **UI:** sección «Peso y medidas» dentro del tab Progreso, bajo las metas:
  tarjeta de tendencia (sparkline) con chips 30/90/365 días, botón
  «Añadir registro» y tarjetas de registro con Δ frente al registro anterior,
  con acciones Editar/Borrar. Sin nueva navegación.
- **Sparkline con `CustomPainter`** (sin dependencias): línea `onSurface`
  2.2 dp, área con gradiente blanco, guías punteadas, puntos intermedios
  `outline` y punto final `primary` con stroke `surface` (designer §7.9).
  Con menos de dos mediciones muestra «Registra tu peso para ver la tendencia».
- **Medidas fijas** en orden `neck, chest, arm, waist, thigh, calf, hip` con
  etiquetas Cuello, Pecho, Brazo, Cintura, Pierna, Pantorrilla, Glúteos
  (amenda 2026-10-18); el delta de
  cada medida se calcula contra el registro cronológico anterior (RF-3).
- **Peso opcional:** un registro puede tener solo medidas (o solo notas), pero
  hace falta al menos uno de los tres para guardar (RF-1).
- **Fechas:** `date` se normaliza a la medianoche local (`dayOf`) para
  conservar el día civil en el almacenamiento local (drift lee `DateTime`
  local).
- **Sincronización por fecha:** el push de `body_metrics` elimina por
  `.eq('user_id').eq('date')` y hace upsert con `onConflict: 'user_id, date'`;
  el resto de tablas sigue con `id` (RF-11).
- **Recálculo de metas:** se dispara al guardar o borrar un registro
  (`goalRepository.recalculate()`); `BodyMetricRepository` es el único
  escritor de `body_metrics` y `GoalRepository` solo lee (baseline y recálculo).
  Las metas de peso saltan registros sin peso (`weight_kg` nullable).