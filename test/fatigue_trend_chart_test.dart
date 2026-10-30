import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/domain/fatigue_trend.dart';
import 'package:hevywork/ui/widgets/fatigue_trend_chart.dart';

void main() {
  final now = DateTime(2026, 10, 27);

  testWidgets('render con puntos de fatiga', (WidgetTester tester) async {
    final points = fatigueTrend(sets: [], now: now).map((p) => p.value).toList();
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
      sets: [
        (
          endedAt: now,
          volume: 5000,
          setType: 'normal',
          target: 'quads',
          secondaryMuscles: [],
        ),
      ],
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
      sets: [
        (
          endedAt: now,
          volume: 5000,
          setType: 'normal',
          target: 'quads',
          secondaryMuscles: [],
        ),
      ],
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