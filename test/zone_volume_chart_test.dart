import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/ui/widgets/zone_volume_chart.dart';

void main() {
  final day = DateTime(2026, 10, 27);

  // Datos de prueba: MuscleZoneStats con volumen y fatiga variados
  // Usando valores double para compatibilidad con el typedef
  final stats = [
    (muscle: 'pectorals', weeklyVolume: 12000.0, sets: 8, fatigue: 0.8),
    (muscle: 'lats', weeklyVolume: 9500.0, sets: 6, fatigue: 0.6),
    (muscle: 'quadriceps', weeklyVolume: 15000.0, sets: 10, fatigue: 0.7),
    (muscle: 'deltoids', weeklyVolume: 4500.0, sets: 4, fatigue: 0.4),
    (muscle: 'biceps', weeklyVolume: 3000.0, sets: 3, fatigue: 0.3),
    (muscle: 'triceps', weeklyVolume: 2500.0, sets: 2, fatigue: 0.2),
    (muscle: 'hamstrings', weeklyVolume: 1800.0, sets: 2, fatigue: 0.1),
  ];

  testWidgets('render con datos no lanza excepción', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ZoneVolumeChart(zones: stats))),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('render con lista vacía no lanza excepción', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ZoneVolumeChart(zones: const []))),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('render con un solo punto no lanza excepción', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ZoneVolumeChart(zones: [stats.first]))),
    );
    expect(tester.takeException(), isNull);
  });
}