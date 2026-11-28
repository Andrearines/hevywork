import 'muscle_fatigue.dart';

const List<String> customExerciseTargets = [
  'abductors',
  'abs',
  'adductors',
  'biceps',
  'calves',
  'cardiovascular system',
  'delts',
  'forearms',
  'glutes',
  'hamstrings',
  'lats',
  'levator scapulae',
  'pectorals',
  'quads',
  'serratus anterior',
  'spine',
  'traps',
  'triceps',
  'upper back',
];

final List<String> customExerciseSecondaryMuscles = {
  ...kMuscleAliases.keys,
  ...kMuscleAliases.values,
}.toList()..sort();

class CustomExerciseValidationException implements Exception {
  final String message;

  const CustomExerciseValidationException(this.message);

  @override
  String toString() => message;
}

class CustomExerciseDraft {
  final String name;
  final String bodyPart;
  final String equipment;
  final String target;
  final List<String> secondaryMuscles;
  final int restSeconds;

  const CustomExerciseDraft({
    required this.name,
    required this.bodyPart,
    required this.equipment,
    required this.target,
    this.secondaryMuscles = const [],
    this.restSeconds = 90,
  });

  CustomExerciseDraft copyWith({
    String? name,
    String? bodyPart,
    String? equipment,
    String? target,
    List<String>? secondaryMuscles,
    int? restSeconds,
  }) {
    return CustomExerciseDraft(
      name: name ?? this.name,
      bodyPart: bodyPart ?? this.bodyPart,
      equipment: equipment ?? this.equipment,
      target: target ?? this.target,
      secondaryMuscles: secondaryMuscles ?? this.secondaryMuscles,
      restSeconds: restSeconds ?? this.restSeconds,
    );
  }

  ValidatedCustomExercise validate() {
    final cleanName = name.trim();
    final cleanBodyPart = bodyPart.trim();
    final cleanEquipment = equipment.trim();
    if (cleanName.isEmpty) {
      throw const CustomExerciseValidationException(
        'Escribe el nombre del ejercicio',
      );
    }
    if (cleanBodyPart.isEmpty) {
      throw const CustomExerciseValidationException(
        'Escribe la parte del cuerpo',
      );
    }
    if (cleanEquipment.isEmpty) {
      throw const CustomExerciseValidationException('Escribe el equipo');
    }
    if (restSeconds < 15 || restSeconds > 300) {
      throw const CustomExerciseValidationException(
        'El descanso debe estar entre 15 y 300 segundos',
      );
    }

    final cleanTarget = _normalizeTarget(target);
    final cleanSecondary = <String>[];
    final seen = <String>{};
    final canonicalTarget = canonicalTargetMuscle(cleanTarget);
    for (final muscle in secondaryMuscles) {
      final normalized = _normalizeSecondary(muscle);
      final canonical = canonicalSecondaryMuscle(normalized);
      if (canonical == null) {
        throw const CustomExerciseValidationException(
          'Selecciona músculos secundarios conocidos',
        );
      }
      if (canonical == canonicalTarget || !seen.add(canonical)) {
        throw const CustomExerciseValidationException(
          'No repitas el objetivo ni los músculos secundarios',
        );
      }
      cleanSecondary.add(canonical);
    }

    return ValidatedCustomExercise(
      name: cleanName,
      bodyPart: cleanBodyPart,
      equipment: cleanEquipment,
      target: cleanTarget,
      secondaryMuscles: cleanSecondary,
      muscleGroup: cleanSecondary.isEmpty
          ? canonicalTarget ?? cleanTarget
          : cleanSecondary.first,
      restSeconds: restSeconds,
    );
  }
}

class ValidatedCustomExercise {
  final String name;
  final String bodyPart;
  final String equipment;
  final String target;
  final List<String> secondaryMuscles;
  final String muscleGroup;
  final int restSeconds;

  const ValidatedCustomExercise({
    required this.name,
    required this.bodyPart,
    required this.equipment,
    required this.target,
    required this.secondaryMuscles,
    required this.muscleGroup,
    required this.restSeconds,
  });
}

String _normalizeTarget(String value) {
  final normalized = value.trim().toLowerCase();
  const aliases = {
    'abdominals': 'abs',
    'chest': 'pectorals',
    'deltoids': 'delts',
    'latissimus dorsi': 'lats',
    'latissimus_dorsi': 'lats',
    'lower back': 'spine',
    'lower_back': 'spine',
    'obliques': 'serratus anterior',
    'pectoralis_major': 'pectorals',
    'quadriceps': 'quads',
    'rhomboids': 'upper back',
    'shoulders': 'delts',
    'trapezius': 'traps',
  };
  final target = aliases[normalized] ?? normalized;
  if (!customExerciseTargets.contains(target)) {
    throw const CustomExerciseValidationException(
      'Selecciona un músculo objetivo conocido',
    );
  }
  return target;
}

String _normalizeSecondary(String value) {
  final normalized = value.trim().toLowerCase();
  const aliases = {
    'abs': 'abdominals',
    'delts': 'shoulders',
    'latissimus_dorsi': 'latissimus dorsi',
    'pectoralis_major': 'chest',
    'pectorals': 'chest',
    'quads': 'quadriceps',
    'spine': 'lower back',
  };
  return aliases[normalized] ?? normalized;
}
