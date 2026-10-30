import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/domain/profile_stats.dart';

void main() {
  LoggedSet set({
    String exerciseId = 'bench',
    String exerciseName = 'Bench Press',
    String setType = 'normal',
    double weightKg = 60,
    int reps = 8,
    int rir = 2,
    bool completed = true,
    DateTime? endedAt,
  }) =>
      LoggedSet(
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        setType: setType,
        weightKg: weightKg,
        reps: reps,
        rir: rir,
        completed: completed,
        endedAt: endedAt,
      );

  group('finishedSessionCount', () {
    test('cuenta solo las sesiones terminadas', () {
      expect(
        finishedSessionCount(['finished', 'active', 'finished', 'abandoned']),
        2,
      );
    });

    test('sin sesiones devuelve cero', () {
      expect(finishedSessionCount(const <String>[]), 0);
    });
  });

  group('totalVolumeKg', () {
    test('excluye calentamientos y series no completadas', () {
      final total = totalVolumeKg([
        set(weightKg: 60, reps: 8),
        set(setType: 'warmup', weightKg: 40, reps: 10),
        set(completed: false, weightKg: 100, reps: 5),
      ]);
      expect(total, 480);
    });

    test('las dropsets valen la mitad', () {
      final total = totalVolumeKg([set(setType: 'drop', weightKg: 60, reps: 8)]);
      expect(total, 240);
    });
  });

  group('weekStreak', () {
    final now = DateTime(2026, 10, 9);

    test('cuenta semanas consecutivas terminando en la actual', () {
      final streak = weekStreak([
        now,
        now.subtract(const Duration(days: 7)),
        now.subtract(const Duration(days: 14)),
      ], now);
      expect(streak, 3);
    });

    test('la semana en curso vacía no rompe la racha', () {
      final streak = weekStreak([
        now.subtract(const Duration(days: 7)),
        now.subtract(const Duration(days: 14)),
      ], now);
      expect(streak, 2);
    });

    test('un hueco corta la racha', () {
      final streak = weekStreak([
        now,
        now.subtract(const Duration(days: 21)),
      ], now);
      expect(streak, 1);
    });

    test('sin sesiones devuelve cero', () {
      expect(weekStreak(const <DateTime>[], now), 0);
    });
  });

  group('personalRecords', () {
    test('guarda la mejor e1RM por ejercicio', () {
      final records = personalRecords([
        set(exerciseId: 'bench', weightKg: 60, reps: 8, rir: 2),
        set(exerciseId: 'bench', weightKg: 70, reps: 5, rir: 1),
        set(exerciseId: 'squat', weightKg: 100, reps: 5, rir: 2),
      ]);

      expect(records, hasLength(2));
      expect(records.first.exerciseId, 'bench');
      expect(records.first.weightKg, 70);
      expect(records.first.reps, 5);
      expect(records.first.e1rm, closeTo(84.0, 0.001));
    });

    test('ignora calentamientos, series incompletas y reps > 12', () {
      final records = personalRecords([
        set(setType: 'warmup', weightKg: 100, reps: 5),
        set(completed: false, weightKg: 100, reps: 5),
        set(weightKg: 100, reps: 20),
      ]);
      expect(records, isEmpty);
    });

    test('fecha el récords con endedAt de la serie que fija la marca', () {
      final bestAt = DateTime(2026, 10, 5, 18, 30);
      final later = DateTime(2026, 10, 20, 20, 0);
      final records = personalRecords([
        set(weightKg: 70, reps: 5, rir: 1, endedAt: bestAt),
        set(weightKg: 60, reps: 5, rir: 1, endedAt: later),
      ]);

      expect(records.single.achievedAt, bestAt);
    });

    test('una serie sin endedAt deja el récords sin fecha', () {
      final records = personalRecords([set(weightKg: 70, reps: 5, rir: 1)]);
      expect(records.single.achievedAt, isNull);
    });
  });

  group('isWithinMonth', () {
    final now = DateTime(2026, 10, 15);

    test('acepta cualquier día del mes civil actual', () {
      expect(isWithinMonth(DateTime(2026, 10, 1), now), isTrue);
      expect(isWithinMonth(DateTime(2026, 10, 31, 23, 59), now), isTrue);
      expect(isWithinMonth(now, now), isTrue);
    });

    test('rechaza el mes anterior, el siguiente y la fecha nula', () {
      expect(isWithinMonth(DateTime(2026, 9, 30, 23, 59, 59), now), isFalse);
      expect(isWithinMonth(DateTime(2026, 11, 1), now), isFalse);
      expect(isWithinMonth(null, now), isFalse);
    });

    test('no usa 30 días corridos: cruza el cambio de año', () {
      final startOfYear = DateTime(2027, 1, 1);
      expect(isWithinMonth(DateTime(2026, 12, 31), startOfYear), isFalse);
      expect(isWithinMonth(DateTime(2027, 1, 1), startOfYear), isTrue);
    });
  });

  group('athleteLevel', () {
    test('escala por número de sesiones', () {
      expect(athleteLevel(0), 'Principiante');
      expect(athleteLevel(10), 'Intermedio');
      expect(athleteLevel(50), 'Avanzado');
      expect(athleteLevel(150), 'Élite');
    });
  });
}
