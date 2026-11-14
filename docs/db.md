# db.md — estado de datos de hevywork

## Estado general
- **Local:** drift (SQLite) en `lib/data/local/database.dart`, `schemaVersion = 17`.
- **Remoto:** Supabase Postgres; migraciones en `supabase/migrations/`
  (una por tarea, con RLS + `user_id` en toda tabla remota).
- **Réplica/cola:** SQLite local es réplica de trabajo; Supabase es única
  fuente de verdad; sincronización por cola.
- **Unidades:** pesos en kg en base; conversión a lb solo al mostrar.

## Relación con specs previas
Esquema fijado por las specs 001 (núcleo/sync), 005 (metas), 006 (medidas
17 zonas), 009 (fotos progreso), 010 (plantillas), 011 (health_metrics),
013 (avatar `profiles.avatar_url`, drift v18 según README).

## Spec 020 — fidelidad-mockups
**Sin cambios de esquema.** La spec 020 es de UI pura: no añade tablas,
columnas, migraciones drift ni migraciones Supabase. Cualquier tarea que
requiriera tocar datos estaría fuera de su alcance.
