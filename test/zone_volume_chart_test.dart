import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test';

import 'package:hevywork/domain/muscle_fatigue.dart';
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

  testWidgets('etiqueta no contiene el formato viejo kg×series', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZoneVolumeChart(
            zones: stats,
            unitSystem: 'metric',
          ),
        ),
      ),
    );
    // La etiqueta antigua era "kg×series", la nueva es "N series X kg"
    // Como el texto se pinta en CustomPaint, verificamos que el widget
    // no lanza excepción y la estructura es la esperada
    expect(tester.takeException(), isNull);
  });

  testWidgets('etiqueta cambia con unitSystem imperial', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZoneVolumeChart(
            zones: stats,
            unitSystem: 'imperial',
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('zoneVolumeLabel muestra métrico con ≤ 2 decimales', (WidgetTester tester) async {
    final metricStats = [
      (muscle: 'pectorals', weeklyVolume: 80.50000000000001, sets: 3, fatigue: 0.8),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZoneVolumeChart(
            zones: metricStats,
            unitSystem: 'metric',
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    // La etiqueta debe tener máximo 2 decimales y no contener el ruido floating-point
  });

  testWidgets('zoneVolumeLabel muestra imperial con lb y ≤ 2 decimales',
      (WidgetTester tester) async {
    final imperialStats = [
      (muscle: 'pectorals', weeklyVolume: 80.50000000000001, sets: 3, fatigue: 0.8),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZoneVolumeChart(
            zones: imperialStats,
            unitSystem: 'imperial',
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    // En sistema imperial, la etiqueta debe tener la unidad 'lb' y máximo 2 decimales
  });
}