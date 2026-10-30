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
    await catalogRepository.initializeCatalogIfEmpty();
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

  testWidgets('RF-1: con 2+ caracteres filtra los ejercicios por nombre',
      (tester) async {
    await openCatalog(tester);
    expect(find.text('1324 resultados'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'press');
    await tester.pumpAndSettle();

    expect(find.text('164 resultados'), findsOneWidget);
    expect(find.text('1324 resultados'), findsNothing);
    expect(find.textContaining('press'), findsWidgets);

    await unmount(tester);
  });

  testWidgets('RF-1: con 1 carácter no filtra (solo busca desde 2)',
      (tester) async {
    await openCatalog(tester);

    await tester.enterText(find.byType(TextField), 'a');
    await tester.pumpAndSettle();

    expect(find.text('1324 resultados'), findsOneWidget);
    expect(find.text('Prueba otros filtros'), findsNothing);

    await unmount(tester);
  });

  testWidgets('RF-3/RF-4: filtrar por equipo y "Limpiar filtros" revierte',
      (tester) async {
    await openCatalog(tester);
    expect(find.text('1324 resultados'), findsOneWidget);

    await tester.tap(find.text('Equipo'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('barbell'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();

    expect(find.text('1324 resultados'), findsNothing);
    expect(find.text('Limpiar filtros'), findsOneWidget);
    expect(find.textContaining('barbell'), findsWidgets);

    await tester.tap(find.text('Limpiar filtros'));
    await tester.pumpAndSettle();

    expect(find.text('1324 resultados'), findsOneWidget);
    expect(find.text('Limpiar filtros'), findsNothing);

    await unmount(tester);
  });

  testWidgets('caso límite: 0 resultados muestra "Prueba otros filtros"',
      (tester) async {
    await openCatalog(tester);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();

    expect(find.text('0 resultados'), findsOneWidget);
    expect(find.text('Prueba otros filtros'), findsOneWidget);
    expect(find.text('No hay ejercicios'), findsNothing);

    await unmount(tester);
  });

  testWidgets('los filtros combinados suman dentro de una dimensión (OR)',
      (tester) async {
    await openCatalog(tester);

    await tester.tap(find.text('Equipo'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('band'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('barbell'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();

    expect(find.text('208 resultados'), findsOneWidget,
        reason: 'band y barbell suman y descartan el resto');

    await unmount(tester);
  });
}