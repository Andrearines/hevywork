import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/app/theme/app_theme.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/body_metric_repository.dart';
import 'package:hevywork/data/repositories/catalog_repository.dart';
import 'package:hevywork/data/repositories/goal_repository.dart';
import 'package:hevywork/data/repositories/routine_repository.dart';
import 'package:hevywork/data/repositories/workout_repository.dart';
import 'package:hevywork/data/sync/sync_engine.dart';
import 'package:hevywork/main.dart';
import 'package:hevywork/ui/views/goal_editor_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    localDb = AppDatabase(NativeDatabase.memory());
    syncEngine = SyncEngine(localDb, null);
    catalogRepository = CatalogRepository(localDb);
    workoutRepository = WorkoutRepository(localDb);
    routineRepository = RoutineRepository(localDb, workoutRepository);
    goalRepository = GoalRepository(localDb);
    bodyMetricRepository = BodyMetricRepository(localDb);

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

  setUp(() async {
    await localDb.delete(localDb.goals).go();
    await localDb.delete(localDb.bodyMetrics).go();
  });

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: GoalEditorView()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
  }

  Future<void> pickExercise(WidgetTester tester) async {
    await tester.tap(find.text('Elegir Ejercicio'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Press de banca'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('crear una meta de fuerza pide ejercicio y objetivo (RF-2)',
      (tester) async {
    await pumpView(tester);

    await pickExercise(tester);
    expect(find.text('Press de banca'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '80');
    await tester.tap(find.text('Guardar meta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));

    final goals = await localDb.select(localDb.goals).get();
    expect(goals, hasLength(1));
    expect(goals.single.type, 'strength');
    expect(goals.single.targetValue, 80);
    expect(goals.single.metricRef, 'bench-press');
    expect(goals.single.status, 'active');
  });

  testWidgets('una meta sin objetivo no se guarda y avisa', (tester) async {
    await pumpView(tester);

    await tester.tap(find.text('Guardar meta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('Pon un objetivo válido'), findsOneWidget);
    expect(await localDb.select(localDb.goals).get(), isEmpty);
  });

  testWidgets('una meta de fuerza sin ejercicio no se guarda', (tester) async {
    await pumpView(tester);

    await tester.enterText(find.byType(TextField), '80');
    await tester.tap(find.text('Guardar meta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('Elige un ejercicio'), findsOneWidget);
    expect(await localDb.select(localDb.goals).get(), isEmpty);
  });

  testWidgets('cambiar a Volumen muestra músculo y periodo', (tester) async {
    await pumpView(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Volumen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('Por ejercicio'), findsOneWidget);
    expect(find.text('Por músculo'), findsOneWidget);
    expect(find.text('Semanal'), findsOneWidget);
    expect(find.text('Mensual'), findsOneWidget);

    await tester.tap(find.text('Por músculo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('Músculo'), findsOneWidget);

    await tester.tap(find.text('Músculo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('chest').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '1500');
    await tester.tap(find.text('Guardar meta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));

    final goal = (await localDb.select(localDb.goals).get()).single;
    expect(goal.type, 'volume');
    expect(goal.period, 'weekly');
    expect(goal.metricRef, 'chest');
    expect(goal.targetValue, 1500);
  });

  testWidgets('editar una meta cargada trae sus valores (RF-2)', (tester) async {
    final goal = await goalRepository.createGoal(
      type: 'strength',
      targetValue: 80,
      metricRef: 'bench-press',
      deadline: DateTime(2026, 12, 31),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: GoalEditorView(goal: goal)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('Editar meta'), findsOneWidget);
    expect(find.text('Press de banca'), findsOneWidget);
    expect(find.text('80'), findsOneWidget);
    expect(find.text('Plazo: 31/12/2026'), findsOneWidget);
  });
}