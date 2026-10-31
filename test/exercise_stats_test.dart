import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/domain/exercise_stats.dart';

void main() {
  ExerciseSetRow set({
    double weightKg = 100,
    int reps = 5,
    int? rir = 2,
    String setType = 'normal',
    bool completed = true,
  }) =>
      ExerciseSetRow(
        orderIndex: 1,
        setType: setType,
        weightKg: weightKg,
        reps: reps,
        rir: rir,
        completed: completed,
      );

  ExerciseSessionSummary session({
    String workoutId = 'w1',
    String? name,
    DateTime? endedAt,
    List<ExerciseSetRow>? sets,
  }) =>
      ExerciseSessionSummary(
        workoutId: workoutId,
        name: name,
        endedAt: endedAt ?? DateTime(2026, 10, 1),
        sets: sets ?? [set()],
      );

  group('exerciseKpis', () {
    test('sin sesiones devuelve nulls y contadores a cero', () {
      final kpis = exerciseKpis(const []);

      expect(kpis.bestE1rm, isNull);
      expect(kpis.bestE1rmAt, isNull);
      expect(kpis.secondBestE1rm, isNull);
      expect(kpis.topSet, isNull);
      expect(kpis.maxSessionVolume, isNull);
      expect(kpis.maxSessionVolumeSets, 0);
      expect(kpis.totalSets, 0);
      expect(kpis.sessionCount, 0);
    });

    test('con solo calentamientos o incompletas no hay KPIs', () {
      final kpis = exerciseKpis([
        session(
          sets: [
            set(setType: 'warmup', weightKg: 100),
            set(completed: false, weightKg: 100),
          ],
        ),
      ]);

      expect(kpis.bestE1rm, isNull);
      expect(kpis.secondBestE1rm, isNull);
      expect(kpis.topSet, isNull);
      expect(kpis.maxSessionVolume, isNull);
      expect(kpis.totalSets, 0);
      expect(kpis.sessionCount, 1);
    });

    test('mejor y segundo mejor e1RM ignoran series no válidas', () {
      final kpis = exerciseKpis([
        session(
          workoutId: 'w1',
          endedAt: DateTime(2026, 10, 1),
          sets: [
            set(weightKg: 80, reps: 5, rir: 2),
            set(setType: 'warmup', weightKg: 200, reps: 5, rir: 0),
          ],
        ),
        session(
          workoutId: 'w2',
          endedAt: DateTime(2026, 10, 5),
          sets: [
            set(weightKg: 90, reps: 3, rir: 1),
            set(completed: false, weightKg: 150, reps: 5),
          ],
        ),
        session(
          workoutId: 'w3',
          endedAt: DateTime(2026, 10, 8),
          sets: [
            set(weightKg: 85, reps: 5, rir: 0),
            set(weightKg: 100, reps: 20),
            set(weightKg: 0, reps: 10),
          ],
        ),
      ]);

      expect(kpis.bestE1rm, closeTo(102.0, 1e-9));
      expect(kpis.bestE1rmAt, DateTime(2026, 10, 5));
      expect(kpis.secondBestE1rm, closeTo(85 * 35 / 30, 1e-9));
      expect(kpis.totalSets, 5);
      expect(kpis.sessionCount, 3);
    });

    test('sin segunda marca válida secondBestE1rm es null', () {
      final kpis = exerciseKpis([
        session(sets: [set(weightKg: 90, reps: 3, rir: 1)]),
      ]);

      expect(kpis.bestE1rm, closeTo(102.0, 1e-9));
      expect(kpis.secondBestE1rm, isNull);
    });

    test('topSet es la mayor serie completada sin calentamiento', () {
      final kpis = exerciseKpis([
        session(
          endedAt: DateTime(2026, 10, 5),
          sets: [
            set(weightKg: 0, reps: 12),
            set(weightKg: 100, reps: 8, rir: 2),
            set(weightKg: 100, reps: 10, rir: 1),
            set(weightKg: 95, reps: 12, setType: 'drop'),
            set(weightKg: 120, reps: 5, setType: 'warmup'),
            set(weightKg: 110, reps: 5, completed: false),
          ],
        ),
      ]);

      expect(kpis.topSet, isNotNull);
      expect(kpis.topSet!.weightKg, 100);
      expect(kpis.topSet!.reps, 10);
      expect(kpis.topSet!.rir, 1);
      expect(kpis.topSet!.achievedAt, DateTime(2026, 10, 5));
    });

    test('topSet es null sin series con peso', () {
      final kpis = exerciseKpis([
        session(sets: [set(weightKg: 0, reps: 12)]),
      ]);

      expect(kpis.topSet, isNull);
      expect(kpis.bestE1rm, isNull);
      expect(kpis.totalSets, 1);
    });

    test('maxSessionVolume usa setVolumeKg y cuenta sus series', () {
      final kpis = exerciseKpis([
        session(
          workoutId: 'w1',
          endedAt: DateTime(2026, 10, 1),
          sets: [
            set(weightKg: 100, reps: 5),
            set(weightKg: 80, reps: 5, setType: 'drop'),
            set(weightKg: 50, reps: 10, setType: 'warmup'),
          ],
        ),
        session(
          workoutId: 'w2',
          endedAt: DateTime(2026, 10, 3),
          sets: [
            set(weightKg: 60, reps: 10),
            set(weightKg: 60, reps: 10),
          ],
        ),
      ]);

      expect(kpis.maxSessionVolume, 1200);
      expect(kpis.maxSessionVolumeSets, 2);
      expect(kpis.totalSets, 4);
      expect(kpis.sessionCount, 2);
    });
  });

  group('exerciseProgressPoints', () {
    final sessions = [
      session(
        workoutId: 'w3',
        endedAt: DateTime(2026, 10, 20),
        sets: [set(weightKg: 100, reps: 5)],
      ),
      session(
        workoutId: 'w1',
        endedAt: DateTime(2026, 10, 1),
        sets: [
          set(weightKg: 80, reps: 5),
          set(weightKg: 120, reps: 5, setType: 'warmup'),
        ],
      ),
      session(
        workoutId: 'w2',
        endedAt: DateTime(2026, 10, 10),
        sets: [
          set(weightKg: 90, reps: 5, rir: 1),
          set(weightKg: 95, reps: 3, rir: 1),
        ],
      ),
    ];

    test('e1rm devuelve un punto por sesión ordenado por fecha asc', () {
      final points = exerciseProgressPoints(
        sessions,
        metric: ExerciseProgressMetric.e1rm,
      );

      expect(points.map((p) => p.date), [
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 10),
        DateTime(2026, 10, 20),
      ]);
      expect(points[0].value, closeTo(80 * 37 / 30, 1e-9));
      expect(points[1].value, closeTo(90 * 36 / 30, 1e-9));
      expect(points[2].value, closeTo(100 * 37 / 30, 1e-9));
    });

    test('load devuelve la mayor carga de cada sesión', () {
      final points = exerciseProgressPoints(
        sessions,
        metric: ExerciseProgressMetric.load,
      );

      expect(points.map((p) => p.value), [80, 95, 100]);
    });

    test('volume suma el volumen válido de cada sesión', () {
      final points = exerciseProgressPoints(
        sessions,
        metric: ExerciseProgressMetric.volume,
      );

      expect(points.map((p) => p.value), [400, 735, 500]);
    });

    test('omite sesiones sin datos para la métrica', () {
      final onlyWarmup = session(
        endedAt: DateTime(2026, 10, 2),
        sets: [set(setType: 'warmup', weightKg: 100)],
      );

      for (final metric in ExerciseProgressMetric.values) {
        expect(
          exerciseProgressPoints([onlyWarmup], metric: metric),
          isEmpty,
        );
      }
    });
  });

  group('periodDelta', () {
    test('menos de dos puntos devuelve null', () {
      expect(periodDelta(const []), isNull);
      expect(
        periodDelta([(date: DateTime(2026, 10, 1), value: 100)]),
        isNull,
      );
    });

    test('calcula delta absoluto y porcentaje entre primero y último', () {
      final delta = periodDelta([
        (date: DateTime(2026, 10, 1), value: 65),
        (date: DateTime(2026, 10, 10), value: 50),
        (date: DateTime(2026, 10, 20), value: 95),
      ]);

      expect(delta, isNotNull);
      expect(delta!.absolute, 30);
      expect(delta.percent, closeTo(46.153846, 1e-5));
    });

    test('con primer punto cero solo devuelve delta absoluto', () {
      final delta = periodDelta([
        (date: DateTime(2026, 10, 1), value: 0),
        (date: DateTime(2026, 10, 20), value: 40),
      ]);

      expect(delta, isNotNull);
      expect(delta!.absolute, 40);
      expect(delta.percent, isNull);
    });
  });

  group('weeklyFrequency', () {
    test('sin sesiones devuelve cero', () {
      expect(weeklyFrequency(sessionCount: 0, windowDays: 30), 0);
    });

    test('sesiones entre semanas de la ventana', () {
      expect(weeklyFrequency(sessionCount: 2, windowDays: 14), 1);
      expect(weeklyFrequency(sessionCount: 3, windowDays: 7), 3);
      expect(
        weeklyFrequency(sessionCount: 1, windowDays: 30),
        closeTo(7 / 30, 1e-9),
      );
    });

    test('ventana sin días no divide por cero', () {
      expect(weeklyFrequency(sessionCount: 2, windowDays: 0), 0);
      expect(weeklyFrequency(sessionCount: 2, windowDays: -7), 0);
    });
  });

  group('sessionRirMean', () {
    test('media el RIR de las series válidas con RIR', () {
      final mean = sessionRirMean([
        set(rir: 2),
        set(rir: 3),
        set(rir: 5, setType: 'warmup'),
        set(rir: 5, completed: false),
        set(rir: null),
      ]);

      expect(mean, 2.5);
    });

    test('null sin series con RIR', () {
      expect(sessionRirMean([set(rir: null)]), isNull);
      expect(sessionRirMean(const []), isNull);
    });
  });
}
