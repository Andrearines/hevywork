import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/catalog_repository.dart';
import 'package:hevywork/domain/exercise_filter.dart';
import 'package:hevywork/domain/media.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CatalogRepository repo;
  late List<dynamic> dataset;

  setUpAll(() async {
    final raw = await rootBundle.loadString(CatalogRepository.assetPath);
    dataset = jsonDecode(raw) as List<dynamic>;
  });

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = CatalogRepository(db);
  });

  tearDown(() => db.close());

  test('RF-1: carga los 1.324 ejercicios del asset en la tabla local', () async {
    await repo.initializeCatalogIfEmpty();

    final exercises = await db.select(db.exercises).get();
    expect(exercises.length, 1324);

    int distinct(String Function(Exercise) column) =>
        exercises.map(column).toSet().length;

    expect(distinct((t) => t.bodyPart), 10);
    expect(distinct((t) => t.equipment), 28);
    expect(distinct((t) => t.target), 19);
    expect(distinct((t) => t.muscleGroup), 29);
  });

  test('constitución §9: cada fila local coincide con el dataset de origen',
      () async {
    await repo.initializeCatalogIfEmpty();

    for (final item in dataset.cast<Map<String, dynamic>>()) {
      final row = await (db.select(db.exercises)
            ..where((t) => t.id.equals(item['id'] as String)))
          .getSingle();

      expect(row.name, item['name'], reason: 'id ${item['id']}');
      expect(row.bodyPart, item['body_part'], reason: 'id ${item['id']}');
      expect(row.equipment, item['equipment'], reason: 'id ${item['id']}');
      expect(row.target, item['target'], reason: 'id ${item['id']}');
      expect(row.muscleGroup, item['muscle_group'], reason: 'id ${item['id']}');
      expect(
        jsonDecode(row.secondaryMuscles!),
        item['secondary_muscles'],
        reason: 'id ${item['id']}',
      );
      expect(row.imagePath, item['image'], reason: 'id ${item['id']}');
      expect(row.gifPath, item['gif_url'], reason: 'id ${item['id']}');
      expect(row.mediaId, item['media_id'], reason: 'id ${item['id']}');
      expect(row.attribution, item['attribution'], reason: 'id ${item['id']}');
      expect(row.createdAt, isNotNull, reason: 'id ${item['id']}');
    }
  });

  test('los pasos de instrucción se guardan en es y en', () async {
    await repo.initializeCatalogIfEmpty();

    final rows = await db.select(db.exerciseInstructions).get();
    expect(rows, isNotEmpty);
    expect(rows.map((r) => r.language).toSet(), {'es', 'en'});
    expect(
      rows.map((r) => r.exerciseId).toSet().length,
      1324,
      reason: 'todo ejercicio debe tener pasos en ambos idiomas',
    );

    final first = rows.where((r) => r.exerciseId == '0001').toList();
    for (final language in ['es', 'en']) {
      final steps = first.where((r) => r.language == language).toList()
        ..sort((a, b) => a.stepNumber.compareTo(b.stepNumber));
      expect(steps, isNotEmpty, reason: 'pasos en $language');
      expect(steps.first.stepNumber, 1);
      expect(
        steps.map((s) => s.stepNumber).toList(),
        List.generate(steps.length, (i) => i + 1),
        reason: 'numeración continua en $language',
      );
    }
  });

  test('las miniaturas de todos los ejercicios están empaquetadas',
      () async {
    await repo.initializeCatalogIfEmpty();
    final exercises = await db.select(db.exercises).get();

    expect(exercises.length, 1324);
    for (final row in exercises) {
      final asset = row.imagePath;
      expect(asset, isNotNull, reason: 'id ${row.id}');
      expect(
        File(thumbAsset(asset!)).existsSync(),
        isTrue,
        reason: 'falta la miniatura $asset',
      );
    }
  });

  test('RF-1/RF-4: recargar no duplica, no borra y respeta lo existente',
      () async {
    Future<int> exerciseCount() async =>
        (await db.select(db.exercises).get()).length;
    Future<int> instructionCount() async =>
        (await db.select(db.exerciseInstructions).get()).length;

    await repo.initializeCatalogIfEmpty();
    final exercisesBefore = await exerciseCount();
    final instructionsBefore = await instructionCount();

    await repo.initializeCatalogIfEmpty();
    await repo.initializeCatalogIfEmpty();

    expect(await exerciseCount(), exercisesBefore);
    expect(await instructionCount(), instructionsBefore);

    await db.into(db.exercises).insert(
          ExercisesCompanion.insert(
            id: 'sentinel',
            name: 'Ejercicio local',
            bodyPart: 'chest',
            equipment: 'barbell',
            target: 'pectorals',
            muscleGroup: 'chest',
          ),
        );

    await repo.initializeCatalogIfEmpty();

    expect(await exerciseCount(), exercisesBefore + 1);
    final sentinel = await (db.select(db.exercises)
          ..where((t) => t.id.equals('sentinel')))
        .getSingleOrNull();
    expect(sentinel, isNotNull, reason: 'RF-4: el loader nunca borra filas');
  });

  group('rest_seconds (RF-5 de la 002)', () {
    test('ajusta el descanso por defecto dentro del rango', () async {
      await repo.initializeCatalogIfEmpty();

      await repo.updateRestSeconds('0001', 120);

      final exercise = await (db.select(db.exercises)
            ..where((t) => t.id.equals('0001')))
          .getSingle();
      expect(exercise.restSeconds, 120);
    });

    test('rechaza fuera del rango 15-300 y deja el valor intacto', () async {
      await repo.initializeCatalogIfEmpty();

      await expectLater(
        repo.updateRestSeconds('0001', 14),
        throwsArgumentError,
      );
      await expectLater(
        repo.updateRestSeconds('0001', 301),
        throwsArgumentError,
      );

      final exercise = await (db.select(db.exercises)
            ..where((t) => t.id.equals('0001')))
          .getSingle();
      expect(exercise.restSeconds, 90);
    });
  });

  group('Spec 003: buscador y filtros', () {
    test('RF-1: el nombre contiene el texto sin distinguir mayúsculas',
        () async {
      await repo.initializeCatalogIfEmpty();

      final page = await repo.searchPage(query: 'PReSS');

      expect(page.total, 164);
      expect(page.exercises, isNotEmpty);
      for (final ex in page.exercises) {
        expect(ex.name.toLowerCase(), contains('press'));
      }
    });

    test('RF-1: los acentos de la consulta se ignoran', () async {
      await repo.initializeCatalogIfEmpty();

      final page = await repo.searchPage(query: 'barbéll');

      expect(page.total, 159);
      for (final ex in page.exercises) {
        expect(ex.name.toLowerCase(), contains('barbell'));
      }
    });

    test('RF-1: sin texto devuelve el catálogo completo', () async {
      await repo.initializeCatalogIfEmpty();

      final page = await repo.searchPage();

      expect(page.exercises.length, 50);
      expect(page.total, 1324);
    });

    test('RF-3: equipos y body_part se combinan con AND', () async {
      await repo.initializeCatalogIfEmpty();

      final page = await repo.searchPage(
        filter: const ExerciseFilter(
          equipment: {'barbell'},
          bodyParts: {'chest'},
        ),
        pageSize: 100,
      );

      expect(page.total, 13);
      for (final ex in page.exercises) {
        expect(ex.equipment, 'barbell');
        expect(ex.bodyPart, 'chest');
      }
    });

    test('RF-3: varios valores de la misma dimensión suman (OR)', () async {
      await repo.initializeCatalogIfEmpty();

      final page = await repo.searchPage(
        filter: const ExerciseFilter(equipment: {'barbell', 'kettlebell'}),
        pageSize: 1000,
      );

      expect(page.total, 195);
      expect(
        page.exercises.map((e) => e.equipment).toSet(),
        {'barbell', 'kettlebell'},
      );
    });

    test('RF-3: la búsqueda y los filtros se combinan con AND', () async {
      await repo.initializeCatalogIfEmpty();

      final page = await repo.searchPage(
        query: 'curl',
        filter: const ExerciseFilter(equipment: {'barbell'}),
        pageSize: 100,
      );

      expect(page.total, 23);
      for (final ex in page.exercises) {
        expect(ex.name.toLowerCase(), contains('curl'));
        expect(ex.equipment, 'barbell');
      }
    });

    test('RF-3: los secundarios se filtran dentro del JSON de la fila',
        () async {
      await repo.initializeCatalogIfEmpty();

      final page = await repo.searchPage(
        filter: const ExerciseFilter(secondaryMuscles: {'biceps'}),
        pageSize: 1000,
      );

      expect(page.total, 194);
      for (final ex in page.exercises) {
        expect(jsonDecode(ex.secondaryMuscles!), contains('biceps'));
      }
    });

    test('RF-1: los comodines de LIKE se tratan como texto literal', () async {
      await repo.initializeCatalogIfEmpty();

      expect((await repo.searchPage(query: 'curl')).total, 185);
      final page = await repo.searchPage(query: 'curl%');
      expect(page.total, 0);
    });

    test('RF-5: paginación de 50 con total estable y orden por nombre',
        () async {
      await repo.initializeCatalogIfEmpty();

      final first = await repo.searchPage(pageSize: 50);
      final second = await repo.searchPage(offset: 50, pageSize: 50);

      expect(first.exercises.length, 50);
      expect(second.exercises.length, 50);
      expect(first.total, 1324);
      expect(second.total, 1324);

      final all = (await repo.searchPage(pageSize: 1000)).exercises;
      expect(
        [...first.exercises, ...second.exercises].map((e) => e.id),
        all.take(100).map((e) => e.id).toList(),
        reason: 'páginas consecutivas sin solaparse y ordenadas por nombre',
      );

      final last = await repo.searchPage(offset: 1300, pageSize: 50);
      expect(last.exercises.length, 24);
      expect(last.total, 1324);
    });

    test('RF-4: el contador coincide con un barrido completo', () async {
      await repo.initializeCatalogIfEmpty();

      const filter = ExerciseFilter(bodyParts: {'chest'});
      final page = await repo.searchPage(filter: filter, pageSize: 50);
      final all = await repo.searchPage(filter: filter, pageSize: 2000);

      expect(page.total, all.exercises.length);
      expect(all.exercises.length, greaterThan(50));
    });

    test('filtro con 0 resultados devuelve página vacía', () async {
      await repo.initializeCatalogIfEmpty();

      final page = await repo.searchPage(
        query: 'zzzz',
        filter: const ExerciseFilter(equipment: {'bosu ball'}),
      );

      expect(page.total, 0);
      expect(page.exercises, isEmpty);
    });

    test('RF-3: las opciones salen de la base local (10/28/19/29/40)',
        () async {
      await repo.initializeCatalogIfEmpty();

      final options = await repo.filterOptions();

      expect(options.bodyParts.length, 10);
      expect(options.equipments.length, 28);
      expect(options.targets.length, 19);
      expect(options.muscleGroups.length, 29);
      expect(options.secondaryMuscles.length, 40);
      expect(options.bodyParts.first, 'back');
      expect(options.bodyParts.last, 'waist');
      expect(options.secondaryMuscles.first, 'abdominals');
    });
  });
}
