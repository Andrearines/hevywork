# AGENTS.md — hevywork

## Proyecto
App de entrenamiento en Flutter. El usuario registra entrenamientos
(rutinas, objetivos, peso, medidas corporales) y ve un mapa muscular
vectorial que se enroja en los músculos fatigados. Funciona sin conexión:
SQLite local (drift) como réplica de trabajo, Supabase Postgres como única
fuente de verdad, sincronización por cola. El catálogo de 1.324 ejercicios
es local y viene del asset de metadatos.

## Comandos
- Ejecutar: `flutter run`
- Tests: `flutter test`
- Análisis: `flutter analyze`
- Regenerar drift tras tocar una tabla: `dart run build_runner build --delete-conflicting-outputs`
- Regenerar el asset del catálogo tras actualizar el clon de `exercises-dataset/`: `dart run tool/build_catalog_asset.dart`

## Estilo y convenciones
- Minimalismo tipo Apple: superficies planas, sin `elevation` ni `BoxShadow`.
  Jerarquía por tipografía y espacio.
- El mapa de músculos se dibuja con vectores (`CustomPainter`), nunca con
  imágenes. La escala de fatiga va de frío a rojo.
- Código e identificadores en inglés; mensajes al usuario y docs en español.
- Pesos en kg en la base; conversión a lb solo al mostrar.

## Reglas
- Lee `docs/constitucion.md` y la spec activa en `docs/specs/` antes de tocar
  código. La spec manda.
- No añadas dependencias: la lista vigente está en el principio 2.
- El esquema remoto solo cambia por migración en `supabase/migrations/`, una
  por tarea. El local, por la `schemaVersion` de drift.
- Toda tabla de Postgres necesita RLS y `user_id`; toda tabla de drift
  necesita `local_user_id`.
- No toques lo que no te pide, ni introduzcas comentarios.
- No commitees nada sin que te lo pidan.

## Al terminar cualquier tarea
- `flutter test` en verde y `flutter analyze` sin incidencias. Si no pasa,
  la tarea no está terminada.