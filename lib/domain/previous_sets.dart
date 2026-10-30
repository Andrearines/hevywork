/// Serie de una sesión anterior para la tabla de series en vivo (RF-14).
class HistorySet {
  final String exerciseId;
  final DateTime sessionEndedAt;
  final int setOrderIndex;
  final bool completed;
  final String setType;
  final double weightKg;
  final int reps;
  final int rir;

  const HistorySet({
    required this.exerciseId,
    required this.sessionEndedAt,
    required this.setOrderIndex,
    required this.completed,
    required this.setType,
    required this.weightKg,
    required this.reps,
    required this.rir,
  });
}

/// El «previo» de un ejercicio: peso × reps × RIR de la última serie
/// completada en la sesión anterior (RF-14).
class PreviousSet {
  final double weightKg;
  final int reps;
  final int rir;

  const PreviousSet({
    required this.weightKg,
    required this.reps,
    required this.rir,
  });
}

/// Series completadas de la sesión anterior más reciente, por ejercicio
/// (RF-14). Se ignora el calentamiento, igual que en el resto del dominio.
/// Las sesiones se pasan ordenadas de más reciente a más antigua; dentro de
/// una misma sesión se conserva el orden de las series.
Map<String, List<PreviousSet>> previousSessionSets(
  Iterable<HistorySet> sets, {
  required DateTime before,
}) {
  final byExercise = <String, List<HistorySet>>{};
  for (final set in sets) {
    if (!set.completed || set.setType == 'warmup') continue;
    if (!set.sessionEndedAt.isBefore(before)) continue;
    byExercise.putIfAbsent(set.exerciseId, () => []).add(set);
  }

  final result = <String, List<PreviousSet>>{};
  for (final entry in byExercise.entries) {
    final grouped = <DateTime, List<HistorySet>>{};
    for (final set in entry.value) {
      grouped.putIfAbsent(set.sessionEndedAt, () => []).add(set);
    }
    final lastEnd = grouped.keys.reduce(
      (a, b) => a.isAfter(b) ? a : b,
    );
    final lastSession = grouped[lastEnd]!
      ..sort((a, b) => a.setOrderIndex.compareTo(b.setOrderIndex));
    result[entry.key] = [
      for (final set in lastSession)
        PreviousSet(
          weightKg: set.weightKg,
          reps: set.reps,
          rir: set.rir,
        ),
    ];
  }
  return result;
}

/// Última serie completada de la sesión anterior del ejercicio (RF-14):
/// conveniencia para la píldora «Sesión previa» de la tarjeta.
PreviousSet? lastPreviousSet({
  required String exerciseId,
  required DateTime before,
  required Iterable<HistorySet> sets,
}) {
  final session = previousSessionSets(sets, before: before)[exerciseId];
  if (session == null || session.isEmpty) return null;
  return session.last;
}

/// El «previo» de la serie nº [setIndex] (1-based): la serie en esa misma
/// posición de la sesión anterior; si la sesión anterior tuvo menos series,
/// se repite la última.
PreviousSet? previousSetAt({
  required String exerciseId,
  required int setIndex,
  required DateTime before,
  required Iterable<HistorySet> sets,
}) {
  final session = previousSessionSets(sets, before: before)[exerciseId];
  if (session == null || session.isEmpty) return null;
  if (setIndex <= session.length) return session[setIndex - 1];
  return session.last;
}