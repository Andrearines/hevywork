import 'package:drift/drift.dart' show OrderingTerm, Value;
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
    // Viewport de móvil alto (800×1200): la tarjeta de sesión con acciones
    // ocupa más de la mitad de un viewport de 600 y empuja las filas al
    // borde superior del listado, donde el hit-test de los slivers falla.
    // Con CustomScrollView necesitamos más altura para que la lista perezosa
    // construya al menos la primera tarjeta.
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

  Future<void> dismissSnackBars(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await unmount(tester);
  }

  testWidgets('muestra la tabla de series y registra una serie con e1RM',
      (tester) async {
    final workout = await workoutRepository.startWorkout();
    final item = await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );

    await pumpView(tester, workout.id);

    expect(find.text('SESIÓN EN CURSO'), findsOneWidget);
    expect(find.text('Press de banca'), findsOneWidget);
    expect(find.text('SET'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
    expect(find.text('KG'), findsWidgets);
    expect(find.text('REPS'), findsWidgets);
    expect(find.text('RIR'), findsWidgets);
    expect(find.text('VOLUMEN'), findsOneWidget);
    expect(find.text('0'), findsWidgets);

    await tester.enterText(
      find.byKey(Key('set-weight-${item.id}')),
      '80',
    );
    await tester.enterText(
      find.byKey(Key('set-reps-${item.id}')),
      '8',
    );
    await tester.enterText(
      find.byKey(Key('set-rir-${item.id}')),
      '2',
    );
    await tester.tap(find.byKey(Key('set-check-${item.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    final sets = await (localDb.select(localDb.workoutSets)
          ..where((t) => t.workoutExerciseId.equals(item.id)))
        .get();
    expect(sets, hasLength(1));
    expect(sets.single.completed, isTrue);
    expect(sets.single.weightKg, 80);

    expect(find.text('640'), findsOneWidget);
    expect(find.text('106.7'), findsWidgets);
    expect(find.text('80'), findsWidgets);

    await unmount(tester);
  });

  testWidgets('sin repeticiones avisa y no registra la serie',
      (tester) async {
    // ignore: avoid_print
    print('PROBE: antes de select workouts');
    final ws = await localDb.select(localDb.workouts).get();
    print('PROBE: select workouts ok n=${ws.length}');
    final ps = await localDb.select(localDb.localProfiles).get();
    print('PROBE: select profiles ok n=${ps.length}');
    print('P1: select previous');
    final previous = await (localDb.select(localDb.workouts)
          ..where((t) => t.status.equals('active')))
        .getSingleOrNull();
    print('P2: previous=${previous?.id}');
    if (previous != null) {
      final abandoned = previous.copyWith(
        status: 'abandoned',
        endedAt: Value(DateTime.now()),
        updatedAt: DateTime.now(),
      );
      await localDb.update(localDb.workouts).replace(abandoned);
      print('P3: abandonar ok');
    }
    await tester.pump(const Duration(seconds: 2));
    print('P3b: pump 2s ok');
    print('P4a: microtask');
    await Future<void>.value();
    print('P4b: microtask ok');
    final exRows = await localDb.select(localDb.exercises).get();
    print('P4c: exercises ok ${exRows.length}');
    final prof2 = await (localDb.select(localDb.localProfiles)
          ..where((t) => t.id.equals(1)))
        .getSingle();
    print('P4d: profile filtrado ok');
    final now = DateTime.now();
    final workout = Workout(
      id: 'probe-${now.microsecondsSinceEpoch}',
      localUserId: prof2.localUserId,
      routineId: null,
      name: null,
      notes: null,
      startedAt: now,
      endedAt: null,
      status: 'active',
      createdAt: now,
      updatedAt: now,
    );
    await localDb.into(localDb.workouts).insert(workout);
    print('P5: insert ok');
    await (localDb.update(localDb.localProfiles)
          ..where((t) => t.id.equals(1)))
        .write(LocalProfilesCompanion(
          lastActiveWorkoutId: Value(workout.id),
        ));
    print('P6: marker ok');
    final workoutOk = workout;
    // ignore: avoid_print
    print('PROBE: startWorkout ok');
    final item = await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );
    // ignore: avoid_print
    print('PROBE: addExercise ok');

    // ignore: avoid_print
    print('PROBE: antes de pumpView');
    await pumpView(tester, workout.id);
    // ignore: avoid_print
    print('PROBE: pumpView ok');

    await tester.enterText(
      find.byKey(Key('set-weight-${item.id}')),
      '80',
    );
    // ignore: avoid_print
    print('PROBE: enterText ok');
    await tester.tap(find.byKey(Key('set-check-${item.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // ignore: avoid_print
    print('PROBE: antes del expect snackbar');
    expect(find.text('Indica las repeticiones'), findsOneWidget);
    // ignore: avoid_print
    print('PROBE: expect snackbar ok');
    final sets = await (localDb.select(localDb.workoutSets)
          ..where((t) => t.workoutExerciseId.equals(item.id)))
        .get();
    expect(sets, isEmpty);

    // ignore: avoid_print
    print('PROBE: antes de dismissSnackBars');
    await dismissSnackBars(tester);
    // ignore: avoid_print
    print('PROBE: dismissSnackBars ok');
  });
}
