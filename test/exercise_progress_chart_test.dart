import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/domain/exercise_stats.dart';
import 'package:hevywork/ui/widgets/chart_enums.dart';
import 'package:hevywork/ui/widgets/exercise_progress_chart.dart';

class _RecordedChartPaint {
  final CustomPainter painter;
  final ExerciseProgressChartGeometry geometry;
  final Size size;
  final List<Offset> nodes;
  final List<Offset> highlightedNodes;
  final Path linePath;
  final Path areaPath;

  const _RecordedChartPaint({
    required this.painter,
    required this.geometry,
    required this.size,
    required this.nodes,
    required this.highlightedNodes,
    required this.linePath,
    required this.areaPath,
  });
}

_RecordedChartPaint _recordChartPaint(WidgetTester tester) {
  final customPaint = tester.widget<CustomPaint>(find.byKey(chartPlotKey));
  final painter = customPaint.painter!;
  final geometry =
      (painter as dynamic).geometry as ExerciseProgressChartGeometry;
  final size = tester.getSize(find.byKey(chartPlotKey));
  final canvas = TestRecordingCanvas();
  painter.paint(canvas, size);
  final circleCalls = canvas.invocations.where((record) {
    return record.invocation.memberName == #drawCircle;
  }).toList();
  final nodeCalls = circleCalls.where((record) {
    return record.invocation.positionalArguments[1] == 3.0;
  }).toList();
  final highlightedNodes = circleCalls
      .where((record) {
        return record.invocation.positionalArguments[1] == 5.0;
      })
      .map((record) {
        return record.invocation.positionalArguments[0] as Offset;
      })
      .toList();
  final pathCalls = canvas.invocations.where((record) {
    return record.invocation.memberName == #drawPath;
  }).toList();

  expect(nodeCalls.length % 2, 0);
  for (var i = 0; i < nodeCalls.length; i += 2) {
    expect(
      nodeCalls[i].invocation.positionalArguments[0],
      nodeCalls[i + 1].invocation.positionalArguments[0],
    );
  }
  expect(pathCalls, hasLength(2));

  return _RecordedChartPaint(
    painter: painter,
    geometry: geometry,
    size: size,
    nodes: [
      for (var i = 0; i < nodeCalls.length; i += 2)
        nodeCalls[i].invocation.positionalArguments[0] as Offset,
    ],
    highlightedNodes: highlightedNodes,
    areaPath: pathCalls[0].invocation.positionalArguments[0] as Path,
    linePath: pathCalls[1].invocation.positionalArguments[0] as Path,
  );
}

