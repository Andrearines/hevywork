# Spec 010 — Plantillas comunitarias

## Contexto y objetivo
Permitir descubrir programas de entrenamiento verificados (plantillas
públicas) e **importarlos** como rutina propia, reutilizando el modelo de
rutinas de la spec 004.

## Usuarios
Mismo perfil.

## Historias de usuario
- H1: Como usuario quiero explorar programas de entrenamiento y ver su
  detalle (semanas, días, ejercicios y objetivo).
- H2: Como usuario quiero importar una plantilla y que se convierta en mi
  rutina editable.

## Requisitos funcionales (EARS)

### Catálogo de plantillas (H1)
- RF-1: EL SISTEMA crea las tablas `templates`, `template_days`,
  `template_exercises` y `template_sets` (`0011_community_templates.sql`) con
  contenido **público de lectura**: `select` para todos los usuarios, sin
  `insert/update/delete` de cliente.
- RF-2: EL SISTEMA siembra un conjunto curado de programas verificados en la
  migración (idempotente, `on conflict do nothing`).
- RF-3: EL SISTEMA muestra un navegador de plantillas con
  `TemplateRepository`: listado por categoría/nivel, búsqueda por nombre y
  detalle (descripción, objetivo, semanas, desglose de días y ejercicios).
- RF-4: EL SISTEMA enlaza la tarjeta «Explorar plantillas» de Rutinas
  (spec 008) con el navegador.

### Importar (H2)
- RF-5: CUANDO el usuario pulsa «Usar esta plantilla», EL SISTEMA crea una
  `routine` propia (`local_user_id`, nuevos UUID) clonando
  `template_exercises`/`template_sets` con `order_index` y objetivos. Si la
  plantilla es un programa de varios días, crea una rutina por día con el
  nombre «Programa · Día».
- RF-6: EL SISTEMA consume la metadata de la plantilla (categoría, nivel,
  objetivo, `target_days`) en la rutina clonada (spec 008).
- RF-7: LA RUTINA importada es local-first y se sincroniza como cualquier
  rutina (spec 004/001); no mantiene vínculo vivo con la plantilla.

## Requisitos no funcionales
- Lectura de plantillas cacheada para funcionar sin conexión tras una
  primera carga.
- Sin escritura de usuario en las tablas de plantillas.

## Casos límite
- Sin conexión y sin caché → mensaje «Conéctate para ver las plantillas».
- Plantilla con ejercicio que ya no está en el catálogo → se omite ese
  ejercicio y se avisa.

## Fuera de alcance (010)
- Publicar/compartir rutinas propias (solo lectura de curaduría).
- Moderación, valoraciones y comentarios.

## Criterios de finalización
- Tests de importación (clon correcto de ejercicios/series y metadata).
- `flutter test` + `flutter analyze` verdes.

## Decisiones arquitectónicas (Cerradas)
- Las plantillas son un **catálogo compartido de solo lectura**, no datos de
  usuario: RLS con política `select` pública y **sin** `user_id`, declarada
  como excepción a la constitución §4 (análoga al catálogo de ejercicios, que
  es local).
- Se importa clonando, no referenciando: la rutina del usuario es totalmente
  suya y editable.

## Dudas abiertas
- Ninguna: el seed inicial son **6 programas curados** (9 días, 58 ejercicios
  y 186 series) con IDs reales del catálogo; el modelo admite tanto sesiones
  sueltas como programas de varios días.

## Implementación (2026-10-20)
- Modelo híbrido: toda plantilla tiene `template_days`. Una plantilla de un
  día importa una rutina; un programa importa una rutina por día.
- Cache local en drift (`schemaVersion` 16) con `templates`,
  `template_days`, `template_exercises` y `template_sets`. `TemplateRepository
  .refresh()` sustituye la cache desde Postgres en una transacción y la
  navegación funciona sin conexión tras la primera carga.
- La importación omite los ejercicios que ya no están en el catálogo, los
  cuenta y avisa al usuario.
- UI: `TemplatesView` (búsqueda, chips por categoría) y `TemplateDetailView`
  (días, ejercicios con resumen de series y botón de importar). La tarjeta
  «Explorar plantillas» de Rutinas abre la biblioteca.
- Tests: `template_repository_test.dart` (cache, filtros, detalle, importación
  simple y multi-día) y `templates_view_test.dart` (catálogo, importación y
  estado sin conexión).
