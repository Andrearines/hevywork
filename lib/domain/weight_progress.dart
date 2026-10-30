import 'dart:math' as math;

import 'units.dart';

/// Ritmo semanal del peso (kg/semana) por mínimos cuadrados sobre los
/// puntos del rango, en orden ascendente (RF-23). Con menos de dos puntos
/// o sin dispersión de fechas el ritmo es 0.
double weeklyRateKg(List<({DateTime date, double weightKg})> points) {
  if (points.length < 2) return 0;
  final first = points.first.date;
  final xs = [
    for (final point in points) point.date.difference(first).inDays.toDouble(),
  ];
  final ys = [for (final point in points) point.weightKg];
  final meanX = xs.reduce((a, b) => a + b) / xs.length;
  final meanY = ys.reduce((a, b) => a + b) / ys.length;
  var numerator = 0.0;
  var denominator = 0.0;
  for (var i = 0; i < xs.length; i++) {
    final dx = xs[i] - meanX;
    numerator += dx * (ys[i] - meanY);
    denominator += dx * dx;
  }
  if (denominator == 0) return 0;
  return numerator / denominator * 7;
}

/// Media móvil trailing con la ventana dada (misma longitud que la serie;
/// los primeros puntos usan la ventana disponible) (RF-23).
List<double> movingAverageKg(
  List<({DateTime date, double weightKg})> points, {
  int window = 3,
}) {
  final result = <double>[];
  var sum = 0.0;
  for (var i = 0; i < points.length; i++) {
    sum += points[i].weightKg;
    if (i >= window) sum -= points[i - window].weightKg;
    result.add(sum / math.min(i + 1, window));
  }
  return result;
}

/// Punto proyectado al cumplimiento de la meta (RF-23): sigue el ritmo
/// semanal actual hasta el plazo y se acota en la meta si lo cruzaría.
/// Devuelve null cuando no hay plazo futuro, no hay ritmo o no hay datos.
({DateTime date, double weightKg})? projectToGoal({
  required List<({DateTime date, double weightKg})> points,
  required double goalKg,
  DateTime? deadline,
  DateTime? now,
}) {
  if (points.length < 2 || deadline == null) return null;
  final last = points.last;
  final start = now == null || now.isBefore(last.date) ? last.date : now;
  if (!deadline.isAfter(start)) return null;
  final rate = weeklyRateKg(points);
  if (rate == 0) return null;
  final days = deadline.difference(start).inDays;
  final projected = last.weightKg + rate * days / 7;
  final crosses = (rate < 0 && projected < goalKg) ||
      (rate > 0 && projected > goalKg);
  return (date: deadline, weightKg: crosses ? goalKg : projected);
}

/// Delta de peso con signo y una decimal en la unidad del sistema
/// («-1.2 kg», «+0.4 lb»).
String kgDeltaLabel(double deltaKg, {String unitSystem = 'metric'}) {
  final value = displayWeightKg(deltaKg, unitSystem);
  final text = value.toStringAsFixed(1);
  return '${value > 0 ? '+' : ''}$text ${weightUnitOf(unitSystem)}';
}
