import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/body_metric_repository.dart';
import 'package:hevywork/data/repositories/goal_repository.dart';

typedef SetSeed = ({
  int order,
  String setType,
  double weight,
  int reps,
  int? rir,
  bool completed,
});

typedef ItemSeed = ({String exerciseId, List<SetSeed> sets});

void main() {
  late AppDatabase db;
  late GoalRepository repo;
  late BodyMetricRepository metrics;
  late List<({String operation, String table, String payload})> enqueued;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    enqueued = [];
    Future<void> enqueue(
      String operation,
      String table,
      String payload,
    ) async {
      enqueued.add((operation: operation, table: table, payload: payload));
    }
    repo = GoalRepository(db, enqueue: enqueue);
    metrics = BodyMetricRepository(db, enqueue: enqueue);
    await db.into(db.exercises).insert(
          ExercisesCompanion.insert(
            id: 'bench-press',
            name: 'Press de banca',
            bodyPart: 'chest',
            equipment: 'barbell',
            target: 'pectorals',
            muscleGroup: 'chest',
          ),
        );
  });

  tearDown(() => db.close());

  Future<void> seedFinishedWorkout({
    required String id,
    required DateTime endedAt,
    required List<ItemSeed> items,
  }) async {
    await db.into(db.workouts).insert(
          WorkoutsCompanion.insert(
            id: id,
            localUserId: 'perfil-1',
            startedAt: endedAt.subtract(const Duration(hours: 1)),
            status: const Value('finished'),
            endedAt: Value(endedAt),
          ),
        );
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final itemId = '$id-item-$i';
      await db.into(db.workoutExercises).insert(
            WorkoutExercisesCompanion.insert(
              id: itemId,
              workoutId: id,
              exerciseId: item.exerciseId,
              orderIndex: i,
            ),
          );
      for (var s = 0; s < item.sets.length; s++) {
        final set = item.sets[s];
        await db.into(db.workoutSets).insert(
              WorkoutSetsCompanion.insert(
                id: '$itemId-set-$s',
                workoutExerciseId: itemId,
                orderIndex: set.order,
                setType: Value(set.setType),
                weightKg: Value(set.weight),
                reps: Value(set.reps),
                rir: Value(set.rir),
                completed: Value(set.completed),
              ),
            );
      }
    }
  }

  SetSeed set({
    int order = 0,
    String setType = 'normal',
    double weight = 60,
    int reps = 10,
    int? rir,
    bool completed = true,
  }) =>
      (
        order: order,
        setType: setType,
        weight: weight,
        reps: reps,
        rir: rir,
        completed: completed,
      );

  group('CRUD y cola (RF-2/RF-11)', () {
    test('crear una meta la guarda active y encola un upsert', () async {
      final goal = await repo.createGoal(
        type: 'strength',
        targetValue: 80,
        metricRef: 'bench-press',
        deadline: DateTime(2026, 12, 31),
      );

      expect(goal.status, 'active');
      expect(goal.currentValue, isNull);
      expect(goal.baselineValue, isNull);

      final stored = (await db.select(db.goals).get()).single;
      expect(stored.id, goal.id);
      expect(stored.localUserId, (await db.select(db.localProfiles).getSingle()).localUserId);

      final last = enqueued.last;
      expect(last.operation, 'upsert');
      expect(last.table, 'goals');
      final payload = jsonDecode(last.payload) as Map<String, dynamic>;
      expect(payload['id'], goal.id);
      expect(payload['type'], 'strength');
      expect(payload['target_value'], 80);
      expect(payload['metric_ref'], 'bench-press');
      expect(payload['status'], 'active');
      expect(payload.containsKey('baseline_value'), isFalse);
      expect(payload.containsKey('baselineValue'), isFalse);
    });

    test('una meta de peso fija su punto de partida con el último registro',
        () async {
      await metrics.upsert(date: DateTime(2026, 10, 1), weightKg: 90);
      enqueued.clear();

      final goal = await repo.createGoal(
        type: 'bodyweight',
        targetValue: 85,
      );

      final stored = (await db.select(db.goals).get()).single;
      expect(stored.baselineValue, 90);
      expect(goal.baselineValue, 90);
    });

    test('editar reactiva la meta y refresca el punto de partida', () async {
      await metrics.upsert(date: DateTime(2026, 10, 1), weightKg: 90);
      final goal = await repo.createGoal(
        type: 'bodyweight',
        targetValue: 85,
      );
      await db.update(db.goals).replace(
            goal.copyWith(
              status: 'achieved',
              currentValue: const Value(84),
            ),
          );
      enqueued.clear();

      final updated = await repo.updateGoal(
        goal.id,
        type: 'bodyweight',
        targetValue: 88,
      );

      expect(updated.status, 'active');
      expect(updated.currentValue, isNull);
      expect(updated.baselineValue, 90);
      expect(enqueued.last.operation, 'upsert');
      expect(enqueued.last.table, 'goals');
    });

    test('borrar elimina la meta y encola el delete', () async {
      final goal = await repo.createGoal(
        type: 'consistency',
        targetValue: 4,
      );
      enqueued.clear();

      await repo.deleteGoal(goal.id);

      expect(await db.select(db.goals).get(), isEmpty);
      final last = enqueued.last;
      expect(last.operation, 'delete');
      expect(last.table, 'goals');
      expect(jsonDecode(last.payload), {'id': goal.id});
    });

    test('consistencia y peso no admiten metric_ref; volumen sí lo exige',
        () async {
      await expectLater(
        repo.createGoal(
          type: 'consistency',
          targetValue: 4,
          metricRef: 'bench-press',
        ),
        throwsArgumentError,
      );
      await expectLater(
        repo.createGoal(type: 'volume', targetValue: 1000),
        throwsArgumentError,
      );
      await expectLater(
        repo.createGoal(type: 'volume', targetValue: 1000, period: 'weekly'),
        throwsArgumentError,
      );
      await expectLater(
        repo.createGoal(
          type: 'volume',
          targetValue: 1000,
          period: 'weekly',
          metricRef: 'chest',
        ),
        isA<Future<Goal>>(),
      );
    });

    test('tipo desconocido, objetivo inválido o plazo pasado se rechazan',
        () async {
      await expectLater(
        repo.createGoal(type: 'medallas', targetValue: 10),
        throwsArgumentError,
      );
      await expectLater(
        repo.createGoal(type: 'strength', targetValue: 0, metricRef: 'bench'),
        throwsArgumentError,
      );
      await expectLater(
        repo.createGoal(
          type: 'strength',
          targetValue: 80,
          metricRef: 'bench',
          deadline: DateTime(2020, 1, 1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('Recálculo (RF-3)', () {
    final now = DateTime.now();

    test('fuerza: el mejor e1RM histórico sin calentamientos', () async {
      final goal = await repo.createGoal(
        type: 'strength',
        targetValue: 80,
        metricRef: 'bench-press',
      );
      await seedFinishedWorkout(
        id: 'w1',
        endedAt: now.subtract(const Duration(hours: 2)),
        items: [
          (
            exerciseId: 'bench-press',
            sets: [
              set(weight: 100, reps: 1, rir: 0, setType: 'warmup'),
              set(weight: 70, reps: 8, rir: 2),
            ],
          ),
        ],
      );
      enqueued.clear();

      final achieved = await repo.recalculate(now: now);

      expect(achieved, hasLength(1));
      expect(achieved.single.id, goal.id);
      final stored = (await db.select(db.goals).get()).single;
      expect(stored.status, 'achieved');
      expect(stored.currentValue, closeTo(70 * (1 + 10 / 30), 1e-9));
      expect(enqueued, hasLength(1));
      expect(enqueued.single.table, 'goals');
    });

    test('fuerza: cuenta marcas de antes de los 30 días', () async {
      await repo.createGoal(
        type: 'strength',
        targetValue: 100,
        metricRef: 'bench-press',
      );
      await seedFinishedWorkout(
        id: 'w-old',
        endedAt: now.subtract(const Duration(days: 40)),
        items: [
          (
            exerciseId: 'bench-press',
            sets: [set(weight: 95, reps: 1, rir: 2)],
          ),
        ],
      );

      await repo.recalculate(now: now);

      final stored = (await db.select(db.goals).get()).single;
      expect(stored.status, 'achieved');
      expect(stored.currentValue, closeTo(95 * (1 + 3 / 30), 1e-9));
    });

    test('volumen semanal por músculo: sin calentamientos, drops al 50 %',
        () async {
      await repo.createGoal(
        type: 'volume',
        targetValue: 2000,
        period: 'weekly',
        metricRef: 'chest',
      );
      await seedFinishedWorkout(
        id: 'w1',
        endedAt: now.subtract(const Duration(hours: 3)),
        items: [
          (
            exerciseId: 'bench-press',
            sets: [
              set(weight: 60, reps: 10),
              set(weight: 60, reps: 8),
              set(weight: 60, reps: 10, setType: 'warmup'),
              set(weight: 60, reps: 10, setType: 'drop'),
            ],
          ),
        ],
      );
      // Fuera de la ventana semanal: no cuenta.
      await seedFinishedWorkout(
        id: 'w-old',
        endedAt: now.subtract(const Duration(days: 10)),
        items: [
          (
            exerciseId: 'bench-press',
            sets: [set(weight: 60, reps: 10)],
          ),
        ],
      );

      await repo.recalculate(now: now);

      final stored = (await db.select(db.goals).get()).single;
      expect(stored.status, 'active');
      expect(stored.currentValue, 600 + 480 + 300);
    });

    test('volumen mensual: cuenta la ventana de 30 días', () async {
      await repo.createGoal(
        type: 'volume',
        targetValue: 3000,
        period: 'monthly',
        metricRef: 'chest',
      );
      await seedFinishedWorkout(
        id: 'w1',
        endedAt: now.subtract(const Duration(days: 20)),
        items: [
          (
            exerciseId: 'bench-press',
            sets: [set(weight: 60, reps: 10), set(weight: 60, reps: 10)],
          ),
        ],
      );
      await seedFinishedWorkout(
        id: 'w-old',
        endedAt: now.subtract(const Duration(days: 40)),
        items: [
          (
            exerciseId: 'bench-press',
            sets: [set(weight: 60, reps: 10)],
          ),
        ],
      );

      await repo.recalculate(now: now);

      final stored = (await db.select(db.goals).get()).single;
      expect(stored.currentValue, 1200);
    });

    test('constancia: sesiones completadas en los últimos 7 días', () async {
      await repo.createGoal(
        type: 'consistency',
        targetValue: 4,
      );
      for (var i = 1; i <= 3; i++) {
        await seedFinishedWorkout(
          id: 'w$i',
          endedAt: now.subtract(Duration(days: i)),
          items: const [],
        );
      }
      await seedFinishedWorkout(
        id: 'w-old',
        endedAt: now.subtract(const Duration(days: 10)),
        items: const [],
      );

      final achieved = await repo.recalculate(now: now);
      expect(achieved, isEmpty);
      final stored = (await db.select(db.goals).get()).single;
      expect(stored.status, 'active');
      expect(stored.currentValue, 3);

      await seedFinishedWorkout(
        id: 'w4',
        endedAt: now.subtract(const Duration(hours: 1)),
        items: const [],
      );
      final achieved2 = await repo.recalculate(now: now);
      expect(achieved2, hasLength(1));
      expect((await db.select(db.goals).get()).single.status, 'achieved');
    });

    test('peso corporal: la pérdida se logra por debajo del objetivo',
        () async {
      await metrics.upsert(date: DateTime(2026, 10, 1), weightKg: 90);
      final goal = await repo.createGoal(
        type: 'bodyweight',
        targetValue: 85,
      );
      await metrics.upsert(date: DateTime(2026, 10, 7), weightKg: 84.5);

      final achieved = await repo.recalculate(now: now);

      expect(achieved.single.id, goal.id);
      final stored = (await db.select(db.goals).get()).single;
      expect(stored.status, 'achieved');
      expect(stored.currentValue, 84.5);
    });

    test('plazo pasado sin lograr abandona la meta', () async {
      final deadline = now.add(const Duration(days: 2));
      await repo.createGoal(
        type: 'strength',
        targetValue: 100,
        metricRef: 'bench-press',
        deadline: deadline,
      );
      enqueued.clear();

      final achieved =
          await repo.recalculate(now: now.add(const Duration(days: 3)));

      expect(achieved, isEmpty);
      final stored = (await db.select(db.goals).get()).single;
      expect(stored.status, 'abandoned');
      expect(enqueued.single.table, 'goals');
      expect(
        (jsonDecode(enqueued.single.payload) as Map<String, dynamic>)['status'],
        'abandoned',
      );
    });

    test('sin metas no hay recálculo ni escrituras', () async {
      final achieved = await repo.recalculate(now: now);
      expect(achieved, isEmpty);
      expect(enqueued, isEmpty);
    });

    test('lo logrado no se revierte aunque el valor baje', () async {
      final goal = await repo.createGoal(
        type: 'strength',
        targetValue: 80,
        metricRef: 'bench-press',
      );
      await seedFinishedWorkout(
        id: 'w1',
        endedAt: now.subtract(const Duration(hours: 2)),
        items: [
          (
            exerciseId: 'bench-press',
            sets: [set(weight: 90, reps: 1, rir: 2)],
          ),
        ],
      );
      await repo.recalculate(now: now);
      // Una serie mala posterior no revierte el estado.
      await seedFinishedWorkout(
        id: 'w2',
        endedAt: now.subtract(const Duration(minutes: 30)),
        items: [
          (
            exerciseId: 'bench-press',
            sets: [set(weight: 50, reps: 5, rir: 4)],
          ),
        ],
      );

      await repo.recalculate(now: now);

      final stored = (await db.select(db.goals).get()).single;
      expect(stored.status, 'achieved');
      expect(stored.id, goal.id);
    });
  });
}