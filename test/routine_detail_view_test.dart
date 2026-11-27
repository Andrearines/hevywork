import 'package:drift/drift.dart' show InsertMode, Value;
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
import 'package:hevywork/ui/unit_system_scope.dart';
import 'package:hevywork/ui/widgets/exercise_progress_chart.dart';
import 'package:hevywork/ui/widgets/exercise_thumb.dart';
import 'package:hevywork/ui/views/exercise_info_view.dart';
import 'package:hevywork/ui/views/routine_detail_view.dart';

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
    const catalog = [
      ExercisesCompanion(
        id: Value('bench-press'),
        name: Value('Press de banca'),
        bodyPart: Value('chest'),
        equipment: Value('barbell'),
        target: Value('pectorals'),
        muscleGroup: Value('triceps'),
      ),
      ExercisesCompanion(
        id: Value('glute-bridge'),
        name: Value('Puente de glúteos'),
        bodyPart: Value('legs'),
        equipment: Value('barbell'),
        target: Value('glutes'),
        muscleGroup: Value('hamstrings'),
      ),
    ];
    for (final exercise in catalog) {
      await localDb
          .into(localDb.exercises)
          .insert(exercise, mode: InsertMode.insertOrIgnore);
    }
  });

  tearDownAll(() => localDb.close());

  Future<Routine> createRoutine({
    String name = 'Tren superior',
    String? description = 'Fuerza y volumen',
    String? category = 'Fuerza',
    String? level = 'Intermedio',
    String? goal = 'Hipertrofia',
    int? targetDays = 4,
    List<RoutineExerciseDraft> exercises = const [
      RoutineExerciseDraft(
        exerciseId: 'bench-press',
        sets: [
          RoutineSetDraft(reps: 8, rir: 2, weightKg: 60),
          RoutineSetDraft(reps: 8, rir: 2, weightKg: 60),
          RoutineSetDraft(reps: 8, rir: 2, weightKg: 60),
        ],
      ),
      RoutineExerciseDraft(
        exerciseId: 'glute-bridge',
        sets: [
          RoutineSetDraft(reps: 12, rir: 1, weightKg: 0),
          RoutineSetDraft(reps: 12, rir: 1, weightKg: 0),
        ],
      ),
    ],
  }) => routineRepository.createRoutine(
    name: name,
    description: description,
    category: category,
    level: level,
    goal: goal,
    targetDays: targetDays,
    exercises: exercises,
  );

  Future<void> insertCustom() async {
    final profile = await localDb.select(localDb.localProfiles).getSingle();
    await localDb
        .into(localDb.exercises)
        .insert(
          ExercisesCompanion.insert(
            id: 'custom_routine-detail',
            name: 'Press propio en rutina',
            bodyPart: 'chest',
            equipment: 'barbell',
            target: 'pectorals',
            muscleGroup: 'triceps',
            secondaryMuscles: const Value('["triceps"]'),
            origin: const Value('custom'),
            localUserId: Value(profile.localUserId),
            imageUploadStatus: const Value('none'),
            updatedAt: Value(DateTime(2026, 11, 26)),
            restSeconds: const Value(135),
          ),
        );
  }

  Future<void> pumpDetail(
    WidgetTester tester, {
    required Routine routine,
    Future<void> Function()? onStart,
    Future<void> Function()? onEdit,
  }) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: RoutineDetailView(
            routine: routine,
            onStart: onStart ?? () async {},
            onEdit: onEdit ?? () async {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
  }

  Future<void> pumpImperialDetail(
    WidgetTester tester, {
    required Routine routine,
  }) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: UnitSystemScope(
          unitSystem: 'imperial',
          child: Scaffold(
            body: RoutineDetailView(
              routine: routine,
              onStart: () async {},
              onEdit: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> seedFinishedBenchSession(
    String workoutId,
    DateTime endedAt,
    double weightKg,
  ) async {
    final profile = await localDb.select(localDb.localProfiles).getSingle();
    await localDb
        .into(localDb.workouts)
        .insert(
          WorkoutsCompanion.insert(
            id: workoutId,
            localUserId: profile.localUserId,
            startedAt: endedAt.subtract(const Duration(hours: 1)),
            endedAt: Value(endedAt),
            status: const Value('finished'),
          ),
        );
    await localDb
        .into(localDb.workoutExercises)
        .insert(
          WorkoutExercisesCompanion.insert(
            id: '$workoutId-bench',
            workoutId: workoutId,
            exerciseId: 'bench-press',
            orderIndex: 1,
          ),
        );
    await localDb
        .into(localDb.workoutSets)
        .insert(
          WorkoutSetsCompanion.insert(
            id: '$workoutId-set',
            workoutExerciseId: '$workoutId-bench',
            orderIndex: 1,
            weightKg: Value(weightKg),
            reps: const Value(5),
            rir: const Value(2),
            completed: const Value(true),
          ),
        );
  }

  test('021/T-002 CA-16: el resumen conserva decimales y unidades', () async {
    final routine = await createRoutine(
      exercises: const [
        RoutineExerciseDraft(
          exerciseId: 'bench-press',
          sets: [
            RoutineSetDraft(reps: 8, rir: 2, weightKg: 61.25),
            RoutineSetDraft(reps: 8, rir: 2, weightKg: 1.25),
          ],
        ),
      ],
    );
    final item = await (localDb.select(
      localDb.routineExercises,
    )..where((row) => row.routineId.equals(routine.id))).getSingle();
    final sets = await routineRepository.routineSets(item.id);

    expect(
      setsSummary(sets, 'metric'),
      '2 series · 8 reps · RIR 2 · 1.25-61.25 kg',
    );
    expect(
      setsSummary(sets, 'imperial'),
      '2 series · 8 reps · RIR 2 · 2.76-135.03 lb',
    );
  });

  testWidgets('muestra metadata de planificación y el número de ejercicios '
      '(RF-38)', (tester) async {
    final routine = await createRoutine();
    await pumpDetail(tester, routine: routine);

    expect(find.byType(RoutineDetailView), findsOneWidget);
    expect(find.text('Tren superior'), findsOneWidget);
    expect(find.text('Fuerza y volumen'), findsOneWidget);
    expect(find.text('Fuerza'), findsOneWidget);
    expect(find.text('Intermedio'), findsOneWidget);
    expect(find.text('Hipertrofia'), findsOneWidget);
    expect(find.text('4 días / semana'), findsOneWidget);
    expect(find.textContaining('EJERCICIOS (2)'), findsOneWidget);
    expect(find.text('5 series'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('lista cada ejercicio con nombre, objetivo y resumen de series', (
    tester,
  ) async {
    final routine = await createRoutine();
    await pumpDetail(tester, routine: routine);

    expect(find.text('Press de banca'), findsOneWidget);
    expect(find.text('Puente de glúteos'), findsOneWidget);
    expect(find.text('Pecho · barbell'), findsOneWidget);
    expect(find.text('Glúteos · barbell'), findsOneWidget);
    expect(find.text('3 series · 8 reps · RIR 2 · 60 kg'), findsOneWidget);
    expect(find.text('2 series · 12 reps · RIR 1'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('la ficha del ejercicio abre su detalle completo (RF-38)', (
    tester,
  ) async {
    final routine = await createRoutine();
    await pumpDetail(tester, routine: routine);

    await tester.tap(
      find.byKey(const Key('routine-detail-exercise-bench-press')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byType(ExerciseInfoView), findsOneWidget);
    expect(find.text('Press de banca'), findsWidgets);

    await unmount(tester);
  });

  testWidgets('volver de la ficha recarga el custom y conserva sus series', (
    tester,
  ) async {
    await insertCustom();
    final routine = await createRoutine(
      exercises: const [
        RoutineExerciseDraft(
          exerciseId: 'custom_routine-detail',
          sets: [
            RoutineSetDraft(reps: 8, rir: 2, weightKg: 52.5, restSeconds: 105),
          ],
        ),
      ],
    );
    await pumpDetail(tester, routine: routine);
    expect(find.byType(ExerciseThumb), findsOneWidget);
    expect(find.text('Press propio en rutina'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('routine-detail-exercise-custom_routine-detail')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(ExerciseInfoView), findsOneWidget);

    await (localDb.update(
      localDb.exercises,
    )..where((row) => row.id.equals('custom_routine-detail'))).write(
      ExercisesCompanion(
        name: const Value('Press propio actualizado'),
        equipment: const Value('dumbbell'),
        updatedAt: Value(DateTime(2026, 11, 26, 12)),
      ),
    );
    await tester.tap(find.byTooltip('Volver'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('Press propio actualizado'), findsOneWidget);
    expect(find.text('Press propio en rutina'), findsNothing);
    expect(find.textContaining('dumbbell'), findsOneWidget);
    final item = await localDb.select(localDb.routineExercises).getSingle();
    final sets = await routineRepository.routineSets(item.id);
    expect(sets.single.weightKg, 52.5);
    expect(sets.single.reps, 8);
    expect(sets.single.rir, 2);
    expect(sets.single.restSeconds, 105);
    expect(find.textContaining('52.50 kg'), findsOneWidget);
    expect(find.textContaining('Descanso 105 s'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('abrir desde rutina carga el historial real y pinta progresión', (
    tester,
  ) async {
    final now = DateTime.now();
    await seedFinishedBenchSession(
      'routine-progress-w1',
      now.subtract(const Duration(days: 12)),
      80,
    );
    await seedFinishedBenchSession(
      'routine-progress-w2',
      now.subtract(const Duration(days: 5)),
      90,
    );
    final routine = await createRoutine(
      exercises: const [
        RoutineExerciseDraft(
          exerciseId: 'bench-press',
          sets: [RoutineSetDraft(reps: 5, rir: 2, weightKg: 80)],
        ),
      ],
    );
    await pumpDetail(tester, routine: routine);

    await tester.tap(
      find.byKey(const Key('routine-detail-exercise-bench-press')),
    );
    await tester.pumpAndSettle();

    final info = tester.widget<ExerciseInfoView>(find.byType(ExerciseInfoView));
    expect(info.database, same(localDb));
    expect(info.workoutRepository, same(workoutRepository));
    expect(find.text('2 registros'), findsOneWidget);
    expect(find.byKey(chartPlotKey), findsOneWidget);
    expect(find.text('Sin datos en esta ventana'), findsNothing);
    expect(tester.takeException(), isNull);

    await unmount(tester);
  });

  testWidgets('la acción Iniciar invoca el callback (RF-38)', (tester) async {
    var started = 0;
    final routine = await createRoutine();
    await pumpDetail(tester, routine: routine, onStart: () async => started++);

    await tester.tap(find.byKey(const Key('routine-detail-start')));
    await tester.pump();

    expect(started, 1);

    await unmount(tester);
  });

  testWidgets('la acción Editar invoca el callback (RF-38)', (tester) async {
    var edited = 0;
    final routine = await createRoutine();
    await pumpDetail(tester, routine: routine, onEdit: () async => edited++);

    await tester.tap(find.byKey(const Key('routine-detail-edit')));
    await tester.pump();

    expect(edited, 1);

    await unmount(tester);
  });

  testWidgets('una rutina vacía muestra su estado y oculta Iniciar', (
    tester,
  ) async {
    final routine = await createRoutine(exercises: const []);
    await pumpDetail(tester, routine: routine);

    expect(find.text('Esta rutina aún no tiene ejercicios'), findsOneWidget);
    expect(find.text('Ábrela en el editor para añadirlos.'), findsOneWidget);
    expect(find.byKey(const Key('routine-detail-start')), findsNothing);

    await unmount(tester);
  });

  testWidgets('en imperial el resumen convierte el peso a lb', (tester) async {
    final routine = await createRoutine(
      exercises: const [
        RoutineExerciseDraft(
          exerciseId: 'bench-press',
          sets: [
            RoutineSetDraft(reps: 8, rir: 2, weightKg: 60),
            RoutineSetDraft(reps: 8, rir: 2, weightKg: 60),
          ],
        ),
      ],
    );
    await pumpImperialDetail(tester, routine: routine);

    expect(find.text('2 series · 8 reps · RIR 2 · 132.28 lb'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('golden: detalle de rutina con ejercicios (RF-38)', (
    tester,
  ) async {
    final routine = await createRoutine();
    await pumpDetail(tester, routine: routine);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(RoutineDetailView),
      matchesGoldenFile('goldens/routine_detail.png'),
    );

    await unmount(tester);
  }, tags: ['golden']);
}
