import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hevywork/ui/widgets/live_fatigue_section.dart';

void main() {
  group('LiveFatigueSection', () {
    testWidgets('render con panel y zonas muestra chips de serie',
        (WidgetTester tester) async {
      final zoneStats = [
        (muscle: 'pectorals', weeklyVolume: 12000.0, sets: 8, fatigue: 0.8),
        (muscle: 'lats', weeklyVolume: 9500.0, sets: 6, fatigue: 0.6),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveFatigueSection(
              panel: (
                fatigue: {'pectorals': 0.8, 'lats': 0.6},
                zones: zoneStats,
                trend: [],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.text('Pecho · 8 series · 12000 kg'),
        findsOneWidget,
      );
      expect(
        find.text('Dorsales · 6 series · 9500 kg'),
        findsOneWidget,
      );
    });

    testWidgets('render con panel vacío muestra "Sin series"',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveFatigueSection(
              panel: (
                fatigue: {},
                zones: const [],
                trend: [],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      // Should show "Sin series" when no zones
      expect(find.text('Sin series'), findsOneWidget);
    });

    testWidgets('render con panel y resumen semanal',
        (WidgetTester tester) async {
      final zoneStats = [
        (muscle: 'pectorals', weeklyVolume: 12000.0, sets: 8, fatigue: 0.8),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveFatigueSection(
              panel: (
                fatigue: {'pectorals': 0.8},
                zones: zoneStats,
                trend: [],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('series'), findsWidgets);
      expect(find.textContaining('8 series'), findsOneWidget);
    });

    testWidgets('zoneChipLabel formatea correctamente el chip',
        (WidgetTester tester) async {
      final zoneStats = [
        (muscle: 'pectorals', weeklyVolume: 80.50000000000001, sets: 3, fatigue: 0.8),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveFatigueSection(
              panel: (
                fatigue: {'pectorals': 0.8},
                zones: zoneStats,
                trend: [],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Pecho · 3 series · 80.50 kg'), findsOneWidget);
      expect(find.text('80.50000000000001'), findsNothing);
    });

    testWidgets('zoneChipLabel muestra 12000 sin decimales para volumen entero',
        (WidgetTester tester) async {
      final zoneStats = [
        (muscle: 'pectorals', weeklyVolume: 12000.0, sets: 8, fatigue: 0.8),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveFatigueSection(
              panel: (
                fatigue: {'pectorals': 0.8},
                zones: zoneStats,
                trend: [],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      // Chip should show "Pecho · 8 series · 12000 kg", sin ".0"
      expect(find.text('Pecho · 8 series · 12000 kg'), findsOneWidget);
    });

    testWidgets('zoneChipLabel devuelve "Sin series" para zona sin series',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveFatigueSection(
              panel: (
                fatigue: {},
                zones: const [],
                trend: [],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Sin series'), findsOneWidget);
    });
  });
}