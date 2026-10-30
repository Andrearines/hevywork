# Spec 013 — Perfil: foto de perfil y ajustes de vista

## Contexto y objetivo
Cierra cuatro huecos que las specs 005, 008 y 009 dejaron sin cubrir: la
foto de perfil (que hoy es un icono fijo), los récords personales (que hoy
mezclan todos los tiempos sin filtro), el borrado de fotos de progreso (la
009 define borrar una foto pero no la UI ni el borrado masivo) y la sección
de objetivos (que hoy crece sin límite y empuja el resto de la pantalla).

## Usuarios
Mismo perfil.

## Historias de usuario
- H1: Como usuario quiero poner mi foto de perfil para reconocer mi cuenta
  al abrir la app.
- H2: Como usuario quiero ver primero los récords de este mes para saber
  cómo voy ahora, y poder consultar los de siempre.
- H3: Como usuario quiero borrar fotos de progreso (una o todas) cuando ya
  no las quiero conservar.
- H4: Como usuario quiero que la sección de objetivos ocupe un hueco
  fijo para encontrar el resto de secciones sin desplazarme mucho.

## Requisitos funcionales (EARS)

### Foto de perfil
- RF-1: CUANDO el usuario toca su avatar en la cabecera del Perfil, EL
  SISTEMA ofrece elegir entre cámara y galería (bottom sheet) y toma la
  imagen con `image_picker` comprimida a un máximo de 512 px por lado.
- RF-2: CUANDO la imagen está elegida y hay sesión iniciada, EL SISTEMA la
  sube al bucket `profile-photos` en la ruta `avatars/<auth.uid>.jpg`
  (sobrescribiendo la anterior) y guarda la URL pública en
  `local_profiles.avatar_url` y en la columna remota `profiles.avatar_url`
  a través de la cola de sync.
- RF-3: SI no hay sesión iniciada, ENTONCES no se abre el selector y se
  muestra el mensaje «Inicia sesión para subir tu foto».
- RF-4: EL SISTEMA muestra la foto con `NetworkImage` cuando hay URL y el
  icono de persona cuando no hay; si la URL falla al cargar, vuelve al
  icono sin romper la cabecera.
- RF-5: EL SISTEMA confirma con «Foto de perfil actualizada» al subir y con
  «No se pudo subir la foto» si falla; ninguna de las dos acciones bloquea
  la interfaz más allá de la propia subida.

### Récords personales
- RF-6: EL SISTEMA presenta la sección «Récords personales» del Perfil con
  dos pestañas: «Este mes» (activa por defecto) e «Histórico».
- RF-7: CUANDO la pestaña es «Este mes», EL SISTEMA muestra solo los
  récords cuya mejor marca se logró dentro del mes civil actual; si no hay
  ninguno, muestra «Sin récords este mes. Termina series para ver tus
  mejores marcas.».
- RF-8: CUANDO la pestaña es «Histórico», EL SISTEMA muestra el mejor
  registro de siempre por ejercicio, tal como lo calcula la spec 008.
- RF-9: EL SISTEMA calcula la fecha del récords desde `workouts.ended_at`
  de la serie que fija la marca; los conjuntos sin `ended_at` no entran en
  «Este mes».

### Fotos de progreso
- RF-10: CUANDO el usuario pide borrar una foto (desde el menú de la
  tarjeta o desde el visor a pantalla completa), EL SISTEMA pide
  confirmación y la elimina local, en Storage y en la tabla remota
  (implementación de la RF-10 de la 009).
- RF-11: CUANDO el usuario pulsa «Eliminar todo» en la cabecera de la
  sección de fotos, EL SISTEMA pide confirmación explícita y elimina todas
  las fotos de progreso del usuario (local, Storage y remoto).
- RF-12: SI no hay fotos, ENTONCES el botón «Eliminar todo» no se muestra.

