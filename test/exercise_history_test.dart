import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/workout_repository.dart';

typedef SeedSet = ({
  String setType,
  double weightKg,
  int reps,
  int? rir,
  bool completed,
});

void main() {
  late AppDatabase db;
  late WorkoutRepository repo;
  late String localUserId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = WorkoutRepository(db);
    localUserId = (await db.select(db.localProfiles).getSingle()).localUserId;
    for (final exercise in const [
      ('bench-press', 'Press de banca'),
      ('squat', 'Sentadilla'),
    ]) {
      await db.into(db.exercises).insert(
            ExercisesCompanion.insert(
              id: exercise.$1,
              name: exercise.$2,
              bodyPart: 'chest',
              equipment: 'barbell',
              target: 'pectorals',
              muscleGroup: 'chest',
            ),
          );
    }
  });

  tearDown(() => db.close());

  Future<void> seedExercise({
    required String workoutId,
    required String exerciseId,
    required int orderIndex,
    required List<SeedSet> sets,
  }) async {
    final itemId = '$workoutId-item-$orderIndex';
    await db.into(db.workoutExercises).insert(
          WorkoutExercisesCompanion.insert(
            id: itemId,
            workoutId: workoutId,
            exerciseId: exerciseId,
            orderIndex: orderIndex,
          ),
        );
    for (var i = 0; i < sets.length; i++) {
      final set = sets[i];
      await db.into(db.workoutSets).insert(
            WorkoutSetsCompanion.insert(
              id: '$itemId-set-${i + 1}',
              workoutExerciseId: itemId,
              orderIndex: i + 1,
              setType: Value(set.setType),
              weightKg: Value(set.weightKg),
              reps: Value(set.reps),
              rir: Value(set.rir),
              completed: Value(set.completed),
            ),
          );
    }
  }

  Future<void> seedWorkout({
    required String workoutId,
    required DateTime? endedAt,
    String status = 'finished',
    String? name,
    String exerciseId = 'bench-press',
    List<SeedSet> sets = const [],
    String? secondExerciseId,
    List<SeedSet> secondSets = const [],
  }) async {
    await db.into(db.workouts).insert(
          WorkoutsCompanion.insert(
            id: workoutId,
            localUserId: localUserId,
            name: Value(name),
            startedAt: endedAt?.subtract(const Duration(hours: 1)) ??
                DateTime(2026, 10, 1),
            endedAt: Value(endedAt),
            status: Value(status),
          ),
        );
    await seedExercise(
      workoutId: workoutId,
      exerciseId: exerciseId,
      orderIndex: 1,
      sets: sets,
    );
    if (secondExerciseId != null) {
      await seedExercise(
        workoutId: workoutId,
        exerciseId: secondExerciseId,
        orderIndex: 2,
        sets: secondSets,
      );
    }
  }

  SeedSet workingSet({
    double weightKg = 100,
    int reps = 5,
    int? rir = 2,
  }) =>
      (
        setType: 'normal',
        weightKg: weightKg,
        reps: reps,
        rir: rir,
        completed: true,
      );

  group('exerciseHistory', () {
    test('pagina sesiones fin de más reciente a más antigua', () async {
      for (var day = 1; day <= 3; day++) {
        await seedWorkout(
          workoutId: 'w$day',
          endedAt: DateTime(2026, 10, day),
          name: 'Sesión $day',
          sets: [workingSet()],
        );
      }

      final firstPage = await repo.exerciseHistory(
        exerciseId: 'bench-press',
        limit: 2,
      );
      expect(firstPage.map((s) => s.workoutId), ['w3', 'w2']);
      expect(firstPage.map((s) => s.name), ['Sesión 3', 'Sesión 2']);
      expect(
        firstPage.first.endedAt.isAfter(firstPage.last.endedAt),
        isTrue,
      );

      final secondPage = await repo.exerciseHistory(
        exerciseId: 'bench-press',
        limit: 2,
        offset: 2,
      );
      expect(secondPage.map((s) => s.workoutId), ['w1']);

      final beyond = await repo.exerciseHistory(
        exerciseId: 'bench-press',
        limit: 2,
        offset: 10,
      );
      expect(beyond, isEmpty);
    });

    test('solo incluye sesiones finished con endedAt', () async {
      await seedWorkout(
        workoutId: 'finished',
        endedAt: DateTime(2026, 10, 1),
        sets: [workingSet()],
      );
      await seedWorkout(
        workoutId: 'active',
        endedAt: null,
        status: 'active',
        sets: [workingSet()],
      );
      await seedWorkout(
        workoutId: 'abandoned',
        endedAt: DateTime(2026, 10, 2),
        status: 'abandoned',
        sets: [workingSet()],
      );
      await seedWorkout(
        workoutId: 'no-ended-at',
        endedAt: null,
        sets: [workingSet()],
      );

      final history = await repo.exerciseHistory(
        exerciseId: 'bench-press',
        limit: 10,
      );

      expect(history.map((s) => s.workoutId), ['finished']);
    });

    test('devuelve solo las series del ejercicio pedido con sus marcas',
        () async {
      await seedWorkout(
        workoutId: 'w1',
        endedAt: DateTime(2026, 10, 1),
        name: 'Push',
        sets: [
          (
            setType: 'warmup',
            weightKg: 60,
            reps: 10,
            rir: null,
            completed: true,
          ),
          workingSet(weightKg: 100, reps: 5, rir: 2),
          (
            setType: 'normal',
            weightKg: 105,
            reps: 3,
            rir: 1,
            completed: false,
          ),
        ],
        secondExerciseId: 'squat',
        secondSets: [workingSet(weightKg: 140, reps: 5)],
      );

      final history = await repo.exerciseHistory(
        exerciseId: 'bench-press',
        limit: 10,
      );

      expect(history, hasLength(1));
      final session = history.single;
      expect(session.name, 'Push');
      expect(session.sets.map((s) => s.setType), ['warmup', 'normal', 'normal']);
      expect(session.sets.map((s) => s.weightKg), [60, 100, 105]);
      expect(session.sets.map((s) => s.reps), [10, 5, 3]);
      expect(session.sets.map((s) => s.rir), [null, 2, 1]);
      expect(session.sets.map((s) => s.completed), [true, true, false]);
      expect(session.completedSetCount, 1);
      expect(session.volumeKg, 500);

      final squats = await repo.exerciseHistory(
        exerciseId: 'squat',
        limit: 10,
      );
      expect(squats.single.sets.single.weightKg, 140);
    });

    test('la paginación cuenta sesiones, no filas de series', () async {
      await seedWorkout(
        workoutId: 'w1',
        endedAt: DateTime(2026, 10, 1),
        sets: [workingSet(), workingSet()],
        secondExerciseId: 'squat',
        secondSets: [workingSet(weightKg: 140)],
      );
      await seedWorkout(
        workoutId: 'w2',
        endedAt: DateTime(2026, 10, 2),
        exerciseId: 'squat',
        sets: [workingSet(weightKg: 150)],
      );
      await seedWorkout(
        workoutId: 'w3',
        endedAt: DateTime(2026, 10, 3),
        sets: [workingSet()],
      );

      final page = await repo.exerciseHistory(
        exerciseId: 'bench-press',
        limit: 2,
      );

      expect(page.map((s) => s.workoutId), ['w3', 'w1']);
      expect(page.last.sets, hasLength(2));
    });

    test('sin historial devuelve lista vacía', () async {
      final history = await repo.exerciseHistory(
        exerciseId: 'bench-press',
        limit: 10,
      );

      expect(history, isEmpty);
    });

    test('limit no positivo no devuelve sesiones', () async {
      await seedWorkout(
        workoutId: 'w1',
        endedAt: DateTime(2026, 10, 1),
        sets: [workingSet()],
      );

      expect(
        await repo.exerciseHistory(exerciseId: 'bench-press', limit: 0),
        isEmpty,
      );
    });
  });
}
