import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/app/theme/app_theme.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/routine_repository.dart';
import 'package:hevywork/data/repositories/template_repository.dart';
import 'package:hevywork/data/repositories/workout_repository.dart';
import 'package:hevywork/data/sync/sync_engine.dart';
import 'package:hevywork/main.dart';
import 'package:hevywork/ui/views/routine_detail_view.dart';
import 'package:hevywork/ui/views/routine_editor_view.dart';
import 'package:hevywork/ui/views/routines_view.dart';
import 'package:hevywork/ui/views/templates_view.dart';
import 'package:hevywork/ui/widgets/exercise_thumb.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    localDb = AppDatabase(NativeDatabase.memory());
    syncEngine = SyncEngine(localDb, null);
    workoutRepository = WorkoutRepository(localDb);
    routineRepository = RoutineRepository(localDb, workoutRepository);
    templateRepository = TemplateRepository(
      localDb,
      routineRepository,
      fetcher: () async => const [],
    );
  });

  setUp(() async {
    await localDb.delete(localDb.workoutSets).go();
    await localDb.delete(localDb.workoutExercises).go();
    await localDb.delete(localDb.workouts).go();
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
        muscleGroup: Value('chest'),
      ),
      ExercisesCompanion(
        id: Value('triceps-pushdown'),
        name: Value('Extensión de tríceps'),
        bodyPart: Value('arms'),
        equipment: Value('cable'),
        target: Value('triceps'),
        muscleGroup: Value('triceps'),
      ),
      ExercisesCompanion(
        id: Value('bicep-curl'),
        name: Value('Curl de bíceps'),
        bodyPart: Value('arms'),
        equipment: Value('dumbbell'),
        target: Value('biceps'),
        muscleGroup: Value('biceps'),
      ),
    ];
    for (final exercise in catalog) {
      await localDb
          .into(localDb.exercises)
          .insert(exercise, mode: InsertMode.insertOrIgnore);
    }
  });

  tearDownAll(() => localDb.close());

  Future<void> pumpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: RoutinesView()),
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

  Future<Routine> createRoutine({
    String name = 'Tren superior',
    String? description = 'Fuerza y volumen',
    String? category,
    String? level,
    String? goal,
    int? targetDays,
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
        exerciseId: 'bench-press',
        sets: [
          RoutineSetDraft(reps: 10, rir: 3, weightKg: 40),
          RoutineSetDraft(reps: 10, rir: 3, weightKg: 40),
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

  Future<void> seedFinishedSession(
    String id, {
    required DateTime endedAt,
    String? routineId,
  }) async {
    await localDb
        .into(localDb.workouts)
        .insert(
          WorkoutsCompanion.insert(
            id: id,
            localUserId: 'perfil-pruebas',
            startedAt: endedAt.subtract(const Duration(hours: 1)),
            status: const Value('finished'),
            endedAt: Value(endedAt),
            routineId: Value(routineId),
          ),
        );
    await localDb
        .into(localDb.workoutExercises)
        .insert(
          WorkoutExercisesCompanion.insert(
            id: '$id-we',
            workoutId: id,
            exerciseId: 'bench-press',
            orderIndex: 0,
          ),
        );
    await localDb
        .into(localDb.workoutSets)
        .insert(
          WorkoutSetsCompanion.insert(
            id: '$id-set',
            workoutExerciseId: '$id-we',
            orderIndex: 0,
            weightKg: const Value(60),
            reps: const Value(8),
          ),
        );
  }

  Future<void> seedActiveSession(String id, {String? routineId}) async {
    await localDb
        .into(localDb.workouts)
        .insert(
          WorkoutsCompanion.insert(
            id: id,
            localUserId: 'perfil-pruebas',
            startedAt: DateTime.now(),
            routineId: Value(routineId),
          ),
        );
  }

  testWidgets('la lista vacía invita a crear la primera rutina (RF-1)', (
    tester,
  ) async {
    await pumpView(tester);

    expect(find.text('PLANIFICACIÓN'), findsOneWidget);
    expect(find.text('Mis Rutinas'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Nueva'), findsOneWidget);
    expect(find.text('Aún no tienes rutinas'), findsOneWidget);
    expect(
      find.text('Crea una plantilla con tus ejercicios y entrena con ella.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(ElevatedButton, 'Nueva rutina'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets(
    'la tarjeta destacada muestra la rutina con su desglose (RF-20)',
    (tester) async {
      await createRoutine();
      await pumpView(tester);

      expect(find.text('Tren superior'), findsOneWidget);
      expect(find.text('DESGLOSE DE SESIONES'), findsOneWidget);
      expect(find.text('Empuje'), findsOneWidget);
      expect(find.text('Pecho · 2 ejercicios'), findsOneWidget);
      expect(find.text('Hoy'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Iniciar Hoy (Empuje)'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Ver detalle'), findsOneWidget);
      expect(find.text('Explorar Biblioteca de Plantillas'), findsOneWidget);

      await unmount(tester);
    },
  );

  testWidgets('Nueva rutina abre el editor (RF-1)', (tester) async {
    await pumpView(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Nueva rutina'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(RoutineEditorView), findsOneWidget);
    expect(find.text('Nueva rutina'), findsWidgets);

    await unmount(tester);
  });

  testWidgets('una rutina sin ejercicios deja Iniciar deshabilitado', (
    tester,
  ) async {
    await createRoutine(name: 'Prensa', exercises: const []);
    await pumpView(tester);

    expect(find.text('Sin ejercicios — ábrelos para empezar'), findsOneWidget);
    expect(find.byTooltip('Añade ejercicios a la rutina'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Iniciar Hoy'),
          )
          .onPressed,
      isNull,
    );

    await unmount(tester);
  });

  testWidgets(
    'Iniciar Hoy instancía la sesión con el objetivo clonado (RF-2)',
    (tester) async {
      await createRoutine(name: 'Tren superior');
      await pumpView(tester);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Iniciar Hoy (Empuje)'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('SESIÓN EN CURSO'), findsOneWidget);
      expect(find.text('Press de banca'), findsWidgets);

      final started = await (localDb.select(
        localDb.workouts,
      )..where((t) => t.routineId.isNotNull())).get();
      expect(started, hasLength(1));
      expect(started.single.name, 'Tren superior');

      await unmount(tester);
    },
  );

  testWidgets('borrar pide confirmación y elimina la rutina con sus hijos', (
    tester,
  ) async {
    final routine = await createRoutine();
    await pumpView(tester);

    await tester.tap(find.byTooltip('Opciones de la rutina'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.text('Borrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('¿Borrar "Tren superior"?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Borrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Aún no tienes rutinas'), findsOneWidget);
    expect(await localDb.select(localDb.routines).get(), isEmpty);
    expect(
      await (localDb.select(
        localDb.routineExercises,
      )..where((t) => t.routineId.equals(routine.id))).get(),
      isEmpty,
    );

    await unmount(tester);
  });

  testWidgets('el ciclo semanal cuenta las sesiones completadas (RF-19)', (
    tester,
  ) async {
    final routine = await createRoutine(targetDays: 4);
    await pumpView(tester);

    expect(find.text('Ciclo Activo: Semana 1'), findsOneWidget);
    expect(
      find.text('0 de 4 sesiones completadas esta semana'),
      findsOneWidget,
    );

    await seedFinishedSession(
      'sesion-1',
      endedAt: DateTime.now().subtract(const Duration(hours: 2)),
      routineId: routine.id,
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));

    expect(
      find.text('1 de 4 sesiones completadas esta semana'),
      findsOneWidget,
    );

    await unmount(tester);
  });

  testWidgets('los chips filtran las tarjetas por categoría (RF-19)', (
    tester,
  ) async {
    await createRoutine(name: 'Plan PPL', category: 'PPL');
    await createRoutine(name: 'Plan TP', category: 'Torso-Pierna');
    await createRoutine(name: 'Plan F', category: 'Fuerza');
    await pumpView(tester);

    expect(find.text('Todas (3)'), findsOneWidget);
    expect(find.text('Plan PPL'), findsOneWidget);
    expect(find.text('Plan TP'), findsOneWidget);
    expect(find.text('Plan F'), findsOneWidget);

    await tester.tap(find.byKey(const Key('routine-filter-ppl')));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Plan PPL'), findsOneWidget);
    expect(find.text('Plan TP'), findsNothing);
    expect(find.text('Plan F'), findsNothing);

    await tester.tap(find.byKey(const Key('routine-filter-torsopierna')));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Plan TP'), findsOneWidget);
    expect(find.text('Plan PPL'), findsNothing);

    await tester.tap(find.byKey(const Key('routine-filter-')));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Plan PPL'), findsOneWidget);
    expect(find.text('Plan TP'), findsOneWidget);
    expect(find.text('Plan F'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('la tarjeta secundaria muestra metadata y pills (RF-20)', (
    tester,
  ) async {
    await createRoutine(
      name: 'Secundaria',
      description: 'División balanceada',
      level: 'Intermedio',
      targetDays: 4,
    );
    final principal = await createRoutine(
      name: 'Principal',
      description: null,
      targetDays: 6,
      goal: 'Fuerza',
    );
    await seedFinishedSession(
      'sesion-principal',
      endedAt: DateTime.now().subtract(const Duration(hours: 2)),
      routineId: principal.id,
    );
    await pumpView(tester);

    expect(find.text('Frecuencia 6x'), findsOneWidget);
    expect(find.text('Frecuencia'), findsOneWidget);
    expect(find.text('6 d/sem'), findsOneWidget);
    expect(find.text('Volumen Medio'), findsOneWidget);
    expect(find.text('Objetivo'), findsOneWidget);
    expect(find.text('Fuerza'), findsOneWidget);

    expect(find.text('INTERMEDIO'), findsOneWidget);
    expect(find.text('División balanceada'), findsOneWidget);
    expect(find.text('4 días / semana'), findsOneWidget);
    expect(find.text('2 series / sesión'), findsOneWidget);
    expect(find.text('RIR 2 - 3'), findsOneWidget);
    // La tarjeta destacada también tiene «Ver detalle»; se acota a la
    // secundaria por su clave para no confundir los dos botones iguales.
    final secondaryDetail = find.byKey(const Key('secondary-detail'));
    expect(secondaryDetail, findsOneWidget);
    expect(
      find.descendant(of: secondaryDetail, matching: find.text('Ver detalle')),
      findsOneWidget,
    );

    await unmount(tester);
  });

  testWidgets('Ver detalle abre el detalle de la rutina (RF-38)', (
    tester,
  ) async {
    await createRoutine(
      name: 'Secundaria',
      description: 'División balanceada',
      level: 'Intermedio',
      targetDays: 4,
    );
    final principal = await createRoutine(
      name: 'Principal',
      description: null,
      targetDays: 6,
      goal: 'Fuerza',
    );
    await seedFinishedSession(
      'sesion-principal',
      endedAt: DateTime.now().subtract(const Duration(hours: 2)),
      routineId: principal.id,
    );
    await pumpView(tester);

    // Se toca la acción de detalle de la tarjeta destacada (Principal) para
    // abrir su pantalla; se usa la clave porque hay dos «Ver detalle».
    await tester.tap(find.byKey(const Key('featured-detail')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byType(RoutineDetailView), findsOneWidget);
    expect(find.text('Principal'), findsWidgets);
    expect(find.text('Fuerza'), findsWidgets);
    expect(find.text('Press de banca'), findsWidgets);
    expect(find.textContaining('EJERCICIOS'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('la tarjeta muestra la franja de miniaturas y el «+N» al '
      'desbordar (amenda 2026-10-22)', (tester) async {
    // Seis entradas (repetando los tres ejercicios del catálogo) para que la
    // destacada muestre 4 miniaturas y un «+2» con el resto.
    const six = [
      RoutineExerciseDraft(
        exerciseId: 'bench-press',
        sets: [RoutineSetDraft(reps: 8, rir: 2)],
      ),
      RoutineExerciseDraft(
        exerciseId: 'triceps-pushdown',
        sets: [RoutineSetDraft(reps: 10, rir: 2)],
      ),
      RoutineExerciseDraft(
        exerciseId: 'bicep-curl',
        sets: [RoutineSetDraft(reps: 10, rir: 2)],
      ),
      RoutineExerciseDraft(
        exerciseId: 'bench-press',
        sets: [RoutineSetDraft(reps: 8, rir: 2)],
      ),
      RoutineExerciseDraft(
        exerciseId: 'triceps-pushdown',
        sets: [RoutineSetDraft(reps: 10, rir: 2)],
      ),
      RoutineExerciseDraft(
        exerciseId: 'bicep-curl',
        sets: [RoutineSetDraft(reps: 10, rir: 2)],
      ),
    ];
    await createRoutine(name: 'Volumen', exercises: six);
    await pumpView(tester);

    expect(find.byType(ExerciseThumb), findsNWidgets(4));
    expect(find.text('+2'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('ambas tarjetas muestran la franja de miniaturas '
      '(amenda 2026-10-22)', (tester) async {
    // Cada rutina por defecto tiene 2 ejercicios: destacada (2) + secundaria
    // (2) = 4 miniaturas en total, sin «+N».
    await createRoutine(name: 'Principal');
    await createRoutine(name: 'Secundaria');
    await pumpView(tester);

    expect(find.byType(ExerciseThumb), findsNWidgets(4));

    await unmount(tester);
  });

  testWidgets('el badge En curso solo aparece con un workout activo (RF-20)', (
    tester,
  ) async {
    final routine = await createRoutine(name: 'En curso');
    await createRoutine(name: 'Otra');
    await seedActiveSession('activa', routineId: routine.id);
    await pumpView(tester);

    expect(find.text('EN CURSO'), findsOneWidget);
    expect(find.text('En curso'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('el desglose agrupa los ejercicios por músculo (RF-20)', (
    tester,
  ) async {
    await createRoutine(
      name: 'PPL Derivado',
      targetDays: 6,
      exercises: const [
        RoutineExerciseDraft(
          exerciseId: 'bench-press',
          sets: [RoutineSetDraft(reps: 8, rir: 2, weightKg: 60)],
        ),
        RoutineExerciseDraft(
          exerciseId: 'triceps-pushdown',
          sets: [RoutineSetDraft(reps: 12, rir: 1, weightKg: 20)],
        ),
        RoutineExerciseDraft(
          exerciseId: 'bicep-curl',
          sets: [RoutineSetDraft(reps: 10, rir: 2, weightKg: 12)],
        ),
      ],
    );
    await pumpView(tester);

    expect(find.text('Empuje'), findsOneWidget);
    expect(find.text('Pecho, Tríceps · 2 ejercicios'), findsOneWidget);
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Tracción'), findsOneWidget);
    expect(find.text('Bíceps · 1 ejercicio'), findsOneWidget);
    expect(find.text('Mañana'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('el footer muestra el último uso de la rutina (RF-20)', (
    tester,
  ) async {
    final vieja = await createRoutine(name: 'Vieja');
    final reciente = await createRoutine(name: 'Reciente');
    final now = DateTime.now();
    await seedFinishedSession(
      'sesion-vieja',
      endedAt: now.subtract(const Duration(days: 12)),
      routineId: vieja.id,
    );
    await seedFinishedSession(
      'sesion-reciente',
      endedAt: now.subtract(const Duration(days: 5)),
      routineId: reciente.id,
    );
    await pumpView(tester);

    expect(find.text('Reciente'), findsOneWidget);
    expect(find.text('Último uso hace 12 días'), findsOneWidget);
    expect(find.text('Vieja'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('la tarjeta Explorar abre la biblioteca de plantillas (RF-21)', (
    tester,
  ) async {
    await createRoutine();
    await pumpView(tester);

    await tester.tap(find.text('Explorar Biblioteca de Plantillas'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(TemplatesView), findsOneWidget);
    expect(find.text('Biblioteca de plantillas'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('el editor guarda la metadata de planificación (RF-18)', (
    tester,
  ) async {
    final routine = await createRoutine(name: 'Con metadata');
    await pumpView(tester);

    await tester.tap(find.byTooltip('Editar rutina'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(RoutineEditorView), findsOneWidget);

    await tester.tap(find.byKey(const Key('planning-toggle')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('meta-PPL')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('Añadir un día'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('Añadir un día'));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar cambios'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));

    final stored = await (localDb.select(
      localDb.routines,
    )..where((t) => t.id.equals(routine.id))).getSingle();
    expect(stored.category, 'PPL');
    expect(stored.level, isNull);
    expect(stored.targetDays, 2);

    await unmount(tester);
  });
}
