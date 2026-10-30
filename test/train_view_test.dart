import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/app/theme/app_theme.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/body_metric_repository.dart';
import 'package:hevywork/data/repositories/catalog_repository.dart';
import 'package:hevywork/data/repositories/fatigue_repository.dart';
import 'package:hevywork/data/repositories/goal_repository.dart';
import 'package:hevywork/data/repositories/profile_repository.dart';
import 'package:hevywork/data/repositories/routine_repository.dart';
import 'package:hevywork/data/repositories/workout_repository.dart';
import 'package:hevywork/data/sync/sync_engine.dart';
import 'package:hevywork/main.dart';
import 'package:hevywork/ui/unit_system_scope.dart';
import 'package:hevywork/ui/views/past_workout_editor_view.dart';
import 'package:hevywork/ui/views/train_view.dart';

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
    fatigueRepository = FatigueRepository(localDb);
    profileRepository = ProfileRepository(localDb);

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
    await localDb.delete(localDb.workoutSets).go();
    await localDb.delete(localDb.workoutExercises).go();
    await localDb.delete(localDb.workouts).go();
  });

  Future<void> pumpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: TrainView()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
  }

  Future<void> pumpImperialView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const UnitSystemScope(
          unitSystem: 'imperial',
          child: Scaffold(body: TrainView()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> seedFinishedSession(
    String id, {
    required DateTime endedAt,
    String? routineId,
    String? name,
  }) async {
    await localDb.into(localDb.workouts).insert(
          WorkoutsCompanion.insert(
            id: id,
            localUserId: 'perfil-pruebas',
            startedAt: endedAt.subtract(const Duration(hours: 1)),
            status: const Value('finished'),
            endedAt: Value(endedAt),
            routineId: Value(routineId),
            name: Value(name),
          ),
        );
    await localDb.into(localDb.workoutExercises).insert(
          WorkoutExercisesCompanion.insert(
            id: '$id-we',
            workoutId: id,
            exerciseId: 'bench-press',
            orderIndex: 0,
          ),
        );
    await localDb.into(localDb.workoutSets).insert(
          WorkoutSetsCompanion.insert(
            id: '$id-set',
            workoutExerciseId: '$id-we',
            orderIndex: 0,
            weightKg: const Value(60),
            reps: const Value(8),
            completed: const Value(true),
          ),
        );
  }

  group('Panel Entrenar — historial', () {
    testWidgets('banner de racha, adherencia y descanso activo', (tester) async {
      await seedFinishedSession(
        'sesion-1',
        endedAt: DateTime.now().subtract(const Duration(hours: 2)),
        routineId: 'rutina-push',
        name: 'Push A',
      );

      await pumpView(tester);

      expect(find.text('RACHA CONTINUA DE ADHERENCIA'), findsOneWidget);
      expect(find.text('semana'), findsOneWidget);
      expect(find.text('1/4 esta semana'), findsOneWidget);

      // Rejilla 2×2 (RF-8): el descanso cuenta los días desde la última
      // sesión; una sesión de hace 2 h son 0 días (amenda T-18).
      expect(find.text('Sesiones'), findsOneWidget);
      expect(find.text('Adherencia'), findsOneWidget);
      expect(find.text('Descanso activo'), findsOneWidget);
      expect(find.text('0 d'), findsOneWidget);
      expect(find.text('Volumen mes'), findsOneWidget);

      expect(find.text('Sesiones Recientes'), findsOneWidget);

      await unmount(tester);
    });

    testWidgets('el descanso cuenta los días desde la última sesión',
        (tester) async {
      await seedFinishedSession(
        'sesion-reciente',
        endedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      await seedFinishedSession(
        'sesion-vieja',
        endedAt: DateTime.now().subtract(const Duration(days: 5)),
      );

      await pumpView(tester);

      // La más reciente (hace 1 día) manda sobre la de hace 5 días.
      expect(find.text('1 d'), findsOneWidget);
      expect(find.text('5 d'), findsNothing);

      await unmount(tester);
    });

    testWidgets('sin sesiones el banner y la rejilla se quedan en cero',
        (tester) async {
      await pumpView(tester);

      expect(find.text('semanas'), findsOneWidget);
      expect(find.text('0/4 esta semana'), findsOneWidget);
      expect(find.text('Sin sesiones todavía'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);

      await unmount(tester);
    });

    testWidgets('el CTA de registrar entrenamiento pasado abre su editor',
        (tester) async {
      await pumpView(tester);

      await tester.tap(find.text('Registrar entrenamiento pasado'));
      await tester.pumpAndSettle();

      expect(find.byType(PastWorkoutEditorView), findsOneWidget);
      expect(find.text('Guardar sesión'), findsOneWidget);
      expect(find.text('Elegir rutina'), findsOneWidget);
      expect(find.text('Añadir ejercicio'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(PastWorkoutEditorView), findsNothing);

      await unmount(tester);
    });

    testWidgets('el botón Exportar CSV copia el historial al portapapeles',
        (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await pumpView(tester);

      await tester.tap(find.text('Exportar CSV'));
      await tester.pumpAndSettle();

      expect(calls.any((call) => call.method == 'Clipboard.setData'), isTrue);
      expect(find.text('Datos copiados al portapapeles'), findsOneWidget);

      await unmount(tester);
    });

    testWidgets('las sesiones del feed muestran sus métricas y Repetir',
        (tester) async {
      await seedFinishedSession(
        'sesion-push',
        endedAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
        routineId: 'rutina-push',
        name: 'Push A',
      );

      await pumpView(tester);

      expect(find.text('Push A'), findsOneWidget);
      expect(find.text('DURACIÓN'), findsOneWidget);
      expect(find.text('SERIES'), findsOneWidget);
      expect(find.text('TONELAJE'), findsOneWidget);
      expect(find.text('Repetir'), findsOneWidget);

      await unmount(tester);
    });

    testWidgets('en imperial el feed presenta tonelaje y series en lb (RF-4)',
        (tester) async {
      await seedFinishedSession(
        'sesion-lb',
        endedAt: DateTime.now().subtract(const Duration(days: 1)),
        name: 'Push A',
      );

      await pumpImperialView(tester);

      expect(find.text('Push A'), findsOneWidget);
      expect(find.text('TONELAJE'), findsOneWidget);
      expect(find.text('1.058'), findsNWidgets(2));
      expect(find.text('132.3 lb × 8'), findsOneWidget);

      await unmount(tester);
    });

    testWidgets('borrar en el feed pide confirmación, cancelar lo conserva '
        'y confirmar elimina la sesión (RF-12)', (tester) async {
      await seedFinishedSession(
        'sesion-borrar',
        endedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      await pumpView(tester);

      expect(find.text('Entrenamiento libre'), findsOneWidget);

      await tester.tap(find.text('Borrar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.textContaining('¿Borrar la sesión'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Entrenamiento libre'), findsOneWidget);
      expect(await localDb.select(localDb.workouts).get(), hasLength(1));

      await tester.tap(find.text('Borrar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.widgetWithText(TextButton, 'Borrar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Entrenamiento libre'), findsNothing);
      expect(find.textContaining('¿Borrar la sesión'), findsNothing);
      expect(await localDb.select(localDb.workouts).get(), isEmpty);
      expect(await localDb.select(localDb.workoutExercises).get(), isEmpty);
      expect(await localDb.select(localDb.workoutSets).get(), isEmpty);

      await unmount(tester);
    });
  });
}
