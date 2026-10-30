# Spec 002 — Editor de sesión: deshacer, editar, timer y reanudar

## Contexto y objetivo
Una vez que el núcleo de registro funciona (001), el usuario necesita
corregir errores, pausar el descanso y no perder la sesión si la app se cierra.

## Usuarios
Mismo perfil que 001.

## Historias de usuario
- H1: Como usuario quiero deshacer la última serie si me equivoqué.
- H2: Como usuario quiero editar reps, peso o RIR de una serie ya confirmada
  antes de cerrar la sesión.
- H3: Como usuario quiero un temporizador de descanso configurable por
  ejercicio, con cuenta atrás y aviso sonoro/vibración.
- H4: Como usuario quiero que si la app se cierra (crash, cambio de app,
  pantalla bloqueada) al volver la sesión esté exactamente donde la dejé.

## Requisitos funcionales (EARS)

### Deshacer y editar (H1, H2)
- RF-1: CUANDO el usuario pulsa "Deshacer" y hay al menos una serie
  `completed = true` en la sesión actual, EL SISTEMA pone la última serie a
  `completed = false` y la deja editable (no la borra).
- RF-2: SI no hay series completadas, ENTONCES EL SISTEMA deshabilita el
  botón y muestra tooltip "Nada que deshacer".
- RF-3: CUANDO el usuario edita una serie (cambia reps, peso, RIR o tipo),
  EL SISTEMA valida los mismos rangos que RF-7 de la 001 y actualiza
  `updated_at` local + re-encola en `sync_queue`.
- RF-4: EL SISTEMA permite editar solo series de la sesión `active`. Series
  de sesiones `finished` o `abandoned` son inmutables.

### Temporizador de descanso (H3)
- RF-5: CUANDO el usuario completa una serie `normal`, `failure` o `drop`,
  EL SISTEMA inicia un timer con duración por defecto 90 s (configurable por
  ejercicio en ajustes, rango 15–300 s).
- RF-6: MIENTRAS el timer corre, EL SISTEMA muestra cuenta atrás en la UI
  principal de la sesión.
- RF-7: CUANDO el timer llega a 0, EL SISTEMA emite notificación local
  (sonido + vibración si el dispositivo lo soporta) y pasa a estado "listo".
- RF-8: EL USUARIO puede pausar, saltar o ajustar el timer en cualquier
  momento; los cambios se reflejan al instante.
  - Aprobación §2 (dependencias): `flutter_local_notifications` y
    `timezone` para la notificación local programada en background
    (caso límite "Timer en background → notificación local programada").
    El aviso en primer plano usa `SystemSound` + `HapticFeedback` del SDK
    de Flutter, sin dependencias.

### Reanudar sesión tras cierre (H4)
- RF-9: CUANDO la app se cierra con una sesión `active`, EL SISTEMA guarda
  un marcador `last_active_workout_id` en `local_profile`.
- RF-10: CUANDO la app arranca y existe `last_active_workout_id` con una
  sesión `active` sin `ended_at`, EL SISTEMA restaura esa sesión como la
  actual, con todas sus series y el timer en el tiempo restante si estaba
  corriendo.
- RF-11: SI el usuario confirma "Empezar nueva" en lugar de reanudar,
  ENTONCES la anterior pasa a `abandoned` (RF-19 de la 001).

### Borrar sesiones del historial (amenda T-14, decisión 2026-10-16)
- RF-12: CUANDO el usuario pulsa «Borrar» en una tarjeta del historial de
  Entrenar, EL SISTEMA pide confirmación; SI el usuario confirma, ENTONCES
  borra el workout con sus ejercicios y series en local, re-encola el
  borrado del workout en `sync_queue` (los hijos los elimina la cascada
  remota) y la sesión desaparece del feed. La sesión `active` no es
  borrable.

## Requisitos no funcionales
- Timer preciso a ±1 s aunque la app esté en background (usar `DateTime`
  anclado, no `Timer.periodic`).
- Deshacer/editar < 100 ms local.

## Casos límite
- Deshacer en cascada: el usuario puede deshacer varias series seguidas.
- Timer en background en iOS/Android → notificación local programada.
- Sesión `active` de hace > 7 días → al arrancar, la app pregunta si
  reanudar o abandonar (evita sesiones fantasma).

## Fuera de alcance
- Timer con fases (preparación, trabajo, recuperación).
- Historial de ediciones por serie (auditoría completa).

## Criterios de finalización
- Tests unitarios de deshacer/editar + timer + restauración.
- `flutter test` + `flutter analyze` verdes.
- Demo manual: cerrar app a mitad de sesión → reabrir → todo intacto.

## Dudas abiertas
- Ninguna heredada de 001.