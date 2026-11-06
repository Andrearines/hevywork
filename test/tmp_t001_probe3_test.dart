// Probe temporal T-001: qué suscripción de la vista bloquea la BD.
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

  Future<String> seed() async {
    final workout = await workoutRepository.startWorkout();
    await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );
    return workout.id;
  }

  Future<void> abandonAndQuery(String label) async {
    // ignore: avoid_print
    print('$label: startWorkout (abandona la anterior)');
    final w2 = await workoutRepository.startWorkout();
    // ignore: avoid_print
    print('$label: startWorkout ok ${w2.id}');
    final rows = await localDb.select(localDb.exercises).get();
    // ignore: avoid_print
    print('$label: select ok ${rows.length}');
  }

  test('A: watchWorkout sin cancelar', () async {
    final id = await seed();
    // ignore: avoid_print
    print('A: suscrito');
    // ignore: cancel_subscriptions
    workoutRepository.watchWorkout(id).listen((_) {});
    await abandonAndQuery('A');
  });

  test('B: watchWorkout cancelada', () async {
    final id = await seed();
    final sub = workoutRepository.watchWorkout(id).listen((_) {});
    await Future<void>.value();
    await sub.cancel();
    // ignore: avoid_print
    print('B: cancelada');
    await abandonAndQuery('B');
  });

  test('C: watchFatiguePanel sin cancelar', () async {
    final id = await seed();
    // ignore: cancel_subscriptions
    fatigueRepository.watchFatiguePanel().listen((_) {});
    // ignore: avoid_print
    print('C: suscrito');
    await abandonAndQuery('C');
  });

  test('D: watchFatiguePanel cancelada', () async {
    final id = await seed();
    final sub = fatigueRepository.watchFatiguePanel().listen((_) {});
    await Future<void>.value();
    await sub.cancel();
    // ignore: avoid_print
    print('D: cancelada');
    await abandonAndQuery('D');
  });

  test('E: watchSets sin cancelar', () async {
    final id = await seed();
    // ignore: cancel_subscriptions
    workoutRepository.watchSets(id).listen((_) {});
    // ignore: avoid_print
    print('E: suscrito');
    await abandonAndQuery('E');
  });
}
