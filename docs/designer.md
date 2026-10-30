# Designer — hevywork

Sistema de diseño **Obsidian Kinetic** adaptado a Flutter.
Cada token, componente y regla aquí documentados son la referencia canónica
para toda pantalla de la app. Las pantallas de referencia viven en
`docs/stitch_gestor_de_rutinas_fitness/`.

---

## 1. Identidad y principios visuales

| Principio | Descripción |
|---|---|
| Minimalismo tipo Apple | Superficies planas, sin `elevation` ni `BoxShadow` (constitución §7). Jerarquía por tipografía y espacio. |
| Dark-mode-first | Fondo off-black `#121316`, optimizado para OLED y entornos de gimnasio con brillo alto. |
| Legibilidad instantánea | Números de peso, reps y timer siempre en blanco puro sobre superficie oscura — lectura en < 200 ms. |
| Ergonomía de una mano | Zonas táctiles mínimas de 48 × 44 dp; acciones principales en la mitad inferior de la pantalla. |
| Densidad sin ruido | Cada pixel muestra datos reales — cero relleno decorativo. |

---

## 2. Paleta de color

### 2.1 Superficies (escala tonal)

| Token Flutter (`ColorScheme`) | Hex | Uso |
|---|---|---|
| `surface` / `surfaceDim` | `#121316` | Canvas base / fondo de la app. |
| `surfaceContainerLowest` | `#0D0E11` | Overlays más profundos, gradientes inferiores en fotos. |
| `surfaceContainerLow` | `#1B1B1F` | Superficie de tarjeta secundaria, fondos de fila completada. |
| `surfaceContainer` | `#1F1F23` | Tarjeta principal de ejercicio, contenedores de datos. |
| `surfaceContainerHigh` | `#292A2D` | Fila activa en la tabla de series, inputs enfocados. |
| `surfaceContainerHighest` | `#343538` | Bordes hairline (1 dp), chips seleccionados, pill flotante. |
| `surfaceBright` | `#38393C` | Hover/pressed sobre inputs y steppers. |

### 2.2 Contenido sobre superficie

| Token Flutter | Hex | Uso |
|---|---|---|
| `onSurface` | `#E3E2E6` | Texto de cuerpo, valores numéricos secundarios. |
| `onSurfaceVariant` | `#C4C7C8` | Labels, placeholders, unidades (kg, cm), timestamps. |
| `primary` | `#FFFFFF` | Números críticos (peso, reps, timer), texto de máxima jerarquía, CTA principal. |
| `onPrimary` | `#2F3131` | Texto sobre botón CTA blanco. |
| `secondary` | `#C6C6C9` | Checkmarks completados, métricas activas de segundo nivel. |
| `onSecondary` | `#2F3033` | Texto sobre superficie secundaria. |
| `outline` | `#8E9192` | Puntos de dato en gráficas, separadores sutiles. |
| `outlineVariant` | `#444748` | Bordes de checkbox sin marcar, divisores entre filas de PR. |

### 2.3 Acento funcional

| Token Flutter | Hex | Uso |
|---|---|---|
| `tertiary` | `#FFFFFF` | Iconos funcionales (timer pulsante, verified badge). |
| `tertiaryContainer` | `#D7E7D8` | Indicadores de tendencia positiva (flecha ↑, delta +). |
| `onTertiaryContainer` | `#59685C` | Texto sobre indicador de tendencia. |
| `error` | `#FFB4AB` | Alerta de fallo de sincronización, validación. |
| `errorContainer` | `#93000A` | Fondo de alerta crítica. |
| `onErrorContainer` | `#FFDAD6` | Texto sobre error container. |

### 2.4 Color semántico extra (extensión)

| Token | Hex | Uso |
|---|---|---|
| `oliveAccent` | `#849386` | Color reservado para hitos positivos: PRs completados, indicadores de preparación/readiness. No tiene equivalente en `ColorScheme`; implementar como extensión (`ThemeExtension`). |

### 2.5 Reglas de aplicación

- Nunca poner fondo coloreado detrás de números grandes; siempre `#FFFFFF`
  sobre superficie oscura.
- Evitar badges saturados multicolor; preferir contraste tonal +
  iconografía discreta.
- La barra de progreso del objetivo usa `primary` (`#FFFFFF`) sobre
  `surfaceContainerHighest` (`#343538`).

---

## 3. Tipografía

