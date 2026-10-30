import 'dart:math' as math;

/// Enfoque de una sesión derivada de los músculos de sus ejercicios (RF-20).
enum SessionFocus { push, pull, legs, core }

/// Clasifica un ejercicio por su grupo muscular (con el objetivo principal
/// como respaldo) en uno de los cuatro enfoques de sesión del desglose.
SessionFocus focusOfExercise({required String muscleGroup, String? target}) {
  final byGroup = _classify(_normalizeKey(muscleGroup));
  if (byGroup != null) return byGroup;
  if (target == null) return SessionFocus.core;
  return _classify(_normalizeKey(target)) ?? SessionFocus.core;
}

SessionFocus? _classify(String key) {
  for (final entry in _focusKeys.entries) {
    if (entry.value.contains(key)) return entry.key;
  }
  return null;
}

const Map<SessionFocus, Set<String>> _focusKeys = {
  SessionFocus.push: {
    'chest',
    'pectorals',
    'shoulders',
    'deltoids',
    'delts',
    'triceps',
    'serratusanterior',
    'rotatorcuff',
  },
  SessionFocus.pull: {
    'back',
    'lats',
    'latissimusdorsi',
    'upperback',
    'middleback',
    'biceps',
    'forearms',
    'trapezius',
    'traps',
    'rhomboids',
    'lowerback',
    'wristflexors',
    'wristextensors',
    'wrists',
    'hands',
    'levatorscapulae',
  },
  SessionFocus.legs: {
    'quadriceps',
    'quads',
    'hamstrings',
    'glutes',
    'calves',
    'soleus',
    'hipflexors',
    'adductors',
    'abductors',
    'ankles',
    'anklestabilizers',
  },
  SessionFocus.core: {
    'abdominals',
    'abs',
    'obliques',
    'core',
    'spine',
    'cardio',
    'cardiovascularsystem',
  },
};

/// Nombre corto en español de un enfoque de sesión.
String focusLabel(SessionFocus focus) => switch (focus) {
      SessionFocus.push => 'Empuje',
      SessionFocus.pull => 'Tracción',
      SessionFocus.legs => 'Pierna',
      SessionFocus.core => 'Core',
    };

/// Etiqueta en español del objetivo muscular del catálogo (sin huecos: lo
/// que no se conoce se muestra tal cual).
String muscleTargetLabel(String target) =>
    _targetLabels[_normalizeKey(target)] ?? target;

const Map<String, String> _targetLabels = {
  'abs': 'Abdominales',
  'pectorals': 'Pecho',
  'biceps': 'Bíceps',
  'glutes': 'Glúteos',
  'delts': 'Hombros',
  'triceps': 'Tríceps',
  'upperback': 'Espalda alta',
  'lats': 'Dorsal',
  'calves': 'Gemelos',
  'quads': 'Cuádriceps',
  'forearms': 'Antebrazos',
  'cardiovascularsystem': 'Cardio',
  'hamstrings': 'Isquios',
  'spine': 'Columna',
  'traps': 'Trapecio',
  'adductors': 'Aductores',
  'serratusanterior': 'Serrato',
  'abductors': 'Abductores',
  'levatorscapulae': 'Escápula',
};

String _normalizeKey(String value) =>
    value.toLowerCase().replaceAll(RegExp('[^a-z]'), '');

/// Fila del desglose de sesiones de una rutina (RF-20).
class SessionRow {
  final SessionFocus focus;

  /// Día de la semana al que se reparte la sesión («Hoy», «Mañana»…).
  final String dayLabel;

  /// Músculos principales traducidos, en orden de aparición.
  final String muscles;
  final int exerciseCount;

  const SessionRow({
    required this.focus,
    required this.dayLabel,
    required this.muscles,
    required this.exerciseCount,
  });

  String get title => focusLabel(focus);

  String get detail =>
      '$muscles · $exerciseCount ${exerciseCount == 1 ? 'ejercicio' : 'ejercicios'}';
}

const List<String> _dayNames = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

/// Desglose de sesiones derivado de los músculos de los ejercicios (RF-20):
/// agrupa por enfoque en orden de aparición y reparte los enfoques a lo
/// largo de la semana según la frecuencia objetivo de la rutina.
List<SessionRow> buildSessionBreakdown({
  required List<({String muscleGroup, String target})> exercises,
  int? targetDays,
  DateTime? today,
}) {
  if (exercises.isEmpty) return const [];
  final now = today ?? DateTime.now();
  final order = <SessionFocus>[];
  final grouped = <SessionFocus, List<String>>{};
  for (final exercise in exercises) {
    final focus = focusOfExercise(
      muscleGroup: exercise.muscleGroup,
      target: exercise.target,
    );
    grouped.putIfAbsent(focus, () {
      order.add(focus);
      return [];
    }).add(exercise.target);
  }

  final step =
      targetDays == null || targetDays < 1 ? 1 : math.max(1, 7 ~/ targetDays);
  final rows = <SessionRow>[];
  for (var i = 0; i < order.length; i++) {
    final focus = order[i];
    final targets = grouped[focus]!;
    final distinct = <String>[];
    for (final target in targets) {
      final label = muscleTargetLabel(target);
      if (!distinct.contains(label)) distinct.add(label);
    }
    final offset = i * step;
    final dayLabel = offset == 0
        ? 'Hoy'
        : offset == 1
            ? 'Mañana'
            : _dayNames[now.add(Duration(days: offset)).weekday - 1];
    rows.add(
      SessionRow(
        focus: focus,
        dayLabel: dayLabel,
        muscles: distinct.take(3).join(', '),
        exerciseCount: targets.length,
      ),
    );
  }
  return rows;
}

/// Volumen medio por sesión: series planificadas repartidas entre los
/// ejercicios de la rutina.
int avgSetsPerSession({required int totalSets, required int exerciseCount}) =>
    exerciseCount < 1 ? 0 : totalSets ~/ exerciseCount;

/// Etiqueta del rango de RIR planificado; null si no hay series con RIR.
String? rirRangeLabel(int? minRir, int? maxRir) {
  if (minRir == null || maxRir == null) return null;
  return minRir == maxRir ? 'RIR $minRir' : 'RIR $minRir - $maxRir';
}

/// Texto del footer «Último uso …» (RF-20); null si nunca se usó, para no
/// mostrar huecos.
String? lastUsedFooter(DateTime lastUsed, {DateTime? now}) {
  final days = (now ?? DateTime.now()).difference(lastUsed).inDays;
  if (days < 1) return 'Último uso hoy';
  if (days < 30) {
    return 'Último uso hace $days ${days == 1 ? 'día' : 'días'}';
  }
  final months = math.max(1, (days / 30).round());
  return 'Último uso hace $months ${months == 1 ? 'mes' : 'meses'}';
}

/// Filtros de categoría del mockup (RF-19): etiqueta mostrada y clave
/// canónica contra la que se normaliza `routines.category`.
const List<({String label, String key})> kRoutineCategoryFilters = [
  (label: 'PPL', key: 'ppl'),
  (label: 'Torso / Pierna', key: 'torsopierna'),
  (label: 'Fuerza / Hipertrofia', key: 'fuerza'),
];

/// Clave de filtro de una categoría guardada (vacío si no hay categoría).
String normalizeCategory(String? category) =>
    category == null ? '' : _normalizeKey(category);
