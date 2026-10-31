import 'package:cached_network_image/cached_network_image.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/catalog_repository.dart';
import 'package:hevywork/data/repositories/workout_repository.dart';
import 'package:hevywork/main.dart';
import 'package:hevywork/ui/unit_system_scope.dart';
import 'package:hevywork/ui/views/exercise_info_view.dart';

typedef SeedSet = ({
  String setType,
  double weightKg,
  int reps,
  int? rir,
  bool completed,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Exercise exercise;
  late AppDatabase localDb;

  setUpAll(() async {
    db = AppDatabase(NativeDatabase.memory());
    localDb = db;
    catalogRepository = CatalogRepository(db);
    workoutRepository = WorkoutRepository(db);

    exercise = await db.into(db.exercises).insertReturning(
          ExercisesCompanion.insert(
            id: '0001',
            name: 'Press de banca con barra',
            bodyPart: 'chest',
            equipment: 'barbell',
            target: 'pectorals',
            muscleGroup: 'pecho',
            imagePath: const Value('images/0001-2gPfomN.jpg'),
            gifPath: const Value('videos/0001-2gPfomN.gif'),
            attribution: const Value('© Gym visual — https://gymvisual.com/'),
            restSeconds: const Value(120),
          ),
        );

    // Insert exercise instructions in Spanish and English
    await db.batch((batch) {
      batch.insert(db.exerciseInstructions, ExerciseInstructionsCompanion.insert(
        exerciseId: '0001',
        language: 'es',
        stepNumber: 1,
        instruction: 'Baja la barra hasta tocar el pecho',
      ));
      batch.insert(db.exerciseInstructions, ExerciseInstructionsCompanion.insert(
        exerciseId: '0001',
        language: 'es',
        stepNumber: 2,
        instruction: 'Empuja hasta extender los brazos',
      ));
      batch.insert(db.exerciseInstructions, ExerciseInstructionsCompanion.insert(
        exerciseId: '0001',
        language: 'en',
        stepNumber: 1,
        instruction: 'Lower the bar to your chest',
      ));
      batch.insert(db.exerciseInstructions, ExerciseInstructionsCompanion.insert(
        exerciseId: '0001',
        language: 'en',
        stepNumber: 2,
        instruction: 'Push until arms extended',
      ));
    });
  });

  tearDownAll(() => db.close());

  Future<void> pumpView(
    WidgetTester tester, {
    Exercise? target,
    String? unitSystem,
  }) async {
    Widget home = ExerciseInfoView(
      exercise: target ?? exercise,
      database: localDb,
    );
    if (unitSystem != null) {
      home = UnitSystemScope(unitSystem: unitSystem, child: home);
    }
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  Future<Exercise> insertExercise(String id, String name) {
    return db.into(db.exercises).insertReturning(
          ExercisesCompanion.insert(
            id: id,
            name: name,
            bodyPart: 'chest',
            equipment: 'barbell',
            target: 'pectorals',
            muscleGroup: 'pecho',
          ),
        );
  }

  SeedSet loggedSet({
    double kg = 100,
    int reps = 5,
    int? rir = 2,
    String type = 'normal',
  }) =>
      (
        setType: type,
        weightKg: kg,
        reps: reps,
        rir: rir,
        completed: true,
      );

  Future<void> seedFinishedSession({
    required String workoutId,
    required String exerciseId,
    required DateTime endedAt,
    String? name,
    List<SeedSet> sets = const [],
  }) async {
    final profile = await db.select(db.localProfiles).getSingle();
    await db.into(db.workouts).insert(
          WorkoutsCompanion.insert(
            id: workoutId,
            localUserId: profile.localUserId,
            name: Value(name),
            startedAt: endedAt.subtract(const Duration(hours: 1)),
            endedAt: Value(endedAt),
            status: const Value('finished'),
          ),
        );
    final itemId = '$workoutId-item';
    await db.into(db.workoutExercises).insert(
          WorkoutExercisesCompanion.insert(
            id: itemId,
            workoutId: workoutId,
            exerciseId: exerciseId,
            orderIndex: 1,
          ),
        );
    for (var i = 0; i < sets.length; i++) {
      final set = sets[i];
      await db.into(db.workoutSets).insert(
            WorkoutSetsCompanion.insert(
              id: '$itemId-set-${i + 1}',
              workoutExerciseId: itemId,
              orderIndex: i + 1,
              setType: Value(set.setType),
              weightKg: Value(set.weightKg),
              reps: Value(set.reps),
              rir: Value(set.rir),
              completed: Value(set.completed),
            ),
          );
    }
  }

  testWidgets('muestra nombre y miniatura local sin URL de GIF',
      (tester) async {
    await pumpView(tester);

    // Nombre visible
    expect(find.text('Press de banca con barra'), findsOneWidget);
    // No hay CachedNetworkImage sin configuración (RF-3)
    expect(find.byType(CachedNetworkImage), findsNothing);
    // Se muestra imagen local (Image.asset), no ThumbFallback ya que imagePath está set
    expect(find.byType(Image), findsNWidgets(1));
  });

  testWidgets('lista los pasos en español por defecto', (tester) async {
    await pumpView(tester);

    expect(find.text('Baja la barra hasta tocar el pecho'), findsOneWidget);
    expect(find.text('Empuja hasta extender los brazos'), findsOneWidget);
    expect(find.text('ES'), findsOneWidget);
    expect(find.text('EN'), findsOneWidget);
  });

  testWidgets('al cambiar a EN muestra los pasos ingleses', (tester) async {
    await pumpView(tester);

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    expect(find.text('Lower the bar to your chest'), findsOneWidget);
    expect(find.text('Baja la barra hasta tocar el pecho'), findsNothing);
  });

  testWidgets('ajusta el descanso por defecto del ejercicio (RF-5 de la 002)',
      (tester) async {
    await pumpView(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('rest-detail-minus')),
      300,
    );
    await tester.pumpAndSettle();

    // Verificar valor inicial
    expect(find.text('120 s'), findsOneWidget);

    // Reducir 15 s
    await tester.tap(find.byKey(const Key('rest-detail-minus')));
    await tester.pump();
    expect(find.text('105 s'), findsOneWidget);

    // Aumentar 15 s
    await tester.tap(find.byKey(const Key('rest-detail-plus')));
    await tester.pump();
    expect(find.text('120 s'), findsOneWidget);
  });

  testWidgets('muestra badges de equipo y músculo', (tester) async {
    await pumpView(tester);

    // Badges deben aparecer
    expect(find.text('BARBELL'), findsOneWidget); // equipment
    expect(find.text('PECTORALS'), findsOneWidget); // muscleLabel fallthrough
  });

  group('historial de sesiones paginado (SCR-7, RF-14 y RF-15)', () {
    testWidgets('sin sesiones muestra el estado vacío con llamada al CTA',
        (tester) async {
      final target = await insertExercise('hist-empty', 'Prensa francesa');

      await pumpView(tester, target: target);
      await tester.scrollUntilVisible(
        find.text('Aún no hay sesiones con este ejercicio'),
        300,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Aún no hay sesiones con este ejercicio'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Usa «Añadir a Rutina o Iniciar Sesión» para registrar tu primera serie.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('history-load-more')), findsNothing);
    });

    testWidgets('la sesión más reciente se expande con tabla, warmup y ★',
        (tester) async {
      final target = await insertExercise('hist-full', 'Press inclinado');
      await seedFinishedSession(
        workoutId: 'hist-full-w1',
        exerciseId: target.id,
        name: 'Empuje Torso A',
        endedAt: DateTime.now().subtract(const Duration(days: 3)),
        sets: [
          loggedSet(type: 'warmup', kg: 60, reps: 10, rir: null),
          loggedSet(kg: 100, reps: 5, rir: 2),
          loggedSet(kg: 105, reps: 3, rir: 1),
        ],
      );

      await pumpView(tester, target: target);
      await tester.scrollUntilVisible(
        find.text('Historial de Sesiones'),
        300,
      );
      await tester.pumpAndSettle();

      expect(find.text('Historial de Sesiones'), findsOneWidget);
      expect(find.text('Empuje Torso A'), findsOneWidget);
      expect(find.textContaining('Hace 3 días'), findsOneWidget);
      expect(find.text('815 kg'), findsOneWidget);
      expect(find.text('Volumen total'), findsOneWidget);

      expect(find.text('SET'), findsOneWidget);
      expect(find.text('KG × REPS'), findsOneWidget);
      expect(find.text('RIR'), findsOneWidget);
      expect(find.text('EST. 1RM'), findsOneWidget);

      expect(find.text('1 (Cal.)'), findsOneWidget);
      expect(find.text('2 ★'), findsOneWidget);
      expect(find.text('123.3 kg'), findsOneWidget);
      expect(find.text('RIR medio: 1.5'), findsOneWidget);
      expect(find.byKey(const Key('history-load-more')), findsNothing);
    });

    testWidgets('con nombre null muestra «Sesión» y la fecha', (tester) async {
      final target = await insertExercise('hist-noname', 'Fondos en paralelas');
      await seedFinishedSession(
        workoutId: 'hist-noname-w1',
        exerciseId: target.id,
        name: null,
        endedAt: DateTime.now().subtract(const Duration(days: 1)),
        sets: [loggedSet(kg: 40, reps: 8, rir: 2)],
      );

      await pumpView(tester, target: target);
      await tester.scrollUntilVisible(find.text('Sesión'), 300);
      await tester.pumpAndSettle();

      expect(find.text('Sesión'), findsOneWidget);
      expect(find.textContaining('· Ayer'), findsOneWidget);
    });

    testWidgets('las sesiones anteriores se muestran condensadas',
        (tester) async {
      final target = await insertExercise('hist-cond', 'Remo con barra');
      final now = DateTime.now();
      await seedFinishedSession(
        workoutId: 'hist-cond-w1',
        exerciseId: target.id,
        name: 'Tirón A',
        endedAt: now.subtract(const Duration(days: 2)),
        sets: [loggedSet(kg: 80, reps: 5, rir: 3)],
      );
      await seedFinishedSession(
        workoutId: 'hist-cond-w2',
        exerciseId: target.id,
        name: 'Tirón B',
        endedAt: now.subtract(const Duration(days: 9)),
        sets: [loggedSet(kg: 70, reps: 6, rir: 2)],
      );
      await seedFinishedSession(
        workoutId: 'hist-cond-w3',
        exerciseId: target.id,
        name: 'Tirón C',
        endedAt: now.subtract(const Duration(days: 16)),
        sets: [loggedSet(kg: 65, reps: 8, rir: 1)],
      );

      await pumpView(tester, target: target);
      await tester.scrollUntilVisible(find.text('Tirón C'), 300);
      await tester.pumpAndSettle();

      expect(find.text('Tirón A'), findsOneWidget);
      expect(find.text('Tirón C'), findsOneWidget);
      expect(
        find.text('1 sets completados · Top: 70 kg × 6 reps'),
        findsOneWidget,
      );
      expect(
        find.text('1 sets completados · Top: 65 kg × 8 reps'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('history-load-more')), findsNothing);
    });

    testWidgets('pagina de 10 en 10 y desaparece al agotar', (tester) async {
      final target = await insertExercise('hist-pag', 'Sentadilla profunda');
      final now = DateTime.now();
      for (var i = 1; i <= 12; i++) {
        await seedFinishedSession(
          workoutId: 'hist-pag-w$i',
          exerciseId: target.id,
          name: 'Página $i',
          endedAt: now.subtract(Duration(days: i)),
          sets: [loggedSet(kg: 100, reps: 5, rir: 2)],
        );
      }

      await pumpView(tester, target: target);
      await tester.scrollUntilVisible(
        find.byKey(const Key('history-load-more')),
        300,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Cargar sesiones anteriores (2 más)'),
        findsOneWidget,
      );
      expect(find.text('Página 10'), findsOneWidget);
      expect(find.text('Página 11'), findsNothing);

      await tester.tap(find.byKey(const Key('history-load-more')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history-load-more')), findsNothing);
      await tester.scrollUntilVisible(find.text('Página 12'), 300);
      await tester.pumpAndSettle();
      expect(find.text('Página 11'), findsOneWidget);
      expect(find.text('Página 12'), findsOneWidget);
    });

    testWidgets('muestra los pesos en la unidad del perfil (RNF-7)',
        (tester) async {
      final target = await insertExercise('hist-lb', 'Press militar con barra');
      await seedFinishedSession(
        workoutId: 'hist-lb-w1',
        exerciseId: target.id,
        name: 'Hombros',
        endedAt: DateTime.now().subtract(const Duration(days: 2)),
        sets: [loggedSet(kg: 60, reps: 5, rir: 2)],
      );

      await pumpView(tester, target: target, unitSystem: 'imperial');
      await tester.scrollUntilVisible(
        find.text('Historial de Sesiones'),
        300,
      );
      await tester.pumpAndSettle();

      expect(find.text('661.4 lb'), findsOneWidget);
      expect(find.text('132.3 lb × 5'), findsOneWidget);
    });

    testWidgets('no desborda en 375 dp (RNF-3)', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final target = await insertExercise('hist-narrow', 'Curl con mancuernas');
      final now = DateTime.now();
      for (var i = 1; i <= 11; i++) {
        await seedFinishedSession(
          workoutId: 'hist-narrow-w$i',
          exerciseId: target.id,
          name: 'Sesión estrecha $i',
          endedAt: now.subtract(Duration(days: i)),
          sets: i == 1
              ? [
                  loggedSet(type: 'warmup', kg: 30, reps: 12, rir: null),
                  loggedSet(kg: 40, reps: 8, rir: 2),
                  loggedSet(kg: 42.5, reps: 6, rir: 1),
                ]
              : [loggedSet(kg: 40, reps: 8, rir: 2)],
        );
      }

      await pumpView(tester, target: target);
      await tester.scrollUntilVisible(
        find.byKey(const Key('history-load-more')),
        300,
      );
      await tester.pumpAndSettle();

      expect(find.text('Historial de Sesiones'), findsOneWidget);
      expect(find.text('Cargar sesiones anteriores (1 más)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}