import 'goals.dart';

class LoggedSet {
  final String exerciseId;
  final String exerciseName;
  final String setType;
  final double weightKg;
  final int reps;
  final int rir;
  final bool completed;
  final DateTime? endedAt;

  const LoggedSet({
    required this.exerciseId,
    required this.exerciseName,
    required this.setType,
    required this.weightKg,
    required this.reps,
    required this.rir,
    required this.completed,
    this.endedAt,
  });
}

class PersonalRecord {
  final String exerciseId;
  final String exerciseName;
  final double e1rm;
  final double weightKg;
  final int reps;
  final DateTime? achievedAt;

  const PersonalRecord({
    required this.exerciseId,
    required this.exerciseName,
    required this.e1rm,
    required this.weightKg,
    required this.reps,
    this.achievedAt,
  });
}

class ProfileStats {
  final int finishedSessions;
  final double totalVolumeKg;
  final int weekStreak;
  final List<PersonalRecord> records;

  const ProfileStats({
    required this.finishedSessions,
    required this.totalVolumeKg,
    required this.weekStreak,
    required this.records,
  });

  static const ProfileStats empty = ProfileStats(
    finishedSessions: 0,
    totalVolumeKg: 0,
    weekStreak: 0,
    records: <PersonalRecord>[],
  );
}

int finishedSessionCount(Iterable<String> statuses) {
  var count = 0;
  for (final status in statuses) {
    if (status == 'finished') count++;
  }
  return count;
}

double totalVolumeKg(Iterable<LoggedSet> sets) {
  var total = 0.0;
  for (final set in sets) {
    total += setVolumeKg(
      weightKg: set.weightKg,
      reps: set.reps,
      setType: set.setType,
      completed: set.completed,
    );
  }
  return total;
}

DateTime weekStart(DateTime value) {
  final day = DateTime(value.year, value.month, value.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

int weekStreak(Iterable<DateTime> sessionEnds, DateTime now) {
  final weeks = sessionEnds.map(weekStart).toSet();
  var cursor = weekStart(now);
  if (!weeks.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 7));
  }
  var streak = 0;
  while (weeks.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 7));
  }
  return streak;
}

List<PersonalRecord> personalRecords(Iterable<LoggedSet> sets) {
  final best = <String, ({PersonalRecord record, DateTime? date})>{};
  for (final set in sets) {
    if (!set.completed || set.setType == 'warmup') continue;
    final value = e1RM(weightKg: set.weightKg, reps: set.reps, rir: set.rir);
    if (value == null) continue;
    final current = best[set.exerciseId];
    if (current == null || value > current.record.e1rm) {
      best[set.exerciseId] = (
        record: PersonalRecord(
          exerciseId: set.exerciseId,
          exerciseName: set.exerciseName,
          e1rm: value,
          weightKg: set.weightKg,
          reps: set.reps,
          achievedAt: set.endedAt,
        ),
        date: set.endedAt,
      );
    }
  }
  return best.values.map((v) => v.record).toList();
}

bool isWithinMonth(DateTime? date, DateTime now) {
  if (date == null) return false;
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth =
      DateTime(now.year, now.month + 1, 1).subtract(const Duration(microseconds: 1));
  return !date.isBefore(startOfMonth) && !date.isAfter(endOfMonth);
}

String athleteLevel(int finishedSessions) {
  if (finishedSessions >= 150) return 'Élite';
  if (finishedSessions >= 50) return 'Avanzado';
  if (finishedSessions >= 10) return 'Intermedio';
  return 'Principiante';
}
