import 'package:muscle_mapper/muscle_mapper.dart';

/// Músculos canónicos de la spec 007 (los 15 del dominio). El dominio no
/// cambia: sigue exponiendo `Map<String, double>`; aquí se traducen a los
/// enums del paquete `muscle_mapper`.
const List<String> kCanonicalMuscles = [
  'pectoralis_major',
  'deltoids',
  'biceps',
  'triceps',
  'forearms',
  'abdominals',
  'obliques',
  'quadriceps',
  'hamstrings',
  'glutes',
  'calves',
  'latissimus_dorsi',
  'trapezius',
  'rhomboids',
  'lower_back',
  'hands',
  'feet',
];

/// Grupos del paquete visibles en la vista frontal (los del mockup Frente).
const Set<MuscleGroup> kFrontGroups = {
  MuscleGroup.chest,
  MuscleGroup.deltoids,
  MuscleGroup.biceps,
  MuscleGroup.triceps,
  MuscleGroup.forearms,
  MuscleGroup.abs,
  MuscleGroup.obliques,
  MuscleGroup.quads,
  MuscleGroup.calves,
  MuscleGroup.hands,
  MuscleGroup.feet,
};

/// Grupos del paquete visibles en la vista trasera (los del mockup Espalda).
const Set<MuscleGroup> kBackGroups = {
  MuscleGroup.deltoids,
  MuscleGroup.triceps,
  MuscleGroup.forearms,
  MuscleGroup.hamstrings,
  MuscleGroup.glutes,
  MuscleGroup.calves,
  MuscleGroup.lats,
  MuscleGroup.traps,
  MuscleGroup.lowerBack,
  MuscleGroup.hands,
};

/// Traduce un músculo canónico (spec 007) a los grupos del paquete que lo
/// representan. Los antebrazos y los gemelos aparecen en frente y espalda.
Set<MuscleGroup> muscleGroupsFor(String canonical) => switch (canonical) {
      'pectoralis_major' => {MuscleGroup.chest},
      'deltoids' => {MuscleGroup.deltoids},
      'biceps' => {MuscleGroup.biceps},
      'triceps' => {MuscleGroup.triceps},
      'forearms' => {MuscleGroup.forearms},
      'abdominals' => {MuscleGroup.abs},
      'obliques' => {MuscleGroup.obliques},
      'quadriceps' => {MuscleGroup.quads},
      'hamstrings' => {MuscleGroup.hamstrings},
      'glutes' => {MuscleGroup.glutes},
      'calves' => {MuscleGroup.calves},
      'latissimus_dorsi' => {MuscleGroup.lats},
      'trapezius' => {MuscleGroup.traps},
      // Sin grupo propio en el paquete: los romboides viven bajo la
      // espalda media, en la región de los trapecios (no en los dorsales).
      'rhomboids' => {MuscleGroup.traps},
      'lower_back' => {MuscleGroup.lowerBack},
      'hands' => {MuscleGroup.hands},
      // Los pies solo tienen región en la vista frontal del SVG.
      'feet' => {MuscleGroup.feet},
      _ => const <MuscleGroup>{},
    };

/// Desdobla los grupos de un canónico en los `Muscle` individuales del
/// paquete, filtrados por la vista en la que pinta. Es la superficie que
/// consume el widget `MuscleMapper` (trabaja con `Muscle`, no con grupos).
Set<Muscle> musclesForCanonical(String canonical, AnatomyView view) {
  final visible =
      view == AnatomyView.front ? kFrontGroups : kBackGroups;
  final result = <Muscle>{};
  for (final group in muscleGroupsFor(canonical)) {
    if (!visible.contains(group)) continue;
    result.addAll(group.subMuscles);
  }
  return result;
}
