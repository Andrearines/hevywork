# Spec 022 — Gráfico, descansos y ejercicios personalizados

**Estado: APROBADA — DESIGN y alcance confirmados por el usuario el 2026-11-23.**
**Tarea inicial lista:** T-001. Las demás tareas están listas y ordenadas por
dependencias en `tasks.md`; ninguna está implementada ni aprobada todavía.

La spec 021 está cerrada y aprobada; esta petición nueva no la reabre ni cambia sus
criterios. Q-006 quedó cerrada por D-117. El diseño vinculante está en `DESIGN.md`
y los contratos de datos en `docs/db.md`.

## 1. Contexto y objetivo

La ficha de ejercicio todavía puede representar incorrectamente una serie
cronológica de más de cuatro puntos. Además, el descanso editado en la ficha no
sobrevive por sí solo a reabrir la pantalla y el ajuste live debe actualizar a la
vez el valor predeterminado y el countdown activo. El usuario quiere crear
personalizados con imagen propia o placeholder, editar músculos de cualquier
ejercicio con restauración y sincronizar los nuevos datos. También reporta que la
sincronización actual no funciona, sin aportar un síntoma más concreto.

El objetivo es corregir esos flujos sin perder datos locales, sin inventar una
causa para la avería de sincronización y manteniendo el trabajo offline.

## 2. Usuarios

Deportistas que entrenan offline, consultan su progresión, personalizan el
catálogo y pueden usar una cuenta en más de un dispositivo.

## 3. Decisiones de producto

- **D-111:** opción C para el descanso live: la edición desde la tarjeta cambia el
  predeterminado y el countdown activo, con efecto inmediato.
- **D-112:** objetivo y secundarios son editables en cualquier ejercicio; para
  catálogo existe una restauración reversible de los valores originales.
- **D-113:** el personalizado admite galería, cámara o ausencia de imagen con
  placeholder; sus datos e imagen se sincronizan.
- **D-114 (histórica, superada por D-117):** recogió el estado previo de los
  puntos 1–7 cuando aún eran propuestas. No describe el alcance vigente.
- **D-117:** el usuario respondió «aprovado» a la pregunta que pedía «Apruebo el
  diseño 022 completo» o cambios. Se registra como aprobación explícita del DESIGN
  completo, sin cambios, el 2026-11-23.

D-117 confirma expresamente los siete puntos que estaban pendientes:

1. Timers independientes por ejercicio, varios countdown simultáneos, retirada de
   la píldora global salvo fallback legacy y controles del módulo descritos en SCR-03.
2. Sincronización remota del descanso predeterminado y del countdown activo.
3. Placeholder tonal con mancuerna de `ThumbFallback`, sin asset nuevo.
4. Nombre, objetivo, equipo y parte del cuerpo obligatorios; secundarios
   opcionales; descanso inicial de 90 s y rango 15–300 s.
5. Fechas reales en el eje, como máximo cuatro etiquetas sin overflow, y ninguna
   frecuencia `0x / semana` falsa en «Todo».
6. Estados de sincronización y reintento de `dead_letter` en Perfil.
7. `muscle_group` derivado del primer secundario canónico, u objetivo si no hay
   secundarios, y paginación de catálogo de 50 elementos.

## 4. Historias de usuario y pantallas

| US | Historia | SCR |
|---|---|---|
| US-01 | Como usuario quiero que el gráfico represente todos mis puntos en orden y dentro del lienzo para interpretar mi progresión. | SCR-06 |
| US-02 | Como usuario quiero conservar mi descanso y que el ajuste live actualice predeterminado y countdown para no repetir cambios. | SCR-03, SCR-06 |
| US-03 | Como usuario quiero crear personalizados con o sin imagen y encontrarlos en el catálogo para usarlos como cualquier otro ejercicio. | SCR-06, SCR-07, SCR-08 |
| US-04 | Como usuario quiero corregir objetivo/secundarios de cualquier ejercicio y restaurar el catálogo para controlar filtros y fatiga sin perder historial. | SCR-06, SCR-09 |
| US-05 | Como usuario quiero que la sincronización actual y la de mis personalizados conserven mis cambios entre dispositivos. | SCR-05 y efectos de datos en SCR-03/06/07/08/09 |

SCR-01, SCR-02 y SCR-04 solo reciben efectos de datos. No se rediseñan por esta
spec.

## 5. Requisitos funcionales

### Gráfico

- **FR-01:** CUANDO el gráfico recibe dos o más puntos válidos, incluidos más de
  cuatro, EL SISTEMA representa un nodo por punto en orden cronológico creciente,
  con posiciones horizontales estrictamente crecientes dentro del ancho real del
  lienzo; el área y el punto destacado terminan en el último punto real.
- **FR-02:** CUANDO el último valor es menor que el primero, EL SISTEMA conserva
  el signo negativo del delta; las correcciones no alteran los puntos calculados
  por el dominio ni las ventanas ya aprobadas en la 021.
