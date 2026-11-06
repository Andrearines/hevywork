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
    await tester.tap(find.byKey(Key('set-check-${item.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Indica las repeticiones'), findsOneWidget);
    final sets = await (localDb.select(localDb.workoutSets)
          ..where((t) => t.workoutExerciseId.equals(item.id)))
        .get();
    expect(sets, isEmpty);

    await dismissSnackBars(tester);
  });

  testWidgets('el picker añade un ejercicio a la sesión', (tester) async {
    final workout = await workoutRepository.startWorkout();

    await pumpView(tester, workout.id);

    expect(
      find.text('Añade tu primer ejercicio para empezar'),
      findsOneWidget,
    );

    await tester.tap(find.text('Añadir ejercicio'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.enterText(find.byType(TextField), 'Press');
    await tester.pump();
    expect(find.text('Press de banca'), findsOneWidget);

    await tester.tap(find.text('Press de banca'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Press de banca'), findsOneWidget);
    expect(find.text('Añade tu primer ejercicio para empezar'), findsNothing);

    final items = await (localDb.select(localDb.workoutExercises)
          ..where((t) => t.workoutId.equals(workout.id)))
        .get();
    expect(items, hasLength(1));

    await unmount(tester);
  });

  testWidgets('cerrar sin series confirma y borra la sesión (RF-10)',
      (tester) async {
    final workout = await workoutRepository.startWorkout();
    await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );

    await pumpView(tester, workout.id);

    await tester.tap(find.text('Terminar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Sesión sin series'), findsOneWidget);
    expect(
      find.text('No has completado ninguna serie. La sesión se eliminará.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Descartar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));

    final rows = await (localDb.select(localDb.workouts)
          ..where((t) => t.id.equals(workout.id)))
        .get();
    expect(rows, isEmpty);
    expect(find.text('Sesión vacía descartada'), findsOneWidget);

    await dismissSnackBars(tester);
  });

  testWidgets('deshacer se deshabilita sin series y deshace la última (RF-1/RF-2)',
      (tester) async {
    final workout = await workoutRepository.startWorkout();
    final item = await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );

    await pumpView(tester, workout.id);

    expect(find.byTooltip('Nada que deshacer'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Deshacer'),
          )
          .onPressed,
      isNull,
    );

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

    expect(find.byTooltip('Nada que deshacer'), findsNothing);

    await tester.tap(find.text('Deshacer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    final sets = await (localDb.select(localDb.workoutSets)
          ..where((t) => t.workoutExerciseId.equals(item.id)))
        .get();
    expect(sets, hasLength(1));
    expect(sets.single.completed, isFalse);

    expect(find.byIcon(Icons.check_outlined), findsNWidgets(2));
    expect(find.byTooltip('Nada que deshacer'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('editar una serie en línea con el checklist actualiza la fila (RF-3)',
      (tester) async {
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
    await tester.enterText(
      find.byKey(Key('set-rir-${item.id}')),
      '2',
    );
    await tester.tap(find.byKey(Key('set-check-${item.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    final set = await (localDb.select(localDb.workoutSets)
          ..where((t) => t.workoutExerciseId.equals(item.id)))
        .getSingle();
    expect(find.text('106.7'), findsWidgets);

    // Desmarcar deja la serie pendiente y editable en la fila.
    await tester.ensureVisible(find.byKey(Key('set-check-${set.id}')));
    await tester.pump();
    await tester.tap(find.byKey(Key('set-check-${set.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    var stored = await (localDb.select(localDb.workoutSets)
          ..where((t) => t.id.equals(set.id)))
        .getSingle();
    expect(stored.completed, isFalse);

    // Un RIR fuera de rango no confirma la serie y avisa.
    await tester.enterText(find.byKey(Key('set-rir-${set.id}')), '15');
    await tester.tap(find.byKey(Key('set-check-${set.id}')));
    await tester.pump();

    expect(find.text('El RIR debe estar entre 0 y 10'), findsOneWidget);
    stored = await (localDb.select(localDb.workoutSets)
          ..where((t) => t.id.equals(set.id)))
        .getSingle();
    expect(stored.completed, isFalse);

    // Se deja pasar el aviso y se confirma con valores válidos.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byKey(Key('set-reps-${set.id}')), '6');
    await tester.enterText(find.byKey(Key('set-rir-${set.id}')), '2');
    await tester.tap(find.byKey(Key('set-check-${set.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));

    final updated = await (localDb.select(localDb.workoutSets)
          ..where((t) => t.id.equals(set.id)))
        .getSingle();
    expect(updated.reps, 6);
    expect(updated.rir, 2);
    expect(updated.completed, isTrue);

    expect(find.text('101.3'), findsWidgets);
    expect(find.text('106.7'), findsNothing);

    await unmount(tester);
  });

  testWidgets(
      'el descanso arranca tras la serie y se pausa, ajusta y salta '
      '(RF-5/RF-6/RF-8)', (tester) async {
    final workout = await workoutRepository.startWorkout();
    final item = await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );

    await pumpView(tester, workout.id);

    expect(find.text('DESCANSO'), findsNothing);

    await tester.enterText(find.byKey(Key('set-weight-${item.id}')), '80');
    await tester.enterText(find.byKey(Key('set-reps-${item.id}')), '8');
    await tester.enterText(find.byKey(Key('set-rir-${item.id}')), '2');
    await tester.tap(find.byKey(Key('set-check-${item.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('DESCANSO'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^\d+:\d{2}$')), findsWidgets);

    var stored = await (localDb.select(localDb.workouts)
          ..where((t) => t.id.equals(workout.id)))
        .getSingle();
    expect(stored.restEndsAt, isNotNull);
    expect(stored.restPausedSeconds, isNull);

    await tester.tap(find.byKey(const Key('rest-plus')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const Key('rest-pause')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('EN PAUSA'), findsOneWidget);
    stored = await (localDb.select(localDb.workouts)
          ..where((t) => t.id.equals(workout.id)))
        .getSingle();
    expect(stored.restEndsAt, isNull);
    expect(stored.restPausedSeconds, isNotNull);

    await tester.tap(find.byKey(const Key('rest-skip')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('EN PAUSA'), findsNothing);
    expect(find.text('DESCANSO'), findsNothing);
    stored = await (localDb.select(localDb.workouts)
          ..where((t) => t.id.equals(workout.id)))
        .getSingle();
    expect(stored.restEndsAt, isNull);
    expect(stored.restPausedSeconds, isNull);

    await unmount(tester);
  });

  testWidgets('al llegar a cero el descanso queda LISTO (RF-7)',
      (tester) async {
    final workout = await workoutRepository.startWorkout();
    final item = await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );

    await pumpView(tester, workout.id);

    await tester.enterText(find.byKey(Key('set-weight-${item.id}')), '80');
    await tester.enterText(find.byKey(Key('set-reps-${item.id}')), '8');
    await tester.enterText(find.byKey(Key('set-rir-${item.id}')), '2');
    await tester.tap(find.byKey(Key('set-check-${item.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('DESCANSO'), findsOneWidget);

    // El descanso llega a cero: se simula terminándolo en la base (el reloj
    // real no avanza con pump, pero el ticker recalcula y detecta el final).
    await (localDb.update(localDb.workouts)..where((t) => t.id.equals(workout.id)))
        .write(WorkoutsCompanion(
      restEndsAt: Value(DateTime.now().subtract(const Duration(seconds: 1))),
    ));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('LISTO'), findsOneWidget);
    expect(find.text('DESCANSO'), findsNothing);

    // No repite el aviso: sigue LISTO en los siguientes ticks.
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('LISTO'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rest-clear')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('LISTO'), findsNothing);

    await unmount(tester);
  });

  testWidgets('cerrar una sesión libre con series termina y no sugiere nada',
      (tester) async {
    final workout = await workoutRepository.startWorkout();
    final item = await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );

    await pumpView(tester, workout.id);

    await tester.enterText(find.byKey(Key('set-weight-${item.id}')), '60');
    await tester.enterText(find.byKey(Key('set-reps-${item.id}')), '8');
    await tester.enterText(find.byKey(Key('set-rir-${item.id}')), '2');
    await tester.tap(find.byKey(Key('set-check-${item.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Terminar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Progresión sugerida'), findsNothing);
    expect(find.text('Sesión terminada'), findsOneWidget);

    final stored = await (localDb.select(localDb.workouts)
          ..where((t) => t.id.equals(workout.id)))
        .getSingle();
    expect(stored.status, 'finished');

    await dismissSnackBars(tester);
  });

  testWidgets(
      'cerrar una sesión de rutina con objetivo cumplido sugiere +2.5 kg '
      'y Aceptar actualiza la rutina (RF-3/RF-4)', (tester) async {
    final routine = await routineRepository.createRoutine(
      name: 'Tren superior',
      exercises: const [
        RoutineExerciseDraft(
          exerciseId: 'bench-press',
          sets: [
            RoutineSetDraft(reps: 8, rir: 2, weightKg: 60),
            RoutineSetDraft(reps: 8, rir: 2, weightKg: 60),
            RoutineSetDraft(reps: 8, rir: 2, weightKg: 60),
          ],
        ),
      ],
    );
    final started = await routineRepository.startWorkoutFromRoutine(routine.id);
    final items = await (localDb.select(localDb.workoutExercises)
          ..where((t) => t.workoutId.equals(started.workout.id)))
        .get();
    final item = items.single;

    await pumpView(tester, started.workout.id);

    for (var i = 0; i < 3; i++) {
      await tester.enterText(
          find.byKey(Key('set-weight-${item.id}')), '60');
      await tester.enterText(find.byKey(Key('set-reps-${item.id}')), '8');
      await tester.enterText(find.byKey(Key('set-rir-${item.id}')), '2');
      final logButton = find.byKey(Key('set-check-${item.id}'));
      await tester.ensureVisible(logButton);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(logButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.tap(find.text('Terminar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Progresión sugerida'), findsOneWidget);
    expect(find.text('60 → 62.5 kg'), findsNWidgets(3));

    await tester.tap(find.text('Aceptar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Pesos guardados'), findsOneWidget);

    await tester.tap(find.text('Listo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Sesión terminada'), findsOneWidget);

    final plan = await (localDb.select(localDb.routineExercises)
          ..where((t) => t.routineId.equals(routine.id)))
        .getSingle();
    final plannedSets = await (localDb.select(localDb.routineSets)
          ..where((t) => t.routineExerciseId.equals(plan.id)))
        .get();
    expect(plannedSets, hasLength(3));
    expect(
      plannedSets.every((set) => set.weightKg == 62.5),
      isTrue,
    );

    await dismissSnackBars(tester);
  });

  testWidgets(
      'terminar una sesión persiste el peso real en la rutina aunque no se '
      'cumpla el objetivo (RF-4)', (tester) async {
    final routine = await routineRepository.createRoutine(
      name: 'Push',
      exercises: const [
        RoutineExerciseDraft(
          exerciseId: 'bench-press',
          sets: [
            RoutineSetDraft(reps: 8, rir: 2, weightKg: 60),
            RoutineSetDraft(reps: 8, rir: 2, weightKg: 60),
            RoutineSetDraft(reps: 8, rir: 2, weightKg: 60),
          ],
        ),
      ],
    );
    final started = await routineRepository.startWorkoutFromRoutine(routine.id);
    final items = await (localDb.select(localDb.workoutExercises)
          ..where((t) => t.workoutId.equals(started.workout.id)))
        .get();
    final item = items.single;
    final preloaded = await (localDb.select(localDb.workoutSets)
          ..where((t) => t.workoutExerciseId.equals(item.id))
          ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
        .get();

    await pumpView(tester, started.workout.id);

    // Se confirma solo la primera serie con el peso real cambiado en línea.
    await tester.enterText(
      find.byKey(Key('set-weight-${preloaded[0].id}')),
      '65',
    );
    final logButton = find.byKey(Key('set-check-${preloaded[0].id}'));
    await tester.ensureVisible(logButton);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(logButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Terminar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));

    // Solo se hizo 1 de 3 series: no hay progresión sugerida y aun así la
    // rutina adopta el peso real de la serie confirmada.
    expect(find.text('Progresión sugerida'), findsNothing);
    expect(find.text('Sesión terminada'), findsOneWidget);

    final plan = await (localDb.select(localDb.routineExercises)
          ..where((t) => t.routineId.equals(routine.id)))
        .getSingle();
    final plannedSets = await (localDb.select(localDb.routineSets)
          ..where((t) => t.routineExerciseId.equals(plan.id))
          ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
        .get();
    expect(plannedSets, hasLength(3));
    expect(plannedSets[0].weightKg, 65);
    expect(plannedSets[1].weightKg, 60);
    expect(plannedSets[2].weightKg, 60);

    await dismissSnackBars(tester);
  });

  testWidgets('los steppers del ajuste rápido mueven el peso (RF-15)',
      (tester) async {
    final workout = await workoutRepository.startWorkout();
    final item = await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );

    await pumpView(tester, workout.id);

    final weightField = find.byKey(Key('set-weight-${item.id}'));
    await tester.enterText(weightField, '60');

    Future<void> step(String label, String expected) async {
      await tester.tap(find.text(label));
      await tester.pump();
      expect(
        tester.widget<TextField>(weightField).controller!.text,
        expected,
      );
    }

    await step('+1.3 kg', '61.3');
    await step('+2.5 kg', '63.8');
    await step('−1.3 kg', '62.5');
    await step('−2.5 kg', '60');

    await unmount(tester);
  });

  testWidgets('el chip RIR es cíclico y Añadir serie confirma la fila nueva',
      (tester) async {
    final workout = await workoutRepository.startWorkout();
    final item = await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );

    await pumpView(tester, workout.id);

    final rirChip = find.byKey(Key('rir-cycle-${item.id}'));
    expect(rirChip, findsOneWidget);

    await tester.tap(rirChip);
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(Key('set-rir-${item.id}')))
          .controller!
          .text,
      '1',
    );

    await tester.tap(rirChip);
    await tester.pump();
    expect(find.text('RIR 2'), findsOneWidget);

    await tester.enterText(find.byKey(Key('set-weight-${item.id}')), '80');
    await tester.enterText(find.byKey(Key('set-reps-${item.id}')), '8');
    await tester.tap(find.text('Añadir serie'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    final sets = await (localDb.select(localDb.workoutSets)
          ..where((t) => t.workoutExerciseId.equals(item.id)))
        .get();
    expect(sets, hasLength(1));
    expect(sets.single.weightKg, 80);
    expect(sets.single.reps, 8);
    expect(sets.single.rir, 2);

    await unmount(tester);
  });

  testWidgets(
      'el ejercicio siguiente aparece colapsado con su objetivo y se expande '
      'al tocar (mockup de registro en vivo)', (tester) async {
    await localDb.into(localDb.exercises).insert(
          ExercisesCompanion.insert(
            id: 'squat',
            name: 'Sentadilla',
            bodyPart: 'legs',
            equipment: 'barbell',
            target: 'quads',
            muscleGroup: 'legs',
          ),
        );

    final routine = await routineRepository.createRoutine(
      name: 'Tren inferior',
      exercises: const [
        RoutineExerciseDraft(
          exerciseId: 'bench-press',
          sets: [RoutineSetDraft(reps: 8, rir: 2, weightKg: 60)],
        ),
        RoutineExerciseDraft(
          exerciseId: 'squat',
          sets: [
            RoutineSetDraft(reps: 6, rir: 1, weightKg: 100),
            RoutineSetDraft(reps: 6, rir: 1, weightKg: 100),
            RoutineSetDraft(reps: 6, rir: 1, weightKg: 100),
          ],
        ),
      ],
    );
    final started = await routineRepository.startWorkoutFromRoutine(routine.id);
    final items = await (localDb.select(localDb.workoutExercises)
          ..where((t) => t.workoutId.equals(started.workout.id)))
        .get();
    final squat = items.singleWhere((item) => item.exerciseId == 'squat');

    await pumpView(tester, started.workout.id);

    expect(find.text('3 series programadas'), findsOneWidget);
    expect(find.text('OBJETIVO'), findsOneWidget);
    expect(find.text('RIR 1'), findsOneWidget);
    expect(find.text('SET'), findsOneWidget);

    final expandKey = find.byKey(Key('expand-${squat.id}'));
    await tester.ensureVisible(expandKey);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(expandKey);
    await tester.pump();

    expect(find.text('SET'), findsNWidgets(2));
    expect(find.byKey(Key('collapse-${squat.id}')), findsOneWidget);

    final collapseKey = find.byKey(Key('collapse-${squat.id}'));
    await tester.ensureVisible(collapseKey);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(collapseKey);
    await tester.pump();

    expect(find.text('SET'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('borrar una serie desde la UI la quita de la BD y reindexa '
      '1..n (RF-5)', (tester) async {
    final workout = await workoutRepository.startWorkout();
    final item = await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );
    final first = await workoutRepository.logSet(
      workoutExerciseId: item.id,
      weightKg: 70,
      reps: 10,
      rir: 3,
    );
    final second = await workoutRepository.logSet(
      workoutExerciseId: item.id,
      weightKg: 75,
      reps: 8,
      rir: 2,
    );
    final third = await workoutRepository.logSet(
      workoutExerciseId: item.id,
      weightKg: 80,
      reps: 6,
      rir: 1,
    );

    await pumpView(tester, workout.id);

    expect(find.byKey(ValueKey('set-${second.id}')), findsOneWidget);

    final deleteButton = find.byKey(Key('set-delete-${second.id}'));
    await tester.ensureVisible(deleteButton);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(deleteButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Eliminar serie'), findsOneWidget);

    await tester.tap(find.text('Eliminar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(ValueKey('set-${second.id}')), findsNothing);

    final rows = await (localDb.select(localDb.workoutSets)
          ..where((t) => t.workoutExerciseId.equals(item.id)))
        .get();
    final ordered = rows.toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    expect(ordered.map((s) => s.id), [first.id, third.id]);
    expect(ordered.map((s) => s.orderIndex), [1, 2]);
    expect(ordered.map((s) => s.weightKg), [70.0, 80.0]);

    await unmount(tester);
  });

  testWidgets('al recargar la vista las series pendientes siguen en la tabla '
      'con sus valores (RF-5/RF-7)', (tester) async {
    final workout = await workoutRepository.startWorkout();
    final item = await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );
    final pending = await workoutRepository.logSet(
      workoutExerciseId: item.id,
      weightKg: 60,
      reps: 8,
      rir: 2,
      restSeconds: 90,
      completed: false,
    );

    await pumpView(tester, workout.id);
    expect(find.byKey(ValueKey('set-${pending.id}')), findsOneWidget);
    await unmount(tester);

    // Cerrar y reabrir la sesión (mismo workoutId).
    await pumpView(tester, workout.id);

    expect(find.byKey(ValueKey('set-${pending.id}')), findsOneWidget);
    final stored = await (localDb.select(localDb.workoutSets)
          ..where((t) => t.id.equals(pending.id)))
        .getSingle();
    expect(stored.completed, isFalse);
    expect(stored.weightKg, 60);
    expect(stored.reps, 8);
    expect(stored.rir, 2);
    expect(stored.setType, 'normal');
    expect(stored.orderIndex, 1);
    expect(stored.restSeconds, 90);
    expect(
      tester
          .widget<TextField>(find.byKey(Key('set-reps-${pending.id}')))
          .controller!
          .text,
      '8',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(Key('set-weight-${pending.id}')))
          .controller!
          .text,
      '60',
    );

    await unmount(tester);
  });

  testWidgets('borrar con la sesión ya cerrada avisa en snackbar y no cambia '
      'ninguna fila (RF-6)', (tester) async {
    final workout = await workoutRepository.startWorkout();
    final item = await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );
    final set = await workoutRepository.logSet(
      workoutExerciseId: item.id,
      weightKg: 70,
      reps: 10,
      rir: 3,
    );

    await pumpView(tester, workout.id);

    // La sesión deja de ser editable con la vista abierta.
    await (localDb.update(localDb.workouts)
          ..where((t) => t.id.equals(workout.id)))
        .write(const WorkoutsCompanion(status: Value('finished')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final deleteButton = find.byKey(Key('set-delete-${set.id}'));
    await tester.ensureVisible(deleteButton);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(deleteButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Eliminar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('La sesión ya está cerrada'), findsOneWidget);

    final rows = await localDb.select(localDb.workoutSets).get();
    expect(rows, hasLength(1));
    expect(rows.single.completed, isTrue);

    await dismissSnackBars(tester);
  });
}
