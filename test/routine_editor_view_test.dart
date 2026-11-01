import 'package:drift/drift.dart' show InsertMode;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/app/theme/app_theme.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/catalog_repository.dart';
import 'package:hevywork/data/repositories/routine_repository.dart';
import 'package:hevywork/data/repositories/workout_repository.dart';
import 'package:hevywork/data/sync/sync_engine.dart';
import 'package:hevywork/main.dart';
import 'package:hevywork/ui/views/routine_editor_view.dart';
import 'package:hevywork/ui/widgets/exercise_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    localDb = AppDatabase(NativeDatabase.memory());
    syncEngine = SyncEngine(localDb, null);
    catalogRepository = CatalogRepository(localDb);
    workoutRepository = WorkoutRepository(localDb);
    routineRepository = RoutineRepository(localDb, workoutRepository);
  });

  setUp(() async {
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
    await localDb.into(localDb.exercises).insert(
          ExercisesCompanion.insert(
            id: 'squat',
            name: 'Sentadilla',
            bodyPart: 'legs',
            equipment: 'barbell',
            target: 'quads',
            muscleGroup: 'legs',
          ),
          mode: InsertMode.insertOrIgnore,
        );
  });

  tearDownAll(() => localDb.close());

  Future<void> pumpEditor(WidgetTester tester, {Routine? routine}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: SizedBox()),
      ),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => RoutineEditorView(
          routine: routine,
          catalogRepository: catalogRepository,
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

  Future<void> pickExerciseNamed(
    WidgetTester tester,
    String query,
    String name,
  ) async {
    await tester.tap(find.widgetWithText(OutlinedButton, 'Añadir ejercicio'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final searchField = find.descendant(
      of: find.byType(ExercisePicker),
      matching: find.byType(TextField),
    );
    await tester.enterText(searchField, query);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text(name));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> pickBenchPress(WidgetTester tester) =>
      pickExerciseNamed(tester, 'Press', 'Press de banca');

  testWidgets('crea la rutina con las series planificadas del picker (RF-1)',
      (tester) async {
    await pumpEditor(tester);

    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Crear rutina'),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byKey(const Key('routine-name')), 'Fuerza');
    await pickBenchPress(tester);

    expect(find.text('Press de banca'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('draft-set-kg-set-0')), '72.5');
    await tester.enterText(
        find.byKey(const Key('draft-set-reps-set-0')), '6');
    await tester.enterText(
        find.byKey(const Key('draft-set-rir-set-0')), '1');
    await tester.enterText(
        find.byKey(const Key('draft-set-rest-set-0')), '120');
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Crear rutina'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(RoutineEditorView), findsNothing);
    expect(find.text('Rutina creada'), findsOneWidget);

    final routine = await localDb.select(localDb.routines).getSingle();
    expect(routine.name, 'Fuerza');

    final items = await (localDb.select(localDb.routineExercises)
          ..where((t) => t.routineId.equals(routine.id)))
        .get();
    expect(items, hasLength(1));
    expect(items.single.exerciseId, 'bench-press');
    expect(items.single.targetSets, 3);
    expect(items.single.autoProgress, isTrue);

    final sets = await routineRepository.routineSets(items.single.id);
    expect(sets, hasLength(3));
    expect(sets.first.weightKg, 72.5);
    expect(sets.first.reps, 6);
    expect(sets.first.rir, 1);
    expect(sets.first.restSeconds, 120);

    await unmount(tester);
  });

  testWidgets('añade y quita series en el editor (RF-1)', (tester) async {
    await pumpEditor(tester);

    await tester.enterText(find.byKey(const Key('routine-name')), 'Series');
    await pickBenchPress(tester);

    await tester.ensureVisible(find.byKey(const Key('draft-add-set-new-0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('draft-add-set-new-0')));
    await tester.pump();
    expect(find.byKey(const Key('draft-set-kg-set-3')), findsOneWidget);

    await tester.ensureVisible(
        find.byKey(const Key('draft-remove-set-set-0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('draft-remove-set-set-0')));
    await tester.pump();

    await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Crear rutina'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Crear rutina'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(seconds: 1));

    final item = await localDb.select(localDb.routineExercises).getSingle();
    final sets = await routineRepository.routineSets(item.id);
    expect(sets, hasLength(3));

    await unmount(tester);
  });

  testWidgets('una serie fuera de rango avisa y no guarda nada',
      (tester) async {
    await pumpEditor(tester);

    await tester.enterText(
        find.byKey(const Key('routine-name')), 'Rutina rota');
    await pickBenchPress(tester);
    await tester.enterText(
        find.byKey(const Key('draft-set-reps-set-0')), '0');
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Crear rutina'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Revisa las series de Press de banca'), findsOneWidget);
    expect(find.byType(RoutineEditorView), findsOneWidget);
    expect(await localDb.select(localDb.routines).get(), isEmpty);

    await unmount(tester);
  });

  testWidgets('el switch de progresión apagado guarda auto_progress false',
      (tester) async {
    await pumpEditor(tester);

    await tester.enterText(
        find.byKey(const Key('routine-name')), 'Sin progresión');
    await pickBenchPress(tester);

    expect(find.text('Progresión automática'), findsOneWidget);
    await tester.ensureVisible(find.text('Progresión automática'));
    await tester.pump();
    await tester.tap(find.text('Progresión automática'));
    await tester.pump();

    await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Crear rutina'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Crear rutina'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));

    final item = await localDb.select(localDb.routineExercises).getSingle();
    expect(item.autoProgress, isFalse);

    await unmount(tester);
  });

  testWidgets('editar carga las series y conserva el id de sus ejercicios',
      (tester) async {
    final routine = await routineRepository.createRoutine(
      name: 'Push',
      description: 'Empuje',
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
    final original = await localDb.select(localDb.routineExercises).getSingle();
    final originalSets = await routineRepository.routineSets(original.id);

    await pumpEditor(tester, routine: routine);

    expect(find.text('Push'), findsOneWidget);
    expect(find.text('Press de banca'), findsOneWidget);
    expect(find.text('Guardar cambios'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('routine-name')), 'Push pesado');
    await tester.enterText(
        find.byKey(Key('draft-set-kg-${originalSets.first.id}')), '65');
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar cambios'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(RoutineEditorView), findsNothing);
    expect(find.text('Rutina guardada'), findsOneWidget);

    final updatedRoutine = await (localDb.select(localDb.routines)
          ..where((t) => t.id.equals(routine.id)))
        .getSingle();
    expect(updatedRoutine.name, 'Push pesado');

    final items = await localDb.select(localDb.routineExercises).get();
    expect(items, hasLength(1));
    expect(items.single.id, original.id);

    final sets = await routineRepository.routineSets(original.id);
    expect(sets, hasLength(3));
    expect(sets.first.weightKg, 65);
    expect(
      [for (final set in sets) set.id],
      [for (final set in originalSets) set.id],
    );

    await unmount(tester);
  });

  testWidgets('arrastrar el primer ejercicio abajo lo deja el último (RF-2)',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpEditor(tester);
    await tester.enterText(find.byKey(const Key('routine-name')), 'Orden');
    await pickBenchPress(tester);
    await pickExerciseNamed(tester, 'Sent', 'Sentadilla');

    final handle = find.byIcon(Icons.drag_handle).first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 10));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 245));
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Sentadilla')).dy,
      lessThan(tester.getTopLeft(find.text('Press de banca')).dy),
    );

    await tester.ensureVisible(
      find.widgetWithText(ElevatedButton, 'Crear rutina'),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Crear rutina'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(RoutineEditorView), findsNothing);

    final items = await localDb.select(localDb.routineExercises).get();
    final ordered = [for (final item in items) item]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    expect(
      [for (final item in ordered) item.exerciseId],
      ['squat', 'bench-press'],
    );

    await unmount(tester);
  });
}