- **FR-15:** EL SISTEMA etiqueta el eje con fechas de puntos representativos en
  `dd/MM`, añadiendo año cuando sea necesario, con un máximo de cuatro etiquetas,
  sin duplicados ni overflow a 320 dp. CUANDO la ventana «Todo» produzca una
  frecuencia cero por carecer de una ventana temporal finita, EL SISTEMA oculta ese
  insight en lugar de mostrar `0x / semana`.

### Descanso

- **FR-03:** CUANDO el usuario cambia el descanso en `ExerciseInfoView`, cierra y
  vuelve a abrir la ficha, EL SISTEMA recupera el valor guardado para ese
  ejercicio. La escritura es local primero y no inicia un countdown.
- **FR-04:** CUANDO el usuario edita el descanso desde una tarjeta live con un
  countdown activo o en pausa, EL SISTEMA aplica la opción C: persiste el nuevo
  predeterminado y ajusta el countdown visible sin esperar otra serie ni reabrir
  la sesión. Pausar, reanudar o saltar no cambia el predeterminado.
- **FR-11:** CADA tarjeta de ejercicio de una sesión activa mantiene su propio
  countdown asociado a `workoutExerciseId`; varios pueden coexistir. El timer
  global anterior solo sobrevive como fallback legacy hasta terminar, saltarse o
  iniciarse un timer asociado. Los controles `−15/+15/+30` aplican al restante el
  delta realmente aplicado al predeterminado tras limitar este a 15–300 s; el
  restante nunca es negativo.
- **FR-12:** CUANDO existe una cuenta sincronizable, EL SISTEMA propaga entre
  dispositivos el descanso predeterminado y el estado del countdown asociado
  (`endsAt` o pausa), sin confundirlo con el `rest_seconds` planificado de una
  serie. La UI local responde de inmediato y no espera la réplica.

### Personalizados e imagen

- **FR-05:** CUANDO el usuario guarda un ejercicio personalizado válido, EL
  SISTEMA lo conserva localmente y lo hace utilizable en catálogo, búsqueda y
  selección de ejercicios, también sin conexión.
- **FR-06:** CUANDO el usuario crea o edita un personalizado, EL SISTEMA permite
  elegir imagen de galería o cámara, conservar el borrador si el permiso/archivo
  falla y guardar sin imagen. La imagen es estática, privada y no sustituye los
  GIF/miniaturas del catálogo maestro.
- **FR-07:** CUANDO existe una cuenta sincronizable, EL SISTEMA propaga los datos
  e imágenes de los personalizados sin convertir el guardado local en un error;
  MIENTRAS no hay conexión, conserva el trabajo local y su intención de subida.
- **FR-13:** CUANDO un personalizado no tiene imagen o esta todavía no está
  disponible en el dispositivo, EL SISTEMA muestra `ThumbFallback` con fondo tonal
  e icono de mancuerna, sin crear un asset ni mostrar atribución inexistente.
- **FR-14:** EL SISTEMA exige nombre, objetivo, equipo y parte del cuerpo recortados
  y no vacíos; permite secundarios opcionales sin duplicados canónicos; y usa 90 s
  como descanso inicial editable dentro de 15–300 s. «Guardar» no queda bloqueado
  por ausencia de imagen.

### Músculos y catálogo

- **FR-08:** CUANDO el usuario edita objetivo o secundarios de un ejercicio de
  catálogo o personalizado, EL SISTEMA guarda la selección y actualiza las vistas
  y datos derivados que consumen esos músculos sin editar series ni cargas.
- **FR-09:** CUANDO el usuario restaura los músculos de un ejercicio de catálogo,
  EL SISTEMA recupera su objetivo y secundarios originales de forma reversible y
  no borra historial, descanso, imagen ni otras preferencias.
- **FR-17:** EL SISTEMA deriva `muscle_group` del primer secundario canónico o, si
  no hay secundarios, del objetivo canónico; impide un secundario equivalente al
  objetivo o duplicado canónico. Las páginas de catálogo conservan tamaño 50 y las
  mutaciones invalidan resultados/opciones sin perder la consulta activa.

### Sincronización actual y estado

- **FR-10:** CUANDO se investiga el fallo de sincronización actual, EL SISTEMA
  exige primero una reproducción automatizada o una evidencia remota acotada;
  cualquier corrección debe convertir ese caso rojo en verde y conservar cola y
  datos locales. No se declara una causa ni un arreglo si todas las comprobaciones
  disponibles pasan.
- **FR-16:** EL SISTEMA distingue en Perfil «Sin cuenta», «Pendiente»,
  «Sincronizando», «Actualizado» y «Necesita atención». «Actualizado» exige claim
  completado, cola sin pendientes/dead-letter, media sin operaciones pendientes y
  un ciclo de descarga correcto. «Reintentar sincronización» reactiva dead-letter
  sin borrar datos y nunca expone SQL, tokens ni stack traces.

