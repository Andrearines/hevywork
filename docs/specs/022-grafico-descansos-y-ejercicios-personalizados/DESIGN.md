# DESIGN — Spec 022

**Estado: APROBADO explícitamente por el usuario el 2026-11-23 (D-117).**
**Slug:** `022-grafico-descansos-y-ejercicios-personalizados`.
**Alcance:** inventario incremental; no sustituye los mockups ni reabre las specs
020 o 021. La 021 permanece cerrada y aprobada.

> Q-006 está cerrada. El usuario respondió «aprovado» a la pregunta que pedía
> responder «Apruebo el diseño 022 completo» o indicar cambios; se registra como
> aprobación explícita del DESIGN completo, sin cambios. La afirmación anterior de
> una aprobación el 2026-11-21 era incorrecta y no se conserva como histórico.

## 0. Decisiones confirmadas

- **D-111:** al editar el descanso desde una tarjeta live se aplica la opción C:
  cambian tanto el predeterminado del ejercicio como el countdown activo, con
  efecto inmediato.
- **D-112:** se puede editar objetivo y secundarios de cualquier ejercicio,
  incluido el catálogo; el catálogo conserva una restauración reversible.
- **D-113:** un personalizado puede usar imagen de galería o cámara, o quedarse
  sin imagen con placeholder; sus datos e imagen se sincronizan.
- **D-114 (histórica, superada por D-117):** recogió el estado previo en que los
  puntos 1–7 todavía no estaban confirmados. Ya no representa el estado vigente.
- **D-117:** aprueba el DESIGN completo sin cambios, incluidos: timers
  independientes y simultáneos; sincronización del predeterminado y del countdown;
  `ThumbFallback` con mancuerna; campos obligatorios y descanso inicial de 90 s;
  fechas reales y frecuencia sin `0x / semana` falsa; estados/reintento en Perfil;
  derivación de `muscle_group` y paginación de 50.

La aprobación autoriza la planificación técnica y las tareas, no una aprobación de
implementación: cada tarea conserva su puerta de tests, analyze y revisión.

## 1. Referencias y tokens

Se conservan Obsidian Kinetic y los tokens de `docs/DESIGN.md`: superficies
planas, `surface`/`surface-1`/`surface-2`, bordes `tonal-border`, Geist y Space
Grotesk, radios 8/16/24, targets táctiles de al menos 44 dp, margen 16 dp y
contenido centrado con máximo 640 dp desde tablet. No se añaden colores,
fuentes, assets de placeholder, dependencias, `elevation` ni `BoxShadow`.

La ficha y el gráfico conservan su estructura vigente: la 022 corrige datos,
geometría y controles, no ejecuta el rediseño completo pendiente de la 020.

## 2. Inventario y trazabilidad de pantallas

| SCR | Pantalla/componente | Entrada y propósito | Cambio de la 022 |
|---|---|---|---|
| SCR-03 | `LiveWorkoutView`, tarjeta de cada ejercicio | Sesión activa | Una cuenta atrás independiente dentro de cada tarjeta; varias pueden coexistir. Controles de duración, pausa/reanudación y salto asociados al `workoutExerciseId`. |
| SCR-05 | `ProfileView`, estado de sincronización | Ajustes de cuenta | Estado pendiente/error/última sincronización y acción de reintento de `dead_letter`; no se expone diagnóstico técnico ni secretos. |
| SCR-06 | `ExerciseInfoView` | Ficha de catálogo o personalizado | Gráfico cronológico corregido, descanso persistente, imagen estática personalizada y acceso a «Editar músculos»/«Restaurar originales». |
| SCR-07 | `CatalogView` y selector de ejercicios | Catálogo/buscador | Acción primaria «Crear ejercicio»; personalizados integrados en búsqueda, filtros y paginación con miniatura propia o placeholder. |
| SCR-08 | `CustomExerciseEditorView` | `/catalog/custom/new` y `/catalog/custom/:id/edit` | Alta/edición completa de personalizados e imagen desde galería/cámara. |
| SCR-09 | Editor muscular modal desde SCR-06 | Ficha de cualquier ejercicio | Edita objetivo y secundarios; para catálogo guarda un override reversible y permite restaurar sin borrar otros ajustes. |

SCR-01, SCR-02 y SCR-04 solo reciben efectos de datos ya previstos —nombres,
filtros, historial y fatiga— sin cambios de composición.

## 3. SCR-03 — Descansos independientes en vivo

- Cada tarjeta expandida muestra su módulo solo si su descanso está corriendo,
  en pausa o terminado. Dos o más tarjetas pueden mostrarlo simultáneamente.
- El título incluye «DESCANSO» y el nombre del ejercicio; el tiempo usa
  `tabular-nums`. Controles: `−15 s`, `+15 s`, `+30 s`, pausar/reanudar y saltar.
- `−15/+15/+30` aplican el mismo delta al tiempo restante y al descanso
  predeterminado del ejercicio; no copian el tiempo restante como predeterminado.
- Pausar/reanudar/saltar no cambia el predeterminado. El predeterminado queda
  entre 15 y 300 s; el tiempo restante puede llegar a cero.
- La antigua píldora global no representa varios timers y desaparece para el
  nuevo modelo. Solo se conserva como fallback de un timer legacy sin ejercicio
  asociado hasta que termine, se salte o comience uno nuevo.
- La replicación del countdown activo y del descanso predeterminado entre
  dispositivos queda aprobada por D-117. El contrato vigente previo a la 022 los
  mantiene locales y `sync_payload.dart` los descarta; T-006 amplía ese contrato
  mediante la migración y las reglas de sync congeladas en `docs/db.md`.
- Estados: sin descanso (módulo oculto), corriendo, pausa, listo, pendiente de
  sincronizar y error de sync (aviso discreto, sin detener el countdown).

