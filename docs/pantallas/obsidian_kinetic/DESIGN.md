---
name: Obsidian Kinetic
colors:
  surface: '#121316'
  surface-dim: '#121316'
  surface-bright: '#38393c'
  surface-container-lowest: '#0d0e11'
  surface-container-low: '#1b1b1f'
  surface-container: '#1f1f23'
  surface-container-high: '#292a2d'
  surface-container-highest: '#343538'
  on-surface: '#e3e2e6'
  on-surface-variant: '#c4c7c8'
  inverse-surface: '#e3e2e6'
  inverse-on-surface: '#2f3034'
  outline: '#8e9192'
  outline-variant: '#444748'
  surface-tint: '#c6c6c7'
  primary: '#ffffff'
  on-primary: '#2f3131'
  primary-container: '#e2e2e2'
  on-primary-container: '#636565'
  inverse-primary: '#5d5f5f'
  secondary: '#c6c6c9'
  on-secondary: '#2f3033'
  secondary-container: '#4a4b4e'
  on-secondary-container: '#bbbbbe'
  tertiary: '#ffffff'
  on-tertiary: '#26332a'
  tertiary-container: '#d7e7d8'
  on-tertiary-container: '#59685c'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#e2e2e2'
  primary-fixed-dim: '#c6c6c7'
  on-primary-fixed: '#1a1c1c'
  on-primary-fixed-variant: '#454747'
  secondary-fixed: '#e2e2e5'
  secondary-fixed-dim: '#c6c6c9'
  on-secondary-fixed: '#1a1c1e'
  on-secondary-fixed-variant: '#454749'
  tertiary-fixed: '#d7e7d8'
  tertiary-fixed-dim: '#bbcbbc'
  on-tertiary-fixed: '#111e15'
  on-tertiary-fixed-variant: '#3c4a3f'
  background: '#121316'
  on-background: '#e3e2e6'
  surface-variant: '#343538'
typography:
  display-lg:
    fontFamily: Space Grotesk
    fontSize: 44px
    fontWeight: '600'
    lineHeight: 48px
    letterSpacing: -0.04em
  headline-lg:
    fontFamily: Space Grotesk
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 38px
    letterSpacing: -0.03em
  headline-lg-mobile:
    fontFamily: Space Grotesk
    fontSize: 26px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Space Grotesk
    fontSize: 20px
    fontWeight: '500'
    lineHeight: 26px
    letterSpacing: -0.02em
  metric-xl:
    fontFamily: Space Grotesk
    fontSize: 36px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.03em
  metric-md:
    fontFamily: Space Grotesk
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 26px
    letterSpacing: -0.02em
  body-lg:
    fontFamily: Geist
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: -0.01em
  body-md:
    fontFamily: Geist
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: -0.005em
  label-md:
    fontFamily: Geist
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.04em
  label-sm:
    fontFamily: Geist
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.06em
  caption:
    fontFamily: Geist
    fontSize: 10px
    fontWeight: '400'
    lineHeight: 14px
    letterSpacing: 0.02em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 0.75rem
  gutter-md: 1rem
  margin: 1rem
  margin-md: 1.5rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1.25rem
  space-xl: 2rem
---

## Brand & Style

This design system is tailored for an elite, distraction-free strength and body metrics interface. Built for dedicated athletes, coaches, and lifters who demand zero visual friction during high-intensity training, the aesthetic combines technical precision with a modern architectural minimalism.

The emotional objective is absolute focus, composure, and mechanical clarity. In high-glare gym environments, the interface eliminates cognitive overload by stripping away decorative noise and relying on impeccable typographic hierarchy, tactile feedback surfaces, and precise data grouping. 

The visual execution draws heavily from functional minimalism and technical instrumentation:
- Dark-mode-first architecture grounded in deep off-black and precision slate surfaces.
- High-legibility monospaced-influenced geometric tracking for instantaneous reading of weights, target reps, RIR (reps in reserve), and progression deltas.
- Subdued hairline containment that frames metrics without clutter.
- Generous, ergonomic tap zones engineered for sweaty, chalked fingers and swift transitions between sets.