Dos familias: **Space Grotesk** para headlines y métricas, **Geist** para
cuerpo y labels operacionales.

### 3.1 Escala tipográfica

| Rol | Familia | Tamaño | Peso | Alto línea | Tracking | Uso |
|---|---|---|---|---|---|---|
| `displayLarge` | Space Grotesk | 44 | w600 | 48 | −0.04 em | (Reservado para splash / landing.) |
| `headlineLarge` | Space Grotesk | 32 | w600 | 38 | −0.03 em | Título de sección desktop. |
| `headlineMedium` | Space Grotesk | 26 | w600 | 32 | −0.02 em | Título de pantalla móvil: "Mis Rutinas", "Perfil". |
| `headlineSmall` | Space Grotesk | 20 | w500 | 26 | −0.02 em | Nombre de ejercicio, subtítulo de sección. |
| `titleLarge` | Space Grotesk | 36 | w700 | 40 | −0.03 em | Métrica XL: peso corporal "78.4", "13.8%". |
| `titleMedium` | Space Grotesk | 22 | w600 | 26 | −0.02 em | Métrica MD: "140 kg", "104 cm", timer "01:45". |
| `titleSmall` | Geist | 16 | w400 | 24 | −0.01 em | Cuerpo grande: nombre de PR, descripción objetivo. |
| `bodyLarge` | Geist | 16 | w400 | 24 | −0.01 em | Texto descriptivo, sinopsis de rutina. |
| `bodyMedium` | Geist | 14 | w400 | 20 | −0.005 em | Texto operacional, subtítulos de tarjeta. |
| `bodySmall` | Geist | 12 | w500 | 16 | +0.04 em | Label MD: chips, filtros, unidades. |
| `labelLarge` | Geist | 12 | w500 | 16 | +0.04 em | Etiquetas de columna: SET, KG, REPS, RIR. |
| `labelMedium` | Geist | 11 | w600 | 14 | +0.06 em | Micro-labels: "SESIÓN EN CURSO", "1RM ESTIMADO", "DESCANSO". |
| `labelSmall` | Geist | 10 | w400 | 14 | +0.02 em | Caption: timestamps, deltas, leyendas de gráfica. |

### 3.2 Reglas tipográficas

- `labelMedium` y `labelLarge` siempre en **UPPERCASE** con tracking
  positivo para escaneo periférico rápido.
- Aplicar `fontFeatures: [FontFeature.tabularFigures()]` en toda métrica
  numérica y timer para evitar saltos de layout.
- Las unidades (kg, %, cm, t) se renderizan con `bodySmall` o `labelSmall`
  inmediatamente después del valor, en la misma línea base.

---

## 4. Espaciado

### 4.1 Tokens de espaciado

| Token | Valor | Uso |
|---|---|---|
| `spaceXs` | 4 dp | Gap entre unidad y valor, separación micro-interna. |
| `spaceSm` | 8 dp | Separación entre chips, gap dentro de fila de serie. |
| `spaceMd` | 12 dp | Padding interno de tarjeta, gap entre secciones ligeras. |
| `spaceLg` | 20 dp | Gap principal entre tarjetas / secciones verticales. |
| `spaceXl` | 32 dp | Separación de bloques mayores. |
| `margin` | 16 dp | Margen horizontal de pantalla (borde izquierdo/derecho). |
| `marginMd` | 24 dp | Margen expandido en tablets. |
| `gutter` | 12 dp | Gutter de grid interno (entre columnas de la tabla de sets). |
| `gutterMd` | 16 dp | Gutter expandido en tablet. |

### 4.2 Grid

- **Móvil**: 4 columnas fluidas, margen 16 dp, gutter 12 dp.
  La tabla de series (SET, PREV, KG, REPS, RIR, ✓) usa 12 subdivisiones
  internas para caber en 375 dp sin scroll horizontal.
- **Tablet**: 6–8 columnas centradas, ancho máximo 640 dp.

---

## 5. Formas y radios

| Token | Valor | Uso |
|---|---|---|
| `rounded-sm` | 4 dp | Checkbox, micro-tags de músculo, indicadores de serie. |
| `rounded` | 8 dp | Inputs de peso/reps, steppers +/−, chips de filtro, botones secundarios. |
| `rounded-md` | 12 dp | (Intermedio, uso excepcional.) |
| `rounded-lg` | 16 dp | Tarjetas de ejercicio, tarjetas de gráfica, cards de medidas corporales. |
| `rounded-xl` | 24 dp | Top corners de bottom sheets y modales. |
| `rounded-full` | `StadiumBorder` | Timer flotante pill, badge "EN CURSO", avatar de perfil, filtros pill. |

