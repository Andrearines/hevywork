// Tendencia diaria de fatiga (spec 014, RF-9 parte de dominio). Lógica
// pura sin Flutter: reutiliza `muscleFatigue` de la 007 para evaluar el
// pico de cada día, sin migraciones ni tablas nuevas.

import 'muscle_fatigue.dart';

/// Punto de la tendencia: día (medianoche local) y valor de fatiga 0–1.
typedef FatigueTrendPoint = ({DateTime day, double value});

/// Ventana de la tendencia: los últimos 14 días (RF-9).
const int kFatigueTrendDays = 14;

/// Serie diaria de fatiga de los últimos [days] días, terminando hoy: un
/// punto por día con el pico de fatiga 0–1 de ese día, evaluado con
/// [muscleFatigue]. Si se indica [muscle], solo cuenta las series en las
/// que ese músculo canónico es primario o secundario y el valor del punto
/// es el suyo; sin filtro es el pico global de todos los músculos. Los días
/// sin aporte valen 0; sin series en la ventana se devuelve lista vacía.
List<FatigueTrendPoint> fatigueTrend({
  required Iterable<FatigueSet> sets,
  int days = kFatigueTrendDays,
  DateTime? now,
  String? muscle,
}) {
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);

  var source = sets;
  if (muscle != null) {
    source = source.where((set) => _touchesMuscle(set, muscle));
  }
  final all = source.toList();
  if (all.isEmpty) return const [];

  final points = <FatigueTrendPoint>[];
  for (var offset = days - 1; offset >= 0; offset--) {
    final day = today.subtract(Duration(days: offset));
    final nextDay = day.add(const Duration(days: 1));
    final daySets = all.where((set) {
      final at = set.endedAt;
      return !at.isBefore(day) && at.isBefore(nextDay);
    });
    final fatigue = muscleFatigue(sets: daySets, now: clock);
    final value = muscle == null
        ? _peak(fatigue.values)
        : (fatigue[muscle] ?? 0);
    points.add((day: day, value: value));
  }
  return points;
}

/// Máximo de una colección de valores; 0 si está vacía.
double _peak(Iterable<double> values) =>
    values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);

/// true si [set] aporta fatiga a [muscle] como primario (`target`) o como
/// secundario (`secondary_muscles`), usando las tablas de alias de la 007.
bool _touchesMuscle(FatigueSet set, String muscle) {
  if (kTargetMuscleAliases[set.target] == muscle) return true;
  for (final secondary in set.secondaryMuscles) {
    if (kMuscleAliases[secondary] == muscle) return true;
  }
  return false;
}
