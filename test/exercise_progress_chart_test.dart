import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/domain/exercise_stats.dart';
import 'package:hevywork/ui/widgets/chart_enums.dart';
import 'package:hevywork/ui/widgets/exercise_progress_chart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fixedNow = DateTime(2026, 11, 17, 12, 0, 0, 0, 123456);

  ExerciseSetRow workingSet({
    double weightKg = 80,
    int reps = 5,
    String setType = 'normal',
    bool completed = true,
  }) =>
      ExerciseSetRow(
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
  }) =>
      ExerciseSessionSummary(
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
  }) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExerciseProgressChart(
            sessions: sessions,
            metric: metric,
            window: window,
            now: () => fixedNow,
            onMetricChanged: (_) {},
            onWindowChanged: (_) {},
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

    test('una ventana finita incluye inicio y ahora y excluye ambos exteriores',
        () {
      final filtered = filterByProgressWindow(
        points,
        ProgressWindow.threeMonths,
        now: fixedNow,
      );

      expect(filtered.map((point) => point.value), [1, 2, 3]);
    });

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

  testWidgets('dos puntos pintan plot e insights con altura no acotada',
      (tester) async {
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

  testWidgets('las ventanas excluyen antiguos y futuros y Todo los restaura',
      (tester) async {
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

    await pumpChart(
      tester,
      sessions: sessions,
      metric: ProgressMetric.load,
    );
    expect(find.byKey(chartPlotKey), findsOneWidget);
    expect(find.text('+20.0 kg'), findsOneWidget);

    await pumpChart(
      tester,
      sessions: sessions,
      window: ProgressWindow.oneMonth,
    );
    expectEmpty();

    await pumpChart(
      tester,
      sessions: sessions,
      window: ProgressWindow.all,
    );
    expect(find.byKey(chartPlotKey), findsOneWidget);
    expect(find.byKey(insightDeltaKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cada métrica usa los puntos y deltas del dominio',
      (tester) async {
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

  testWidgets('warmups e incompletas no generan puntos en ninguna métrica',
      (tester) async {
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

  testWidgets('volumen conserva ceros legítimos sin inventar carga ni e1RM',
      (tester) async {
    final sessions = [
      session('zero-old', fixedNow.subtract(const Duration(days: 20)), weightKg: 0),
      session('zero-new', fixedNow.subtract(const Duration(days: 5)), weightKg: 0),
    ];

    await pumpChart(
      tester,
      sessions: sessions,
      metric: ProgressMetric.volume,
    );
    expect(find.byKey(chartPlotKey), findsOneWidget);
    expect(find.text('+0 kg·sesiones'), findsOneWidget);

    await pumpChart(tester, sessions: sessions, metric: ProgressMetric.load);
    expectEmpty();
    await pumpChart(tester, sessions: sessions);
    expectEmpty();
    expect(tester.takeException(), isNull);
  });

  testWidgets('más de diez puntos alimentan el delta completo sin overflow',
      (tester) async {
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
