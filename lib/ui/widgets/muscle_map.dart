import 'package:flutter/material.dart';
import 'package:muscle_mapper/muscle_mapper.dart';

import '../../domain/muscle_map_adaptor.dart';
import '../theme/colors.dart';

// Colores de la escala de fatiga (spec 007, RF-2): 0 = #4A90E9 (frío),
// 0.5 = #F5A623 (tibio), 1 = #D0021B (rojo). Sin datos: gris neutro (RF-5).
const Color kFatigueCold = Color(0xFF4A90E9);
const Color kFatigueWarm = Color(0xFFF5A623);
const Color kFatigueHot = Color(0xFFD0021B);

/// Conjuntos de músculos canónicos para las vistas frontal y trasera (spec 016, RF-10).
/// Extraídos de `progress_view.dart` al widget compartido `view_toggle.dart`.
const Set<String> kFrontCanonicals = {
  'pectoralis_major',
  'deltoids',
  'biceps',
  'triceps',
  'forearms',
  'hands',
  'abdominals',
  'obliques',
  'quadriceps',
  'calves',
  'feet',
};

const Set<String> kBackCanonicals = {
  'deltoids',
  'triceps',
  'forearms',
  'hands',
  'hamstrings',
  'glutes',
  'calves',
  'latissimus_dorsi',
  'trapezius',
  'rhomboids',
  'lower_back',
};

/// Base neutra del mockup (#292A2D) para los músculos sin dato (RF-33).
const Color kMuscleBase = Color(0xFF292A2D);

/// Color del gradiente continuo frío→rojo para un valor 0–1 (RF-2).
Color fatigueColor(double value) {
  final v = value.clamp(0.0, 1.0);
  if (v <= 0.5) {
    return Color.lerp(kFatigueCold, kFatigueWarm, v / 0.5)!;
  }
  return Color.lerp(kFatigueWarm, kFatigueHot, (v - 0.5) / 0.5)!;
}

/// Etiqueta en español de un músculo canónico (solo presentación).
String muscleLabel(String muscle) => switch (muscle) {
      'abdominals' => 'Abdominales',
      'biceps' => 'Bíceps',
      'calves' => 'Gemelos',
      'deltoids' => 'Hombros',
      'feet' => 'Pies',
      'forearms' => 'Antebrazos',
      'glutes' => 'Glúteos',
      'hands' => 'Manos',
      'hamstrings' => 'Isquios',
      'latissimus_dorsi' => 'Dorsales',
      'lower_back' => 'Lumbar',
      'obliques' => 'Oblicuos',
      'pectoralis_major' => 'Pecho',
      'quadriceps' => 'Cuádriceps',
      'rhomboids' => 'Romboides',
      'trapezius' => 'Trapecio',
      'triceps' => 'Tríceps',
      _ => muscle,
    };

/// Teñe cada `Muscle` del paquete con el color de fatiga de su músculo
/// canónico (RF-33). Un canónico compartido entre vistas (p. ej. hombros)
/// teñe el mismo `Muscle` con el mismo color en ambas.
Map<Muscle, Color> buildMuscleColors(
  Map<String, double> fatigue, {
  required AnatomyView view,
}) {
  // Varios canónicos pueden compartir región (romboides y trapecio en la
  // espalda): la pinta el más cargado para que el color de la región nunca
  // contradiga el estado de su fila.
  final peak = <Muscle, double>{};
  for (final canonical in kCanonicalMuscles) {
    final value = fatigue[canonical];
    if (value == null) continue;
    for (final muscle in musclesForCanonical(canonical, view)) {
      final current = peak[muscle];
      if (current == null || value > current) peak[muscle] = value;
    }
  }
  return {
    for (final entry in peak.entries) entry.key: fatigueColor(entry.value),
  };
}

/// Regresa el músculo canónico (spec 007) que cubre el `Muscle` pulsado en
/// la vista dada; si ninguno, el nombre del grupo como etiqueta cruda.
String canonicalOfMuscle(Muscle muscle, AnatomyView view) {
  for (final canonical in kCanonicalMuscles) {
    if (musclesForCanonical(canonical, view).contains(muscle)) return canonical;
  }
  return muscle.group.name;
}

/// Mapa muscular vectorial (spec 007 + spec 008, RF-33): adaptador sobre
/// `muscle_mapper`. Cada región canónica se tiñe con su color de fatiga
/// frío→rojo; sin dato usa la base neutra. El toque devuelve el músculo
/// canónico de la región pulsada para sincronizar con la lista de zonas.
class MuscleMap extends StatelessWidget {
  final Map<String, double> fatigue;
  final bool showBack;
  final double height;

  /// Región canónica resaltada (seleccionada) sobre el color de fatiga.
  final String? selected;

  /// Se dispara con el músculo canónico pulsado; null lo deja no interactivo.
  final ValueChanged<String>? onMuscleTapped;

  const MuscleMap({
    super.key,
    this.fatigue = const {},
    this.showBack = false,
    this.height = 300,
    this.selected,
    this.onMuscleTapped,
  });

  @override
  Widget build(BuildContext context) {
    final view = showBack ? AnatomyView.back : AnatomyView.front;
    final selectedMuscles = selected == null
        ? const <Muscle>{}
        : musclesForCanonical(selected!, view).toSet();
    // La selección siempre se ve: el paquete da prioridad a `muscleColors`,
    // así que el músculo elegido se retira del color de fatiga para que se
    // pinte con `highlightColor` (blanco) sobre cualquier estado.
    final allColors = buildMuscleColors(fatigue, view: view);
    final intensities = {
      for (final muscle in allColors.keys) muscle: 1.0,
    };
    final colors = {...allColors}
      ..removeWhere((muscle, _) => selectedMuscles.contains(muscle));

    return RepaintBoundary(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: MuscleMapper(
          view: view,
          gender: AnatomyGender.male,
          assetProvider:
              const DefaultAnatomyProvider(style: AnatomyStyle.minimal),
          baseColor: kMuscleBase,
          highlightColor: kOnSurface,
          muscleColors: colors,
          muscleIntensities: intensities,
          activeMuscles: selectedMuscles,
          animationDuration: Duration.zero,
          loadingWidget: const SizedBox(height: 300),
          onMuscleTapped: onMuscleTapped == null
              ? null
              : (muscle) => onMuscleTapped!(
                    canonicalOfMuscle(muscle, view),
                  ),
        ),
      ),
    );
  }
}
