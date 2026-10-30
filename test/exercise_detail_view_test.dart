import 'package:cached_network_image/cached_network_image.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/catalog_repository.dart';
import 'package:hevywork/main.dart';
import 'package:hevywork/ui/views/exercise_detail_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Exercise exercise;

  setUpAll(() async {
    db = AppDatabase(NativeDatabase.memory());
    localDb = db;
    catalogRepository = CatalogRepository(db);

    exercise = await db.into(db.exercises).insertReturning(
          ExercisesCompanion.insert(
            id: '0001',
            name: 'Press de banca con barra',
            bodyPart: 'chest',
            equipment: 'barbell',
            target: 'pectorals',
            muscleGroup: 'pecho',
            imagePath: const Value('images/0001-2gPfomN.jpg'),
            gifPath: const Value('videos/0001-2gPfomN.gif'),
            attribution: const Value('© Gym visual — https://gymvisual.com/'),
          ),
        );
  });

  setUp(() async {
    await db.delete(db.exerciseInstructions).go();
    await db.batch((batch) {
      batch.insert(db.exerciseInstructions, ExerciseInstructionsCompanion.insert(
        exerciseId: '0001',
        language: 'es',
        stepNumber: 1,
        instruction: 'Baja la barra hasta tocar el pecho',
      ));
      batch.insert(db.exerciseInstructions, ExerciseInstructionsCompanion.insert(
        exerciseId: '0001',
        language: 'es',
        stepNumber: 2,
        instruction: 'Empuja hasta extender los brazos',
      ));
      batch.insert(db.exerciseInstructions, ExerciseInstructionsCompanion.insert(
        exerciseId: '0001',
        language: 'en',
        stepNumber: 1,
        instruction: 'Lower the bar to your chest',
      ));
    });
  });

  tearDownAll(() => db.close());

  Future<void> pumpDetail(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ExerciseDetailView(exercise: exercise)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('muestra nombre, miniatura local y atribución', (tester) async {
    await pumpDetail(tester);

    expect(find.text('Press de banca con barra'), findsOneWidget);
    expect(find.textContaining('Gym visual'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);

    // Sin URL de Supabase configurada no se pinta ningún GIF (RF-3).
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('lista los pasos en español por defecto', (tester) async {
    await pumpDetail(tester);

    expect(find.text('Baja la barra hasta tocar el pecho'), findsOneWidget);
    expect(find.text('Empuja hasta extender los brazos'), findsOneWidget);
    expect(find.text('ES'), findsOneWidget);
    expect(find.text('EN'), findsOneWidget);
  });

  testWidgets('al cambiar a EN muestra los pasos ingleses', (tester) async {
    await pumpDetail(tester);

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    expect(find.text('Lower the bar to your chest'), findsOneWidget);
    expect(find.text('Baja la barra hasta tocar el pecho'), findsNothing);
  });

  testWidgets('ajusta el descanso por defecto del ejercicio (RF-5 de la 002)',
      (tester) async {
    await pumpDetail(tester);

    expect(find.text('Descanso por defecto'), findsOneWidget);
    expect(find.text('90 s'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rest-detail-plus')));
    await tester.pumpAndSettle();
    expect(find.text('105 s'), findsOneWidget);

    var stored = await (db.select(db.exercises)
          ..where((t) => t.id.equals('0001')))
        .getSingle();
    expect(stored.restSeconds, 105);

    await tester.tap(find.byKey(const Key('rest-detail-minus')));
    await tester.tap(find.byKey(const Key('rest-detail-minus')));
    await tester.pumpAndSettle();
    expect(find.text('75 s'), findsOneWidget);

    stored = await (db.select(db.exercises)
          ..where((t) => t.id.equals('0001')))
        .getSingle();
    expect(stored.restSeconds, 75);

    await tester.tap(find.byKey(const Key('rest-detail-minus')));
    await tester.tap(find.byKey(const Key('rest-detail-minus')));
    await tester.tap(find.byKey(const Key('rest-detail-minus')));
    await tester.pumpAndSettle();
    expect(find.text('30 s'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('rest-detail-minus')))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('rest-detail-minus')));
    await tester.pumpAndSettle();
    expect(find.text('15 s'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('rest-detail-minus')))
          .onPressed,
      isNull,
      reason: 'el mínimo del rango es 15 s',
    );
  });
}
