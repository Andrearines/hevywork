# Constitución — hevywork

Principios de obligado cumplimiento en todo el trabajo del proyecto. Derivada
de `AGENTS.md`; si ambas difieren, manda `AGENTS.md`.

## 1. Diseño visual
- Minimalismo tipo Apple: superficies planas, sin `elevation` ni `BoxShadow`.
  La jerarquía se construye con tipografía, espacio y bordes hairline.
- El mapa muscular se dibuja siempre con vectores (`CustomPainter`), nunca
  con imágenes.
- Dark-mode-first; la escala de fatiga va de frío a rojo.

## 2. Código
- Identificadores y código en inglés; mensajes al usuario y documentación en
  español.
- Sin comentarios en el código.
- No se añaden dependencias: la lista vigente es cerrada.

## 3. Datos
- Pesos en kg en la base de datos; la conversión a lb solo ocurre al mostrar.
- El esquema remoto solo cambia por migración en `supabase/migrations/`, una
  por tarea; el local, por la `schemaVersion` de drift.
- Toda tabla de Postgres necesita RLS y `user_id`; toda tabla de drift
  necesita `local_user_id`.

## 4. Proceso
- La spec activa (en `docs/specs/`) manda sobre cualquier otra fuente.
- No se toca lo que la spec no pide.
- Al terminar cualquier tarea: `flutter test` en verde y `flutter analyze`
  sin incidencias. Si no pasa, la tarea no está terminada.
- No se commitea nada sin orden expresa.
