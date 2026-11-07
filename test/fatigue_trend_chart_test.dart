import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/domain/exercise_stats.dart';
import 'package:hevywork/domain/fatigue_trend.dart';
import 'package:hevywork/ui/widgets/fatigue_trend_chart.dart';

final kTestDays = 14;

void main() {
  final now = DateTime(2026, 10, 27);

  testWidgets('render con puntos de fatiga', (WidgetTester tester) async {
    final points = fatigueTrend(sets: [], days: kTestDays, now: now).map((p) => p.value).toList();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: FatigueTrendChart(points: points))),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FatigueTrendChart), findsOneWidget);
  });

  testWidgets('render con lista vacía', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: FatigueTrendChart(points: const []))),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FatigueTrendChart), findsOneWidget);
  });

  testWidgets('render con un solo punto', (WidgetTester tester) async {
    final points = fatigueTrend(
      sets: const [
        ExerciseSetRow(
          orderIndex: 0,
          setType: 'normal',
          weightKg: 5000,
          reps: 1,
          completed: true,
        ),
      ],
      days: kTestDays,
      now: now,
    ).map((p) => p.value).toList();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: FatigueTrendChart(points: points))),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FatigueTrendChart), findsOneWidget);
  });

  testWidgets('highlight con músculo opcional', (WidgetTester tester) async {
    final points = fatigueTrend(
      sets: const [
        ExerciseSetRow(
          orderIndex: 0,
          setType: 'normal',
          weightKg: 5000,
          reps: 1,
          completed: true,
        ),
      ],
      days: kTestDays,
      now: now,
      muscle: 'quadriceps',
    ).map((p) => p.value).toList();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: FatigueTrendChart(points: points, muscle: 'quadriceps'))),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FatigueTrendChart), findsOneWidget);
  });
}