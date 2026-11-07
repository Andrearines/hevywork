import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test';

import 'package:hevywork/domain/muscle_fatigue.dart';
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
              panel: FatiguePanel(
                fatigue: {'pectorals': 0.8, 'lats': 0.6},
                zones: zoneStats,
                trend: [],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      // Verify chips are rendered with the new format
      expect(find.text('pectorals'), findsOneWidget);
      expect(find.text('lats'), findsOneWidget);
    });

    testWidgets('render con panel vacío muestra "Sin series"',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveFatigueSection(
              panel: FatiguePanel(
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
              panel: FatiguePanel(
                fatigue: {'pectorals': 0.8},
                zones: zoneStats,
                trend: [],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      // Verify the weekly volume format appears
      expect(find.text('series'), findsWidgets);
      expect(find.text('8 series'), findsOneWidget);
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
              panel: FatiguePanel(
                fatigue: {'pectorals': 0.8},
                zones: zoneStats,
                trend: [],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      // Chip should show "Pecho · 3 series · 80.5 kg", NOT "80.50000000000001"
      expect(find.text('Pecho · 3 series · 80.5 kg'), findsOneWidget);
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
              panel: FatiguePanel(
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
              panel: FatiguePanel(
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