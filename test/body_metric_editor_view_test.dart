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
import 'package:hevywork/domain/body_metrics.dart';
import 'package:hevywork/main.dart';
import 'package:hevywork/ui/unit_system_scope.dart';
import 'package:hevywork/ui/views/body_metric_editor_view.dart';

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
  });

  tearDownAll(() => localDb.close());

  setUp(() => localDb.delete(localDb.bodyMetrics).go());

  Future<void> pumpView(WidgetTester tester, {BodyMetric? record}) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: BodyMetricEditorView(record: record),
        ),
      ),
    );
    await tester.pump();
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
          child: Scaffold(body: BodyMetricEditorView()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('guardar peso nuevo crea el registro del día (RF-1)',
      (tester) async {
    await pumpView(tester);

    expect(find.text('Nuevo registro'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Peso (kg)'),
      '84',
    );
    await tester.tap(find.text('Guardar registro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Registro guardado'), findsOneWidget);
    final rows = await localDb.select(localDb.bodyMetrics).get();
    expect(rows, hasLength(1));
    final today = BodyMetricRepository.dayOf(DateTime.now());
    expect(rows.single.date, today);
    expect(rows.single.weightKg, 84);

    await unmount(tester);
  });

  testWidgets('en imperial edita en lb/in y guarda en kg/cm (RF-4)',
      (tester) async {
    await pumpImperialView(tester);

    expect(find.text('Peso (lb)'), findsOneWidget);
    expect(find.text('Cintura (in)'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Peso (lb)'),
      '176.4',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Cintura (in)'),
      '39.4',
    );
    await tester.tap(find.text('Guardar registro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Registro guardado'), findsOneWidget);
    final rows = await localDb.select(localDb.bodyMetrics).get();
    expect(rows, hasLength(1));
    expect(rows.single.weightKg, closeTo(80, 0.05));
    expect(
      decodeMeasures(rows.single.measuresJson).values.single,
      closeTo(100.076, 0.01),
    );

    await unmount(tester);
  });

  testWidgets('pedir guardar sin datos muestra aviso (RF-1)', (tester) async {
    await pumpView(tester);

    await tester.tap(find.text('Guardar registro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Añade peso, medidas o composición'), findsOneWidget);
    expect(await localDb.select(localDb.bodyMetrics).get(), isEmpty);

    await unmount(tester);
  });

  testWidgets('guarda composición corporal (spec 009, RF-1)', (tester) async {
    await pumpView(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Peso (kg)'),
      '80',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '% de grasa'),
      '18.5',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Masa magra (kg) · opcional'),
      '65.2',
    );
    await tester.tap(find.text('Guardar registro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Registro guardado'), findsOneWidget);
    final row = (await localDb.select(localDb.bodyMetrics).get()).single;
    expect(row.bodyFatPct, 18.5);
    expect(row.leanMassKg, 65.2);

    await unmount(tester);
  });

  testWidgets('rechaza un % de grasa fuera de rango (spec 009)',
      (tester) async {
    await pumpView(tester);

    await tester.enterText(
      find.widgetWithText(TextField, '% de grasa'),
      '75',
    );
    await tester.tap(find.text('Guardar registro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Pon un % de grasa entre 0 y 70'), findsOneWidget);
    expect(await localDb.select(localDb.bodyMetrics).get(), isEmpty);

    await unmount(tester);
  });

  testWidgets('editar un registro precarga su composición', (tester) async {
    final today = BodyMetricRepository.dayOf(DateTime.now());
    await bodyMetricRepository.upsert(
      date: today,
      weightKg: 80,
      bodyFatPct: 18.5,
      leanMassKg: 65.2,
    );
    final record = (await localDb.select(localDb.bodyMetrics).get()).single;

    await pumpView(tester, record: record);

    expect(find.text('Editar registro'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, '% de grasa'),
          )
          .controller
          ?.text,
      '18.5',
    );
    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, 'Masa magra (kg) · opcional'),
          )
          .controller
          ?.text,
      '65.2',
    );

    await unmount(tester);
  });

  testWidgets('un peso sin sentido muestra aviso (RF-1)', (tester) async {
    await pumpView(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Peso (kg)'),
      '-2',
    );
    await tester.tap(find.text('Guardar registro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Pon un peso válido'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('guardar medidas sin peso también vale (RF-1)', (tester) async {
    await pumpView(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Pecho (cm)'),
      '102.5',
    );
    await tester.tap(find.text('Guardar registro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final rows = await localDb.select(localDb.bodyMetrics).get();
    expect(rows, hasLength(1));
    expect(rows.single.weightKg, isNull);
    expect(rows.single.measuresJson, contains('102.5'));

    await unmount(tester);
  });

  testWidgets('editar carga los valores y actualiza el registro (RF-2)',
      (tester) async {
    final record = await bodyMetricRepository.upsert(
      date: DateTime(2026, 10, 3),
      weightKg: 80,
      measures: const {'chest': 100, 'arm': 38},
      notes: 'Antes de entrenar',
    );
    await pumpView(tester, record: record);

    expect(find.text('Editar registro'), findsOneWidget);
    final weightField = find.widgetWithText(TextField, 'Peso (kg)');
    expect(tester.widget<TextField>(weightField).controller!.text, '80');
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Pecho (cm)'))
          .controller!
          .text,
      '100',
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Brazo (cm)'))
          .controller!
          .text,
      '38',
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Notas'))
          .controller!
          .text,
      'Antes de entrenar',
    );

    await tester.enterText(weightField, '79.5');
    await tester.tap(find.text('Guardar registro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Registro actualizado'), findsOneWidget);
    final rows = await localDb.select(localDb.bodyMetrics).get();
    expect(rows, hasLength(1));
    expect(rows.single.weightKg, 79.5);
    expect(rows.single.measuresJson, contains('100'));
    expect(rows.single.notes, 'Antes de entrenar');

    await unmount(tester);
  });

  testWidgets('editar muestra la fecha del registro', (tester) async {
    final record = await bodyMetricRepository.upsert(
      date: DateTime(2026, 10, 3),
      weightKg: 80,
    );
    await pumpView(tester, record: record);

    expect(
      find.widgetWithText(OutlinedButton, '03/10/2026'),
      findsOneWidget,
    );

    await unmount(tester);
  });
}