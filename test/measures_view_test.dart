import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/app/theme/app_theme.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/body_metric_repository.dart';
import 'package:hevywork/main.dart';
import 'package:hevywork/ui/unit_system_scope.dart';
import 'package:hevywork/ui/views/measures_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase localDb;

  setUpAll(() async {
    localDb = AppDatabase(NativeDatabase.memory());
    bodyMetricRepository = BodyMetricRepository(localDb);
  });

  tearDownAll(() => localDb.close());

  setUp(() async {
    await localDb.delete(localDb.bodyMetrics).go();
  });

  Future<void> pumpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const UnitSystemScope(
          unitSystem: 'metric',
          child: Scaffold(body: MeasuresView()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('la lista de medidas muestra el último chequeo y deltas '
      '(RF-25)', (tester) async {
    final today = BodyMetricRepository.dayOf(DateTime.now());
    await bodyMetricRepository.upsert(
      date: today.subtract(const Duration(days: 2)),
      weightKg: 84,
      measures: const {'chest': 102, 'arm': 38, 'waist': 84},
    );
    await bodyMetricRepository.upsert(
      date: today.subtract(const Duration(days: 1)),
      weightKg: 84.5,
      measures: const {'chest': 103, 'arm': 37.5, 'waist': 82},
    );
    await pumpView(tester);

    final title = find.text('Medidas Corporales');
    expect(title, findsOneWidget);
    final last = today.subtract(const Duration(days: 1));
    const months = [
      'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
      'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
    ];
    expect(
      find.text('ÚLTIMO CHEQUEO: ${last.day} ${months[last.month - 1]}'),
      findsOneWidget,
    );
    expect(find.text('Pecho / Torso'), findsOneWidget);
    expect(find.text('Contorno axilar'), findsOneWidget);
    expect(find.text('Cintura'), findsWidgets);
    expect(find.text('+1.0 cm'), findsOneWidget);
    expect(find.text('-0.5 cm'), findsOneWidget);
    expect(find.text('-2.0 cm'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('la evolución de medidas muestra pills, gráfico y stat boxes '
      '(RF-22)', (tester) async {
    final today = BodyMetricRepository.dayOf(DateTime.now());
    await bodyMetricRepository.upsert(
      date: today.subtract(const Duration(days: 30)),
      weightKg: 84,
      measures: const {'chest': 100, 'waist': 85},
    );
    await bodyMetricRepository.upsert(
      date: today.subtract(const Duration(days: 10)),
      weightKg: 84.5,
      measures: const {'chest': 102, 'waist': 83},
    );
    await pumpView(tester);

    expect(find.text('Evolución de Medidas'), findsOneWidget);
    expect(find.text('Tendencia de las últimas 12 semanas'), findsOneWidget);
    expect(find.text('Pecho'), findsWidgets);
    expect(find.text('Cintura'), findsWidgets);
    expect(find.text('Brazos'), findsOneWidget);
    expect(find.text('Cuádriceps'), findsWidgets);
    expect(find.text('RATIO CINTURA/PECHO'), findsOneWidget);
    expect(find.text('CRECIMIENTO ACUMULADO'), findsOneWidget);
    // Stat boxes del último chequeo: ratio 83/102 y crecimiento 0 cm.
    expect(find.text('0.81'), findsOneWidget);
    expect(find.text('-0.04'), findsOneWidget);
    expect(find.text('0.0 cm'), findsOneWidget);

    // Cambiar de serie repinta sin excepciones.
    final pill = find.text('Cintura').first;
    await tester.ensureVisible(pill);
    await tester.pumpAndSettle();
    await tester.tap(pill);
    await tester.pump();
    expect(tester.takeException(), isNull);

    await unmount(tester);
  });

  testWidgets('sin medidas la sección muestra su estado vacío (RF-37)',
      (tester) async {
    final today = BodyMetricRepository.dayOf(DateTime.now());
    await bodyMetricRepository.upsert(date: today, weightKg: 80);
    await pumpView(tester);

    expect(
      find.text('Añade medidas a un registro para verlas aquí'),
      findsOneWidget,
    );
    expect(find.text('RATIO CINTURA/PECHO'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('las secciones de medidas no desbordan a 320 dp con escala 1.3',
      (tester) async {
    tester.view.physicalSize = const Size(640, 6000);
    tester.view.devicePixelRatio = 2.0;
    tester.view.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.platformDispatcher.clearAllTestValues);

    final today = BodyMetricRepository.dayOf(DateTime.now());
    await bodyMetricRepository.upsert(
      date: today.subtract(const Duration(days: 30)),
      weightKg: 84,
      measures: const {'chest': 100, 'waist': 85, 'arm': 33},
    );
    await bodyMetricRepository.upsert(
      date: today.subtract(const Duration(days: 10)),
      weightKg: 84.5,
      measures: const {'chest': 102, 'waist': 83, 'arm': 34},
    );
    await pumpView(tester);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('Medidas Corporales'), findsOneWidget);
    expect(find.text('Evolución de Medidas'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });
}
