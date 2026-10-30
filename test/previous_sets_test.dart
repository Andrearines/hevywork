import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/domain/previous_sets.dart';

void main() {
  HistorySet historySet({
    String exerciseId = 'bench',
    DateTime? endedAt,
    int order = 1,
    bool completed = true,
    String setType = 'normal',
    double weightKg = 60,
    int reps = 8,
    int rir = 2,
  }) =>
      HistorySet(
        exerciseId: exerciseId,
        sessionEndedAt: endedAt ?? DateTime(2026, 10, 1, 10),
        setOrderIndex: order,
        completed: completed,
        setType: setType,
        weightKg: weightKg,
        reps: reps,
        rir: rir,
      );

  group('previousSessionSets', () {
    test('usa solo la sesión anterior más reciente y conserva el orden', () {
      final result = previousSessionSets([
        historySet(
            endedAt: DateTime(2026, 10, 1, 10),
            order: 1,
            weightKg: 60,
            reps: 8),
        historySet(
            endedAt: DateTime(2026, 10, 1, 10),
            order: 2,
            weightKg: 70,
            reps: 6),
        historySet(
            endedAt: DateTime(2026, 10, 3, 10),
            order: 1,
            weightKg: 80,
            reps: 5),
        historySet(
            endedAt: DateTime(2026, 10, 3, 10),
            order: 2,
            weightKg: 85,
            reps: 4),
      ], before: DateTime(2026, 10, 5));

      expect(result['bench'], isNotNull);
      expect(result['bench']!.map((s) => s.weightKg), [80, 85]);
      expect(result['bench']!.map((s) => s.reps), [5, 4]);
      expect(result['bench']!.map((s) => s.rir), [2, 2]);
    });

    test('ignora calentamientos y series sin completar', () {
      final result = previousSessionSets([
        historySet(order: 1, setType: 'warmup', weightKg: 40, reps: 10),
        historySet(order: 2, completed: false, weightKg: 100, reps: 5),
        historySet(order: 3, weightKg: 90, reps: 3),
      ], before: DateTime(2026, 10, 5));

      expect(result['bench'], hasLength(1));
      expect(result['bench']!.single.weightKg, 90);
      expect(result['bench']!.single.reps, 3);
    });

    test('excluye sesiones que no terminan antes de `before`', () {
      final result = previousSessionSets([
        historySet(
            endedAt: DateTime(2026, 10, 5, 9), weightKg: 60, reps: 8),
        historySet(
            endedAt: DateTime(2026, 10, 5, 10), weightKg: 70, reps: 6),
      ], before: DateTime(2026, 10, 5, 10));

      expect(result['bench'], hasLength(1));
      expect(result['bench']!.single.weightKg, 60);
    });

    test('agrupa los resultados por ejercicio', () {
      final result = previousSessionSets([
        historySet(exerciseId: 'bench', weightKg: 80, reps: 5),
        historySet(exerciseId: 'squat', weightKg: 100, reps: 5),
      ], before: DateTime(2026, 10, 5));

      expect(result.keys.toSet(), {'bench', 'squat'});
      expect(result['squat']!.single.weightKg, 100);
    });
  });

  group('lastPreviousSet', () {
    test('devuelve la última serie completada de la sesión previa', () {
      final set = lastPreviousSet(
        exerciseId: 'bench',
        before: DateTime(2026, 10, 5),
        sets: [
          historySet(order: 1, weightKg: 80, reps: 5),
          historySet(order: 2, weightKg: 85, reps: 4),
        ],
      );

      expect(set, isNotNull);
      expect(set!.weightKg, 85);
      expect(set.reps, 4);
    });

    test('sin sesión previa devuelve null', () {
      final set = lastPreviousSet(
        exerciseId: 'bench',
        before: DateTime(2026, 10, 5),
        sets: const <HistorySet>[],
      );

      expect(set, isNull);
    });
  });

  group('previousSetAt', () {
    test('devuelve la serie en la misma posición (1-based)', () {
      final set = previousSetAt(
        exerciseId: 'bench',
        setIndex: 2,
        before: DateTime(2026, 10, 5),
        sets: [
          historySet(order: 1, weightKg: 80, reps: 5),
          historySet(order: 2, weightKg: 85, reps: 4),
        ],
      );

      expect(set!.weightKg, 85);
    });

    test('si la sesión previa tuvo menos series, repite la última', () {
      final set = previousSetAt(
        exerciseId: 'bench',
        setIndex: 3,
        before: DateTime(2026, 10, 5),
        sets: [
          historySet(order: 1, weightKg: 80, reps: 5),
          historySet(order: 2, weightKg: 85, reps: 4),
        ],
      );

      expect(set!.weightKg, 85);
    });

    test('sin sesión previa devuelve null', () {
      final set = previousSetAt(
        exerciseId: 'bench',
        setIndex: 1,
        before: DateTime(2026, 10, 5),
        sets: const <HistorySet>[],
      );

      expect(set, isNull);
    });
  });
}