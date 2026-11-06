import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/app/theme/app_theme.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/body_metric_repository.dart';
import 'package:hevywork/data/repositories/catalog_repository.dart';
import 'package:hevywork/data/repositories/fatigue_repository.dart';
import 'package:hevywork/data/repositories/goal_repository.dart';
import 'package:hevywork/data/repositories/photo_repository.dart';
import 'package:hevywork/data/repositories/profile_repository.dart';
import 'package:hevywork/data/repositories/routine_repository.dart';
import 'package:hevywork/data/repositories/workout_repository.dart';
import 'package:hevywork/data/sync/sync_engine.dart';
import 'package:hevywork/main.dart';
import 'package:hevywork/ui/layout/screen_breakpoints.dart';
import 'package:hevywork/ui/widgets/hevy_bottom_nav.dart';

// Test breakpoints helper and MainNavigator shell layout.

// Test screenClassOf boundaries.

// Test horizontalMarginOf.

// Test gutterOf.

// Test kContentMaxWidth.

// Test MainNavigator shell layout.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    localDb = AppDatabase(NativeDatabase.memory());
    syncEngine = SyncEngine(localDb, null);
    catalogRepository = CatalogRepository(localDb);
    workoutRepository = WorkoutRepository(localDb);
    routineRepository = RoutineRepository(localDb, workoutRepository);
    goalRepository = GoalRepository(localDb);
    bodyMetricRepository = BodyMetricRepository(localDb);
    fatigueRepository = FatigueRepository(localDb);
    photoRepository = PhotoRepository(localDb);
    profileRepository = ProfileRepository(localDb);
  });

  tearDownAll(() {
    syncEngine.stop();
    localDb.close();
  });

  group('screenBreakpoints helper', () {
    test('599 dp -> phone', () {
      expect(screenClassOf(599.0), equals(ScreenClass.phone));
    });

    test('600 dp -> tablet', () {
      expect(screenClassOf(600.0), equals(ScreenClass.tablet));
    });

    test('horizontalMarginOf phone -> 16.0', () {
      expect(horizontalMarginOf(ScreenClass.phone), equals(16.0));
    });

    test('horizontalMarginOf tablet -> 24.0', () {
      expect(horizontalMarginOf(ScreenClass.tablet), equals(24.0));
    });

    test('gutterOf phone -> 12.0', () {
      expect(gutterOf(ScreenClass.phone), equals(12.0));
    });

    test('gutterOf tablet -> 16.0', () {
      expect(gutterOf(ScreenClass.tablet), equals(16.0));
    });

    test('kContentMaxWidth -> 640.0', () {
      expect(kContentMaxWidth, equals(640.0));
    });
  });

  group('MainNavigator shell layout', () {
    // Test sizes that cover phone and tablet breakpoints.
    // Each width is tested with text scale 1.0 (the HevyWorkApp builder
    // clamps textScaler to 1.0-1.3, ensuring layout independence from
    // system text scaling).
    final testWidths = [320, 360, 375, 412, 768, 1024, 1366];

    for (final widthDp in testWidths) {
      testWidgets('width=$widthDp dp — no render exceptions',
          (tester) async {
        tester.view.physicalSize = Size(widthDp * 2, widthDp * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Pump HevyWorkApp which has the textScaler clamp in its builder.
        // The clamp ensures layout is independent of system text scaling.
        await tester.pumpWidget(
          const HevyWorkApp(),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
      });
    }
  });
}