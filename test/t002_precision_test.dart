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
import 'package:hevywork/ui/unit_system_scope.dart';
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

  tearDownAll(() => localDb.close());

  StateSetter? unitSetter;
  String currentUnit = 'metric';

  Future<void> pumpLive(
    WidgetTester tester,
    String workoutId, {
    String unit = 'metric',
    bool switchable = false,
  }) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    currentUnit = unit;

    if (switchable) {
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            unitSetter = setState;
            return UnitSystemScope(
              unitSystem: currentUnit,
              child: MaterialApp(
                theme: buildAppTheme(),
                home: const Scaffold(body: SizedBox()),
              ),
            );
          },
        ),
      );
    } else {
      await tester.pumpWidget(
        UnitSystemScope(
          unitSystem: unit,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const Scaffold(body: SizedBox()),
          ),
        ),
      );
    }
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

  Future<void> setUnit(WidgetTester tester, String unit) async {
    currentUnit = unit;
    unitSetter!(() {});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  }

  String ctrl(WidgetTester tester, String rowId) => tester
      .widget<TextField>(find.byKey(Key('set-weight-$rowId')))
      .controller!
      .text;

  void expectSummaries40(WidgetTester tester) {
    final texts = tester.widgetList<Text>(find.byType(Text)).toList();
    expect(texts.where((text) => text.data == '40'), hasLength(2));
    expect(texts.where((text) => text.data == 'kg'), hasLength(2));
    expect(texts.where((text) => text.data == '39.99'), isEmpty);
  }

  Future<void> chip(WidgetTester tester, String label) async {
    final ink = tester.widget<InkWell>(
      find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
    );
    ink.onTap!();
    await tester.pump();
  }

  Future<void> confirm(WidgetTester tester, String rowId) async {
    final detector = tester.widget<GestureDetector>(
      find.byKey(Key('set-check-$rowId')),
    );
    detector.onTap!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<List<WorkoutSet>> setsOf(String itemId) async {
    return (localDb.select(
      localDb.workoutSets,
    )..where((t) => t.workoutExerciseId.equals(itemId))).get();
  }

  Future<Map<String, String>> newWorkout() async {
    final workout = await workoutRepository.startWorkout();
    final item = await workoutRepository.addExercise(
      workoutId: workout.id,
      exerciseId: 'bench-press',
    );
    return {'workoutId': workout.id, 'itemId': item.id};
  }

  testWidgets('021/T-002 CA-10…CA-14: precisión numérica en vivo', (
    tester,
  ) async {
    var w = await newWorkout();
    final confirmedWorkoutId = w['workoutId']!;
    await pumpLive(tester, confirmedWorkoutId);
    await tester.enterText(find.byKey(Key('set-weight-${w['itemId']}')), '40');
    await tester.enterText(find.byKey(Key('set-reps-${w['itemId']}')), '1');
    await tester.enterText(find.byKey(Key('set-rir-${w['itemId']}')), '0');
    await confirm(tester, w['itemId']!);
    var sets = await setsOf(w['itemId']!);
    final confirmedSetId = sets.single.id;
    expect(sets.single.weightKg, 40.0);
    expect(ctrl(tester, confirmedSetId), '40');
    expectSummaries40(tester);
    expect(find.text('39.99'), findsNothing);
    await unmount(tester);

    await pumpLive(tester, confirmedWorkoutId);
    sets = await setsOf(w['itemId']!);
    expect(sets.single.id, confirmedSetId);
    expect(sets.single.weightKg, 40.0);
    expect(ctrl(tester, confirmedSetId), '40');
    expectSummaries40(tester);
    expect(find.text('39.99'), findsNothing);
    await unmount(tester);

    w = await newWorkout();
    await pumpLive(tester, w['workoutId']!);
    expect(find.text('+1.25 kg'), findsOneWidget);
    expect(find.text('+2.50 kg'), findsOneWidget);
    expect(find.text('−1.25 kg'), findsOneWidget);
    expect(find.text('−2.50 kg'), findsOneWidget);
    expect(find.text('+1.3 kg'), findsNothing);
    await tester.enterText(find.byKey(Key('set-weight-${w['itemId']}')), '40');
    await chip(tester, '+1.25 kg');
    expect(ctrl(tester, w['itemId']!), '41.25');
    await chip(tester, '−1.25 kg');
    expect(ctrl(tester, w['itemId']!), '40');
    await tester.enterText(find.byKey(Key('set-reps-${w['itemId']}')), '8');
    await tester.enterText(find.byKey(Key('set-rir-${w['itemId']}')), '2');
    await confirm(tester, w['itemId']!);
    expect((await setsOf(w['itemId']!)).single.weightKg, 40.0);
    await unmount(tester);

    w = await newWorkout();
    await pumpLive(tester, w['workoutId']!, unit: 'imperial', switchable: true);
    await tester.enterText(find.byKey(Key('set-weight-${w['itemId']}')), '100');
    await tester.enterText(find.byKey(Key('set-reps-${w['itemId']}')), '8');
    await tester.enterText(find.byKey(Key('set-rir-${w['itemId']}')), '2');
    await confirm(tester, w['itemId']!);
    sets = await setsOf(w['itemId']!);
    expect(sets.single.weightKg, 45.359);
    final imperialSetId = sets.single.id;
    expect(ctrl(tester, imperialSetId), '100');
    await setUnit(tester, 'metric');
    expect(ctrl(tester, imperialSetId), '45.36');
    await setUnit(tester, 'imperial');
    expect(ctrl(tester, imperialSetId), '100');
    await unmount(tester);

    w = await newWorkout();
    final existing = await workoutRepository.logSet(
      workoutExerciseId: w['itemId']!,
      weightKg: 40,
      reps: 8,
      rir: 2,
      completed: false,
    );
    await pumpLive(tester, w['workoutId']!, switchable: true);
    expect(ctrl(tester, existing.id), '40');
    await tester.enterText(find.byKey(Key('set-weight-${existing.id}')), '50');
    await setUnit(tester, 'imperial');
    expect(ctrl(tester, existing.id), '110.23');
    await setUnit(tester, 'metric');
    expect(ctrl(tester, existing.id), '50');
    await confirm(tester, existing.id);
    sets = await setsOf(w['itemId']!);
    expect(sets.single.weightKg, 50.0);
    expect(ctrl(tester, existing.id), '50');
    await unmount(tester);

    w = await newWorkout();
    await pumpLive(tester, w['workoutId']!, switchable: true);
    await tester.enterText(find.byKey(Key('set-weight-${w['itemId']}')), '40');
    expect(ctrl(tester, w['itemId']!), '40');
    await setUnit(tester, 'imperial');
    expect(ctrl(tester, w['itemId']!), '88.18');
    await tester.enterText(find.byKey(Key('set-reps-${w['itemId']}')), '8');
    await tester.enterText(find.byKey(Key('set-rir-${w['itemId']}')), '2');
    await confirm(tester, w['itemId']!);
    expect((await setsOf(w['itemId']!)).single.weightKg, closeTo(40, 1e-9));
    await unmount(tester);
  });
}
