import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/body_metric_repository.dart';
import 'package:hevywork/data/repositories/catalog_repository.dart';
import 'package:hevywork/data/repositories/fatigue_repository.dart';
import 'package:hevywork/data/repositories/goal_repository.dart';
import 'package:hevywork/data/repositories/profile_repository.dart';
import 'package:hevywork/data/repositories/routine_repository.dart';
import 'package:hevywork/data/repositories/workout_repository.dart';
import 'package:hevywork/data/sync/sync_engine.dart';
import 'package:hevywork/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    localDb = AppDatabase(NativeDatabase.memory());
    syncEngine = SyncEngine(localDb, null);
    catalogRepository = CatalogRepository(localDb);
    workoutRepository = WorkoutRepository(localDb);
    routineRepository = RoutineRepository(localDb, workoutRepository);
    goalRepository = GoalRepository(localDb);
    bodyMetricRepository = BodyMetricRepository(localDb);
    fatigueRepository = FatigueRepository(localDb);
    profileRepository = ProfileRepository(localDb);

    // Catálogo sintético de 130 filas: suficiente para 3 páginas de 50.
    await localDb.batch((batch) {
      batch.insertAll(localDb.exercises, [
        for (var i = 0; i < 130; i++)
          ExercisesCompanion.insert(
            id: i.toString().padLeft(3, '0'),
            name: 'Synthetic Exercise ${i.toString().padLeft(3, '0')}',
            bodyPart: 'chest',
            equipment: 'barbell',
            target: 'pectorals',
            muscleGroup: 'chest',
          ),
      ]);
    });
  });

  tearDownAll(() => localDb.close());

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  /// RF-10 de la 008: el catálogo vive en pantalla propia, accesible desde el
  /// icono de búsqueda del header de Entrenar.
  Future<void> openCatalog(WidgetTester tester) async {
    await tester.pumpWidget(const HevyWorkApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
  }

  testWidgets('RF-5: al llegar al 80% del scroll pide la siguiente página',
      (tester) async {
    await openCatalog(tester);

    // Primera página: 50 filas cargadas, el resto aún no construido.
    expect(find.text('130 resultados'), findsOneWidget);
    expect(find.text('Synthetic Exercise 000'), findsOneWidget);
    expect(find.text('Synthetic Exercise 129'), findsNothing);

    // Scrolling repetido hasta el fondo: las páginas 2 y 3 se cargan solas.
    for (var i = 0; i < 12; i++) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -1200));
      await tester.pumpAndSettle();
    }

    expect(find.text('Synthetic Exercise 129'), findsOneWidget,
        reason: 'la última fila solo existe si el scroll cargo las páginas');
    expect(find.text('130 resultados'), findsOneWidget,
        reason: 'el contador total no depende de la página');

    await unmount(tester);
  });
}