import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/catalog_repository.dart';
import 'package:hevywork/data/repositories/workout_repository.dart';
import 'package:hevywork/ui/views/exercise_info_view.dart';
import 'package:hevywork/ui/widgets/exercise_thumb.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CatalogRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = CatalogRepository(db);
  });

  tearDown(() => db.close());

  Future<Exercise> insertCustom({
    String id = 'custom_12345678-1234-4123-8123-123456789012',
    String name = 'Mi press',
    int restSeconds = 135,
    String? imagePath,
  }) async {
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            id: id,
            name: name,
            bodyPart: 'chest',
            equipment: 'barbell',
            target: 'pectorals',
            muscleGroup: 'triceps',
            secondaryMuscles: const Value('["triceps"]'),
            localUserId: Value(
              (await db.select(db.localProfiles).getSingle()).localUserId,
            ),
            origin: const Value('custom'),
            imageUploadStatus: const Value('none'),
            updatedAt: Value(DateTime(2026, 11, 26)),
            restSeconds: Value(restSeconds),
            imagePath: Value(imagePath),
          ),
        );
    return (db.select(
      db.exercises,
    )..where((row) => row.id.equals(id))).getSingle();
  }

  test('el descanso de un custom usa su propia fila', () async {
    await insertCustom(restSeconds: 135);

    expect(
      await repository.effectiveRestSeconds(
        'custom_12345678-1234-4123-8123-123456789012',
      ),
      135,
    );
    expect(await db.select(db.exercisePreferences).get(), isEmpty);
  });

  test('un custom previo no bloquea la importación del asset', () async {
    await insertCustom();

    await repository.initializeCatalogIfEmpty();
    await repository.initializeCatalogIfEmpty();

    final rows = await db.select(db.exercises).get();
    expect(rows, hasLength(1325));
    expect(rows.where((row) => row.origin == 'catalog'), hasLength(1324));
    final custom = rows.singleWhere((row) => row.id.startsWith('custom_'));
    expect(custom.name, 'Mi press');
    expect(custom.restSeconds, 135);
    expect(custom.localUserId, isNotNull);
    expect(custom.secondaryMuscles, '["triceps"]');
  });

  testWidgets('la miniatura custom usa un archivo local', (tester) async {
    final file = File(
      '${Directory.systemTemp.path}/hevywork_t004_thumb_test.png',
    );
    final exercise = await tester.runAsync(() async {
      await file.writeAsBytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
        ),
      );
      return insertCustom(imagePath: file.path);
    });
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ExerciseThumb(exercise: exercise!)),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final resized = image.image as ResizeImage;
    expect(resized.imageProvider, isA<FileImage>());
    expect((resized.imageProvider as FileImage).file.path, file.path);
  });

  testWidgets('la ficha custom usa el archivo local sin atribución', (
    tester,
  ) async {
    final file = File(
      '${Directory.systemTemp.path}/hevywork_t004_info_test.png',
    );
    final exercise = await tester.runAsync(() async {
      await file.writeAsBytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
        ),
      );
      return insertCustom(imagePath: file.path);
    });
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ExerciseInfoView(
          exercise: exercise!,
          database: db,
          workoutRepository: WorkoutRepository(db),
        ),
      ),
    );
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<FileImage>());
    expect((image.image as FileImage).file.path, file.path);
    expect(find.byKey(const Key('custom-edit')), findsOneWidget);
    expect(find.textContaining('©'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('la miniatura custom configura fallback para archivo ausente', (
    tester,
  ) async {
    final missingPath =
        '/tmp/opencode/hevywork-t004/missing-'
        '${DateTime.now().microsecondsSinceEpoch}.png';
    final exercise = await insertCustom(imagePath: missingPath);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ExerciseThumb(exercise: exercise)),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(File(missingPath).existsSync(), isFalse);
    expect(image.image, isA<ResizeImage>());
    final fallback = image.errorBuilder!(
      tester.element(find.byType(ExerciseThumb)),
      StateError('Archivo ausente'),
      StackTrace.empty,
    );
    expect(fallback, isA<ThumbFallback>());
    expect(tester.takeException(), isNull);
  });
}
