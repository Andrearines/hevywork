# Hoja de ruta de specs — hevywork

Orden de implementación. Cada spec debe cumplir la constitución y cerrar con
`flutter test` + `flutter analyze` en verde antes de pasar a la siguiente.

| Spec | Título | Estado | Decisiones clave |
|---|---|---|---|
| 001 | Catálogo local + sesión + sync | **núcleo ✅** | drift local, Postgres remoto, RLS, cola sync, server `updated_at`, 1 sesión activa. Abiertos: login en UI (RF-16) y reanudación de cola (RF-12). Esquema local/remoto alineado (2026-10-20) |
| 002 | Editor de sesión | **✅** | deshacer, editar, timer descanso (notif. local aprobada §2), reanudar tras cierre |
| 003 | Buscador de ejercicios | **✅** | búsqueda ≥ 2 car., acentos ignorados, filtros OR dentro/AND entre, páginas de 50 al 80 % del scroll |
| 004 | Rutinas y plantillas | **✅** | plantilla; criterio serie+reps+RIR, aceptar actualiza la rutina, switch `auto_progress` por ejercicio |
| 005 | Objetivos y metas | **✅** | tipos peso/fuerza/volumen/constancia; peso corporal en la 005; dirección por baseline; recálculo al cerrar sesión y al abrir; notificación in-app (snackbar + banner) |
| 006 | Peso y medidas corporales | **✅** | registro diario por (usuario, día); 17 zonas canónicas en cm; peso opcional; historial y Δ en pantalla propia |
| 007 | Mapa muscular de fatiga | **✅** | 17 zonas canónicas normalizadas; `muscle_mapper`; fatiga cruda y normalizada; secundarios con suelo «Óptimo»; recuperación a 3 días |
| 008 | Rediseño de UI + Perfil | **✅** | fidelidad a Stitch salvo sombras (sin `elevation`/`BoxShadow`), nav pill flotante, `ProfileView` y ajustes, shell y estados vacíos de 009–011 |
| 009 | Progreso: fotos y composición | **✅** | composición con US Navy (0009), bucket privado `progress-photos` y tabla (0010), `image_picker`, editor y grid con Δ |
| 010 | Plantillas comunitarias | **✅** | catálogo público de solo lectura (0011) con `template_days`; seed de 6 programas; importar clonando (una rutina o una por día); cache drift v16 |
| 011 | Integraciones: dispositivos y HRV | pendiente | BLE (`flutter_blue_plus`) + HRV (`health`), `health_metrics` (0012) |
| 012 | Registro de entrenamientos pasados | **✅** | sesión `finished` creada directamente con fecha/hora/duración; origen rutina o manual; sin migración; recálculo fatiga+metas (2026-10-25) |
| 013 | Perfil: foto de perfil y ajustes de vista | **en curso** | bucket público `profile-photos` + `profiles.avatar_url` (drift v18); récords con pestañas «Este mes»/«Histórico»; borrado individual y masivo de fotos; objetivos con scroll interno (2026-10-26) |
| 015 | Ficha de información del ejercicio | ✅ | sustituye a `ExerciseDetailView` con `ExerciseInfoView`; KPIs + gráfico de progresión con CustomPainter; historial paginado; CTA a sesión activa/nueva; sin dependencias ni migraciones |
