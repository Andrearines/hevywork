// Probe temporal T-001: ¿hace falta la vista para colgar la BD?
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/catalog_repository.dart';
import 'package:hevywork/data/repositories/fatigue_repository.dart';
import 'package:hevywork/data/repositories/goal_repository.dart';
import 'package:hevywork/data/repositories/routine_repository.dart';
import 'package:hevywork/data/repositories/workout_repository.dart';
import 'package:hevywork/data/sync/sync_engine.dart';
import 'package:hevywork/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    localDb = AppDatabase(NativeDatabase.memory());
    syncEngine = SyncEngine(localDb, null);
    catalogRepository = CatalogRepository(localDb);
    workoutRepository = WorkoutRepository(localDb);
    routineRepository = RoutineRepository(localDb, workoutRepository);
    goalRepository = GoalRepository(localDb);
    fatigueRepository = FatigueRepository(localDb);

    await localDb.into(localDb.exercises).insert(
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

  tearDownAll(() => localDb.close());

  test('1: solo repositorio, sin vista', () async {
    final workout = await workoutRepository.startWorkout();
    // ignore: avoid_print
    print('P2-1: startWorkout ok');
    final item = await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );
    // ignore: avoid_print
    print('P2-2: addExercise ok');
    await workoutRepository.logSet(
      workoutExerciseId: item.id,
      weightKg: 80,
      reps: 8,
      rir: 2,
    );
    // ignore: avoid_print
    print('P2-3: logSet ok');
  });

  test('2: abandonar la anterior y consultar', () async {
    // ignore: avoid_print
    print('P2-P1');
    final previous = await (localDb.select(localDb.workouts)
          ..where((t) => t.status.equals('active')))
        .getSingleOrNull();
    // ignore: avoid_print
    print('P2-P2 previous=${previous?.id}');
    if (previous != null) {
      final abandoned = previous.copyWith(
        status: 'abandoned',
        endedAt: Value(DateTime.now()),
        updatedAt: DateTime.now(),
      );
      await localDb.update(localDb.workouts).replace(abandoned);
      // ignore: avoid_print
      print('P2-P3 abandonar ok');
    }
    final exRows = await localDb.select(localDb.exercises).get();
    // ignore: avoid_print
    print('P2-P4 exercises ok ${exRows.length}');
    final w2 = await workoutRepository.startWorkout();
    // ignore: avoid_print
    print('P2-P5 startWorkout ok ${w2.id}');
  });
}