## 4. SCR-05 — Sincronización comprensible

- La sección de cuenta distingue «Sin cuenta», «Pendiente», «Sincronizando»,
  «Actualizado» y «Necesita atención».
- Un fallo de claim, subida, descarga o Storage conserva los datos locales y
  muestra un mensaje breve en español; nunca presenta la cuenta como enlazada y
  al día cuando el claim no terminó.
- «Reintentar sincronización» reactiva los elementos `dead_letter` sin borrar
  datos. El estado no incluye SQL, tokens ni stack traces.

## 5. SCR-06 — Ficha, gráfico y músculos

### Gráfico

- Con dos o más puntos, las fechas aumentan de izquierda a derecha y todos los
  nodos quedan dentro del ancho/alto real del `CustomPaint`.
- Los puntos se distribuyen por índice cronológico entre el primer y último
  borde útil; el área y el punto destacado terminan en el último punto real.
- El eje inferior muestra fechas de puntos representativos (`dd/MM`, y año si
  hace falta), no las etiquetas fijas `1M/3M/6M/<ventana>`. Como máximo cuatro
  etiquetas, sin duplicados ni overflow a 320 dp.
- El delta conserva su signo. En «Todo» no se muestra una frecuencia falsa de
  `0x / semana`. Los estados de cero/un punto conservan el mensaje vacío actual.

### Descanso y media

- El stepper existente `rest-detail-*` mantiene ±15 s y rango 15–300 s, pero su
  valor sobrevive a reabrir y se sincroniza. No crea ni modifica un countdown
  desde esta pantalla.
- Un personalizado sin GIF muestra su imagen estática; sin imagen usa el
  `ThumbFallback` aprobado por D-117: fondo tonal e icono de mancuerna. No se muestra una
  atribución inexistente y las instrucciones vacías tienen estado explícito.

### Edición muscular

- Acción secundaria «Editar músculos», disponible para catálogo y personalizados.
- En catálogo con override se muestra «Personalizado» y la acción «Restaurar
  originales». Restaurar afecta solo a objetivo/secundarios; conserva el
  descanso, la imagen y el historial.

## 6. SCR-07 — Catálogo extensible

- «Crear ejercicio» es visible sin desplazar la búsqueda y mantiene el CTA de
  entreno libre. En 320 dp no se superpone con filtros ni resultados.
- Las filas conservan nombre, objetivo, equipo y miniatura de 48 dp. Los
  personalizados no necesitan un badge saturado; basta un indicador discreto
  «Personalizado» cuando aporte contexto.
- Altas, ediciones, overrides y restauraciones invalidan resultados/opciones de
  filtros sin perder la consulta activa. La paginación sigue siendo de 50.

## 7. SCR-08 — Editor completo de ejercicio personalizado

### Composición

1. App bar con volver y título «Crear ejercicio»/«Editar ejercicio».
2. Vista previa 16:9 con imagen propia o mancuerna; acciones «Galería»,
   «Cámara» y, si hay imagen, «Quitar imagen».
3. Nombre (obligatorio).
4. Objetivo (obligatorio, selección simple con vocabulario muscular conocido).
5. Secundarios (opcional, selección múltiple sin duplicados).
6. Equipo y parte del cuerpo (obligatorios, texto recortado; se ofrecen valores
   existentes como sugerencia sin impedir un valor nuevo).
7. Descanso inicial obligatorio, 15–300 s y 90 s al crear. El rango y el valor se
   heredan de la spec 002 y su aplicación a este formulario queda confirmada por
   D-117.
8. CTA primario «Guardar ejercicio»; en edición, «Guardar cambios».

### Estados

- **Sin imagen:** `ThumbFallback` aprobado; no bloquea guardar.
- **Cargando imagen:** indicador dentro de la vista previa, formulario usable.
- **Permiso denegado/cámara no disponible/archivo inválido:** mensaje en español,
  se conserva el borrador y la imagen anterior.
- **Guardando:** CTA bloqueado para evitar duplicados; escritura local primero.
- **Pendiente/offline:** alta disponible de inmediato y aviso «Se sincronizará
  cuando haya conexión».
- **Error de sync posterior:** el ejercicio sigue disponible; se refleja en
  SCR-05 y la cola, sin convertir el guardado local en error.
- **Validación:** errores junto al campo; no se pierde la selección muscular.

## 8. SCR-09 — Editor muscular y restauración

- Bottom sheet o pantalla modal con título «Editar músculos», selector simple de
  objetivo y selector múltiple de secundarios; CTA «Guardar» y «Cancelar».
- Se usan valores reconocidos por los aliases de fatiga/filtros. No se permite
  un secundario exactamente duplicado ni uno equivalente al objetivo canónico.
- `muscle_group` se deriva del primer secundario; si no hay secundarios, se usa
  el objetivo para mantener un valor filtrable no vacío.
- En catálogo, «Restaurar originales» pide confirmación e indica que solo se
  revertirá la personalización muscular. En personalizados no se muestra una
  restauración de catálogo inexistente.
- Tras guardar/restaurar/descargar un cambio se actualizan ficha, filtros,
  referencias históricas y caché de fatiga; las series y cargas no se editan.

## 9. Responsive, accesibilidad y validación visual

- Verificación funcional a 320, 375, 640 y 1024 dp, con `textScaler` hasta 1.3.
- Selectores con semántica de selección, labels para iconos, contraste AA y
  targets ≥44 dp aunque el icono visual sea menor.
- No se añaden goldens. Las regresiones son unitarias/widget/integración y las
  comprobaciones geométricas del gráfico no dependen de PNG.
- La política vigente se mantiene: `flutter test --exclude-tags golden` y
  `flutter analyze`; ningún PNG existente se edita o regenera por esta spec.