## Colors

The palette operates in strict tonal layers to deliver high-contrast legibility while preserving dark-adapted vision and battery life on OLED mobile screens. 

### Palette Architecture
- **Canvas Base (`#121316`)**: Pure off-black ground canvas minimizing glare and providing an infinite depth plane.
- **Surface Level 1 (`#1E2024`)**: Base card and container surface for primary modules, active exercise tables, and metric summary blocks.
- **Surface Level 2 (`#282A2F`)**: Elevated inputs, active row highlights, chip backgrounds, and segmented controls.
- **Surface Level 3 / Tonal Border (`#32353B`)**: Hairline borders (1px) used strictly for separation, boundary definition, and progress track wells.
- **Primary Text & High Action (`#FFFFFF`)**: Pure crisp white for primary numbers, set weights, and critical state actions.
- **Secondary Metric & Active Slate (`#E4E4E7`)**: Refined bright silver for active toggle states, secondary actions, and high-readout labels.
- **Muted Text & Inactive States (`#9E9EA7`)**: Balanced medium-slate for labels, completed states, units (kg/lbs), timestamps, and non-active sets.
- **Functional Accent / Calibrated Olive (`#849386`)**: A desaturated, tactical olive-slate reserved exclusively for positive milestones, completed PRs (personal records), and subtle readiness indicators.

### Application Rules
- Avoid stark multi-colored state representations; prefer contrast differences and discrete iconography over bright saturated badges.
- Never use colored fills behind large numerical values; numbers must remain pure `#FFFFFF` against dark containers for maximum instantaneous optical recognition.

## Typography

The typography couples the technical, engineered character of **Space Grotesk** for display headlines, timers, and critical workout metrics with the surgical neutrality and clarity of **Geist** for tabular logging, inputs, and analytical prose.

### Role Assignments
- **Space Grotesk**: Applied to workout titles, timer counters, set weight figures, rep counters, and high-impact delta figures. Always apply tabular numbers (`font-variant-numeric: tabular-nums`) to avoid layout jitter during live stopwatches, countdown rests, and metric updates.
- **Geist**: Powers the rest of the operational UI—set indexes, column headers (SET, PREV, KG, REPS, RIR), notes, settings, and navigation.

### Formatting Principles
- All micro-labels (`label-sm`, `label-md`) conveying measurement classifications (e.g., `TARGET RIR`, `EST. 1RM`, `BODYWEIGHT`) must be styled in uppercase with intentional positive tracking (`+0.04em` to `+0.06em`) for rapid peripheral scannability.
- Metric values pair directly with muted unit descriptors on the same baseline or stacked immediately below using `label-sm`.

## Layout & Spacing

The layout is built for single-hand, thumb-driven mobile ergonomics under demanding physical conditions.

### Grid & Margins
- **Mobile Grid**: A fluid 4-column system with a `1rem` (16px) margin and `0.75rem` (12px) gutter. Content stretches to fit edge margins while internal interactive components (such as set tables) use dense horizontal spacing to ensure all 5 core columns (Set, Prev, Weight, Reps, Check) fit comfortably on 375px screens without horizontal scrolling.
- **Tablet / Expanded**: Adapts to a centered 6-column to 8-column layout constrained to a maximum width of 640px to preserve focused data density and single-field line of sight.

### Touch Targets & Hit Zones
- Interactive logging cells must have a minimum physical hit target of 48px by 44px, even when visually framed inside tighter 36px containers.
- Key bottom-docked actions (e.g., "Add Set", "Complete Workout", "Start Rest Timer") span the full horizontal width minus canvas margins, fixed above mobile safe areas.

## Elevation & Depth

This system avoids realistic skeuomorphic drop shadows and intense blurs, relying instead on **tactile tonal layering and precision hairline containment**. This keeps views crisp, high-contrast, and performant.

