import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/ui/widgets/exercise_progress_chart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExerciseProgressChart chart;

  setUp(() {
    chart = const ExerciseProgressChart(
      sessions: [],
      metric: ProgressMetric.volume,
      window: ProgressWindow.threeMonths,
      onMetricChanged: (_) {},
      onWindowChanged: (_) {},
    );
  });

  testWidgets('widget can be created', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: chart));
    expect(find.byType(ExerciseProgressChart), findsOneWidget);
  });
}