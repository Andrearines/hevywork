// Probe temporal T-001: qué parte de test 1 provoca el cuelgue.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/app/theme/app_theme.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/catalog_repository.dart';
import 'package:hevywork/data/repositories/fatigue_repository.dart';
import 'package:hevywork/data/repositories/goal_repository.dart';
import 'package:hevywork/data/repositories/routine_repository.dart';
import 'package:hevywork/data/repositories/workout_repository.dart';
import 'package:hevywork/data/sync/sync_engine.dart';
import 'package:hevywork/main.dart';
import 'package:hevywork/ui/views/live_workout_view.dart';

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

  Future<void> pumpView(WidgetTester tester, String workoutId) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: SizedBox()),
      ),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => LiveWorkoutView(workoutId: workoutId),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> abandonAndQuery(String label) async {
    // ignore: avoid_print
    print('$label: startWorkout (abandona)');
    final w2 = await workoutRepository.startWorkout();
    // ignore: avoid_print
    print('$label: startWorkout ok');
    final rows = await localDb.select(localDb.exercises).get();
    // ignore: avoid_print
    print('$label: select ok ${rows.length}');
  }

  testWidgets('V1: abrir y cerrar la vista sin series', (tester) async {
    final workout = await workoutRepository.startWorkout();
    await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );
    // ignore: avoid_print
    print('V1: pumpView');
    await pumpView(tester, workout.id);
    // ignore: avoid_print
    print('V1: unmount');
    await unmount(tester);
    // ignore: avoid_print
    print('V1: listo');
    await abandonAndQuery('V1');
    await unmount(tester);
  });

  testWidgets('V2: abrir, registrar serie y cerrar', (tester) async {
    final workout = await workoutRepository.startWorkout();
    final item = await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );
    await pumpView(tester, workout.id);
    await tester.enterText(
      find.byKey(Key('set-weight-${item.id}')),
      '80',
    );
    await tester.enterText(
      find.byKey(Key('set-reps-${item.id}')),
      '8',
    );
    await tester.tap(find.byKey(Key('set-check-${item.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    // ignore: avoid_print
    print('V2: serie registrada');
    await unmount(tester);
    // ignore: avoid_print
    print('V2: listo');
    await abandonAndQuery('V2');
    await unmount(tester);
  });
}
