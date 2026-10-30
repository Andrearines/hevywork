import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/app/theme/app_theme.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/routine_repository.dart';
import 'package:hevywork/data/repositories/template_repository.dart';
import 'package:hevywork/data/repositories/workout_repository.dart';
import 'package:hevywork/main.dart';
import 'package:hevywork/ui/views/templates_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late TemplateFetcher activeFetcher;

  Map<String, dynamic> fixture() => {
    'id': 't-1',
    'name': 'Cuerpo completo',
    'description': 'Sesión de ejemplo',
    'category': 'Full Body',
    'level': 'Principiante',
    'goal': 'Adaptación',
    'target_days': 3,
    'weeks': 6,
    'template_days': [
      {
        'id': 'td-1',
        'template_id': 't-1',
        'order_index': 1,
        'name': 'Sesión A',
        'template_exercises': [
          {
            'id': 'te-1',
            'template_day_id': 'td-1',
            'exercise_id': '0025',
            'order_index': 1,
            'template_sets': [
              {
                'id': 'ts-1',
                'template_exercise_id': 'te-1',
                'order_index': 1,
                'set_type': 'normal',
                'weight_kg': 40,
                'reps': 8,
                'rir': 2,
                'rest_seconds': 90,
              },
            ],
          },
        ],
      },
    ],
  };

  setUpAll(() {
    db = AppDatabase(NativeDatabase.memory());
    localDb = db;
    final workouts = WorkoutRepository(db);
    routineRepository = RoutineRepository(db, workouts);
    templateRepository = TemplateRepository(
      db,
      routineRepository,
      fetcher: () => activeFetcher(),
    );
  });

  tearDownAll(() => db.close());

  setUp(() async {
    activeFetcher = () async => [fixture()];
    await db.delete(db.routineSets).go();
    await db.delete(db.routineExercises).go();
    await db.delete(db.routines).go();
    await db.delete(db.templateSets).go();
    await db.delete(db.templateExercises).go();
    await db.delete(db.templateDays).go();
    await db.delete(db.templates).go();
    await (db.update(db.localProfiles)..where((t) => t.id.equals(1))).write(
      const LocalProfilesCompanion(localUserId: Value('local-1')),
    );
    await db
        .into(db.exercises)
        .insertOnConflictUpdate(
          ExercisesCompanion.insert(
            id: '0025',
            name: 'Press de banca',
            bodyPart: 'chest',
            equipment: 'barbell',
            target: 'pectorals',
            muscleGroup: 'chest',
          ),
        );
  });

  Future<void> pumpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const TemplatesView()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('muestra el catálogo y permite importar desde el detalle', (
    tester,
  ) async {
    await pumpView(tester);

    expect(find.text('Biblioteca de plantillas'), findsOneWidget);
    expect(find.text('Cuerpo completo'), findsOneWidget);

    await tester.tap(find.byKey(const Key('template-card-t-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Sesión A'), findsOneWidget);
    expect(find.text('Press de banca'), findsOneWidget);
    expect(find.text('1 series · 8 reps · RIR 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('import-template')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('Rutina creada'), findsOneWidget);
    final routines = await db.select(db.routines).get();
    expect(routines.single.name, 'Cuerpo completo');

    // Deja expirar el SnackBar antes de desmontar: su timer no debe llegar
    // al siguiente test.
    await tester.pump(const Duration(seconds: 5));

    await unmount(tester);
  });

  testWidgets('sin cache ni conexión pide conectarse', (tester) async {
    activeFetcher = () async => throw StateError('offline');
    await pumpView(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Conéctate para ver las plantillas'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    await unmount(tester);
  });
}