### Objetivos
- RF-13: EL SISTEMA limita la sección de objetivos de Progreso y Perfil a
  un alto de hasta 3 tarjetas visibles; si hay más, la lista crece con
  scroll interno sin desplazar el resto de la pantalla.

### Visor de fotos
- RF-14: EL SISTEMA abre el visor en la foto exacta que se tocó y el
  contador «n / total» avanza al deslizar (corrección de la RF-8 de la
  009).

## Requisitos no funcionales
- La subida del avatar reutiliza `image_picker` (`imageQuality: 80`); no se
  añade ninguna dependencia.
- El bucket `profile-photos` es público de lectura (el avatar se muestra en
  la app sin URLs firmadas) y de escritura solo para el propio usuario en su
  carpeta `avatars/`.
- Contraste y objetivos táctiles ≥ 48 dp en pestañas, menús y botones
  (WCAG 2.2 AA).
- Los textos de la sección de récords caben sin desbordar con texto al 200 %.

## Casos límite
- Permiso de cámara/galería denegado → no se elige imagen; la app no crashea
  y el selector se puede reabrir.
- Subida sin red → el mensaje de error es claro; el avatar local queda como
  estaba (la URL solo se guarda tras subir con éxito).
- Mes con cambios de año (enero/diciembre) → el filtro usa año y mes
  civil, no un desplazamiento de 30 días.
- Mes vacío en «Este mes» → mensaje de estado vacío, sin lista en blanco.
- Borrar «todo» sin fotos → botón oculto (RF-12).
- Varias fotos el mismo día → el borrado masivo las elimina todas.

## Fuera de alcance (013)
- Recorte o edición de la foto de perfil (se usa tal cual la elige).
- Avatar en la sincronización de otros dispositivos más allá del payload
  `profiles`.
- Etiquetas o álbumes en las fotos de progreso.
- Cambios en el cálculo de e1RM o en la definición de récord.

## Criterios de finalización
- Tests del filtro mensual de récords (dominio puro), de las pestañas, del
  borrado individual y masivo de fotos y de la sección de objetivos
  limitada.
- Migración drift (`schemaVersion` 18) con test de upgrade y migración
  remota `supabase/migrations/` con el bucket y `profiles.avatar_url`.
- `flutter test` + `flutter analyze` verdes.

## Decisiones (Cerradas) — 2026-10-26
- **Spec nueva (013)** en lugar de ampliaciones repartidas: los cuatro
  cambios comparten pantalla (Perfil/Progreso) y una sola tarea de cierre.
- **Bucket nuevo `profile-photos`, público de lectura**, en vez de
  reutilizar el privado `progress-photos`: el avatar se muestra con
  `NetworkImage` y una URL firmada caducaría dejando la foto rota. La
  escritura sigue restringida a `avatars/<auth.uid>.jpg` por política de
  Storage.
- **`profiles.avatar_url`** se añade en la misma migración que el bucket
  (una migración por tarea, constitución §5) y viaja en el payload de sync
  existente; la columna local nace en `schemaVersion` 18.
- **Récords con pestañas** «Este mes» (activa por defecto) + «Histórico»:
  el filtro mensual no sustituye al histórico, lo ordena. El estado vacío
  de «Este mes» es propio y menciona el mes.
- **Fecha del récords = `ended_at`** del workout de la serie ganadora
  (mismo criterio que historial y racha); se añade `achievedAt` a
  `PersonalRecord` y `endedAt` a `LoggedSet` sin tocar esquema.
- **Borrado masivo con confirmación explícita** (nombre del botón
  «Eliminar todo») y botón ausente sin fotos; el borrado reutiliza la cola
  de sync de la 009, sin mecanismo nuevo.
- **Objetivos con alto máximo de 3 tarjetas** y scroll interno en la propia
  sección, en Progreso y Perfil; el resto de la pantalla no se desplaza al
  crecer la lista.
- **Visor corregido**: `PageController` con estado propio (no recreado en
  cada build), `initialPage` acotado al rango y contador en `onPageChanged`.
