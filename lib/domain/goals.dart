// Lógica pura de metas y progreso (spec 005, RF-1 a RF-4).
// Código en inglés; las etiquetas visibles al usuario viven en la UI.

/// Sesiones contadas en una meta de constancia (decisión de la tanda:
/// ventana móvil de 7 días).
const int kConsistencyWindowDays = 7;

/// Periodos de volumen (RF-1).
const int kVolumeWeekDays = 7;
const int kVolumeMonthDays = 30;

/// Tipos de meta soportados (RF-1).
const Set<String> kGoalTypes = {
  'bodyweight',
  'strength',
  'volume',
  'consistency',
};

/// Calcula el e1RM de una serie con la misma fórmula que WorkoutManager:
/// weight × (1 + (reps + rir)/30), válido solo con reps ≤ 12.
double? e1RM({
  required double weightKg,
  required int reps,
  required int rir,
}) {
  if (reps > 12 || weightKg <= 0 || reps <= 0) return null;
  if (reps == 1 && rir == 0) return weightKg;
  return weightKg * (1 + (reps + rir) / 30);
}

/// Volumen de una serie: excluye calentamientos y series sin completar;
/// las dropsets valen el 50 % (mismo criterio que WorkoutManager).
double setVolumeKg({
  required double weightKg,
  required int reps,
  required String setType,
  required bool completed,
}) {
  if (!completed || setType == 'warmup') return 0;
  if (reps <= 0 || weightKg <= 0) return 0;
  final volume = weightKg * reps;
  return setType == 'drop' ? volume * 0.5 : volume;
}

/// Mejor marca de e1RM (RF-3): máximo de los valores válidos, null si no
/// hay ninguno.
double? strengthBest(Iterable<double> values) {
  double? best;
  for (final value in values) {
    if (best == null || value > best) best = value;
  }
  return best;
}

/// Sesiones completadas en la ventana móvil de 7 días (decisión de la tanda
/// para `consistency`).
int consistencySessions(Iterable<DateTime> endedAts, DateTime now) {
  final since = now.subtract(const Duration(days: kConsistencyWindowDays));
  var count = 0;
  for (final endedAt in endedAts) {
    if (!endedAt.isBefore(since) && !endedAt.isAfter(now)) count++;
  }
  return count;
}

/// Último peso registrado (decide `measured_at` más reciente). Los registros
/// sin peso (solo medidas, spec 006) no cuentan.
double? latestBodyWeight(
  Iterable<({double? weightKg, DateTime measuredAt})> items,
) {
  ({double? weightKg, DateTime measuredAt})? latest;
  for (final item in items) {
    if (item.weightKg == null) continue;
    if (latest == null || item.measuredAt.isAfter(latest.measuredAt)) {
      latest = item;
    }
  }
  return latest?.weightKg;
}

/// ¿La meta se considera lograda con su valor actual? (RF-4).
///
/// La dirección de `bodyweight` sale del punto de partida: objetivo menor que
/// el peso inicial es pérdida (se logra ≤ objetivo); en cualquier otro caso
/// se logra alcanzando o superando el objetivo.
bool goalMet({
  required String type,
  required double? currentValue,
  required double targetValue,
  double? startValue,
}) {
  if (currentValue == null) return false;
  final isLoss = type == 'bodyweight' &&
      startValue != null &&
      targetValue < startValue;
  if (isLoss) return currentValue <= targetValue;
  return currentValue >= targetValue;
}

/// Progreso 0..1 para el dashboard (H3).
///
/// Para metas de pérdida de peso el avance es el cierre de brecha desde el
/// peso de partida hasta el objetivo; si no hay punto de partida, 0.
double goalProgress({
  required String type,
  required double? currentValue,
  required double targetValue,
  double? startValue,
}) {
  if (currentValue == null || targetValue <= 0) return 0;
  if (type == 'bodyweight' && startValue != null && targetValue < startValue) {
    final span = startValue - targetValue;
    if (span <= 0) return 0;
    final closed = startValue - currentValue;
    return (closed / span).clamp(0.0, 1.0);
  }
  return (currentValue / targetValue).clamp(0.0, 1.0);
}

/// Estado de la meta tras una evaluación (RF-3/RF-4). Los estados
/// `achieved` y `abandoned` son definitivos.
String evaluateGoalStatus({
  required String currentStatus,
  required String type,
  required double? currentValue,
  required double targetValue,
  double? startValue,
  required DateTime? deadline,
  required DateTime now,
}) {
  if (currentStatus != 'active') return currentStatus;
  if (goalMet(
    type: type,
    currentValue: currentValue,
    targetValue: targetValue,
    startValue: startValue,
  )) {
    return 'achieved';
  }
  if (deadline != null && !deadline.isAfter(now)) return 'abandoned';
  return 'active';
}