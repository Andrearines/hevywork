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
import 'package:hevywork/domain/services/rest_notifier.dart';
import 'package:hevywork/domain/units.dart';
import 'package:hevywork/main.dart';
import 'package:hevywork/ui/views/live_workout_view.dart';

class FakeRestNotifier implements RestNotificationService {
  final List<({String timerKey, DateTime when})> scheduled = [];
  final List<String> cancelled = [];
  final List<String> alerts = [];
  final List<String> resets = [];

  @override
  Future<void> scheduleAt(
    DateTime when, {
    String timerKey = RestNotificationService.legacyKey,
    String title = 'Descanso terminado',
    String body = 'Reanuda tu sesión',
  }) async {
    scheduled.add((timerKey: timerKey, when: when));
  }

  @override
  Future<void> cancel({
    String timerKey = RestNotificationService.legacyKey,
  }) async {
    cancelled.add(timerKey);
  }

  @override
  Future<void> alertNow({
    String timerKey = RestNotificationService.legacyKey,
  }) async {
    alerts.add(timerKey);
  }

  @override
  void resetAlertFlag({String timerKey = RestNotificationService.legacyKey}) {
    resets.add(timerKey);
  }
}

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

    await localDb
        .into(localDb.exercises)
        .insert(
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

  setUp(() async {
    await localDb.delete(localDb.workoutSets).go();
    await localDb.delete(localDb.workoutExercises).go();
    await localDb.delete(localDb.workouts).go();
    await localDb.delete(localDb.exercisePreferences).go();
  });

  tearDownAll(() => localDb.close());

  Future<void> pumpView(
    WidgetTester tester,
    String workoutId, {
    Size viewport = const Size(800, 1600),
    RestNotificationService? notifier,
    DateTime Function()? clock,
    double textScale = 1.0,
  }) async {
    // Viewport de móvil alto (800×1600): la tarjeta de sesión con acciones
    // ocupa más de la mitad de un viewport de 600 y empuja las filas al
    // borde superior del listado, donde el hit-test de los slivers falla.
    // Con CustomScrollView necesitamos más altura para que la lista perezosa
    // construya al menos la primera tarjeta.
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const Scaffold(body: SizedBox()),
      ),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => LiveWorkoutView(
          workoutId: workoutId,
          restNotifier: notifier ?? FakeRestNotifier(),
          clock: clock,
        ),
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

  Future<WorkoutExercise> storedItem(String id) {
    return (localDb.select(
      localDb.workoutExercises,
    )..where((row) => row.id.equals(id))).getSingle();
  }

  Future<void> dismissSnackBars(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await unmount(tester);
  }

  testWidgets('muestra la tabla de series y registra una serie con e1RM', (
    tester,
  ) async {
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

    await tester.enterText(find.byKey(Key('set-weight-${item.id}')), '80');
    await tester.enterText(find.byKey(Key('set-reps-${item.id}')), '8');
    await tester.enterText(find.byKey(Key('set-rir-${item.id}')), '2');
    await tester.tap(find.byKey(Key('set-check-${item.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    final sets = await (localDb.select(
      localDb.workoutSets,
    )..where((t) => t.workoutExerciseId.equals(item.id))).get();
    expect(sets, hasLength(1));
    expect(sets.single.completed, isTrue);
    expect(sets.single.weightKg, 80);

    expect(find.text('640'), findsOneWidget);
    expect(find.text(formatDisplay(80 * (1 + 10 / 30))), findsWidgets);
    expect(find.text('80'), findsWidgets);

    await unmount(tester);
  });

  testWidgets('sin repeticiones avisa y no registra la serie', (tester) async {
    final workout = await workoutRepository.startWorkout();
    final item = await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );

    await pumpView(tester, workout.id);

    await tester.enterText(find.byKey(Key('set-weight-${item.id}')), '80');
    await tester.tap(find.byKey(Key('set-check-${item.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Indica las repeticiones'), findsOneWidget);
    final sets = await (localDb.select(
      localDb.workoutSets,
    )..where((t) => t.workoutExerciseId.equals(item.id))).get();
    expect(sets, isEmpty);

    await dismissSnackBars(tester);
  });

  testWidgets('el picker añade un ejercicio a la sesión', (tester) async {
    final workout = await workoutRepository.startWorkout();

    await pumpView(tester, workout.id);

    expect(find.text('Añade tu primer ejercicio para empezar'), findsOneWidget);

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

    final items = await (localDb.select(
      localDb.workoutExercises,
    )..where((t) => t.workoutId.equals(workout.id))).get();
    expect(items, hasLength(1));

    await unmount(tester);
  });

  testWidgets('cerrar sin series confirma y borra la sesión (RF-10)', (
    tester,
  ) async {
    final workout = await workoutRepository.startWorkout();
    await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );

    await pumpView(tester, workout.id);

    await tester.ensureVisible(find.text('Terminar'));
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

    final rows = await (localDb.select(
      localDb.workouts,
    )..where((t) => t.id.equals(workout.id))).get();
    expect(rows, isEmpty);
    expect(find.text('Sesión vacía descartada'), findsOneWidget);

    await dismissSnackBars(tester);
  });

  testWidgets(
    'deshacer se deshabilita sin series y deshace la última (RF-1/RF-2)',
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

      await tester.enterText(find.byKey(Key('set-weight-${item.id}')), '80');
      await tester.enterText(find.byKey(Key('set-reps-${item.id}')), '8');
      await tester.enterText(find.byKey(Key('set-rir-${item.id}')), '2');
      await tester.tap(find.byKey(Key('set-check-${item.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byTooltip('Nada que deshacer'), findsNothing);

      await tester.ensureVisible(find.text('Deshacer'));
      await tester.tap(find.text('Deshacer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      final sets = await (localDb.select(
        localDb.workoutSets,
      )..where((t) => t.workoutExerciseId.equals(item.id))).get();
      expect(sets, hasLength(1));
      expect(sets.single.completed, isFalse);

      expect(find.byIcon(Icons.check_outlined), findsNWidgets(2));
      expect(find.byTooltip('Nada que deshacer'), findsOneWidget);

      await unmount(tester);
    },
  );

  testWidgets(
    'editar una serie en línea con el checklist actualiza la fila (RF-3)',
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

      final set = await (localDb.select(
        localDb.workoutSets,
      )..where((t) => t.workoutExerciseId.equals(item.id))).getSingle();
      expect(find.text(formatDisplay(80 * (1 + 10 / 30))), findsWidgets);

      // Desmarcar deja la serie pendiente y editable en la fila.
      await tester.ensureVisible(find.byKey(Key('set-check-${set.id}')));
      await tester.pump();
      await tester.tap(find.byKey(Key('set-check-${set.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      var stored = await (localDb.select(
        localDb.workoutSets,
      )..where((t) => t.id.equals(set.id))).getSingle();
      expect(stored.completed, isFalse);

      // Un RIR fuera de rango no confirma la serie y avisa.
      await tester.enterText(find.byKey(Key('set-rir-${set.id}')), '15');
      await tester.tap(find.byKey(Key('set-check-${set.id}')));
      await tester.pump();

      expect(find.text('El RIR debe estar entre 0 y 10'), findsOneWidget);
      stored = await (localDb.select(
        localDb.workoutSets,
      )..where((t) => t.id.equals(set.id))).getSingle();
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

      final updated = await (localDb.select(
        localDb.workoutSets,
      )..where((t) => t.id.equals(set.id))).getSingle();
      expect(updated.reps, 6);
      expect(updated.rir, 2);
      expect(updated.completed, isTrue);

      expect(find.text(formatDisplay(80 * (1 + 8 / 30))), findsWidgets);
      expect(find.text(formatDisplay(80 * (1 + 10 / 30))), findsNothing);

      await unmount(tester);
    },
  );

  testWidgets('el descanso arranca tras la serie y se pausa, ajusta y salta '
      '(RF-5/RF-6/RF-8)', (tester) async {
    final workout = await workoutRepository.startWorkout();
    final item = await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );
    final now = DateTime(2026, 3, 1, 12);
    final notifier = FakeRestNotifier();

    await pumpView(tester, workout.id, clock: () => now, notifier: notifier);

    expect(find.textContaining('DESCANSO'), findsNothing);

    await workoutRepository.saveRestTimer(
      workout.id,
      endsAt: now.add(const Duration(seconds: 300)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('DESCANSO ACTIVO'), findsOneWidget);

    await tester.enterText(find.byKey(Key('set-weight-${item.id}')), '80');
    await tester.enterText(find.byKey(Key('set-reps-${item.id}')), '8');
    await tester.enterText(find.byKey(Key('set-rir-${item.id}')), '2');
    await tester.tap(find.byKey(Key('set-check-${item.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('DESCANSO · Press de banca'), findsOneWidget);
    expect(find.text('1:30'), findsOneWidget);

    var stored = await storedItem(item.id);
    expect(stored.restEndsAt, now.add(const Duration(seconds: 90)));
    expect(stored.restPausedSeconds, isNull);
    final legacy = await localDb.select(localDb.workouts).getSingle();
    expect(legacy.restEndsAt, isNull);
    expect(legacy.restPausedSeconds, isNull);
    expect(notifier.cancelled, contains(RestNotificationService.legacyKey));

    await tester.tap(find.byKey(Key('rest-plus-${item.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    stored = await storedItem(item.id);
    expect(stored.restEndsAt, now.add(const Duration(seconds: 105)));
    expect(find.text('1:45'), findsOneWidget);
    expect(
      (await localDb.select(localDb.exercisePreferences).getSingle())
          .restSeconds,
      105,
    );

    await tester.tap(find.byKey(Key('rest-pause-${item.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('EN PAUSA'), findsOneWidget);
    stored = await storedItem(item.id);
    expect(stored.restEndsAt, isNull);
    expect(stored.restPausedSeconds, 105);

    await tester.tap(find.byKey(Key('rest-skip-${item.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('EN PAUSA'), findsNothing);
    expect(find.textContaining('DESCANSO'), findsNothing);
    stored = await storedItem(item.id);
    expect(stored.restEndsAt, isNull);
    expect(stored.restPausedSeconds, isNull);
    expect(
      (await localDb.select(localDb.exercisePreferences).getSingle())
          .restSeconds,
      105,
    );
    expect(notifier.cancelled, contains(item.id));

    await unmount(tester);
  });

  testWidgets('el ajuste live cambia la segunda serie y sobrevive a reabrir', (
    tester,
  ) async {
    final workout = await workoutRepository.startWorkout();
    final item = await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );
    final now = DateTime(2026, 3, 1, 12);
    final notifier = FakeRestNotifier();

    await pumpView(tester, workout.id, clock: () => now, notifier: notifier);

    Future<void> logSet() async {
      await tester.enterText(find.byKey(Key('set-weight-${item.id}')), '80');
      await tester.enterText(find.byKey(Key('set-reps-${item.id}')), '8');
      await tester.enterText(find.byKey(Key('set-rir-${item.id}')), '2');
      await tester.tap(find.byKey(Key('set-check-${item.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    await logSet();
    await tester.tap(find.byKey(Key('rest-plus-${item.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(Key('rest-skip-${item.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await logSet();

    final stored = await storedItem(item.id);
    expect(stored.restEndsAt, now.add(const Duration(seconds: 105)));
    expect(find.text('1:45'), findsOneWidget);
    expect(
      (await localDb.select(localDb.exercisePreferences).getSingle())
          .restSeconds,
      105,
    );

    await unmount(tester);
    await pumpView(tester, workout.id, clock: () => now, notifier: notifier);

    expect(find.text('1:45'), findsOneWidget);
    expect((await storedItem(item.id)).restEndsAt, stored.restEndsAt);

    await unmount(tester);
  });

  testWidgets('al llegar a cero el item queda LISTO, avisa una vez y limpia', (
    tester,
  ) async {
    final workout = await workoutRepository.startWorkout();
    final item = await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );
    var now = DateTime(2026, 3, 1, 12);
    final notifier = FakeRestNotifier();

    await pumpView(tester, workout.id, clock: () => now, notifier: notifier);

    await tester.enterText(find.byKey(Key('set-weight-${item.id}')), '80');
    await tester.enterText(find.byKey(Key('set-reps-${item.id}')), '8');
    await tester.enterText(find.byKey(Key('set-rir-${item.id}')), '2');
    await tester.tap(find.byKey(Key('set-check-${item.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('DESCANSO · Press de banca'), findsOneWidget);

    now = now.add(const Duration(seconds: 90));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('LISTO · Press de banca'), findsOneWidget);
    expect(find.textContaining('DESCANSO'), findsNothing);
    expect(notifier.alerts.where((key) => key == item.id), hasLength(1));

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('LISTO · Press de banca'), findsOneWidget);
    expect(notifier.alerts.where((key) => key == item.id), hasLength(1));

    await tester.tap(find.byKey(Key('rest-clear-${item.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('LISTO'), findsNothing);
    expect((await storedItem(item.id)).restEndsAt, isNull);
    expect((await storedItem(item.id)).restPausedSeconds, isNull);

    await unmount(tester);
  });

  testWidgets('cerrar una sesión libre con series termina y no sugiere nada', (
    tester,
  ) async {
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

    await tester.ensureVisible(find.text('Terminar'));
    await tester.tap(find.text('Terminar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Progresión sugerida'), findsNothing);
    expect(find.text('Sesión terminada'), findsOneWidget);

    final stored = await (localDb.select(
      localDb.workouts,
    )..where((t) => t.id.equals(workout.id))).getSingle();
    expect(stored.status, 'finished');

    await dismissSnackBars(tester);
  });

  testWidgets(
    'cerrar una sesión de rutina con objetivo cumplido sugiere +2.5 kg '
    'y Aceptar actualiza la rutina (RF-3/RF-4)',
    (tester) async {
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
      final started = await routineRepository.startWorkoutFromRoutine(
        routine.id,
      );
      final items = await (localDb.select(
        localDb.workoutExercises,
      )..where((t) => t.workoutId.equals(started.workout.id))).get();
      final item = items.single;

      await pumpView(
        tester,
        started.workout.id,
        viewport: const Size(1000, 3000),
      );

      for (var i = 0; i < 3; i++) {
        await tester.enterText(find.byKey(Key('set-weight-${item.id}')), '60');
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
      expect(find.text('60 → 62.50 kg'), findsNWidgets(3));

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

      final plan = await (localDb.select(
        localDb.routineExercises,
      )..where((t) => t.routineId.equals(routine.id))).getSingle();
      final plannedSets = await (localDb.select(
        localDb.routineSets,
      )..where((t) => t.routineExerciseId.equals(plan.id))).get();
      expect(plannedSets, hasLength(3));
      expect(plannedSets.every((set) => set.weightKg == 62.5), isTrue);

      await dismissSnackBars(tester);
    },
  );

  testWidgets(
    'terminar una sesión persiste el peso real en la rutina aunque no se '
    'cumpla el objetivo (RF-4)',
    (tester) async {
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
      final started = await routineRepository.startWorkoutFromRoutine(
        routine.id,
      );
      final items = await (localDb.select(
        localDb.workoutExercises,
      )..where((t) => t.workoutId.equals(started.workout.id))).get();
      final item = items.single;
      final preloaded =
          await (localDb.select(localDb.workoutSets)
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

      await tester.ensureVisible(find.text('Terminar'));
      await tester.tap(find.text('Terminar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      // Solo se hizo 1 de 3 series: no hay progresión sugerida y aun así la
      // rutina adopta el peso real de la serie confirmada.
      expect(find.text('Progresión sugerida'), findsNothing);
      expect(find.text('Sesión terminada'), findsOneWidget);

      final plan = await (localDb.select(
        localDb.routineExercises,
      )..where((t) => t.routineId.equals(routine.id))).getSingle();
      final plannedSets =
          await (localDb.select(localDb.routineSets)
                ..where((t) => t.routineExerciseId.equals(plan.id))
                ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
              .get();
      expect(plannedSets, hasLength(3));
      expect(plannedSets[0].weightKg, 65);
      expect(plannedSets[1].weightKg, 60);
      expect(plannedSets[2].weightKg, 60);

      await dismissSnackBars(tester);
    },
  );

  testWidgets('los steppers del ajuste rápido mueven el peso (RF-15)', (
    tester,
  ) async {
    final workout = await workoutRepository.startWorkout();
    final item = await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );

    await pumpView(tester, workout.id);

    final weightField = find.byKey(Key('set-weight-${item.id}'));
    await tester.enterText(weightField, '60');

    Future<void> step(String label, String expected) async {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pump();
      expect(tester.widget<TextField>(weightField).controller!.text, expected);
    }

    await step('+1.25 kg', '61.25');
    await step('+2.50 kg', '63.75');
    await step('−1.25 kg', '62.50');
    await step('−2.50 kg', '60');

    await unmount(tester);
  });

  testWidgets('el chip RIR es cíclico y Añadir serie confirma la fila nueva', (
    tester,
  ) async {
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

    final sets = await (localDb.select(
      localDb.workoutSets,
    )..where((t) => t.workoutExerciseId.equals(item.id))).get();
    expect(sets, hasLength(1));
    expect(sets.single.weightKg, 80);
    expect(sets.single.reps, 8);
    expect(sets.single.rir, 2);

    await unmount(tester);
  });

  testWidgets(
    'el ejercicio siguiente aparece colapsado con su objetivo y se expande '
    'al tocar (mockup de registro en vivo)',
    (tester) async {
      await localDb
          .into(localDb.exercises)
          .insert(
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
      final started = await routineRepository.startWorkoutFromRoutine(
        routine.id,
      );
      final items = await (localDb.select(
        localDb.workoutExercises,
      )..where((t) => t.workoutId.equals(started.workout.id))).get();
      final squat = items.singleWhere((item) => item.exerciseId == 'squat');

      await pumpView(
        tester,
        started.workout.id,
        viewport: const Size(1000, 3000),
      );

      expect(find.text('3 series programadas'), findsOneWidget);
      expect(find.text('OBJETIVO'), findsOneWidget);
      expect(find.text('RIR 1'), findsOneWidget);
      expect(find.text('SET'), findsOneWidget);

      final expandKey = find.byKey(Key('expand-${squat.id}'));
      await tester.tap(expandKey);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('SET'), findsNWidgets(2));
      expect(find.byKey(Key('collapse-${squat.id}')), findsOneWidget);

      final collapseKey = find.byKey(Key('collapse-${squat.id}'));
      await tester.tap(collapseKey);
      await tester.pump();

      expect(find.text('SET'), findsOneWidget);

      await unmount(tester);
    },
  );

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

    final rows = await (localDb.select(
      localDb.workoutSets,
    )..where((t) => t.workoutExerciseId.equals(item.id))).get();
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
    final stored = await (localDb.select(
      localDb.workoutSets,
    )..where((t) => t.id.equals(pending.id))).getSingle();
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

  testWidgets('dos tarjetas aíslan countdown y comparten solo el default', (
    tester,
  ) async {
    final workout = await workoutRepository.startWorkout();
    final first = await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );
    final second = await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );
    var now = DateTime(2026, 3, 1, 12);
    final notifier = FakeRestNotifier();
    await workoutRepository.startRestTimer(
      workoutExerciseId: first.id,
      plannedRestSeconds: 60,
      now: now,
    );
    await workoutRepository.startRestTimer(
      workoutExerciseId: second.id,
      plannedRestSeconds: 120,
      now: now,
    );
    final secondEndsAt = (await storedItem(second.id)).restEndsAt;

    await pumpView(
      tester,
      workout.id,
      viewport: const Size(1000, 2200),
      clock: () => now,
      notifier: notifier,
    );
    await tester.tap(find.byKey(Key('expand-${second.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('1:00'), findsOneWidget);
    expect(find.text('2:00'), findsOneWidget);

    await tester.tap(find.byKey(Key('rest-plus-${first.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      (await storedItem(first.id)).restEndsAt,
      now.add(const Duration(seconds: 75)),
    );
    expect((await storedItem(second.id)).restEndsAt, secondEndsAt);
    expect(
      (await localDb.select(localDb.exercisePreferences).getSingle())
          .restSeconds,
      105,
    );

    now = now.add(const Duration(seconds: 15));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('1:00'), findsOneWidget);
    expect(find.text('1:45'), findsOneWidget);

    await tester.tap(find.byKey(Key('rest-pause-${first.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect((await storedItem(first.id)).restPausedSeconds, 60);
    expect((await storedItem(second.id)).restEndsAt, secondEndsAt);

    now = now.add(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 1));
    expect((await storedItem(first.id)).restPausedSeconds, 60);
    expect(find.text('1:00'), findsOneWidget);

    await tester.tap(find.byKey(Key('rest-pause-${first.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      (await storedItem(first.id)).restEndsAt,
      now.add(const Duration(seconds: 60)),
    );

    await tester.tap(find.byKey(Key('rest-skip-${second.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect((await storedItem(second.id)).restEndsAt, isNull);
    expect(
      (await storedItem(first.id)).restEndsAt,
      now.add(const Duration(seconds: 60)),
    );

    await unmount(tester);
  });

  testWidgets(
    'una serie de calentamiento no inicia descanso ni escribe default',
    (tester) async {
      final workout = await workoutRepository.startWorkout();
      final item = await workoutRepository.addExercise(
        workoutId: workout.id,
        exerciseId: 'bench-press',
      );
      final now = DateTime(2026, 3, 1, 12);

      await pumpView(tester, workout.id, clock: () => now);
      await tester.tap(find.text('CALENTAMIENTO'));
      await tester.pump();
      await tester.enterText(find.byKey(Key('set-weight-${item.id}')), '40');
      await tester.enterText(find.byKey(Key('set-reps-${item.id}')), '12');
      await tester.enterText(find.byKey(Key('set-rir-${item.id}')), '4');
      await tester.tap(find.byKey(Key('set-check-${item.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final stored = await storedItem(item.id);
      expect(stored.restEndsAt, isNull);
      expect(stored.restPausedSeconds, isNull);
      expect(find.textContaining('DESCANSO'), findsNothing);
      expect(await localDb.select(localDb.exercisePreferences).get(), isEmpty);

      await unmount(tester);
    },
  );

  testWidgets('legacy conserva sus claves y no aplica opción C', (
    tester,
  ) async {
    final workout = await workoutRepository.startWorkout();
    await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );
    final now = DateTime(2026, 3, 1, 12);
    final notifier = FakeRestNotifier();
    await workoutRepository.saveRestTimer(
      workout.id,
      pausedRemaining: const Duration(seconds: 45),
    );

    await pumpView(tester, workout.id, clock: () => now, notifier: notifier);

    expect(find.text('DESCANSO'), findsOneWidget);
    expect(find.byKey(const Key('rest-plus')), findsOneWidget);
    await tester.tap(find.byKey(const Key('rest-pause')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      (await localDb.select(localDb.workouts).getSingle()).restEndsAt,
      now.add(const Duration(seconds: 45)),
    );

    await tester.tap(find.byKey(const Key('rest-plus')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      (await localDb.select(localDb.workouts).getSingle()).restEndsAt,
      now.add(const Duration(seconds: 60)),
    );
    expect(await localDb.select(localDb.exercisePreferences).get(), isEmpty);

    await tester.tap(find.byKey(const Key('rest-skip')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final stored = await localDb.select(localDb.workouts).getSingle();
    expect(stored.restEndsAt, isNull);
    expect(stored.restPausedSeconds, isNull);
    expect(notifier.cancelled, contains(RestNotificationService.legacyKey));

    await unmount(tester);
  });

  testWidgets('legacy done desaparece, limpia y alerta una sola vez', (
    tester,
  ) async {
    final workout = await workoutRepository.startWorkout();
    await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );
    var now = DateTime(2026, 3, 1, 12);
    final notifier = FakeRestNotifier();
    await workoutRepository.saveRestTimer(
      workout.id,
      endsAt: now.add(const Duration(seconds: 15)),
    );

    await pumpView(tester, workout.id, clock: () => now, notifier: notifier);
    expect(find.text('DESCANSO ACTIVO'), findsOneWidget);

    now = now.add(const Duration(seconds: 15));
    await tester.pump(const Duration(seconds: 2));

    expect(find.textContaining('LISTO'), findsNothing);
    expect(find.text('DESCANSO ACTIVO'), findsNothing);
    expect(notifier.alerts, [RestNotificationService.legacyKey]);
    final stored = await localDb.select(localDb.workouts).getSingle();
    expect(stored.restEndsAt, isNull);
    expect(stored.restPausedSeconds, isNull);

    await tester.pump(const Duration(seconds: 3));
    expect(notifier.alerts, [RestNotificationService.legacyKey]);

    await unmount(tester);
  });

  testWidgets(
    'background programa solo running futuro y resume cancela su ID',
    (tester) async {
      final workout = await workoutRepository.startWorkout();
      final running = await workoutRepository.addExercise(
        workoutId: workout.id,
        exerciseId: 'bench-press',
      );
      final paused = await workoutRepository.addExercise(
        workoutId: workout.id,
        exerciseId: 'bench-press',
      );
      final now = DateTime(2026, 3, 1, 12);
      final notifier = FakeRestNotifier();
      await workoutRepository.startRestTimer(
        workoutExerciseId: running.id,
        plannedRestSeconds: 120,
        now: now,
      );
      await workoutRepository.startRestTimer(
        workoutExerciseId: paused.id,
        plannedRestSeconds: 90,
        now: now,
      );
      await workoutRepository.pauseRestTimer(paused.id, now);
      final runningEndsAt = (await storedItem(running.id)).restEndsAt;

      await pumpView(
        tester,
        workout.id,
        viewport: const Size(1000, 2200),
        clock: () => now,
        notifier: notifier,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(notifier.scheduled, hasLength(1));
      expect(notifier.scheduled.single.timerKey, running.id);
      expect(notifier.scheduled.single.when, runningEndsAt);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(notifier.cancelled, contains(running.id));
      expect(notifier.cancelled, isNot(contains(paused.id)));
      expect((await storedItem(running.id)).restEndsAt, runningEndsAt);
      expect((await storedItem(paused.id)).restPausedSeconds, 90);

      await unmount(tester);
    },
  );

  testWidgets('done alerta cada item una vez y clear no toca al otro', (
    tester,
  ) async {
    final workout = await workoutRepository.startWorkout();
    final first = await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );
    final second = await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );
    var now = DateTime(2026, 3, 1, 12);
    final notifier = FakeRestNotifier();
    await workoutRepository.startRestTimer(
      workoutExerciseId: first.id,
      plannedRestSeconds: 15,
      now: now,
    );
    await workoutRepository.startRestTimer(
      workoutExerciseId: second.id,
      plannedRestSeconds: 30,
      now: now,
    );

    await pumpView(
      tester,
      workout.id,
      viewport: const Size(1000, 2200),
      clock: () => now,
      notifier: notifier,
    );
    await tester.tap(find.byKey(Key('expand-${second.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    now = now.add(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 2));

    expect(notifier.alerts.where((key) => key == first.id), hasLength(1));
    expect(notifier.alerts.where((key) => key == second.id), hasLength(1));
    expect(find.text('LISTO · Press de banca'), findsNWidgets(2));

    await tester.pump(const Duration(seconds: 3));
    expect(notifier.alerts.where((key) => key == first.id), hasLength(1));
    expect(notifier.alerts.where((key) => key == second.id), hasLength(1));

    await tester.tap(find.byKey(Key('rest-clear-${first.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(Key('rest-clear-${first.id}')), findsNothing);
    expect(find.byKey(Key('rest-clear-${second.id}')), findsOneWidget);
    expect((await storedItem(second.id)).restEndsAt, isNotNull);

    await unmount(tester);
  });

  testWidgets('controles del item miden 44 dp y no desbordan a 320/375 dp', (
    tester,
  ) async {
    final workout = await workoutRepository.startWorkout();
    final item = await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );
    final now = DateTime(2026, 3, 1, 12);
    await workoutRepository.startRestTimer(
      workoutExerciseId: item.id,
      plannedRestSeconds: 120,
      now: now,
    );

    for (final width in [320.0, 375.0]) {
      await pumpView(
        tester,
        workout.id,
        viewport: Size(width, 1800),
        clock: () => now,
        textScale: 1.3,
      );
      final plus = find.byKey(Key('rest-plus-${item.id}'));
      await tester.ensureVisible(plus);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      for (final key in [
        'rest-minus-${item.id}',
        'rest-pause-${item.id}',
        'rest-plus-${item.id}',
        'rest-card-add30-${item.id}',
        'rest-skip-${item.id}',
      ]) {
        final size = tester.getSize(find.byKey(Key(key)));
        expect(size.width, greaterThanOrEqualTo(44), reason: '$width / $key');
        expect(size.height, greaterThanOrEqualTo(44), reason: '$width / $key');
      }
      expect(find.byTooltip('Ajustar +15 s'), findsOneWidget);
      expect(find.byTooltip('Ajustar +30 s'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'viewport $width');

      await unmount(tester);
    }
  });

  testWidgets('golden: LiveWorkoutView con datos (T-009 / SCR-03)', (
    tester,
  ) async {
    final workout = await workoutRepository.startWorkout();
    await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );

    await pumpView(tester, workout.id);

    await expectLater(
      find.byType(LiveWorkoutView),
      matchesGoldenFile('goldens/live_workout_view.png'),
    );

    await dismissSnackBars(tester);
  }, tags: ['golden']);
}
