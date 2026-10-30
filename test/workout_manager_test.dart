import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/domain/use_cases/workout_manager.dart';

WorkoutSet _set({
  required String type,
  required double weightKg,
  required int reps,
  bool completed = true,
}) {
  final now = DateTime(2026, 1, 1);
  return WorkoutSet(
    id: 'set-${type.hashCode}-$reps',
    workoutExerciseId: 'workout-exercise-1',
    orderIndex: 1,
    setType: type,
    weightKg: weightKg,
    reps: reps,
    rir: 2,
    completed: completed,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final manager = WorkoutManager();

  group('RF-8: e1RM', () {
    test('weight_kg × (1 + (reps + RIR)/30)', () {
      expect(
        manager.calculateE1RM(100, 5, 2),
        closeTo(100 * (1 + 7 / 30), 1e-9),
      );
      expect(manager.calculateE1RM(60, 10, 3), closeTo(60 * 1.4333, 0.01));
    });

    test('si reps > 12 no hay e1RM', () {
      expect(manager.calculateE1RM(100, 13, 2), isNull);
    });

    test('si reps == 1 y RIR == 0 el e1RM es el peso', () {
      expect(manager.calculateE1RM(120, 1, 0), 120);
    });

    test('peso o reps sin sentido → sin e1RM', () {
      expect(manager.calculateE1RM(0, 5, 2), isNull);
      expect(manager.calculateE1RM(-10, 5, 2), isNull);
      expect(manager.calculateE1RM(100, 0, 2), isNull);
    });
  });

  group('RF-9: volumen', () {
    test('excluye warmup, aplica 50 % a drop e ignora incompletas', () {
      final volume = manager.computeVolume([
        _set(type: 'warmup', weightKg: 40, reps: 10),
        _set(type: 'normal', weightKg: 80, reps: 8),
        _set(type: 'failure', weightKg: 80, reps: 8),
        _set(type: 'drop', weightKg: 80, reps: 8),
        _set(type: 'normal', weightKg: 100, reps: 10, completed: false),
      ]);

      expect(volume, closeTo(80 * 8 + 80 * 8 + 80 * 8 * 0.5, 1e-9));
    });

    test('sin series completadas el volumen es cero', () {
      expect(
        manager.computeVolume([
          _set(type: 'warmup', weightKg: 40, reps: 10),
          _set(type: 'normal', weightKg: 80, reps: 8, completed: false),
        ]),
        0,
      );
    });
  });
}
