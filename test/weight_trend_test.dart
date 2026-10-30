import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/domain/weight_progress.dart';
import 'package:hevywork/ui/widgets/weight_trend.dart';

void main() {
  group('weeklyRateKg (RF-23)', () {
    test('con una recta descendente devuelve el ritmo semanal', () {
      final day = DateTime(2026, 3, 1);
      final points = [
        (date: day, weightKg: 80.0),
        (date: day.add(const Duration(days: 7)), weightKg: 79.0),
        (date: day.add(const Duration(days: 14)), weightKg: 78.0),
      ];

      expect(weeklyRateKg(points), closeTo(-1, 1e-9));
    });

    test('con menos de dos puntos el ritmo es 0', () {
      final day = DateTime(2026, 3, 1);

      expect(weeklyRateKg([(date: day, weightKg: 80.0)]), 0);
      expect(weeklyRateKg(const []), 0);
    });

    test('con puntos del mismo día el ritmo es 0', () {
      final day = DateTime(2026, 3, 1);
      final points = [
        (date: day, weightKg: 80.0),
        (date: day, weightKg: 82.0),
      ];

      expect(weeklyRateKg(points), 0);
    });
  });

  group('movingAverageKg (RF-23)', () {
    test('aplica la ventana trailing y conserva la longitud', () {
      final day = DateTime(2026, 3, 1);
      final points = [
        (date: day, weightKg: 80.0),
        (date: day.add(const Duration(days: 1)), weightKg: 82.0),
        (date: day.add(const Duration(days: 2)), weightKg: 84.0),
      ];

      expect(movingAverageKg(points), [80, 81, 82]);
      expect(movingAverageKg(points, window: 2), [80, 81, 83]);
    });
  });

  group('projectToGoal (RF-23)', () {
    final day = DateTime(2026, 3, 1);
    List<({DateTime date, double weightKg})> series(double last) => [
          (date: day, weightKg: 80.0),
          (date: day.add(const Duration(days: 14)), weightKg: last),
        ];

    test('sigue el ritmo hasta el plazo y se acota en la meta', () {
      final projection = projectToGoal(
        points: series(78),
        goalKg: 76,
        deadline: day.add(const Duration(days: 42)),
        now: day.add(const Duration(days: 14)),
      );

      expect(projection, isNotNull);
      expect(projection!.weightKg, 76);
      expect(
        projection.date,
        day.add(const Duration(days: 42)),
      );
    });

    test('sin cruce devuelve el valor proyectado sin acotar', () {
      final projection = projectToGoal(
        points: series(79),
        goalKg: 76,
        deadline: day.add(const Duration(days: 28)),
        now: day.add(const Duration(days: 14)),
      );

      expect(projection!.weightKg, closeTo(78, 1e-9));
    });

    test('sin plazo futuro o sin ritmo no hay proyección', () {
      expect(
        projectToGoal(
          points: series(78),
          goalKg: 76,
          deadline: day,
          now: day.add(const Duration(days: 14)),
        ),
        isNull,
      );
      expect(
        projectToGoal(
          points: series(80),
          goalKg: 76,
          deadline: day.add(const Duration(days: 28)),
          now: day,
        ),
        isNull,
      );
      expect(
        projectToGoal(
          points: series(78),
          goalKg: 76,
          deadline: null,
        ),
        isNull,
      );
    });
  });

  group('kgDeltaLabel (RF-23)', () {
    test('fija el signo y una decimal', () {
      expect(kgDeltaLabel(-1.2), '-1.2 kg');
      expect(kgDeltaLabel(0.4), '+0.4 kg');
      expect(kgDeltaLabel(0), '0.0 kg');
    });
  });

  group('WeightTrend', () {
    final day = DateTime(2026, 3, 1);
    List<({DateTime date, double weightKg})> series() => [
          for (var i = 0; i < 4; i++)
            (date: day.add(Duration(days: i * 7)), weightKg: 80.0 - i),
        ];

    Future<void> pumpView(
      WidgetTester tester,
      WeightTrend trend,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: trend)),
      );
    }

    testWidgets('con menos de dos puntos muestra el aviso', (tester) async {
      await pumpView(tester, WeightTrend(points: series().take(1).toList()));

      expect(find.text('Registra tu peso para ver la tendencia'), findsOneWidget);
    });

    testWidgets('con meta y proyección pinta el gráfico sin errores',
        (tester) async {
      await pumpView(
        tester,
        WeightTrend(
          points: series(),
          goalKg: 76,
          projection: (date: day.add(const Duration(days: 56)), weightKg: 76),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(WeightTrend),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