## 6. Contratos de datos aprobados

`docs/db.md` es la fuente técnica detallada. Las decisiones estructurales son:

- Catálogo maestro inmutable por esta feature; preferencias de catálogo separadas
  en `exercise_preferences` para descanso y override muscular.
- Personalizados identificados como `custom_<uuid>` en la tabla local `exercises`
  y replicados en la tabla remota `custom_exercises`; las referencias históricas
  siguen usando `exercise_id` en texto.
- Un countdown por fila `workout_exercises`, con `rest_ends_at` y
  `rest_paused_seconds`; los campos globales de `workouts` quedan solo como
  fallback legacy local.
- Imágenes en bucket privado `custom-exercise-images`, clave
  `<auth.uid()>/<exerciseId>`, bytes JPEG/PNG/WebP y `ThumbFallback` mientras el
  objeto no esté disponible. La ruta local nunca se envía como ruta remota.
- Restauración muscular desde el asset maestro con `kCatalogMusclePatches`
  aplicado, nunca desde una fila ya personalizada.
- Cambios locales por drift v19 (T-003), v20 (T-004) y v21 (T-006). T-005 reutiliza
  v19/v20. T-006 tiene una única migración Supabase; ninguna se aplica durante la
  planificación.

## 7. Requisitos no funcionales y verificación

| NFR | Regla | Método de verificación |
|---|---|---|
| NFR-01 | Toda escritura de personalizados, músculos y descanso funciona localmente sin esperar red. | Tests de repositorio con Supabase ausente y fallos de red inyectados. |
| NFR-02 | No se añaden dependencias ni se modifica `pubspec.lock`; se reutiliza `image_picker` ya declarado. | Revisión de diff y manifiesto de dependencias. |
| NFR-03 | Cada cambio drift incrementa `schemaVersion` y pasa por `build_runner`; cada cambio remoto usa una migración por tarea, RLS y `user_id`. | Tests de migración local y revisión SQL/políticas antes de aplicar. |
| NFR-04 | Las pantallas mantienen AA, targets ≥44 dp y comportamiento usable a 320/375/640/1024 dp con `textScaler` hasta 1.3. | Tests widget/unitarios, semántica y comprobaciones de overflow sin goldens. |
| NFR-05 | La puerta es `flutter test --exclude-tags golden` completa en verde y `flutter analyze` sin incidencias; ningún PNG se modifica. | Salida completa de ambos comandos y comprobación de hashes/diff de PNG. |
| NFR-06 | Se preservan la 021, el trabajo ajeno y los archivos no relacionados; no se hacen commits. | Revisión de estado/diff al inicio y cierre de cada tarea. |
| NFR-07 | Los contadores se calculan contra `DateTime`, no contra ticks, y la UI no se bloquea por sincronización. | Tests con reloj fijo, pausa/reanudación y latencia/fallo de red. |
| NFR-08 | Una réplica nunca sobrescribe una mutación local pendiente; el servidor resuelve el orden final con `updated_at`. | Tests de dos réplicas, cola pendiente y conflictos de subida/descarga. |

## 8. Fuera de alcance

- Reabrir o rehacer la spec 021 y ejecutar el rediseño general pendiente de la 020.
- Sustituir el catálogo maestro ni editar sus datos originales para personalizar
  músculos: se usa una personalización reversible.
- Añadir dependencias, generar goldens, modificar PNG o hacer commits.
- Reescribir toda la sincronización sin un caso rojo que lo justifique.
- Aplicar migraciones o cambiar `database.g.dart` durante la planificación.
- Temporizadores de fases, ejercicios compartidos públicamente, borrado de
  personalizados, instrucciones personalizadas y edición de plantillas ajenas.
- Sincronización realtime por canales: la réplica usa arranque/login, escrituras,
  reanudación y ciclo periódico existente; «tiempo real» se refiere a la respuesta
  inmediata de la tarjeta local.

## 9. Q-006 — Cerrada

El usuario aprobó explícitamente el DESIGN completo sin cambios el 2026-11-23 con
la respuesta «aprovado». D-117 sustituye el estado pendiente anterior y D-114 se
conserva solo como antecedente histórico. **No quedan preguntas de producto
abiertas.**

El diagnóstico de sync no exige otra pregunta inicial. Si T-001 no reproduce un
rojo ni obtiene evidencia remota, devolverá el bloqueo concreto sin declarar la
avería corregida.

## 10. Orden y finalización

Orden previsto: **T-001 → T-002 → T-003 → T-004 → T-005 → T-006**. T-002 no tiene
dependencia técnica de T-001 y podría ejecutarse en paralelo, pero la entrega
recomendada es serial. T-006 depende de T-001 y T-005, transitivamente de todas.

La spec no se cierra hasta que todos los FR tengan regresión, todas las tareas
estén aprobadas por revisión y se cumpla NFR-05 sin excepciones.
