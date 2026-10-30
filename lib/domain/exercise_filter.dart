/// Dimensiones de filtro del catálogo (RF-3 de la 003).
enum ExerciseDimension { bodyPart, equipment, target, muscleGroup, secondaryMuscle }

/// Filtro combinado del catálogo (RF-3 de la 003). Varios valores de una
/// misma dimensión suman (OR); las dimensiones entre sí y con la búsqueda
/// por texto se multiplican (AND). Decisión registrada en la spec 003.
class ExerciseFilter {
  const ExerciseFilter({
    this.bodyParts = const {},
    this.equipment = const {},
    this.targets = const {},
    this.muscleGroups = const {},
    this.secondaryMuscles = const {},
  });

  final Set<String> bodyParts;
  final Set<String> equipment;
  final Set<String> targets;
  final Set<String> muscleGroups;
  final Set<String> secondaryMuscles;

  /// Número de valores seleccionados en total (RF-4: contador y botón
  /// "Limpiar filtros").
  int get activeCount =>
      bodyParts.length +
      equipment.length +
      targets.length +
      muscleGroups.length +
      secondaryMuscles.length;

  bool get isEmpty => activeCount == 0;

  /// Copia con la dimensión [dimension] reemplazada por [values].
  ExerciseFilter withDimension(ExerciseDimension dimension, Set<String> values) {
    switch (dimension) {
      case ExerciseDimension.bodyPart:
        return ExerciseFilter(
          bodyParts: values,
          equipment: equipment,
          targets: targets,
          muscleGroups: muscleGroups,
          secondaryMuscles: secondaryMuscles,
        );
      case ExerciseDimension.equipment:
        return ExerciseFilter(
          bodyParts: bodyParts,
          equipment: values,
          targets: targets,
          muscleGroups: muscleGroups,
          secondaryMuscles: secondaryMuscles,
        );
      case ExerciseDimension.target:
        return ExerciseFilter(
          bodyParts: bodyParts,
          equipment: equipment,
          targets: values,
          muscleGroups: muscleGroups,
          secondaryMuscles: secondaryMuscles,
        );
      case ExerciseDimension.muscleGroup:
        return ExerciseFilter(
          bodyParts: bodyParts,
          equipment: equipment,
          targets: targets,
          muscleGroups: values,
          secondaryMuscles: secondaryMuscles,
        );
      case ExerciseDimension.secondaryMuscle:
        return ExerciseFilter(
          bodyParts: bodyParts,
          equipment: equipment,
          targets: targets,
          muscleGroups: muscleGroups,
          secondaryMuscles: values,
        );
    }
  }

  /// Valores seleccionados en [dimension].
  Set<String> valuesOf(ExerciseDimension dimension) {
    switch (dimension) {
      case ExerciseDimension.bodyPart:
        return bodyParts;
      case ExerciseDimension.equipment:
        return equipment;
      case ExerciseDimension.target:
        return targets;
      case ExerciseDimension.muscleGroup:
        return muscleGroups;
      case ExerciseDimension.secondaryMuscle:
        return secondaryMuscles;
    }
  }
}