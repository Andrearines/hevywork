import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/domain/exercise_stats.dart';
import 'package:hevywork/ui/unit_system_scope.dart';
import 'package:hevywork/ui/widgets/chart_enums.dart';
import 'package:hevywork/ui/widgets/exercise_progress_chart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ExerciseSessionSummary session(
    String id,
    DateTime endedAt,
    double weightKg,
  ) =>
      ExerciseSessionSummary(
        workoutId: id,
        name: id,
        endedAt: endedAt,
        sets: [
          ExerciseSetRow(
            orderIndex: 1,
            setType: 'normal',
            weightKg: weightKg,
            reps: 5,
            rir: 2,
          ),
        ],
      );

  testWidgets('021/T-002 CA-16: delta, frecuencia y unidades del chart',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final sessions = [
      session('first', now.subtract(const Duration(days: 20)), 40),
      session('last', now.subtract(const Duration(days: 5)), 61.25),
    ];

    Future<void> pump(String unitSystem) async {
      await tester.pumpWidget(
        MaterialApp(
          home: UnitSystemScope(
            unitSystem: unitSystem,
            child: Scaffold(
              body: ExerciseProgressChart(
                sessions: sessions,
                metric: ProgressMetric.load,
                onMetricChanged: (_) {},
                onWindowChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pump('metric');
    expect(find.text('+21.25 kg'), findsOneWidget);
    expect(find.text('0.16x / semana'), findsOneWidget);
    expect(find.text('Carga Máx (kg) · 3M'), findsOneWidget);

    await pump('imperial');
    expect(find.text('+46.85 lb'), findsOneWidget);
    expect(find.text('0.16x / semana'), findsOneWidget);
    expect(find.text('Carga Máx (lb) · 3M'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