### Surface Tiers
1. **Floor / Base Layer (`#121316`)**: The application viewport background.
2. **Resting Container Tier (`#1E2024`)**: Used for workout cards, chart containers, and routine headers. Framed by a 1px solid border of `#32353B`.
3. **Elevated Surface Tier (`#282A2F`)**: Input fields, active stepper buttons, and floating bottom interaction bars.
4. **Modal / Drawer Overlays (`#1E2024`)**: Floats over the floor with a 1px border of `#32353B` and an ultra-subtle, non-directional dark ambient veil (`rgba(0, 0, 0, 0.6)` backdrop with `rgba(0, 0, 0, 0.45)` 0px 8px 32px diffused shadow).

### Active & Focus States
- Interactive rows transition to an elevated highlight using `#282A2F` with no dimensional offset.
- Completed sets transition to a 20% opacity background state, ensuring active pending sets immediately command the athlete's optical attention.

## Shapes

The design system uses a calibrated roundedness balance (Level 2: `0.5rem` / 8px default radius) that conveys technical exactness without appearing aggressive or unfinished.

### Corner Radius System
- **Micro Radii (`0.25rem` / 4px)**: Checkbox indicators, internal set tags, micro metric pills, and column header highlights.
- **Component Radii (`0.5rem` / 8px)**: Input fields, quick-action stepper buttons, chips, and segmented control tabs.
- **Container Radii (`1rem` / 16px - `rounded-lg`)**: Primary exercise cards, graph modules, body measurement cards, and modular sheets.
- **Floating Modals & Bottom Sheets (`1.5rem` / 24px - `rounded-xl`)**: Top corners of bottom-anchored logging sheets and plate calculators.
- **Pill Shape (`9999px`)**: Reserved strictly for timer floating status badges, current set indicators, and floating pause/resume tokens.

## Components

### Buttons & Interactive Steppers
- **Primary CTA**: Solid `#FFFFFF` fill with `#121316` bold text (`Space Grotesk`, medium weight). Height: 48px. 8px border radius. Active state: `#E4E4E7`.
- **Secondary Action**: Background `#1E2024`, 1px border `#32353B`, text `#FFFFFF`.
- **Ghost / Destructive**: Background transparent, text `#9E9EA7`, hover/active `#282A2F`.
- **Numeric Quick Steppers (+/-)**: Square 40x40px or 44x44px blocks with `#282A2F` background and 1px border `#32353B`. Centered white glyph.

### Set Logging Row & Table
- **Header**: Compact 28px height, 11px uppercase `Geist` font in `#9E9EA7`. Columns: `SET`, `PREVIOUS`, `KG / LBS`, `REPS`, `✓`.
- **Default Row**: Height 44px, 1px bottom border `#1E2024`.
- **Active Row**: Background `#1E2024`, border-radius 6px, input fields highlighted with `#282A2F` surface.
- **Completed Row**: Row text transitions to `#9E9EA7` with the checkbox displaying an active desaturated silver or slate tone, visually fading into the background.

### Input Fields (Weight & Reps)
- Center-aligned numeric entry points. Background `#1E2024` (resting) or `#282A2F` (focused).
- 1px border of `#32353B`, transitioning to `#E4E4E7` on active focus.
- Placeholder text in `#9E9EA7` showing target or previous workout values for instantaneous recall.

### Checkboxes & State Completers
- 24x24px rounded square (4px radius).
- Unchecked: 1.5px border `#32353B`, transparent center.
- Checked: Solid `#E4E4E7` or `#849386` fill with an off-black `#121316` checkmark icon.

### Chips & Filter Pills
- Background `#1E2024`, border 1px `#32353B`, padding 6px 12px.
- Selected state: Background `#282A2F`, border `#E4E4E7`, text `#FFFFFF`.

### Cards & Workout Blocks
- Root container styling: `#1E2024` surface, 1px `#32353B` border, 16px radius (`rounded-lg`), padding `1rem`.
- Exercise header includes exercise name (`Space Grotesk`, 16px, `#FFFFFF`), equipment badge, and historical PR delta in `label-sm`.

### Rest Timer Floating Module
- Sticky bottom pill component (height 40px) with `#1E2024` background, 1px `#32353B` border, featuring a pulsing countdown display in `#FFFFFF` and quick `+30s` increment control.