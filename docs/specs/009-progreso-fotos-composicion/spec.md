# Spec 009 — Progreso: fotos y composición corporal

## Contexto y objetivo
Amplía la spec 006 (que excluía fotos e impedancia/% grasa) para incluir
**composición corporal** (% grasa, masa magra) y **fotos de progreso** en el
tab Progreso, tal como muestran los mockups.

Dependencia nueva aprobada: `image_picker` (constitución §2).

## Usuarios
Mismo perfil.

## Historias de usuario
- H1: Como usuario quiero registrar mi % de grasa y masa magra para ver su
  evolución.
- H2: Como usuario quiero guardar fotos de frente, perfil y espalda y
  compararlas en el tiempo.

## Requisitos funcionales (EARS)

### Composición corporal (H1)
- RF-1: EL SISTEMA añade a `body_metrics` las columnas nullable
  `body_fat_pct` (real) y `lean_mass_kg` (real), en drift y en Postgres
  (`0009_body_composition.sql`).
- RF-2: CUANDO el usuario introduce datos, EL SISTEMA los guarda en el mismo
  registro diario `(user, date)` de la 006 (upsert por fecha).
- RF-3: EL SISTEMA muestra un grid de composición con % grasa, masa magra y
  su Δ vs el registro anterior; sin datos, estado vacío.
- RF-4: SI hay báscula/caliper conectado (spec 011), ENTONCES el valor puede
  rellenarse desde el dispositivo; si no, entrada manual.

### Fotos de progreso (H2)
- RF-5: EL SISTEMA crea la tabla `progress_photos` (`id`, `user_id`, `date`,
  `view ∈ {front, side, back}`, `path`, timestamps) con RLS por `user_id`
  (`0010_progress_photos.sql`) y la tabla local equivalente con
  `local_user_id` para la cola de sync.
- RF-6: EL SISTEMA crea el bucket **privado** `progress-photos` en Supabase
  Storage, con políticas que limitan cada objeto a la carpeta del propio
  usuario (`[1] = auth.uid()::text`), límite de tamaño y `image/jpeg`.
- RF-7: CUANDO el usuario añade una foto, EL SISTEMA la toma/elige con
  `image_picker`, la comprime a JPEG, la guarda localmente y la encola para
  subir a Storage; sin red, queda visibilidad local y pendiente.
- RF-8: EL SISTEMA muestra un grid de 3 columnas (frente/perfil/espalda) con
  fecha, un comparador de dos fechas (antes/después) y zoom a pantalla
  completa.
- RF-9: EL SISTEMA cachea las fotos remotas en disco (mismo criterio que los
  GIFs del catálogo, constitución §3) para uso sin conexión.
- RF-10: CUANDO el usuario borra una foto, EL SISTEMA la elimina local, en
  Storage y en la tabla remota.

## Requisitos no funcionales
- Compresión: objetivo < 500 KB por foto subida.
- Subida en segundo plano; la UI nunca se bloquea.
- Permisos de cámara/galería gestionados con degradación elegante.

## Casos límite
- Permiso denegado → no se puede añadir foto; mensaje claro.
- Foto sin conexión → queda pendiente en la cola, no se pierde.
- Medida de grasa fuera de rango fisiológico (0–70 %) → validación.

## Fuera de alcance (009)
- Análisis automático de la foto (IA/segmentación).
- Impedancia real por BLE → cubierta como fuente en la spec 011.

## Criterios de finalización
- Tests de upsert con composición, deltas y cola de subida/borrado de fotos.
- Migración drift con test de upgrade.
- `flutter test` + `flutter analyze` verdes.

## Decisiones arquitectónicas (Cerradas)
- **Se revierte** el «Fuera de alcance» de la spec 006: fotos y composición
  pasan a estar dentro de alcance en esta spec.
- Bucket **privado** (a diferencia de `exercise-media`, que es público): las
  fotos son datos personales; acceso por RLS de Storage y `user_id`.
- Se reutiliza el registro diario `body_metrics`; no se crea tabla nueva para
  composición.
- **Implementación T-19 (2026-10-18):**
  - La compresión (< 500 KB) la delega `image_picker` (`imageQuality: 80`);
    no se añade ninguna dependencia de imagen.
  - La clave del objeto en el bucket es siempre `<auth.uid>/<id>.jpg`,
    derivada de `user_id` en el empuje de la cola y en la subida: el
    `local_user_id` local difiere del uid tras el claim (RPC 0009).
  - La cola de subida reutiliza el ciclo de sync: `SyncEngine`
    (`onCycleCompleted`) llama a `PhotoRepository.uploadPending()` en cada
    ciclo con sesión; un fallo deja la foto `pending` para el siguiente.
  - El borrado remoto (fila + objeto del bucket) se procesa al consumir la
    cola: funciona sin conexión (RF-10).
  - La tabla `progress_photos` existe también en drift (`schemaVersion` 14);
    `upload_status` (`pending`/`uploaded`) es local y no viaja al remoto.
  - UI del mockup: píldora comparadora con las dos fechas más recientes,
    grid de 3 columnas con la última foto por vista, visor a pantalla
    completa con zoom (`InteractiveViewer`) y comparador antes/después con
    selector de fechas.
- **Implementación T-21 (2026-10-20):**
  - `body_metrics` gana `body_fat_pct` y `lean_mass_kg` (drift
    `schemaVersion` 15 + `0009_body_composition.sql`); el editor permite
    ambos valores, con `%` validado entre 0 y 70 y masa magra > 0.
  - `local_profiles` gana `sex` (`male`/`female`) y `height_cm`; se editan
    en «Configuración de Atleta» (Perfil) y viajan en el payload de
    `profiles` (`sex`, `height_cm`).
  - La estimación US Navy vive en `lib/domain/body_composition.dart`
    (función pura, sin dependencias): hombres con cuello, cintura y altura;
    mujeres añaden cadera (medida `hip`). Sin sexo, altura o perímetros
    válidos no se estima; resultados fuera de 0–70 % se descartan.
  - El valor manual de % grasa manda; si falta, el grid muestra el estimado
    con la etiqueta «Estimado · US Navy». La masa magra manual manda; si
    falta, se deriva de peso y grasa.
  - El grid de composición muestra ambos valores y su Δ frente al registro
    anterior; sin datos conserva el estado vacío.

## Dudas abiertas
- Ninguna pendiente: la masa magra derivada usa `peso × (1 − %grasa/100)`
  (implementado y cubierto por tests).
