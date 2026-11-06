import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test';
import 'package:hevywork/ui/widgets/live_fatigue_section.dart';

void main() {
  group('LiveFatigueSection', () {
    testWidgets('render con panel y zonas muestra chips de serie', (WidgetTester tester) async {
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

    testWidgets('render con panel vacío muestra "Sin series"', (WidgetTester tester) async {
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

    testWidgets('render con panel y resumen semanal', (WidgetTester tester) async {
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
  });
}