List<String> chartDateLabels(WidgetTester tester) {
  return tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(chartDateAxisKey),
          matching: find.byType(Text),
        ),
      )
      .map((text) => text.data!)
      .toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fixedNow = DateTime(2026, 11, 17, 12, 0, 0, 0, 123456);

  ExerciseSetRow workingSet({
    double weightKg = 80,
    int reps = 5,
    String setType = 'normal',
    bool completed = true,
  }) => ExerciseSetRow(
    orderIndex: 1,
    setType: setType,
    weightKg: weightKg,
    reps: reps,
    rir: 2,
    completed: completed,
  );

  ExerciseSessionSummary session(
    String id,
    DateTime endedAt, {
    double weightKg = 80,
    int reps = 5,
    List<ExerciseSetRow>? sets,
  }) => ExerciseSessionSummary(
    workoutId: id,
    name: id,
    endedAt: endedAt,
    sets: sets ?? [workingSet(weightKg: weightKg, reps: reps)],
  );

  Future<void> pumpChart(
    WidgetTester tester, {
    required List<ExerciseSessionSummary> sessions,
    ProgressMetric metric = ProgressMetric.e1rm,
    ProgressWindow window = ProgressWindow.threeMonths,
    double viewportWidth = 375,
    double? parentWidth,
  }) async {
    tester.view.physicalSize = Size(viewportWidth, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final chart = ExerciseProgressChart(
      sessions: sessions,
      metric: metric,
      window: window,
      now: () => fixedNow,
      onMetricChanged: (_) {},
      onWindowChanged: (_) {},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: parentWidth == null
              ? chart
              : Center(
                  child: SizedBox(width: parentWidth, child: chart),
                ),
        ),
      ),
    );
    await tester.pump();
  }

  void expectEmpty() {
    expect(find.textContaining('Sin datos en esta ventana'), findsOneWidget);
    expect(find.byKey(chartPlotKey), findsNothing);
    expect(find.byKey(insightDeltaKey), findsNothing);
    expect(find.byKey(insightFrequencyKey), findsNothing);
  }

  group('filterByProgressWindow', () {
    final start = fixedNow.subtract(const Duration(days: 90));
    final points = [
      (date: start, value: 1.0),
      (date: fixedNow.subtract(const Duration(days: 45)), value: 2.0),
      (date: fixedNow, value: 3.0),
      (date: start.subtract(const Duration(microseconds: 1)), value: 4.0),
      (date: fixedNow.add(const Duration(microseconds: 1)), value: 5.0),
      (date: fixedNow.subtract(const Duration(days: 120)), value: 6.0),
    ];

    test(
      'una ventana finita incluye inicio y ahora y excluye ambos exteriores',
      () {
        final filtered = filterByProgressWindow(
          points,
          ProgressWindow.threeMonths,
          now: fixedNow,
        );

        expect(filtered.map((point) => point.value), [1, 2, 3]);
      },
    );

    test('Todo no recorta puntos antiguos ni futuros', () {
      final filtered = filterByProgressWindow(
        points,
        ProgressWindow.all,
        now: fixedNow,
      );

      expect(filtered, same(points));
    });
  });

  testWidgets('cero y un punto conservan vacío sin insights', (tester) async {
    await pumpChart(tester, sessions: const []);
    expectEmpty();

    await pumpChart(
      tester,
      sessions: [session('one', fixedNow.subtract(const Duration(days: 5)))],
    );
    expectEmpty();
    expect(tester.takeException(), isNull);
  });

  testWidgets('dos puntos pintan plot e insights con altura no acotada', (
    tester,
  ) async {
    await pumpChart(
      tester,
      sessions: [
        session('old', fixedNow.subtract(const Duration(days: 20))),
        session(
          'recent',
          fixedNow.subtract(const Duration(days: 5)),
          weightKg: 100,
        ),
      ],
    );

    expect(find.byKey(chartPlotKey), findsOneWidget);
    expect(find.byKey(insightDeltaKey), findsOneWidget);
    expect(find.byKey(insightFrequencyKey), findsOneWidget);
    expect(find.textContaining('Sin datos en esta ventana'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('las ventanas excluyen antiguos y futuros y Todo los restaura', (
    tester,
  ) async {
    final sessions = [
      session('outside-old', fixedNow.subtract(const Duration(days: 120))),
      session('outside-recent', fixedNow.subtract(const Duration(days: 100))),
      session('inside-old', fixedNow.subtract(const Duration(days: 60))),
      session(
        'inside-recent',
        fixedNow.subtract(const Duration(days: 10)),
        weightKg: 100,
      ),
      session('future', fixedNow.add(const Duration(days: 1)), weightKg: 140),
    ];

    await pumpChart(tester, sessions: sessions, metric: ProgressMetric.load);
    expect(find.byKey(chartPlotKey), findsOneWidget);
    expect(find.text('+20.0 kg'), findsOneWidget);

    await pumpChart(
      tester,
      sessions: sessions,
      window: ProgressWindow.oneMonth,
    );
    expectEmpty();

    await pumpChart(tester, sessions: sessions, window: ProgressWindow.all);
    expect(find.byKey(chartPlotKey), findsOneWidget);
    expect(find.byKey(insightDeltaKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cada métrica usa los puntos y deltas del dominio', (
    tester,
  ) async {
    final sessions = [
      session('first', fixedNow.subtract(const Duration(days: 20))),
      session(
        'last',
        fixedNow.subtract(const Duration(days: 5)),
        weightKg: 100,
      ),
    ];

    for (final metric in ProgressMetric.values) {
      final expected = periodDelta(
        progressChartPoints(
          sessions,
          metric: metric,
          window: ProgressWindow.threeMonths,
          now: fixedNow,
        ),
      )!;
      await pumpChart(tester, sessions: sessions, metric: metric);

      final label = metric == ProgressMetric.volume
          ? '+${expected.absolute.toStringAsFixed(0)} kg·sesiones'
          : '+${expected.absolute.toStringAsFixed(1)} kg';
      expect(find.text(label), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('warmups e incompletas no generan puntos en ninguna métrica', (
    tester,
  ) async {
    final sessions = [
      session(
        'warmup',
        fixedNow.subtract(const Duration(days: 20)),
        sets: [workingSet(setType: 'warmup')],
      ),
      session(
        'incomplete',
        fixedNow.subtract(const Duration(days: 5)),
        sets: [workingSet(completed: false)],
      ),
    ];

    for (final metric in ProgressMetric.values) {
      await pumpChart(tester, sessions: sessions, metric: metric);
      expectEmpty();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('volumen conserva ceros legítimos sin inventar carga ni e1RM', (
    tester,
  ) async {
    final sessions = [
      session(
        'zero-old',
        fixedNow.subtract(const Duration(days: 20)),
        weightKg: 0,
      ),
      session(
        'zero-new',
        fixedNow.subtract(const Duration(days: 5)),
        weightKg: 0,
      ),
    ];

    await pumpChart(tester, sessions: sessions, metric: ProgressMetric.volume);
    expect(find.byKey(chartPlotKey), findsOneWidget);
    expect(find.text('+0 kg·sesiones'), findsOneWidget);

    await pumpChart(tester, sessions: sessions, metric: ProgressMetric.load);
    expectEmpty();
    await pumpChart(tester, sessions: sessions);
    expectEmpty();
    expect(tester.takeException(), isNull);
  });

  testWidgets('seis puntos pintan nodos con x estrictamente creciente', (
    tester,
  ) async {
    final sessions = [
      for (var i = 0; i < 6; i++)
        session(
          'geometry-$i',
          fixedNow.subtract(Duration(days: 6 - i)),
          weightKg: 10 + i * 10,
          reps: 1,
        ),
    ];
    await pumpChart(
      tester,
      sessions: sessions,
      metric: ProgressMetric.load,
      window: ProgressWindow.all,
    );

    final painted = _recordChartPaint(tester);

    expect(painted.nodes, hasLength(sessions.length));
    for (var i = 0; i < painted.nodes.length - 1; i++) {
      expect(painted.nodes[i].dx, lessThan(painted.nodes[i + 1].dx));
    }
  });

  testWidgets('2, 4, 6 y 12 puntos comparten una geometría cerrada', (
    tester,
  ) async {
    for (final count in [2, 4, 6, 12]) {
      final sessions = [
        for (var i = 0; i < count; i++)
          session(
            'shared-$count-$i',
            fixedNow.subtract(Duration(days: count - i)),
            weightKg: 20.0 + (i % 4) * 15 + i,
            reps: 1,
          ),
      ];
      await pumpChart(
        tester,
        sessions: sessions,
        metric: ProgressMetric.load,
        window: ProgressWindow.all,
      );
      final painted = _recordChartPaint(tester);

      expect(painted.nodes, hasLength(count));
      expect(painted.nodes, painted.geometry.nodes);
      expect(painted.linePath, same(painted.geometry.linePath));
      expect(painted.areaPath, same(painted.geometry.areaPath));
      expect(painted.highlightedNodes, hasLength(2));
      expect(painted.highlightedNodes, everyElement(painted.nodes.last));
      expect(painted.linePath.getBounds().right, painted.nodes.last.dx);
      expect(painted.areaPath.getBounds().right, painted.nodes.last.dx);
      expect(painted.areaPath.getBounds().bottom, painted.size.height);

      for (var i = 0; i < painted.nodes.length; i++) {
        final node = painted.nodes[i];
        expect(node.dx, closeTo(i * painted.size.width / (count - 1), 1e-9));
        expect(node.dx, inInclusiveRange(0, painted.size.width));
        expect(node.dy, inInclusiveRange(0, painted.size.height));
        if (i > 0) {
          expect(painted.nodes[i - 1].dx, lessThan(node.dx));
        }
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('el padre real gobierna el ancho en viewports de 320 y 375', (
    tester,
  ) async {
    final sessions = [
      for (var i = 0; i < 4; i++)
        session(
          'constraints-$i',
          fixedNow.subtract(Duration(days: 3 - i)),
          weightKg: 40 + i * 5,
          reps: 1,
        ),
    ];

    for (final viewportWidth in [320.0, 375.0]) {
      final parentWidth = viewportWidth - 24;
      await pumpChart(
        tester,
        sessions: sessions,
        metric: ProgressMetric.load,
        window: ProgressWindow.all,
        viewportWidth: viewportWidth,
        parentWidth: parentWidth,
      );
      final painted = _recordChartPaint(tester);
      final plotRect = tester.getRect(find.byKey(chartPlotKey));
      final axisRect = tester.getRect(find.byKey(chartDateAxisKey));

      expect(parentWidth, lessThan(viewportWidth));
      expect(painted.size.width, parentWidth - 80);
      expect(painted.nodes.first.dx, 0);
      expect(painted.nodes.last.dx, painted.size.width);
      expect(plotRect.left, axisRect.left);
      expect(plotRect.right, axisRect.right);
      expect(plotRect.left, greaterThanOrEqualTo(0));
      expect(plotRect.right, lessThanOrEqualTo(viewportWidth));
      expect(chartDateLabels(tester).first, '14/11');
      expect(chartDateLabels(tester).last, '17/11');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('cambios de valores, fechas y ancho repintan la geometría', (
    tester,
  ) async {
    final dates = [
      for (var i = 0; i < 4; i++) fixedNow.subtract(Duration(days: 4 - i)),
    ];
    List<ExerciseSessionSummary> sessions(
      List<double> weights,
      List<DateTime> sessionDates,
    ) {
      return [
        for (var i = 0; i < weights.length; i++)
          session('repaint-$i', sessionDates[i], weightKg: weights[i], reps: 1),
      ];
    }

    await pumpChart(
      tester,
      sessions: sessions([10, 20, 30, 40], dates),
      metric: ProgressMetric.load,
      window: ProgressWindow.all,
      parentWidth: 300,
    );
    final initial = _recordChartPaint(tester);

    final changedWeights = sessions([10, 25, 35, 40], dates);
    await pumpChart(
      tester,
      sessions: changedWeights,
      metric: ProgressMetric.load,
      window: ProgressWindow.all,
      parentWidth: 300,
    );
    final valuesChanged = _recordChartPaint(tester);
    expect(
      (initial.painter as dynamic).shouldRepaint(valuesChanged.painter),
      isTrue,
    );
    expect(valuesChanged.nodes, isNot(initial.nodes));

    final changedDates = [
      for (final date in dates) date.add(const Duration(days: 1)),
    ];
    await pumpChart(
      tester,
      sessions: sessions([10, 25, 35, 40], changedDates),
      metric: ProgressMetric.load,
      window: ProgressWindow.all,
      parentWidth: 300,
    );
    final datesChanged = _recordChartPaint(tester);
    expect(
      (valuesChanged.painter as dynamic).shouldRepaint(datesChanged.painter),
      isTrue,
    );
    expect(chartDateLabels(tester).last, '17/11');

    await pumpChart(
      tester,
      sessions: sessions([10, 25, 35, 40], changedDates),
      metric: ProgressMetric.load,
      window: ProgressWindow.all,
      parentWidth: 340,
    );
    final resized = _recordChartPaint(tester);
    expect(
      (datesChanged.painter as dynamic).shouldRepaint(resized.painter),
      isTrue,
    );
    expect(resized.size.width, greaterThan(datesChanged.size.width));
    expect(resized.nodes.last.dx, resized.size.width);

    await pumpChart(
      tester,
      sessions: sessions([10, 25, 35, 40], changedDates),
      metric: ProgressMetric.load,
      window: ProgressWindow.all,
      parentWidth: 340,
    );
    final unchanged = _recordChartPaint(tester);
    expect(
      (resized.painter as dynamic).shouldRepaint(unchanged.painter),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('un descenso conserva puntos, ventanas y delta negativo', (
    tester,
  ) async {
    final sessions = [
      session(
        'recent-lower',
        fixedNow.subtract(const Duration(days: 5)),
        weightKg: 80,
        reps: 1,
      ),
      session(
        'old-higher',
        fixedNow.subtract(const Duration(days: 20)),
        weightKg: 100,
        reps: 1,
      ),
    ];
    final pointsBefore = progressChartPoints(
      sessions,
      metric: ProgressMetric.load,
      window: ProgressWindow.threeMonths,
      now: fixedNow,
    );

    expect(pointsBefore.map((point) => point.value), [100, 80]);
    expect(periodDelta(pointsBefore)!.absolute, -20);

    await pumpChart(tester, sessions: sessions, metric: ProgressMetric.load);

    expect(find.text('-20.0 kg'), findsOneWidget);
    expect(find.text('+20.0 kg'), findsNothing);
    expect(
      progressChartPoints(
        sessions,
        metric: ProgressMetric.load,
        window: ProgressWindow.threeMonths,
        now: fixedNow,
      ),
      pointsBefore,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('el eje deduplica días y usa como máximo cuatro fechas reales', (
    tester,
  ) async {
    final dates = [
      DateTime(2026, 1, 1, 8),
      DateTime(2026, 1, 1, 18),
      DateTime(2026, 1, 3),
      DateTime(2026, 1, 5),
      DateTime(2026, 1, 7),
      DateTime(2026, 1, 9),
      DateTime(2026, 1, 11),
    ];
    final sessions = [
      for (var i = 0; i < dates.length; i++)
        session('dates-$i', dates[i], weightKg: 40.0 + i, reps: 1),
    ];

    await pumpChart(
      tester,
      sessions: sessions,
      metric: ProgressMetric.load,
      window: ProgressWindow.all,
      viewportWidth: 320,
      parentWidth: 320,
    );

    final labels = chartDateLabels(tester);
    expect(labels, ['01/01', '03/01', '07/01', '11/01']);
    expect(labels, hasLength(lessThanOrEqualTo(4)));
    expect(labels.toSet(), hasLength(labels.length));
    expect(find.byKey(insightDeltaKey), findsOneWidget);
    expect(find.byKey(insightFrequencyKey), findsNothing);
    expect(find.text('0x / semana'), findsNothing);
    expect(find.text('Carga Máx (kg) · Todo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un rango entre años muestra el año sin overflow a 320', (
    tester,
  ) async {
    final dates = [
      DateTime(2025, 12, 30),
      DateTime(2025, 12, 31),
      DateTime(2026, 1, 1),
      DateTime(2026, 1, 2),
    ];
    await pumpChart(
      tester,
      sessions: [
        for (var i = 0; i < dates.length; i++)
          session('years-$i', dates[i], weightKg: 60 + i * 5, reps: 1),
      ],
      metric: ProgressMetric.load,
      window: ProgressWindow.all,
      viewportWidth: 320,
      parentWidth: 320,
    );

    expect(chartDateLabels(tester), [
      '30/12/2025',
      '31/12/2025',
      '01/01/2026',
      '02/01/2026',
    ]);
    expect(find.byKey(insightFrequencyKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Todo omite el cero y una ventana finita conserva frecuencia', (
    tester,
  ) async {
    final sessions = [
      session(
        'frequency-old',
        fixedNow.subtract(const Duration(days: 20)),
        weightKg: 40,
      ),
      session(
        'frequency-new',
        fixedNow.subtract(const Duration(days: 5)),
        weightKg: 61.25,
      ),
    ];

    await pumpChart(
      tester,
      sessions: sessions,
      metric: ProgressMetric.load,
      window: ProgressWindow.all,
    );
    expect(find.byKey(insightFrequencyKey), findsNothing);
    expect(find.text('0x / semana'), findsNothing);

    await pumpChart(tester, sessions: sessions, metric: ProgressMetric.load);
    expect(find.byKey(insightFrequencyKey), findsOneWidget);
    expect(find.text('0.16x / semana'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('más de diez puntos alimentan el delta completo sin overflow', (
    tester,
  ) async {
    final sessions = [
      for (var i = 0; i < 12; i++)
        session(
          'session-$i',
          fixedNow.subtract(Duration(days: 12 - i)),
          weightKg: 10 + i * 10,
          reps: 1,
        ),
    ];

    await pumpChart(
      tester,
      sessions: sessions,
      metric: ProgressMetric.volume,
      window: ProgressWindow.all,
    );

    expect(find.byKey(chartPlotKey), findsOneWidget);
    expect(find.text('+110 kg·sesiones'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
