# Plan de Desarrollo — hevywork

Este documento define la arquitectura general y el orden de implementación del proyecto hevywork, estructurado en base a las especificaciones de `docs/specs/`.

## Arquitectura Base

- **Framework**: Flutter (multiplataforma).
- **Backend Remoto**: Supabase Postgres (única fuente de la verdad permanente).
- **Base de Datos Local**: SQLite a través de `drift` (réplica de trabajo y cola de sincronización).
- **Estado y Lógica**: Dominio puro testeable; widgets Flutter separados de la lógica de negocio.
- **Estilo Visual**: Obsidian Kinetic (definido en `designer.md`), UI construida a medida (sin librerías de componentes complejas que rompan el minimalismo).

## Fases del Desarrollo

### Fase 1: El Núcleo de Entrenamiento (Spec 001)
El objetivo de esta fase es lograr que el usuario pueda abrir la app sin internet, iniciar un entrenamiento, registrar series con el catálogo local y que todo se sincronice silenciosamente cuando haya conexión a Supabase.
- Inicialización de la base de datos local y carga del catálogo de ejercicios.
- Modelo de datos para la sesión de entrenamiento y series.
- Sistema de cola de sincronización bidireccional (con Supabase).
- Autenticación básica y migración de datos locales al usuario logueado (`claim_local_data`).

### Fase 2: Experiencia de Entrenamiento Fluida (Spec 002 & 003)
Una vez que el núcleo sincroniza, se debe mejorar la experiencia in-app del entrenamiento en curso.
- **Spec 002**: Poder deshacer/editar series ya marcadas, temporizador de descanso, reanudación automática si la app se cierra por el sistema operativo.
- **Spec 003**: Buscador y filtros combinados (músculo, equipo, categoría) ultra rápidos sobre el catálogo local.

### Fase 3: Planificación y Metas (Spec 004, 005, 006)
Convertir el tracker en un gestor completo de progreso.
- **Spec 004**: Rutinas y plantillas, que faciliten iniciar entrenamientos preconfigurados con sugerencia de sobrecarga progresiva.
- **Spec 005**: Objetivos y metas concretas (e.g., llegar a 100kg en press de banca), calculados en background al cerrar sesiones.
- **Spec 006**: Registro de peso corporal y medidas antropométricas con gráficas de tendencia temporal.

### Fase 4: Inteligencia Visual (Spec 007)
Implementación del rasgo distintivo de la aplicación.
- **Spec 007**: Mapa muscular vectorial generado mediante `CustomPainter`. Coloreado termal basado en una fórmula de fatiga que pondera volumen reciente, tipo de serie y tiempo de decaimiento.

## Reglas de Ejecución

1. Ninguna fase avanza sin cumplir la `constitucion.md` y el `designer.md`.
2. Las pruebas automáticas (`flutter test`) y el análisis (`flutter analyze`) son compuertas de seguridad obligatorias al finalizar cada tarea.