---

## 6. Elevación y profundidad

**Prohibido** usar `elevation` de Material ni `BoxShadow` (constitución §7).
La profundidad se logra exclusivamente con capas tonales y bordes hairline.

| Capa | Color | Borde | Uso |
|---|---|---|---|
| Floor / Base | `#121316` | — | Viewport background. |
| Container Tier | `#1F1F23` | 1 dp solid `#343538` | Tarjetas de ejercicio, gráficas, rutinas. |
| Elevated Tier | `#292A2D` | 1 dp solid `#343538` | Inputs enfocados, fila activa, stepper buttons. |
| Modal / Drawer | `#1F1F23` | 1 dp solid `#343538` | Overlay con backdrop `rgba(0,0,0,0.6)`. |

### 6.1 Estados de fila

| Estado | Fondo | Opacidad | Comportamiento |
|---|---|---|---|
| Fila completada | `surfaceContainerLow` | 70 % | Desvanece; el ojo se mueve a la fila activa. |
| Fila activa | `surfaceContainerHigh` | 100 % | Inputs visibles con fondo `surfaceVariant`. |
| Fila pendiente | `surfaceContainer` | 100 % | Solo texto placeholder del previo. |

---

## 7. Componentes

### 7.1 Botones

| Variante | Fondo | Texto | Alto | Radio | Comportamiento |
|---|---|---|---|---|---|
| CTA primario | `primary` (#FFF) | `onPrimary` (#2F3131) | 48 dp | 8 dp | `active:scale-95`, fondo → `secondary` al soltar. |
| Secundario | `surfaceContainer` | `primary` | 44 dp | 8 dp | Borde 1 dp `surfaceContainerHighest`. |
| Ghost / Destructivo | Transparente | `onSurfaceVariant` | 44 dp | 8 dp | Hover → `surfaceContainerHigh`. |
| Stepper numérico (+/−) | `surfaceVariant` | `primary` | 40 × 40 dp | 8 dp | Borde 1 dp `surfaceContainerHighest`. |

### 7.2 Tabla de series (Set Logging)

```
┌─────┬──────────┬──────────┬───────┬──────┬─────┐
│ SER │  PREVIO  │    KG    │ REPS  │ RIR  │ OK  │
├─────┼──────────┼──────────┼───────┼──────┼─────┤
│  1  │ 75.0×10  │  75.0    │  10   │  3   │  ✓  │  ← completada (opacity 70%)
│  2  │ 80.0×8   │  80.0    │   8   │  2   │  ✓  │  ← completada
│ *3* │ 80.0×8   │ [82.5]   │ [ 8]  │ [ 2] │ [✓] │  ← activa (surfaceContainerHigh)
└─────┴──────────┴──────────┴───────┴──────┴─────┘
```

- **Header**: 28 dp alto, `labelMedium` uppercase `onSurfaceVariant` (`#C4C7C8`).
- **Fila default**: 44 dp alto, borde inferior 1 dp `surfaceContainerLow`.
- **Fila activa**: fondo `surfaceContainerHigh` (`#292A2D`), radio 6 dp,
  inputs con fondo `surfaceVariant` (`#343538`), foco → `surfaceBright` (`#38393C`).
- **Fila completada**: texto → `onSurfaceVariant`, checkbox relleno
  `secondary`, opacidad global 70 %.

### 7.3 Inputs numéricos (peso y reps)

- Alineación central. Fondo reposo `surfaceVariant` (`#343538`), fondo
  foco `surfaceBright` (`#38393C`).
- Sin borde visible en reposo; en foco → borde 1 dp `onSurface`.
- Placeholder muestra valor de sesión previa en `onSurfaceVariant`.
- `keyboardType: TextInputType.numberWithOptions(decimal: true)`.
- Alto: 40 dp, radio 6 dp (`rounded-md` redondeado).

### 7.4 Checkbox de serie

- 24 × 24 dp, radio 4 dp.
- Sin marcar: borde 1.5 dp `surfaceContainerHighest`, centro transparente.
- Marcado: relleno `secondary` (`#C6C6C9`) con icono check `surface`
  (`#121316`). Alternativa para PRs: relleno `oliveAccent` (`#849386`).
- La fila activa usa un botón de 32 × 32 dp con fondo `primary` y
  check `onPrimary`; al confirmar, se reduce a 28 × 28 dp con fondo
  `secondary`.

### 7.5 Chips y filtros pill

- Fondo `surfaceContainerLow`, padding 6 × 14 dp, radio `StadiumBorder`.
- Texto: `labelMedium` medium `onSurfaceVariant`.
- Seleccionado: fondo `surfaceContainerHighest`, texto `primary`.
- Sin borde explícito (ni en reposo ni en seleccionado).

### 7.6 Tarjetas (Cards)

- Fondo `surfaceContainer`, borde 1 dp `surfaceContainerHighest`,
  radio 16 dp, padding 16 dp.
- Header de ejercicio: nombre en `headlineSmall` blanco,
  badge de músculo en `labelMedium` uppercase sobre `surfaceVariant`,
  equipo en `labelSmall` `onSurfaceVariant`.
- Tarjeta activa (rutina en curso): línea de acento de 1 dp en el borde
  superior, gradiente de `primary` a transparente.

### 7.7 Timer flotante (Rest Timer Pill)

- Sticky bottom, alto 40 dp, radio `StadiumBorder`.
- Fondo `surfaceContainerHighest`, borde 1 dp `surfaceContainerHighest`.
- Indicador pulsante: círculo 10 dp `primary` con `AnimationController`
  (ping).
- Label "DESCANSO ACTIVO" en `labelMedium` uppercase.
- Contador en `titleMedium` blanco, botón "+30s" en `labelMedium`.

### 7.8 Barra de progreso

- Track: `surfaceContainerHighest`, alto 8 dp, radio full.
- Fill: `primary` (#FFF), alto 8 dp, radio full.
- Animar con `AnimatedContainer` / `TweenAnimationBuilder`, duración 500 ms.

### 7.9 Gráficas (sparkline)

- Dibujar con `CustomPainter` sobre `Canvas`.
- Línea: `onSurface` (#E3E2E6), 2.2 dp stroke, `StrokeCap.round`,
  `StrokeJoin.round`.
- Área bajo la curva: gradiente vertical de `#FFFFFF` 18 % opacidad a
  `#FFFFFF` 0 %.
- Guías horizontales: `surfaceContainerHighest` (#343538), 0.75 dp,
  dash pattern [2, 3].
- Punto final: círculo relleno `primary` 4 dp con stroke `surface` 2 dp.
- Puntos intermedios: `outline` (#8E9192) 2.5 dp.

### 7.10 Lista de medidas corporales

- Cada fila: padding 12 dp, radio 8 dp, fondo `surfaceContainerLow`,
  hover → `surfaceContainerHigh`.
- Icono: círculo 32 dp `surfaceContainerHighest`, icono Material
  Symbols 18 dp `primary`.
- Valor: `titleMedium`, unidad `labelSmall` `secondary`.
- Delta badge: padding 8 × 4 dp, fondo `surfaceContainerHighest`,
  texto `primary` (positivo) o `tertiaryContainer` (negativo).

### 7.11 Perfil del atleta

- Avatar: 64 dp, circular, `ClipRRect` full.
- Avatar editable (spec 013, RF-1 a RF-5): área táctil con
  `Semantics(button, label "Cambiar foto de perfil")`; al tocar abre un
  bottom sheet Cámara/Galería con `rounded-xl` (24 dp arriba). Con
  `avatar_url`, `Image.network` a 64 dp con `loadingBuilder` y
  `errorBuilder` de vuelta al icono `person`; sin foto o si falla la
  carga, icono `person` 32 dp sobre `surfaceContainerHigh`. Mensajes:
  «Foto de perfil actualizada» / «No se pudo subir la foto» /
  «Inicia sesión para subir tu foto».
- **Desviación 2026-10-26**: el mockup tiene el avatar fijo; la edición y
  el bucket `profile-photos` son nueva UI de la spec 013.
- Nombre: `headlineSmall` + badge verified (Material Symbol, FILL 1).
- Etiqueta "ATLETA PRO": `labelMedium` uppercase `onSurfaceVariant`.
- Badge "Nivel Avanzado": `labelMedium` con fondo
  `surfaceContainerHighest`, radio 4 dp.
- Grid de 3 métricas (Sesiones, Volumen Total, Racha): `titleMedium`
  centrado, label en `labelSmall` uppercase debajo.

### 7.12 Tarjeta de objetivo

- Fondo `surfaceContainer`, padding 16 dp, radio 8 dp.
- Nombre del objetivo: `bodyLarge` `primary` medium.
- Detalle: `labelMedium` `onSurfaceVariant`.
- Porcentaje: `titleMedium` alineado a la derecha.
- Barra de progreso debajo (ver §7.8).
- Leyenda tripartita: Inicio / Delta / Meta en `labelSmall`.
- Tope de la sección (spec 013, RF-13): con más de 3 metas la lista se
  envuelve en `CappedScroll` (alto máximo = 3 tarjetas, scroll interno en
  la propia sección); con 3 o menos, sin envoltura. Aplica en Progreso
  (tarjetas) y Perfil (filas con barra, cap 162 dp).
- **Desviación 2026-10-26**: el mockup deja crecer la lista sin límite y
  empuja el resto de la pantalla.

### 7.13 Lista de récords personales

- Container con `surfaceContainer`, radio 8 dp, dividido por bordes
  `surfaceContainerHigh`.
- Icono: 40 × 40 dp, radio 8 dp, fondo `surfaceContainerHigh`.
- Nombre del ejercicio: `bodyLarge` medium.
- Fecha del PR: `labelSmall` `onSurfaceVariant`.
- Valor: `titleMedium` + unidad `labelMedium` `secondary`.
- Delta: `labelSmall` `secondary` o `onSurfaceVariant`.
- Pestañas (spec 013, RF-6): `SegmentedButton` con dos segmentos, sin
  icono de selección; «Este mes» activo por defecto, «Histórico» muestra
  el mejor de siempre. Estado vacío mensual: «Sin récords este mes.
  Termina series para ver tus mejores marcas.»; histórico vacío: «Termina
  series para ver tus mejores marcas.».
- **Desviación 2026-10-26**: el mockup muestra una única lista sin filtro
  temporal; las pestañas y el estado vacío del mes son de la spec 013.

### 7.14 Acciones de fotos de progreso (spec 013)

- Menú de tarjeta: `PopupMenuButton` (tooltip «Opciones de la foto») en la
  esquina superior derecha, chip `surfaceContainerHighest`, icono 14 dp;
  opciones «Ver foto» y «Eliminar».
- Visor: acción `delete_outline` en el AppBar con tooltip «Eliminar foto»;
  contador «n / total» en `labelSmall`; el visor arranca en la foto
  tocada y el contador avanza con el deslizamiento.
- «Eliminar todo»: `TextButton.icon` alineado a la derecha bajo la
  rejilla, color `error`, solo cuando hay fotos (RF-12).
- Confirmación: `AlertDialog` radio 16 dp con borde
  `surfaceContainerHighest`, acción destructiva en `error`.
- **Desviación 2026-10-26**: el mockup solo permite añadir y comparar; el
  borrado (RF-10 de la 009) y el masivo (RF-11 de la 013) son nueva UI.

---

## 8. Navegación

### 8.1 Bottom Navigation Bar

- Fija en la parte inferior, altura 64 dp + safe area.
- Fondo `surface` al 85 % opacidad + `BackdropFilter` blur 24.
- 4 destinos:

| Icono (Material Symbols) | Label | Path |
|---|---|---|
| `fitness_center` | ENTRENAR | `/train` |
| `view_timeline` | RUTINAS | `/routines` |
| `monitoring` | PROGRESO | `/progress` |
| `person` | PERFIL | `/profile` |

- Destino activo: `primary` (#FFF). Inactivo: `onSurfaceVariant`.
- Labels en `labelSmall` uppercase tracking wider.

### 8.2 App Bar (Header)

- Fija en la parte superior, altura 64 dp + safe area.
- Fondo `surface` al 80 % opacidad + `BackdropFilter` blur 24.
- Izquierda: logo/marca + título de sección en `headlineSmall` medium.
- Derecha: avatar circular 32 dp con link a perfil.

---

## 9. Iconografía

- **Familia**: Material Symbols Outlined, variable.
- **Tamaños estándar**: 18 dp (inline), 20 dp (card header / nav),
  22 dp (bottom nav).
- **Filled**: solo para `verified`, `local_fire_department`,
  `play_arrow` (CTA de iniciar sesión).
- **Preferir** `font-variation-settings: 'FILL' 0` por defecto; fill 1
  solo en los casos explícitos anteriores.

---

## 10. Animación y movimiento

| Tipo | Duración | Curva | Uso |
|---|---|---|---|
| Tap feedback (scale) | 100 ms | `Curves.easeOut` | `active:scale(0.95)` en todos los botones. |
| Transición de opacidad | 150 ms | `Curves.easeInOut` | Hover sobre fotos, filas completadas. |
| Barra de progreso | 500 ms | `Curves.easeInOut` | Fill de barra de objetivo. |
| Timer pulsante | 1500 ms | Repeat, reverse | Ping del indicador de descanso activo. |
| Transición de color | 200 ms | `Curves.easeIn` | Focus/blur de inputs, cambio de chip. |

---

## 11. Touch targets y accesibilidad

- Toda zona interactiva: mínimo 48 × 44 dp físicos, incluso si el
  contenedor visual es de 36 dp.
- Ratio de contraste mínimo WCAG AA:
  - `primary` (#FFF) sobre `surface` (#121316) → **15.4:1** ✓
  - `onSurfaceVariant` (#C4C7C8) sobre `surface` → **10.2:1** ✓
  - `secondary` (#C6C6C9) sobre `surfaceContainer` (#1F1F23) → **9.8:1** ✓
- Labels semánticos en cada widget interactivo para lectores de pantalla.

---

## 12. Mapa muscular (referencia rápida)

Documentado en constitución §8 y especificado en la spec 007. El mapa se
dibuja con `CustomPainter` / `Path`, nunca con imágenes. La escala de fatiga
es un **gradiente continuo** normalizado 0–1:

| Valor | Color | Descripción |
|---|---|---|
| 0.0 | `#4A90E9` | Frío: sin fatiga reciente. |
| 0.5 | `#F5A623` | Tibio: fatiga media. |
| 1.0 | `#D0021B` | Rojo: fatiga máxima. |
| sin datos | `#9B9B9B` | Músculo sin actividad registrada. |

La normalización es relativa al máximo del mapa (el músculo más cargado vale
1.0). El valor lo calcula el dominio, no el widget. Esta tabla sustituye a las
5 bandas discretas anteriores y queda alineada con la spec 007.

---

## 13. Referencia cruzada de pantallas

| Pantalla | Carpeta de referencia | Componentes principales |
|---|---|---|
| Entrenar (Registro en vivo) | `entrenar_registro_en_vivo/` | App bar, session card, exercise card, set table, rest timer pill, bottom nav. |
| **Registrar entrenamiento pasado (Spec 012)** | `registrar_entrenamiento_pasado/` | **App bar, date/time/duration pickers, routine/manual origin picker, exercise cards with set rows, save bar con spinner, bottom nav.** |
| Rutinas y programas | `rutinas_y_programas/` | Header con CTA, cycle indicator, filter pills, routine cards (activa / inactiva), explore card, bottom nav. |
| Progreso y medidas | `progreso_y_medidas/` | Weight trend sparkline, body composition grid, measurements list, progress photos grid, sync callout, bottom nav. |
| Perfil y objetivos | `perfil_y_objetivos_del_atleta/` | Profile header, stats grid, goals list con progress bar, PR list, settings list, logout button, bottom nav. |

---
 
## 14. Implementación Flutter — mapeo rápido

```dart
// En lib/app/theme/app_theme.dart (ejemplo de estructura, no copiar literal)

const _oliveAccent = Color(0xFF849386);

ThemeData buildAppTheme() {
  const surface        = Color(0xFF121316);
  const surfContLow    = Color(0xFF1B1B1F);
  const surfCont       = Color(0xFF1F1F23);
  const surfContHigh   = Color(0xFF292A2D);
  const surfContHighest= Color(0xFF343538);
  const onSurface      = Color(0xFFE3E2E6);
  const onSurfVariant  = Color(0xFFC4C7C8);
  const primary        = Color(0xFFFFFFFF);
  const onPrimary      = Color(0xFF2F3131);
  const secondary      = Color(0xFFC6C6C9);
  const outline        = Color(0xFF8E9192);
  const outlineVariant = Color(0xFF444748);
  const error          = Color(0xFFFFB4AB);
  const errContainer   = Color(0xFF93000A);
  const onErrContainer = Color(0xFFFFDAD6);
  const tertContainer  = Color(0xFFD7E7D8);
  const onTertContainer= Color(0xFF59685C);

  final colorScheme = ColorScheme.dark(
    surface: surface,
    onSurface: onSurface,
    onSurfaceVariant: onSurfVariant,
    primary: primary,
    onPrimary: onPrimary,
    secondary: secondary,
    outline: outline,
    outlineVariant: outlineVariant,
    error: error,
    errorContainer: errContainer,
    onErrorContainer: onErrContainer,
    tertiaryContainer: tertContainer,
    onTertiaryContainer: onTertContainer,
    surfaceContainerLowest: const Color(0xFF0D0E11),
    surfaceContainerLow: surfContLow,
    surfaceContainer: surfCont,
    surfaceContainerHigh: surfContHigh,
    surfaceContainerHighest: surfContHighest,
    // surfaceBright (#38393C) no existe en ColorScheme;
    // usarlo como Color directo o en ThemeExtension.
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    textTheme: const TextTheme(
      displayLarge:  TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 44, fontWeight: FontWeight.w600, height: 48/44, letterSpacing: -0.04 * 44),
      headlineLarge: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 32, fontWeight: FontWeight.w600, height: 38/32, letterSpacing: -0.03 * 32),
      headlineMedium:TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 26, fontWeight: FontWeight.w600, height: 32/26, letterSpacing: -0.02 * 26),
      headlineSmall: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 20, fontWeight: FontWeight.w500, height: 26/20, letterSpacing: -0.02 * 20),
      titleLarge:    TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 36, fontWeight: FontWeight.w700, height: 40/36, letterSpacing: -0.03 * 36),
      titleMedium:   TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 22, fontWeight: FontWeight.w600, height: 26/22, letterSpacing: -0.02 * 22),
      bodyLarge:     TextStyle(fontFamily: 'Geist',        fontSize: 16, fontWeight: FontWeight.w400, height: 24/16, letterSpacing: -0.01 * 16),
      bodyMedium:    TextStyle(fontFamily: 'Geist',        fontSize: 14, fontWeight: FontWeight.w400, height: 20/14, letterSpacing: -0.005 * 14),
      bodySmall:     TextStyle(fontFamily: 'Geist',        fontSize: 12, fontWeight: FontWeight.w500, height: 16/12, letterSpacing: 0.04 * 12),
      labelLarge:    TextStyle(fontFamily: 'Geist',        fontSize: 12, fontWeight: FontWeight.w500, height: 16/12, letterSpacing: 0.04 * 12),
      labelMedium:   TextStyle(fontFamily: 'Geist',        fontSize: 11, fontWeight: FontWeight.w600, height: 14/11, letterSpacing: 0.06 * 11),
      labelSmall:    TextStyle(fontFamily: 'Geist',        fontSize: 10, fontWeight: FontWeight.w400, height: 14/10, letterSpacing: 0.02 * 10),
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}

// Extensión para colores semánticos fuera de ColorScheme.
// Uso: Theme.of(context).extension<HevyColors>()!.oliveAccent
@immutable
class HevyColors extends ThemeExtension<HevyColors> {
  const HevyColors({
    required this.oliveAccent,
    required this.surfaceBright,
  });

  final Color oliveAccent;
  final Color surfaceBright;

  static const dark = HevyColors(
    oliveAccent: _oliveAccent,
    surfaceBright: Color(0xFF38393C),
  );

  @override
  HevyColors copyWith({Color? oliveAccent, Color? surfaceBright}) {
    return HevyColors(
      oliveAccent: oliveAccent ?? this.oliveAccent,
      surfaceBright: surfaceBright ?? this.surfaceBright,
    );
  }

  @override
  HevyColors lerp(HevyColors? other, double t) {
    if (other is! HevyColors) return this;
    return HevyColors(
      oliveAccent: Color.lerp(oliveAccent, other.oliveAccent, t)!,
      surfaceBright: Color.lerp(surfaceBright, other.surfaceBright, t)!,
    );
  }
}
```

---

*Última actualización: 2026-10-05. Fuente de verdad visual:
`docs/stitch_gestor_de_rutinas_fitness/obsidian_kinetic/DESIGN.md` y las
4 pantallas de referencia.*
