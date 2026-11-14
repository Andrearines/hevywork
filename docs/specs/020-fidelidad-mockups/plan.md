# Plan 020 — fidelidad-mockups

Spec: `docs/specs/020-fidelidad-mockups/spec.md`
Constitución: `docs/constitucion.md` · Diseño: `docs/DESIGN.md`

## 1. Arquitectura

Sin cambios de arquitectura. Es un trabajo de UI sobre el árbol existente:

```
lib/ui/
  theme/        ← FR-01/FR-02: tokens de color, tipografía, espaciado, radios
  widgets/      ← componentes compartidos (nav, chips, cards, tabla de series…)
  views/        ← las 6 vistas SCR-01…06
assets/fonts/   ← ya existen SpaceGrotesk + Geist en pubspec; sin cambios (D-062)
test/           ← goldens/ + tests existentes
```

- **D-056**: los tokens se centralizan en `lib/ui/theme/` para que las 6
  vistas consuman los mismos valores; se evita duplicar hex por vista.
- No se toca `lib/data/`, `supabase/`, repositorios ni sync (docs/db.md:
  sin migraciones).
- No hay API nueva → no se genera `docs/api.md`.

## 2. Datos y contratos

- Datos reales del usuario en pantalla (D-054); los valores de los mockups
  solo guían la maquetación.
- Contratos internos sin cambios: vistas siguen leyendo de sus
  providers/repositorios actuales.
- Estados vacío/carga/error existentes se reestilizan, no se reescriben
  (FR-09).

## 3. Fases

| Fase | Tareas | Entregable |
|---|---|---|
| F0 — Auditoría | T-001 | Checklist de diferencias por pantalla (mockup vs vista actual) |
| F1 — Base | T-002, T-003 | Tokens en theme + roles tipográficos con las fuentes existentes |
| F2 — SCR-01 Rutinas | T-004, T-005 | `RoutinesView` alineada + golden + aprobación |
| F3 — SCR-02 Entrenar | T-006, T-007 | `TrainView` alineada + golden + aprobación |
| F4 — SCR-03 Registro en vivo | T-008, T-009 | `LiveWorkoutView` alineada + golden + aprobación |
| F5 — SCR-04 Progreso/Medidas | T-010, T-011 | `ProgressView`/`MeasuresView` alineadas, secciones funcionales (FR-11) + golden + aprobación |
| F6 — SCR-05 Perfil | T-012, T-013 | `ProfileView` alineada + golden + aprobación |
| F7 — SCR-06 Ficha ejercicio | T-014, T-015 | `ExerciseInfoView` alineada (GIF/miniaturas intactos) + golden + aprobación |
| F8 — Estados y cierre | T-016, T-017, T-018 | Estados vacío/carga/error, suite verde, docs actualizados |

Orden confirmado por el usuario (D-058): de lo más estable a lo más
complejo, dejando la ficha de ejercicio (con la spec 019 reciente) al final.

## 4. Estrategia de aceptación por pantalla

Para cada SCR (D-059):
1. Comparación contra el `screen.png` con checklist (estructura, color,
   tipografía, espaciado, bordes, estados) → diferencias a cero o
   justificadas.
2. Test golden nuevo en verde (`test/goldens/<scr>_test.dart`).
3. Tests preexistentes de la vista en verde + `flutter analyze` sin errores.
4. Aprobación visual del usuario antes de pasar a la siguiente fase.

## 5. Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| Goldens frágiles entre máquinas/versions de Flutter | Q-020 cerrada (D-063): baseline generado y aprobado en local; tamaño de captura fijo; actualizar solo con `--update-golds` documentado |
| Regresiones en tests existentes que asumen la estructura actual (p. ej. `live_fatigue_section_test`, `screen_breakpoints_test`) | Suite completa antes de cerrar cada fase (NFR-04/NFR-05); ajustar solo aserciones de estilo, nunca de lógica |
| Fuentes (Q-021 cerrada, D-062) | Sin cambios: `SpaceGrotesk` y `Geist` ya están en `pubspec.yaml`/`assets/fonts/`; solo se aplican roles existentes, sin archivos nuevos ni dependencias |
| Secciones «Evolución de Medidas» y «Báscula y Caliper» con funcionalidad real (Q-022 cerrada, D-061; Q-023 cerrada, D-064) | `MeasureEvolution` ya existe con datos reales; la tarjeta de dispositivos gestiona el estado real de conexión con lo disponible hoy (sin «próximamente» de relleno). El **BLE real queda para la spec 011** (`flutter_blue_plus`) en una spec futura; **sin dependencias nuevas en la 020** (NFR-03 sin enmendar) |
| Deriva de alcance hacia vistas sin mockup | 2.3 Fuera de alcance; cualquier petición de esas vistas sale de la spec 020 |
| Tocar GIF/miniaturas por error al «igualar» (D-052) | CA-06 exige verificar explícitamente que GIF/miniaturas siguen intactos |

## 6. Trazabilidad resumida

- US-01…US-06 → SCR-01…SCR-06 → fases F2…F7.
- US-04/FR-11 → secciones funcionales de SCR-04 (Evolución de Medidas +
  Báscula/Caliper) → fase F5 (T-010/T-011).
- US-07 → FR-01/FR-02/FR-09/FR-10 → fases F1 y F8.
- Cada FR tiene ≥1 tarea en `tasks.md`; cada NFR tiene método de
  verificación en la spec §6.
