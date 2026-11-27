import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/app/theme/app_theme.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/catalog_repository.dart';
import 'package:hevywork/data/repositories/custom_exercise_repository.dart';
import 'package:hevywork/data/repositories/workout_repository.dart';
import 'package:hevywork/main.dart';
import 'package:hevywork/ui/views/catalog_view.dart';
import 'package:hevywork/ui/widgets/exercise_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUpAll(() {
    db = AppDatabase(NativeDatabase.memory());
    localDb = db;
    catalogRepository = CatalogRepository(db);
    customExerciseRepository = CustomExerciseRepository(
      db,
      onChanged: catalogRepository.invalidateFilterOptions,
    );
    workoutRepository = WorkoutRepository(db);
    catalogReady = null;
  });

  setUp(() async {
    await db.delete(db.exercisePreferences).go();
    await db.delete(db.exercises).go();
    await db.delete(db.syncQueue).go();
    catalogRepository.invalidateFilterOptions();
  });

  tearDownAll(() => db.close());

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 20));
  }

  Future<void> enter(WidgetTester tester, Key key, String value) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.enterText(find.byKey(key), value);
  }

  Future<void> fillNewExercise(WidgetTester tester) async {
    await enter(tester, const Key('custom-name'), 'Press propio');
    await tester.ensureVisible(find.byKey(const Key('custom-target')));
    await tester.tap(find.byKey(const Key('custom-target')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.text('pectorals', skipOffstage: false).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('pectorals').last);
    await tester.pumpAndSettle();
    await enter(tester, const Key('custom-body-part'), 'chest');
    await enter(tester, const Key('custom-equipment'), 'barbell');
  }

  testWidgets('catálogo crea, recarga conservando búsqueda y edita por ruta', (
    tester,
  ) async {
    final routes = _RouteNames();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        navigatorObservers: [routes],
        home: const Scaffold(body: CatalogView()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog-create-custom')), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Press');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('catalog-create-custom')));
    await tester.pumpAndSettle();
    expect(routes.names, contains('/catalog/custom/new'));
    await fillNewExercise(tester);
    await tester.ensureVisible(find.byKey(const Key('custom-save')));
    await tester.tap(find.byKey(const Key('custom-save')));
    await tester.pumpAndSettle();

    expect(find.text('Press propio'), findsOneWidget);
    expect(find.text('1 resultados'), findsOneWidget);
    expect(find.text('Press'), findsOneWidget);
    expect(find.textContaining('Personalizado'), findsOneWidget);
    expect(await db.select(db.syncQueue).get(), isEmpty);

    await tester.tap(find.text('Press propio'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('custom-edit')));
    await tester.pumpAndSettle();
    final id = (await db.select(db.exercises).getSingle()).id;
    expect(routes.names, contains('/catalog/custom/$id/edit'));
    await enter(tester, const Key('custom-name'), 'Press editado');
    await tester.ensureVisible(find.byKey(const Key('custom-save')));
    await tester.tap(find.byKey(const Key('custom-save')));
    await tester.pumpAndSettle();
    expect(find.text('Press editado'), findsOneWidget);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('Press editado'), findsOneWidget);
    expect(find.text('Press'), findsOneWidget);
    expect(find.text('1 resultados'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('el selector incluye custom y carga páginas de 50', (
    tester,
  ) async {
    final localUserId =
        (await db.select(db.localProfiles).getSingle()).localUserId;
    await db.batch((batch) {
      batch.insertAll(db.exercises, [
        for (var i = 0; i < 55; i++)
          ExercisesCompanion.insert(
            id: 'custom_$i',
            name: 'Ejercicio ${i.toString().padLeft(2, '0')}',
            bodyPart: 'chest',
            equipment: 'barbell',
            target: 'pectorals',
            muscleGroup: 'triceps',
            secondaryMuscles: const Value('["triceps"]'),
            origin: const Value('custom'),
            localUserId: Value(localUserId),
            imageUploadStatus: const Value('none'),
            updatedAt: Value(DateTime(2026, 11, 26)),
          ),
      ]);
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: ExercisePicker()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('picker-create-custom')), findsOneWidget);
    expect(find.text('55 resultados'), findsOneWidget);
    expect(find.text('Ejercicio 00'), findsOneWidget);
    expect(find.text('Ejercicio 54'), findsNothing);
    for (var i = 0; i < 8; i++) {
      await tester.drag(
        find.byWidgetPredicate(
          (widget) =>
              widget is ListView && widget.scrollDirection == Axis.vertical,
        ),
        const Offset(0, -1200),
      );
      await tester.pumpAndSettle();
    }
    expect(find.text('Ejercicio 54'), findsOneWidget);
    await unmount(tester);
  });

  for (final width in [320.0, 375.0, 640.0, 1024.0]) {
    testWidgets('catálogo conserva el CTA a $width dp y textScaler 1.3', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child ?? const SizedBox.shrink(),
          ),
          home: const Scaffold(body: CatalogView()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('catalog-create-custom')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('catalog-create-custom'))).height,
        greaterThanOrEqualTo(44),
      );
      await unmount(tester);
    });
  }
}

class _RouteNames extends NavigatorObserver {
  final List<String> names = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null) names.add(name);
  }
}
