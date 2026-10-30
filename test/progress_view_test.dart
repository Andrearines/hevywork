import 'dart:math' as math;

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/app/theme/app_theme.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/body_metric_repository.dart';
import 'package:hevywork/data/repositories/catalog_repository.dart';
import 'package:hevywork/data/repositories/fatigue_repository.dart';
import 'package:hevywork/data/repositories/goal_repository.dart';
import 'package:hevywork/data/repositories/photo_repository.dart';
import 'package:hevywork/data/repositories/profile_repository.dart';
import 'package:hevywork/data/repositories/routine_repository.dart';
import 'package:hevywork/data/repositories/workout_repository.dart';
import 'package:hevywork/data/sync/sync_engine.dart';
import 'package:hevywork/domain/body_composition.dart';
import 'package:hevywork/main.dart';
import 'package:hevywork/ui/theme/colors.dart';
import 'package:hevywork/ui/unit_system_scope.dart';
import 'package:hevywork/ui/views/progress_view.dart';
import 'package:hevywork/ui/widgets/capped_scroll.dart';
import 'package:hevywork/ui/widgets/muscle_map.dart';
import 'package:muscle_mapper/muscle_mapper.dart';

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
    photoRepository = PhotoRepository(localDb);

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
    await localDb.delete(localDb.progressPhotos).go();
    await localDb.delete(localDb.workoutSets).go();
    await localDb.delete(localDb.workoutExercises).go();
    await localDb.delete(localDb.workouts).go();
    // La composición estimada depende del perfil: sin datos entre tests.
    await (localDb.update(localDb.localProfiles)
          ..where((t) => t.id.equals(1)))
        .write(
      const LocalProfilesCompanion(
        sex: Value(null),
        heightCm: Value(null),
      ),
    );
  });

  Future<void> pumpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: ProgressView()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    // El initState recalcula el progreso: dos frames extra para asentar.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
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
          child: Scaffold(body: ProgressView()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> seedFinishedWorkouts(int count) async {
    final now = DateTime.now();
    final profile = await (localDb.select(localDb.localProfiles)
          ..where((t) => t.id.equals(1)))
        .getSingle();
    for (var i = 1; i <= count; i++) {
      final ended = now.subtract(Duration(days: i));
      await localDb.into(localDb.workouts).insert(
            WorkoutsCompanion.insert(
              id: 'w-$i',
              localUserId: profile.localUserId,
              startedAt: ended.subtract(const Duration(hours: 1)),
              status: const Value('finished'),
              endedAt: Value(ended),
            ),
          );
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  /// Sesiones terminadas con dorsales e isquios para poblar la tabla de
  /// zonas y el mapa (T-13). `hamstringsWeightKg` ajusta el volumen de
  /// isquios y `hamstringsDaysAgo` su antigüedad, para contrastar estados.
  Future<void> seedZoneData({
    double hamstringsWeightKg = 60,
    int hamstringsDaysAgo = 0,
  }) async {
    final now = DateTime.now();
    final profile = await (localDb.select(localDb.localProfiles)
          ..where((t) => t.id.equals(1)))
        .getSingle();
    for (final entry in const [
      ('lat-pulldown', 'lats'),
      ('roman-deadlift', 'hamstrings'),
    ]) {
      await localDb.into(localDb.exercises).insert(
            ExercisesCompanion.insert(
              id: entry.$1,
              name: entry.$1,
              bodyPart: 'back',
              equipment: 'cable',
              target: entry.$2,
              muscleGroup: entry.$2,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }

    Future<void> seedZoneWorkout({
      required String workoutId,
      required String exerciseId,
      required double weightKg,
      required int daysAgo,
    }) async {
      final ended = now.subtract(Duration(days: daysAgo, hours: 1));
      await localDb.into(localDb.workouts).insert(
            WorkoutsCompanion.insert(
              id: workoutId,
              localUserId: profile.localUserId,
              startedAt: ended.subtract(const Duration(hours: 1)),
              status: const Value('finished'),
              endedAt: Value(ended),
            ),
          );
      final workoutExerciseId = 'we-$exerciseId';
      await localDb.into(localDb.workoutExercises).insert(
            WorkoutExercisesCompanion.insert(
              id: workoutExerciseId,
              workoutId: workoutId,
              exerciseId: exerciseId,
              orderIndex: 0,
            ),
          );
      await localDb.into(localDb.workoutSets).insert(
            WorkoutSetsCompanion.insert(
              id: 'ws-$exerciseId',
              workoutExerciseId: workoutExerciseId,
              orderIndex: 0,
              weightKg: Value(weightKg),
              reps: const Value(10),
              completed: const Value(true),
            ),
          );
    }

    await seedZoneWorkout(
      workoutId: 'zone-workout-lats',
      exerciseId: 'lat-pulldown',
      weightKg: 60,
      daysAgo: 0,
    );
    await seedZoneWorkout(
      workoutId: 'zone-workout-hams',
      exerciseId: 'roman-deadlift',
      weightKg: hamstringsWeightKg,
      daysAgo: hamstringsDaysAgo,
    );
  }

  /// Fila de la tabla de zonas con el fondo de selección.
  Finder selectedZoneRow(String title) => find.ancestor(
        of: find.text(title),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is AnimatedContainer &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color ==
                  kSurfaceContainerHigh,
        ),
      );

  testWidgets('sin metas ni registros muestra ambas secciones vacías',
      (tester) async {
    await pumpView(tester);

    expect(find.text('Aún no tienes metas'), findsOneWidget);
    expect(find.text('Mis metas'), findsOneWidget);
    expect(find.text('Nueva meta'), findsOneWidget);
    expect(find.text('Peso y medidas'), findsOneWidget);
    expect(find.text('Nueva Medida'), findsOneWidget);
    expect(
      find.text('Pésate cada mañana y guarda tus medidas para ver la '
          'tendencia aquí.'),
      findsOneWidget,
    );
    expect(find.text('Registra tu peso para ver la tendencia'), findsOneWidget);
    expect(find.text('Registra tu peso para ver la tendencia'), findsOneWidget);
    expect(find.text('Registrar peso'), findsNothing);

    await unmount(tester);
  });

  testWidgets(
      'la sección de distribución muscular abre con mapa, toggle y leyenda '
      '(RF-24)', (tester) async {
    await pumpView(tester);

    expect(find.text('Distribución Muscular'), findsOneWidget);
    expect(
      find.text('Volumen semanal y estado de fatiga'),
      findsOneWidget,
    );
    expect(find.text('Frente'), findsOneWidget);
    expect(find.text('Espalda'), findsOneWidget);
    expect(find.textContaining('Alto'), findsOneWidget);
    expect(find.textContaining('Óptimo'), findsOneWidget);
    expect(find.textContaining('Recuperado'), findsOneWidget);
    expect(find.text('Interactivo'), findsOneWidget);
    expect(find.textContaining('ZONAS'), findsOneWidget);
    // Sin sesiones el cache está vacío: aviso en lugar de datos.
    expect(
      find.text('Termina sesiones de entrenamiento para ver qué '
          'músculos están fatigados y cuáles están frescos.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Espalda'));
    await tester.pump();
    expect(find.byType(MuscleMap), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('con sesiones muestra los músculos más fatigados (RF-6)',
      (tester) async {
    final profile = await (localDb.select(localDb.localProfiles)
          ..where((t) => t.id.equals(1)))
        .getSingle();
    final now = DateTime.now();
    await localDb.into(localDb.workouts).insert(
          WorkoutsCompanion.insert(
            id: 'w-fat',
            localUserId: profile.localUserId,
            startedAt: now.subtract(const Duration(hours: 1)),
            status: const Value('finished'),
            endedAt: Value(now),
          ),
        );
    await localDb.into(localDb.workoutExercises).insert(
          WorkoutExercisesCompanion.insert(
            id: 'we-fat',
            workoutId: 'w-fat',
            exerciseId: 'bench-press',
            orderIndex: 0,
          ),
        );
    await localDb.into(localDb.workoutSets).insert(
          WorkoutSetsCompanion.insert(
            id: 'set-fat',
            workoutExerciseId: 'we-fat',
            orderIndex: 0,
            weightKg: const Value(100),
            reps: const Value(10),
            completed: const Value(true),
          ),
        );

    await pumpView(tester);

    // `bench-press` es de pecho → la zona de pectoral aparece en la lista.
    expect(find.text('Pecho'), findsWidgets);

    await unmount(tester);
  });

  testWidgets('los glúteos se marcan aunque el dataset los liste como '
      'secundarios (amenda 2026-10-22)', (tester) async {
    // Réplica del bug: el puente de glúteos trae `target: glutes` pero
    // `muscle_group: hamstrings` (el primer secundario). El mapa debe
    // encender los glúteos en rojo, no los isquios.
    await localDb.into(localDb.exercises).insert(
          ExercisesCompanion.insert(
            id: 'glute-bridge',
            name: 'Puente de glúteos',
            bodyPart: 'legs',
            equipment: 'barbell',
            target: 'glutes',
            muscleGroup: 'hamstrings',
          ),
        );
    final profile = await (localDb.select(localDb.localProfiles)
          ..where((t) => t.id.equals(1)))
        .getSingle();
    final now = DateTime.now();
    await localDb.into(localDb.workouts).insert(
          WorkoutsCompanion.insert(
            id: 'w-glutes',
            localUserId: profile.localUserId,
            startedAt: now.subtract(const Duration(hours: 1)),
            status: const Value('finished'),
            endedAt: Value(now),
          ),
        );
    await localDb.into(localDb.workoutExercises).insert(
          WorkoutExercisesCompanion.insert(
            id: 'we-glutes',
            workoutId: 'w-glutes',
            exerciseId: 'glute-bridge',
            orderIndex: 0,
          ),
        );
    await localDb.into(localDb.workoutSets).insert(
          WorkoutSetsCompanion.insert(
            id: 'set-glutes',
            workoutExerciseId: 'we-glutes',
            orderIndex: 0,
            weightKg: const Value(0),
            reps: const Value(15),
            completed: const Value(true),
          ),
        );

    await pumpView(tester);
    await tester.pumpAndSettle();

    final glutesRow = find
        .ancestor(of: find.text('Glúteos'), matching: find.byType(Row))
        .first;
    final glutesAlto = tester.widget<Text>(
      find.descendant(of: glutesRow, matching: find.text('Alto')),
    );
    expect(glutesAlto.style?.color, kFatigueHot);

    await unmount(tester);
  });

  testWidgets('Nueva meta abre el editor', (tester) async {
    await pumpView(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Nueva meta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Guardar meta'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('una meta activa muestra su % de cumplimiento (H3)',
      (tester) async {
    await goalRepository.createGoal(type: 'consistency', targetValue: 4);
    await seedFinishedWorkouts(2);
    await pumpView(tester);

    expect(find.text('Constancia'), findsOneWidget);
    expect(find.text('2 / 4 sesiones'), findsOneWidget);
    expect(find.text('50 %'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('los objetivos se limitan a 3 tarjetas con scroll interno (RF-13)',
      (tester) async {
    await goalRepository.createGoal(type: 'bodyweight', targetValue: 85);
    await goalRepository.createGoal(type: 'consistency', targetValue: 4);
    await goalRepository.createGoal(
      type: 'strength',
      targetValue: 100,
      metricRef: 'bench-press',
    );
    await pumpView(tester);

    expect(
      find.descendant(
        of: find.byType(CappedScroll),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );

    await goalRepository.createGoal(
      type: 'volume',
      targetValue: 1000,
      period: 'weekly',
      metricRef: 'bench-press',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();

    final capped = find.byType(CappedScroll);
    expect(capped, findsOneWidget);
    expect(
      find.descendant(of: capped, matching: find.byType(SingleChildScrollView)),
      findsOneWidget,
    );
    await tester.ensureVisible(capped);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final section = tester.getRect(capped);
    final titles = const ['Peso corporal', 'Constancia', 'Fuerza', 'Volumen'];

    bool visible(String title) {
      final rect = tester.getRect(
        find.descendant(of: capped, matching: find.text(title)),
      );
      return rect.top >= section.top && rect.bottom <= section.bottom;
    }

    final hidden = titles.where((title) => !visible(title)).toList();
    expect(hidden, hasLength(1));

    await tester.drag(capped, const Offset(0, -260));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(tester.getRect(capped).top, closeTo(section.top, 0.5));
    expect(visible(hidden.single), isTrue);

    await unmount(tester);
  });

  testWidgets('añadir registro guarda y dispara el logro de la meta',
      (tester) async {
    await bodyMetricRepository.upsert(
      date: BodyMetricRepository.dayOf(DateTime.now())
          .subtract(const Duration(days: 3)),
      weightKg: 90,
    );
    await goalRepository.createGoal(type: 'bodyweight', targetValue: 85);
    await pumpView(tester);

    await tester.tap(find.text('Nueva Medida'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Nuevo registro'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Peso (kg)'),
      '84',
    );
    await tester.tap(find.text('Guardar registro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Registro guardado'), findsOneWidget);
    expect(await localDb.select(localDb.bodyMetrics).get(), hasLength(2));

    final goal = (await localDb.select(localDb.goals).get()).single;
    expect(goal.status, 'achieved');
    expect(goal.currentValue, 84);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('¡Metas logradas!'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('sin datos pide peso o medidas', (tester) async {
    await pumpView(tester);

    await tester.tap(find.text('Nueva Medida'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.text('Guardar registro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // El messenger muestra el aviso en el Scaffold del editor y en el del home.
    expect(find.text('Añade peso, medidas o composición'), findsWidgets);

    await unmount(tester);
  });

  testWidgets('los registros muestran medidas y deltas frente al anterior',
      (tester) async {
    final today = BodyMetricRepository.dayOf(DateTime.now());
    await bodyMetricRepository.upsert(
      date: today.subtract(const Duration(days: 2)),
      weightKg: 84,
      measures: const {'chest': 102, 'arm': 38},
    );
    await bodyMetricRepository.upsert(
      date: today.subtract(const Duration(days: 1)),
      weightKg: 84.5,
      measures: const {'chest': 102.5, 'arm': 37.5},
    );
    await pumpView(tester);

    expect(find.text('84 kg'), findsOneWidget);
    expect(find.text('84.5 kg'), findsOneWidget);
    expect(find.text('Pecho 102.5'), findsOneWidget);
    expect(find.text('+0.5 kg'), findsOneWidget);
    expect(find.text('+0.5'), findsOneWidget);
    expect(find.text('-0.5'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('editar un registro guarda los cambios (RF-2)', (tester) async {
    final today = BodyMetricRepository.dayOf(DateTime.now());
    await bodyMetricRepository.upsert(
      date: today,
      weightKg: 80,
      measures: const {'chest': 100},
    );
    await pumpView(tester);

    await tester.tap(find.byTooltip('Opciones del registro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.text('Editar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Editar registro'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Peso (kg)'),
      '79.5',
    );
    await tester.tap(find.text('Guardar registro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));

    final records = await localDb.select(localDb.bodyMetrics).get();
    expect(records, hasLength(1));
    expect(records.single.weightKg, 79.5);
    expect(records.single.measuresJson, contains('100'));

    await unmount(tester);
  });

  testWidgets('borrar un registro pide confirmación y lo elimina (RF-2)',
      (tester) async {
    final today = BodyMetricRepository.dayOf(DateTime.now());
    await bodyMetricRepository.upsert(date: today, weightKg: 80);
    await pumpView(tester);

    await tester.tap(find.byTooltip('Opciones del registro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.text('Borrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      find.textContaining('¿Borrar el registro del'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Borrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));

    expect(await localDb.select(localDb.bodyMetrics).get(), isEmpty);
    expect(find.text('Registro borrado'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('borrar pide confirmación y elimina la meta', (tester) async {
    await goalRepository.createGoal(type: 'consistency', targetValue: 4);
    await pumpView(tester);

    await tester.tap(find.byTooltip('Opciones de la meta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.text('Borrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('¿Borrar "Constancia"?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Borrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Aún no tienes metas'), findsOneWidget);
    expect(await localDb.select(localDb.goals).get(), isEmpty);

    await unmount(tester);
  });

  testWidgets('editar abre el editor con los valores cargados (RF-2)',
      (tester) async {
    await goalRepository.createGoal(
      type: 'strength',
      targetValue: 80,
      metricRef: 'bench-press',
    );
    await pumpView(tester);

    await tester.tap(find.byTooltip('Opciones de la meta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.text('Editar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Editar meta'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Press de banca'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('la tarjeta de peso muestra valor, ritmo del mes y meta (RF-23)',
      (tester) async {
    final today = BodyMetricRepository.dayOf(DateTime.now());
    await bodyMetricRepository.upsert(
      date: today.subtract(const Duration(days: 20)),
      weightKg: 79.6,
    );
    await bodyMetricRepository.upsert(
      date: today.subtract(const Duration(days: 10)),
      weightKg: 79,
    );
    await bodyMetricRepository.upsert(date: today, weightKg: 78.4);
    await goalRepository.createGoal(
      type: 'bodyweight',
      targetValue: 76,
      deadline: today.add(const Duration(days: 30)),
    );
    await pumpView(tester);

    expect(find.text('PESO CORPORAL'), findsOneWidget);
    expect(find.text('78.4'), findsOneWidget);
    expect(find.text('-1.2 kg este mes'), findsOneWidget);
    expect(find.textContaining('Meta:', findRichText: true), findsOneWidget);
    expect(find.text('Hoy (78.4)'), findsOneWidget);
    expect(find.textContaining('79.6)'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('en imperial la tarjeta de peso presenta lb (RF-4)',
      (tester) async {
    final today = BodyMetricRepository.dayOf(DateTime.now());
    await bodyMetricRepository.upsert(
      date: today.subtract(const Duration(days: 10)),
      weightKg: 79,
    );
    await bodyMetricRepository.upsert(date: today, weightKg: 78.4);
    await goalRepository.createGoal(
      type: 'bodyweight',
      targetValue: 76,
      deadline: today.add(const Duration(days: 30)),
    );
    await pumpImperialView(tester);

    expect(find.text('PESO CORPORAL'), findsOneWidget);
    expect(find.text('172.8'), findsOneWidget);
    expect(find.text('lb'), findsWidgets);
    expect(find.text('-1.3 lb este mes'), findsOneWidget);
    expect(find.textContaining('Meta:', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('Meta: 167.6', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Hoy (172.8)'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('sin meta activa la tarjeta no muestra la meta (RF-23)',
      (tester) async {
    final today = BodyMetricRepository.dayOf(DateTime.now());
    await bodyMetricRepository.upsert(date: today, weightKg: 80);
    await pumpView(tester);

    expect(find.text('PESO CORPORAL'), findsOneWidget);
    expect(find.textContaining('Meta:', findRichText: true), findsNothing);

    await unmount(tester);
  });

  testWidgets('con dos o más registros la tendencia pinta la serie '
      '(no el aviso vacío)', (tester) async {
    final today = BodyMetricRepository.dayOf(DateTime.now());
    await bodyMetricRepository.upsert(
      date: today.subtract(const Duration(days: 5)),
      weightKg: 80.2,
    );
    await bodyMetricRepository.upsert(date: today, weightKg: 79.5);
    await pumpView(tester);

    expect(find.text('Registra tu peso para ver la tendencia'), findsNothing);

    await unmount(tester);
  });

  testWidgets('con un solo registro la tendencia muestra el aviso (RF-3)',
      (tester) async {
    final today = BodyMetricRepository.dayOf(DateTime.now());
    await bodyMetricRepository.upsert(date: today, weightKg: 80);
    await pumpView(tester);

    expect(find.text('Registra tu peso para ver la tendencia'), findsOneWidget);

    await unmount(tester);
  });


  testWidgets('sin medidas las secciones nuevas muestran su estado vacío '
      '(RF-37)', (tester) async {
    final today = BodyMetricRepository.dayOf(DateTime.now());
    await bodyMetricRepository.upsert(date: today, weightKg: 80);
    await pumpView(tester);

    // Composición corporal (spec 009): cards con aspecto final y vacío.
    expect(find.text('GRASA ESTIMADA'), findsOneWidget);
    expect(find.text('MASA MAGRA'), findsOneWidget);
    expect(find.text('Sin registro anterior'), findsNWidgets(2));
    expect(find.text('—'), findsWidgets);

    // Las medidas viven en su propia pantalla: entrada compacta en Progreso.
    final measures = find.text('Medidas');
    await tester.dragUntilVisible(
      measures,
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(measures, findsOneWidget);
    expect(find.text('Medidas corporales y evolución'), findsOneWidget);

    final photos = find.text('Fotos de Progreso');
    await tester.dragUntilVisible(
      photos,
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(photos, findsOneWidget);
    expect(find.text('Sin comparación'), findsOneWidget);
    expect(find.text('FRENTE'), findsOneWidget);
    expect(find.text('PERFIL'), findsOneWidget);
    expect(find.text('ESPALDA'), findsOneWidget);
    expect(
      find.text(
        'Añade fotos de frente, perfil y espalda para comparar tu progreso',
      ),
      findsOneWidget,
    );

    final callout = find.text('Báscula y Caliper Conectados');
    await tester.dragUntilVisible(
      callout,
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(callout, findsOneWidget);
    expect(find.text('Sin dispositivos conectados todavía'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('composición: grasa, masa magra y Δ (spec 009, RF-3)',
      (tester) async {
    final now = BodyMetricRepository.dayOf(DateTime.now());
    await bodyMetricRepository.upsert(
      date: now.subtract(const Duration(days: 30)),
      bodyFatPct: 20,
      leanMassKg: 64,
    );
    await bodyMetricRepository.upsert(
      date: now,
      bodyFatPct: 18,
      leanMassKg: 66,
    );
    await pumpView(tester);

    await tester.dragUntilVisible(
      find.text('GRASA ESTIMADA'),
      find.byType(ListView).first,
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();

    expect(find.text('18.0'), findsOneWidget);
    expect(find.text('66.0'), findsOneWidget);
    expect(find.textContaining('Registro manual'), findsNWidgets(2));
    expect(find.textContaining('-2.0 %'), findsOneWidget);
    expect(find.textContaining('+2.0 kg'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('composición estimada con US Navy desde las medidas '
      '(spec 009, RF-4)', (tester) async {
    await profileRepository.setSex('male');
    await profileRepository.setHeightCm(180);
    final now = BodyMetricRepository.dayOf(DateTime.now());
    await bodyMetricRepository.upsert(
      date: now,
      weightKg: 80,
      measures: const {'neck': 40, 'waist': 90},
    );
    await pumpView(tester);

    await tester.dragUntilVisible(
      find.text('GRASA ESTIMADA'),
      find.byType(ListView).first,
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Estimado · US Navy'), findsNWidgets(2));
    final expectedFat = navyBodyFatPercent(
      sex: 'male',
      heightCm: 180,
      neckCm: 40,
      waistCm: 90,
    )!;
    final expectedLean = 80 * (1 - expectedFat / 100);
    expect(find.text(expectedFat.toStringAsFixed(1)), findsOneWidget);
    expect(find.text(expectedLean.toStringAsFixed(1)), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('composición y dispositivos enlazan a sus specs (009/011)',
      (tester) async {
    final today = BodyMetricRepository.dayOf(DateTime.now());
    await bodyMetricRepository.upsert(date: today, weightKg: 80);
    await pumpView(tester);

    await tester.dragUntilVisible(
      find.text('GRASA ESTIMADA'),
      find.byType(ListView).first,
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(find.text('GRASA ESTIMADA'), findsOneWidget);
    expect(find.text('MASA MAGRA'), findsOneWidget);

    final callout = find.text('Báscula y Caliper Conectados');
    await tester.dragUntilVisible(
      callout,
      find.byType(ListView).first,
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(callout, findsOneWidget);

    await unmount(tester);
  });

  testWidgets(
      'tocar el mapa en una región resalta su fila de la tabla (viceversa)',
      (tester) async {
    await seedZoneData();
    await pumpView(tester);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Espalda'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Espalda'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(MuscleMap));
    await tester.pumpAndSettle();
    final mapRect = tester.getRect(find.byType(MuscleMap));

    // El SVG se pinta con `BoxFit.contain`: el barrido va por el espacio del
    // viewBox para que los toques caigan sobre la silueta, no al lado.
    const viewBox = Size(676.49, 1203.49);
    final scale = math.min(
      mapRect.width / viewBox.width,
      mapRect.height / viewBox.height,
    );
    final offsetX = (mapRect.width - viewBox.width * scale) / 2;
    final offsetY = (mapRect.height - viewBox.height * scale) / 2;
    Offset svgPoint(double x, double y) => Offset(
          mapRect.left + offsetX + x * scale,
          mapRect.top + offsetY + y * scale,
        );

    Offset? latsPoint;
    Offset? hamstringsPoint;
    for (var y = 20.0;
        y < viewBox.height &&
            (latsPoint == null || hamstringsPoint == null);
        y += 40) {
      for (var x = 20.0;
          x < viewBox.width &&
              (latsPoint == null || hamstringsPoint == null);
          x += 40) {
        final point = svgPoint(x, y);
        await tester.tapAt(point);
        await tester.pump();
        final mapper = tester.widget<MuscleMapper>(find.byType(MuscleMapper));
        if (mapper.activeMuscles.contains(Muscle.lats)) latsPoint ??= point;
        if (mapper.activeMuscles.contains(Muscle.lateralHamstrings)) {
          hamstringsPoint ??= point;
        }
      }
    }

    expect(
      latsPoint,
      isNotNull,
      reason: 'la silueta de espalda tiene una región que selecciona dorsales',
    );
    expect(
      hamstringsPoint,
      isNotNull,
      reason: 'la silueta de espalda tiene una región que selecciona isquios',
    );

    var mapper = tester.widget<MuscleMapper>(find.byType(MuscleMapper));
    if (!mapper.activeMuscles.contains(Muscle.lats)) {
      await tester.tapAt(latsPoint!);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    mapper = tester.widget<MuscleMapper>(find.byType(MuscleMapper));
    expect(mapper.activeMuscles, contains(Muscle.lats));
    expect(
      mapper.activeMuscles,
      isNot(contains(Muscle.lateralHamstrings)),
      reason: 'al marcar dorsales no deben quedar marcados los isquios',
    );

    await tester.dragUntilVisible(
      find.text('Dorsales'),
      find.byType(ListView).first,
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(selectedZoneRow('Dorsales'), findsOneWidget);
    expect(selectedZoneRow('Isquios'), findsNothing);

    await unmount(tester);
  });

  testWidgets('el estado de la fila acompaña al color del mapa (RF-24)',
      (tester) async {
    // Cache limpio: la fila tiene que releerse tras el recálculo de apertura.
    await localDb.delete(localDb.muscleFatigue).go();
    // Dorsales hoy (primario → «Alto») e isquios hace 4 días (ya recuperado):
    // el contraste prueba que fila y mapa cuentan la misma historia.
    await seedZoneData(hamstringsWeightKg: 6, hamstringsDaysAgo: 4);
    await pumpView(tester);
    await tester.pumpAndSettle();

    expect(find.text('Dorsales'), findsOneWidget);
    // Dorsales entrenados hoy: badge «Alto» en rojo, nunca «Recuperado».
    final alto = tester.widget<Text>(find.text('Alto'));
    expect(alto.style?.color, kFatigueHot);
    // Isquios entrenados hace 4 días: chip «Recuperado» en azul dentro
    // de su propia fila (la lista muestra las 17 zonas del mapa).
    final isquiosRow = find
        .ancestor(
          of: find.text('Isquios'),
          matching: find.byType(Row),
        )
        .first;
    final recuperado = tester.widget<Text>(
      find.descendant(of: isquiosRow, matching: find.text('Recuperado')),
    );
    expect(recuperado.style?.color, kFatigueCold);

    // El mapa pinta la misma historia: dorsales rojos, isquios fríos.
    await tester.ensureVisible(find.text('Espalda'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Espalda'));
    await tester.pumpAndSettle();
    final mapper = tester.widget<MuscleMapper>(find.byType(MuscleMapper));
    expect(mapper.muscleColors?[Muscle.lats], kFatigueHot);
    expect(mapper.muscleColors?[Muscle.lateralHamstrings], isNot(kFatigueHot));

    await unmount(tester);
  });

  testWidgets('la cabecera cambia el rango de la tendencia (RF-22)',
      (tester) async {
    await pumpView(tester);
    expect(find.text('Últimos 30 días'), findsOneWidget);

    await tester.tap(find.text('Últimos 30 días'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Últimos 90 días').last);
    await tester.pumpAndSettle();

    expect(find.text('Últimos 90 días'), findsOneWidget);
    expect(find.text('Peso y medidas'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('golden: Progreso sin datos (T-12)', (tester) async {
    await pumpView(tester);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ProgressView),
      matchesGoldenFile('goldens/progress_empty.png'),
    );

    await unmount(tester);
  });
}