import 'package:drift/drift.dart' show InsertMode;
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
import 'package:hevywork/ui/views/past_workout_editor_view.dart';
import 'package:hevywork/ui/widgets/exercise_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    localDb = AppDatabase(NativeDatabase.memory());
    syncEngine = SyncEngine(localDb, null);
    catalogRepository = CatalogRepository(localDb);
    workoutRepository = WorkoutRepository(localDb);
    routineRepository = RoutineRepository(localDb, workoutRepository);
    goalRepository = GoalRepository(localDb);
    fatigueRepository = FatigueRepository(localDb);
  });

  setUp(() async {
    await localDb.delete(localDb.workoutSets).go();
    await localDb.delete(localDb.workoutExercises).go();
    await localDb.delete(localDb.workouts).go();
    await localDb.delete(localDb.routineSets).go();
    await localDb.delete(localDb.routineExercises).go();
    await localDb.delete(localDb.routines).go();
    await localDb.into(localDb.exercises).insert(
          ExercisesCompanion.insert(
            id: 'bench-press',
            name: 'Press de banca',
            bodyPart: 'chest',
            equipment: 'barbell',
            target: 'pectorals',
            muscleGroup: 'chest',
          ),
          mode: InsertMode.insertOrIgnore,
        );
  });

  tearDownAll(() => localDb.close());

  Future<void> pumpEditor(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: SizedBox()),
      ),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const PastWorkoutEditorView(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> pickBenchPress(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(OutlinedButton, 'Añadir ejercicio'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final searchField = find.descendant(
      of: find.byType(ExercisePicker),
      matching: find.byType(TextField),
    );
    await tester.enterText(searchField, 'Press');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Press de banca'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> saveAndSettle(WidgetTester tester) async {
    await tester.tap(find.text('Guardar sesión'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('guardar sin ejercicios avisa y no crea nada (RF-5)',
      (tester) async {
    await pumpEditor(tester);

    expect(find.text('Añade los ejercicios que hiciste ese día: elige una '
        'rutina o búscalos en el catálogo.'), findsOneWidget);

    await saveAndSettle(tester);

    expect(find.text('Añade al menos un ejercicio'), findsOneWidget);
    final workouts = await localDb.select(localDb.workouts).get();
    expect(workouts, isEmpty);

    await unmount(tester);
  });

  testWidgets('la duración fuera de rango avisa antes de guardar (RF-5)',
      (tester) async {
    await pumpEditor(tester);
    await pickBenchPress(tester);

    await tester.enterText(find.byKey(const Key('past-duration')), '0');
    await saveAndSettle(tester);

    expect(
      find.text('La duración debe estar entre 1 y 720 minutos'),
      findsOneWidget,
    );
    final workouts = await localDb.select(localDb.workouts).get();
    expect(workouts, isEmpty);

    await unmount(tester);
  });

  testWidgets('guarda un ejercicio manual como sesión terminada (RF-4)',
      (tester) async {
    await pumpEditor(tester);
    await pickBenchPress(tester);

    expect(find.text('Press de banca'), findsOneWidget);
    expect(find.text('60.0'), findsNothing);

    await saveAndSettle(tester);

    expect(find.text('Entrenamiento registrado'), findsOneWidget);

    final workouts = await localDb.select(localDb.workouts).get();
    expect(workouts, hasLength(1));
    final workout = workouts.single;
    expect(workout.status, 'finished');
    expect(workout.endedAt, isNotNull);
    expect(
      workout.endedAt!.difference(workout.startedAt),
      const Duration(minutes: 60),
    );
    expect(
      DateTime(
        workout.startedAt.year,
        workout.startedAt.month,
        workout.startedAt.day,
      ),
      DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ),
    );
    expect(workout.routineId, isNull);

    final items = await localDb.select(localDb.workoutExercises).get();
    expect(items, hasLength(1));
    final sets = await localDb.select(localDb.workoutSets).get();
    expect(sets, hasLength(3));
    expect(sets.every((s) => s.completed), isTrue);
    expect([for (final s in sets) s.orderIndex], [1, 2, 3]);

    await unmount(tester);
  });

  testWidgets('una serie con repeticiones vacías bloquea el guardado (RF-5)',
      (tester) async {
    await pumpEditor(tester);
    await pickBenchPress(tester);

    await tester.enterText(
      find.byKey(const Key('past-set-reps-ex-0-0')),
      '',
    );
    await saveAndSettle(tester);

    expect(
      find.text('Press de banca: las repeticiones deben ser 1 o más'),
      findsOneWidget,
    );
    final workouts = await localDb.select(localDb.workouts).get();
    expect(workouts, isEmpty);

    await unmount(tester);
  });

  testWidgets('clona los ejercicios y series de una rutina (RF-2)',
      (tester) async {
    final routine = await routineRepository.createRoutine(
      name: 'Tren superior',
      exercises: const [
        RoutineExerciseDraft(
          exerciseId: 'bench-press',
          sets: [
            RoutineSetDraft(reps: 8, rir: 2, weightKg: 60),
            RoutineSetDraft(reps: 6, rir: 1, weightKg: 65),
          ],
        ),
      ],
    );

    await pumpEditor(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Elegir rutina'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Tren superior'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Press de banca'), findsOneWidget);
    expect(find.text('60.0'), findsOneWidget);
    expect(find.text('65.0'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);

    await saveAndSettle(tester);

    expect(find.text('Entrenamiento registrado'), findsOneWidget);
    final workouts = await localDb.select(localDb.workouts).get();
    expect(workouts, hasLength(1));
    expect(workouts.single.routineId, routine.id);
    expect(workouts.single.name, 'Tren superior');

    final sets = await localDb.select(localDb.workoutSets).get();
    expect(sets, hasLength(2));
    expect(sets.every((s) => s.routineSetId != null), isTrue);
    expect([for (final s in sets) s.weightKg], [60.0, 65.0]);

    await unmount(tester);
  });

  testWidgets('cambiar de rutina con borrador pide confirmación',
      (tester) async {
    await routineRepository.createRoutine(
      name: 'Tren superior',
      exercises: const [
        RoutineExerciseDraft(
          exerciseId: 'bench-press',
          sets: [RoutineSetDraft(reps: 8, rir: 2, weightKg: 60)],
        ),
      ],
    );
    await routineRepository.createRoutine(
      name: 'Pierna',
      exercises: const [
        RoutineExerciseDraft(
          exerciseId: 'bench-press',
          sets: [RoutineSetDraft(reps: 6, rir: 1, weightKg: 80)],
        ),
      ],
    );

    await pumpEditor(tester);
    await pickBenchPress(tester);
    expect(find.text('Press de banca'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Elegir rutina'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Tren superior'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Reemplazar ejercicios'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Press de banca'), findsOneWidget);

    await unmount(tester);
  });
}
