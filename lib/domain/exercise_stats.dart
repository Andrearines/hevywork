import 'goals.dart';

enum ExerciseProgressMetric { e1rm, load, volume }

class ExerciseSetRow {
  final int orderIndex;
  final String setType;
  final double weightKg;
  final int reps;
  final int? rir;
  final bool completed;

  const ExerciseSetRow({
    required this.orderIndex,
    required this.setType,
    required this.weightKg,
    required this.reps,
    this.rir,
    this.completed = true,
  });

  bool get countsForStats => completed && setType != 'warmup';

  double? get e1rm => e1RM(weightKg: weightKg, reps: reps, rir: rir ?? 0);
}

class ExerciseSessionSummary {
  final String workoutId;
  final String? name;
  final DateTime endedAt;
  final List<ExerciseSetRow> sets;

  const ExerciseSessionSummary({
    required this.workoutId,
    required this.name,
    required this.endedAt,
    required this.sets,
  });

  int get completedSetCount {
    var count = 0;
    for (final set in sets) {
      if (set.countsForStats) count++;
    }
    return count;
  }

  double get volumeKg {
    var volume = 0.0;
    for (final set in sets) {
      volume += setVolumeKg(
        weightKg: set.weightKg,
        reps: set.reps,
        setType: set.setType,
        completed: set.completed,
      );
    }
    return volume;
  }

  double? get rirMean => sessionRirMean(sets);
}

class ExerciseTopSet {
  final double weightKg;
  final int reps;
  final int? rir;
  final DateTime achievedAt;

  const ExerciseTopSet({
    required this.weightKg,
    required this.reps,
    required this.rir,
    required this.achievedAt,
  });
}

class ExerciseKpis {
  final double? bestE1rm;
  final DateTime? bestE1rmAt;
  final double? secondBestE1rm;
  final ExerciseTopSet? topSet;
  final double? maxSessionVolume;
  final int maxSessionVolumeSets;
  final int totalSets;
  final int sessionCount;

  const ExerciseKpis({
    required this.bestE1rm,
    required this.bestE1rmAt,
    required this.secondBestE1rm,
    required this.topSet,
    required this.maxSessionVolume,
    required this.maxSessionVolumeSets,
    required this.totalSets,
    required this.sessionCount,
  });

  static const empty = ExerciseKpis(
    bestE1rm: null,
    bestE1rmAt: null,
    secondBestE1rm: null,
    topSet: null,
    maxSessionVolume: null,
    maxSessionVolumeSets: 0,
    totalSets: 0,
    sessionCount: 0,
  );
}

typedef ExerciseSessionPoint = ({DateTime date, double value});

class PeriodDelta {
  final double absolute;
  final double? percent;

  const PeriodDelta({required this.absolute, this.percent});
}

ExerciseKpis exerciseKpis(Iterable<ExerciseSessionSummary> sessions) {
  final e1rms = <({double value, DateTime date})>[];
  ExerciseTopSet? topSet;
  var totalSets = 0;
  var sessionCount = 0;
  double? maxSessionVolume;
  var maxSessionVolumeSets = 0;

  for (final session in sessions) {
    sessionCount++;
    var sessionSets = 0;

    for (final set in session.sets) {
      if (!set.countsForStats) continue;
      sessionSets++;
      totalSets++;

      final value = set.e1rm;
      if (value != null) {
        e1rms.add((value: value, date: session.endedAt));
      }

      if (set.weightKg > 0 && set.reps > 0) {
        final better =
            topSet == null ||
            set.weightKg > topSet.weightKg ||
            (set.weightKg == topSet.weightKg && set.reps > topSet.reps);
        if (better) {
          topSet = ExerciseTopSet(
            weightKg: set.weightKg,
            reps: set.reps,
            rir: set.rir,
            achievedAt: session.endedAt,
          );
        }
      }
    }

    if (sessionSets > 0) {
      final volume = session.volumeKg;
      if (maxSessionVolume == null || volume > maxSessionVolume) {
        maxSessionVolume = volume;
        maxSessionVolumeSets = sessionSets;
      }
    }
  }

  double? bestE1rm;
  DateTime? bestE1rmAt;
  double? secondBestE1rm;
  if (e1rms.isNotEmpty) {
    e1rms.sort((a, b) {
      final byValue = b.value.compareTo(a.value);
      if (byValue != 0) return byValue;
      return a.date.compareTo(b.date);
    });
    bestE1rm = e1rms.first.value;
    bestE1rmAt = e1rms.first.date;
    if (e1rms.length > 1) secondBestE1rm = e1rms[1].value;
  }

  return ExerciseKpis(
    bestE1rm: bestE1rm,
    bestE1rmAt: bestE1rmAt,
    secondBestE1rm: secondBestE1rm,
    topSet: topSet,
    maxSessionVolume: maxSessionVolume,
    maxSessionVolumeSets: maxSessionVolumeSets,
    totalSets: totalSets,
    sessionCount: sessionCount,
  );
}

List<ExerciseSessionPoint> exerciseProgressPoints(
  Iterable<ExerciseSessionSummary> sessions, {
  required ExerciseProgressMetric metric,
}) {
  final points = <ExerciseSessionPoint>[];
  for (final session in sessions) {
    final value = _sessionMetric(session, metric);
    if (value == null) continue;
    points.add((date: session.endedAt, value: value));
  }
  points.sort((a, b) => a.date.compareTo(b.date));
  return points;
}

double? _sessionMetric(
  ExerciseSessionSummary session,
  ExerciseProgressMetric metric,
) {
  switch (metric) {
    case ExerciseProgressMetric.e1rm:
      double? best;
      for (final set in session.sets) {
        if (!set.countsForStats) continue;
        final value = set.e1rm;
        if (value == null) continue;
        if (best == null || value > best) best = value;
      }
      return best;
    case ExerciseProgressMetric.load:
      double? best;
      for (final set in session.sets) {
        if (!set.countsForStats) continue;
        if (set.weightKg <= 0 || set.reps <= 0) continue;
        if (best == null || set.weightKg > best) best = set.weightKg;
      }
      return best;
    case ExerciseProgressMetric.volume:
      if (session.sets.every((set) => !set.countsForStats)) return null;
      return session.volumeKg;
  }
}

PeriodDelta? periodDelta(Iterable<ExerciseSessionPoint> points) {
  final sorted = points.toList()..sort((a, b) => a.date.compareTo(b.date));
  if (sorted.length < 2) return null;

  final first = sorted.first;
  final absolute = sorted.last.value - first.value;
  return PeriodDelta(
    absolute: absolute,
    percent: first.value == 0 ? null : absolute / first.value * 100,
  );
}

double weeklyFrequency({required int sessionCount, required int windowDays}) {
  if (sessionCount <= 0 || windowDays <= 0) return 0;
  return sessionCount / (windowDays / 7);
}

double? sessionRirMean(Iterable<ExerciseSetRow> sets) {
  var total = 0;
  var count = 0;
  for (final set in sets) {
    if (!set.countsForStats || set.rir == null) continue;
    total += set.rir!;
    count++;
  }
  return count == 0 ? null : total / count;
}
