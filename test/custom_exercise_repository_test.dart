import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show OrderingTerm, Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/catalog_repository.dart';
import 'package:hevywork/data/repositories/custom_exercise_repository.dart';
import 'package:hevywork/data/repositories/routine_repository.dart';
import 'package:hevywork/data/repositories/workout_repository.dart';
import 'package:hevywork/domain/custom_exercise.dart';
import 'package:hevywork/domain/custom_exercise_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory documents;
  late CustomExerciseRepository repository;
  late CatalogRepository catalog;
  late String localUserId;
  final jpeg = Uint8List.fromList(const [
    0xff,
    0xd8,
    0xff,
    0xe0,
    0x01,
    0x02,
    0xff,
    0xd9,
  ]);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    documents = Directory(
      '/tmp/opencode/hevywork-t004/repository-'
      '${DateTime.now().microsecondsSinceEpoch}',
    );
    await documents.create(recursive: true);
    catalog = CatalogRepository(db);
    repository = CustomExerciseRepository(
      db,
      documentsDir: () async => documents,
      onChanged: catalog.invalidateFilterOptions,
    );
    localUserId = (await db.select(db.localProfiles).getSingle()).localUserId;
  });

  tearDown(() async {
    await db.close();
    if (await documents.exists()) await documents.delete(recursive: true);
  });

  CustomExerciseDraft draft({int restSeconds = 90}) => CustomExerciseDraft(
    name: '  Press propio  ',
    bodyPart: ' chest ',
    equipment: ' barbell ',
    target: 'pectorals',
    secondaryMuscles: const ['triceps'],
    restSeconds: restSeconds,
  );

  Future<Exercise> insertForeign() {
    return db
        .into(db.exercises)
        .insertReturning(
          ExercisesCompanion.insert(
            id: 'custom_foreign',
            name: 'Press ajeno',
            bodyPart: 'chest',
            equipment: 'barbell',
            target: 'pectorals',
            muscleGroup: 'triceps',
            secondaryMuscles: const Value('["triceps"]'),
            origin: const Value('custom'),
            localUserId: const Value('otro-perfil'),
            imageUploadStatus: const Value('none'),
            updatedAt: Value(DateTime(2026, 11, 26)),
          ),
        );
  }

  test(
    'crea offline con propietario, id, músculos y descanso propios',
    () async {
      final created = await repository.createCustomExercise(draft: draft());

      expect(created.id, matches(r'^custom_[0-9a-f-]{36}$'));
      expect(created.localUserId, localUserId);
      expect(created.origin, 'custom');
      expect(created.name, 'Press propio');
      expect(created.bodyPart, 'chest');
      expect(created.equipment, 'barbell');
      expect(created.muscleGroup, 'triceps');
      expect(jsonDecode(created.secondaryMuscles!), ['triceps']);
      expect(created.restSeconds, 90);
      expect(created.createdAt, isNotNull);
      expect(created.updatedAt, isNotNull);
      expect(created.imagePath, isNull);
      expect(created.imageStoragePath, isNull);
      expect(created.imageMimeType, isNull);
      expect(created.imageUploadStatus, 'none');
      expect(created.gifPath, isNull);
      expect(created.attribution, isNull);
      expect(await db.select(db.syncQueue).get(), isEmpty);
      expect(await db.select(db.exercisePreferences).get(), isEmpty);
      expect(await catalog.effectiveRestSeconds(created.id), 90);
    },
  );

  test('persiste clave prevista, MIME y estado de subida local', () async {
    final created = await repository.createCustomExercise(
      draft: draft(),
      imageBytes: jpeg,
    );

    final row = await db
        .customSelect(
          'SELECT image_storage_path, image_mime_type, image_upload_status '
          'FROM exercises WHERE id = ?',
          variables: [Variable(created.id)],
        )
        .getSingle();
    expect(
      row.read<String>('image_storage_path'),
      '$localUserId/${created.id}',
    );
    expect(row.read<String>('image_mime_type'), 'image/jpeg');
    expect(row.read<String>('image_upload_status'), 'pending_upload');
  });

  test(
    'integra solo los custom propios en búsqueda, filtros y páginas',
    () async {
      final own = await repository.createCustomExercise(draft: draft());
      await insertForeign();

      final page = await catalog.searchPage(query: 'press');
      expect(page.total, 1);
      expect(page.exercises.single.id, own.id);
      expect(await catalog.exerciseById('custom_foreign'), isNull);
      expect(await catalog.exercisesByIds(['custom_foreign']), isEmpty);
      expect(await catalog.exerciseNames(), {own.id: 'Press propio'});
      final options = await catalog.filterOptions();
      expect(options.targets, ['pectorals']);
      expect(options.equipments, ['barbell']);
      expect(options.secondaryMuscles, ['triceps']);

      for (var i = 0; i < 55; i++) {
        await repository.createCustomExercise(
          draft: draft().copyWith(
            name: 'Orden ${i.toString().padLeft(2, '0')}',
          ),
        );
      }
      final first = await catalog.searchPage();
      final second = await catalog.searchPage(offset: 50);
      expect(first.exercises, hasLength(50));
      expect(second.exercises, hasLength(6));
      expect(first.total, 56);
      expect(second.total, 56);
      expect(
        first.exercises
            .map((row) => row.id)
            .toSet()
            .intersection(second.exercises.map((row) => row.id).toSet()),
        isEmpty,
      );
    },
  );

  test('el alta y la edición invalidan las opciones de filtros', () async {
    expect((await catalog.filterOptions()).equipments, isEmpty);

    final created = await repository.createCustomExercise(draft: draft());
    expect((await catalog.filterOptions()).equipments, ['barbell']);

    await repository.updateCustomExercise(
      id: created.id,
      draft: draft().copyWith(equipment: 'dumbbell'),
    );
    final options = await catalog.filterOptions();
    expect(options.equipments, ['dumbbell']);
    expect(options.equipments, isNot(contains('barbell')));
  });

  test('el caché de filtros no mezcla perfiles', () async {
    final own = await repository.createCustomExercise(draft: draft());
    await insertForeign();
    await (db.update(
      db.exercises,
    )..where((row) => row.id.equals('custom_foreign'))).write(
      const ExercisesCompanion(
        name: Value('Remo ajeno'),
        bodyPart: Value('back'),
        equipment: Value('dumbbell'),
        target: Value('lats'),
        muscleGroup: Value('biceps'),
        secondaryMuscles: Value('["biceps"]'),
      ),
    );

    final ownOptions = await catalog.filterOptions();
    expect(ownOptions.equipments, ['barbell']);
    expect(ownOptions.targets, ['pectorals']);
    expect(ownOptions.secondaryMuscles, ['triceps']);

    await (db.update(db.localProfiles)..where((row) => row.id.equals(1))).write(
      const LocalProfilesCompanion(localUserId: Value('otro-perfil')),
    );

    final foreignOptions = await catalog.filterOptions();
    expect(foreignOptions.bodyParts, ['back']);
    expect(foreignOptions.equipments, ['dumbbell']);
    expect(foreignOptions.targets, ['lats']);
    expect(foreignOptions.muscleGroups, ['biceps']);
    expect(foreignOptions.secondaryMuscles, ['biceps']);
    expect(await catalog.exerciseNames(), {'custom_foreign': 'Remo ajeno'});

    await (db.update(db.localProfiles)..where((row) => row.id.equals(1))).write(
      LocalProfilesCompanion(localUserId: Value(localUserId)),
    );
    expect((await catalog.filterOptions()).equipments, ['barbell']);
    expect((await catalog.exerciseById(own.id))!.name, 'Press propio');
  });

  test('el descanso custom se edita en exercises sin preferencia', () async {
    final created = await repository.createCustomExercise(
      draft: draft(restSeconds: 135),
    );

    await catalog.updateRestSeconds(created.id, 150);

    expect(await catalog.effectiveRestSeconds(created.id), 150);
    expect((await catalog.exerciseById(created.id))!.restSeconds, 150);
    expect((await catalog.searchPage()).exercises.single.restSeconds, 150);
    expect(await db.select(db.exercisePreferences).get(), isEmpty);
    expect(await db.select(db.syncQueue).get(), isEmpty);

    final values = expectLater(
      catalog.watchEffectiveRestSeconds(created.id),
      emitsInOrder([150, 165]),
    );
    await Future<void>.delayed(Duration.zero);
    await catalog.updateRestSeconds(created.id, 165);
    await values;
  });

  test('live inicia y ajusta opción C con la fila custom', () async {
    final created = await repository.createCustomExercise(
      draft: draft(restSeconds: 135),
    );
    final workouts = WorkoutRepository(db);
    final workout = await workouts.startWorkout();
    final item = await workouts.addExercise(
      workoutId: workout.id,
      exerciseId: created.id,
    );
    final now = DateTime(2026, 11, 25, 12);

    final timer = await workouts.startRestTimer(
      workoutExerciseId: item.id,
      now: now,
    );
    expect(timer.endsAt, now.add(const Duration(seconds: 135)));

    final adjustment = await workouts.adjustRestTimer(
      workoutExerciseId: item.id,
      requestedDeltaSeconds: 15,
      now: now,
    );
    expect(adjustment.defaultSeconds, 150);
    expect(await catalog.effectiveRestSeconds(created.id), 150);
    expect(await db.select(db.exercisePreferences).get(), isEmpty);
    final projected = await workouts.watchExercises(workout.id).first;
    expect(projected.single.exercise.restSeconds, 150);

    final planned = await workouts.startRestTimer(
      workoutExerciseId: item.id,
      plannedRestSeconds: 60,
      now: now,
    );
    expect(planned.endsAt, now.add(const Duration(seconds: 60)));
    expect(await catalog.effectiveRestSeconds(created.id), 150);
  });

  test('live no lee ni escribe el descanso de un custom ajeno', () async {
    await insertForeign();
    final workouts = WorkoutRepository(db);
    final workout = await workouts.startWorkout();
    final item = await workouts.addExercise(
      workoutId: workout.id,
      exerciseId: 'custom_foreign',
    );
    final now = DateTime(2026, 11, 26, 12);

    await expectLater(
      workouts.startRestTimer(workoutExerciseId: item.id, now: now),
      throwsA(isA<StateError>()),
    );
    await workouts.startRestTimer(
      workoutExerciseId: item.id,
      plannedRestSeconds: 60,
      now: now,
    );
    await expectLater(
      workouts.adjustRestTimer(
        workoutExerciseId: item.id,
        requestedDeltaSeconds: 15,
        now: now,
      ),
      throwsA(isA<StateError>()),
    );

    expect((await db.select(db.exercises).getSingle()).restSeconds, 90);
    expect(await db.select(db.exercisePreferences).get(), isEmpty);
    expect(await workouts.watchExercises(workout.id).first, isEmpty);
  });

  test(
    'rutina, workout e historial conservan referencias y cargas al editar',
    () async {
      final created = await repository.createCustomExercise(
        draft: draft(restSeconds: 135),
        imageBytes: jpeg,
      );
      final mutations = <String>[];
      Future<void> enqueue(
        String operation,
        String table,
        String payload,
      ) async {
        mutations.add(payload);
      }

      final workouts = WorkoutRepository(db, enqueue: enqueue);
      final routines = RoutineRepository(db, workouts, enqueue: enqueue);
      final routine = await routines.createRoutine(
        name: 'Rutina propia',
        exercises: [
          RoutineExerciseDraft(
            exerciseId: created.id,
            sets: const [
              RoutineSetDraft(reps: 8, rir: 2, weightKg: 42.5, restSeconds: 75),
              RoutineSetDraft(reps: 6, rir: 1, weightKg: 45),
            ],
          ),
        ],
      );
      final routineItem = await db.select(db.routineExercises).getSingle();
      final originalRoutineSets = await routines.routineSets(routineItem.id);
      final started = await routines.startWorkoutFromRoutine(routine.id);
      expect(started.skippedExercises, 0);

      final workoutItem = await db.select(db.workoutExercises).getSingle();
      final originalWorkoutSets = await (db.select(
        db.workoutSets,
      )..orderBy([(row) => OrderingTerm.asc(row.orderIndex)])).get();
      expect(originalWorkoutSets.map((row) => row.weightKg), [42.5, 45]);
      for (final set in originalWorkoutSets) {
        await workouts.setSetCompleted(set.id, true);
      }
      expect(await workouts.finishWorkout(started.workout.id), isTrue);

      final edited = await repository.updateCustomExercise(
        id: created.id,
        draft: draft(restSeconds: 150)
            .copyWith(name: 'Press propio editado', equipment: 'dumbbell'),
      );

      final routineReference = (await routines.routineExercises(routine.id))
          .single;
      expect(routineReference.item.id, routineItem.id);
      expect(routineReference.exercise!.name, edited.name);
      final routineSets = await routines.routineSets(routineItem.id);
      expect(
        routineSets.map((row) => row.id),
        originalRoutineSets.map((row) => row.id),
      );
      expect(routineSets.map((row) => row.weightKg), [42.5, 45]);
      expect(routineSets.first.restSeconds, 75);
      expect(
        (await routines.watchRoutineCatalog().first).single.exercise.name,
        edited.name,
      );

      final liveReference =
          (await workouts.watchExercises(started.workout.id).first).single;
      expect(liveReference.item.id, workoutItem.id);
      expect(liveReference.exercise.name, edited.name);
      expect(liveReference.exercise.restSeconds, 150);
      final workoutSets = await (db.select(
        db.workoutSets,
      )..orderBy([(row) => OrderingTerm.asc(row.orderIndex)])).get();
      expect(
        workoutSets.map((row) => row.id),
        originalWorkoutSets.map((row) => row.id),
      );
      expect(workoutSets.map((row) => row.weightKg), [42.5, 45]);

      final history = await workouts.exerciseHistory(
        exerciseId: created.id,
        limit: 10,
      );
      expect(history, hasLength(1));
      expect(history.single.sets.map((row) => row.weightKg), [42.5, 45]);
      final summaries = await workouts.watchFinishedWorkouts().first;
      expect(summaries.single.highlights.single.name, edited.name);
      expect(summaries.single.volumeKg, 610);
      expect((await catalog.exerciseById(created.id))!.name, edited.name);
      expect(await db.select(db.syncQueue).get(), isEmpty);
      for (final payload in mutations) {
        expect(payload, isNot(contains(created.imagePath!)));
        expect(payload, isNot(contains('image_path')));
        expect(payload, isNot(contains('image_storage_path')));
      }
    },
  );

  test('guarda, conserva, reemplaza y quita la imagen local', () async {
    final created = await repository.createCustomExercise(
      draft: draft(),
      imageBytes: jpeg,
    );
    final originalPath = created.imagePath!;
    expect(File(originalPath).readAsBytesSync(), jpeg);
    expect(originalPath, contains(documents.path));

    final unchanged = await repository.updateCustomExercise(
      id: created.id,
      draft: draft().copyWith(name: 'Sin cambio de imagen'),
    );
    expect(unchanged.imagePath, originalPath);
    expect(File(originalPath).existsSync(), isTrue);

    final replaced = await repository.updateCustomExercise(
      id: created.id,
      draft: draft(),
      imageBytes: jpeg,
    );
    expect(replaced.imagePath, isNot(originalPath));
    expect(File(replaced.imagePath!).existsSync(), isTrue);
    expect(File(originalPath).existsSync(), isFalse);

    final removed = await repository.updateCustomExercise(
      id: created.id,
      draft: draft(),
      removeImage: true,
    );
    expect(removed.imagePath, isNull);
    expect(File(replaced.imagePath!).existsSync(), isFalse);
  });

  test(
    'imagen inválida conserva datos, borrador persistente e imagen anterior',
    () async {
      final created = await repository.createCustomExercise(
        draft: draft(),
        imageBytes: jpeg,
      );
      final oldPath = created.imagePath!;

      await expectLater(
        repository.updateCustomExercise(
          id: created.id,
          draft: draft().copyWith(name: 'No debe guardarse'),
          imageBytes: Uint8List.fromList('GIF89a'.codeUnits),
        ),
        throwsA(isA<CustomImageValidationException>()),
      );

      final current = await catalog.exerciseById(created.id);
      expect(current!.name, 'Press propio');
      expect(current.imagePath, oldPath);
      expect(File(oldPath).existsSync(), isTrue);
    },
  );

  test(
    'un fallo de escritura en reemplazo compensa el archivo nuevo',
    () async {
      final created = await repository.createCustomExercise(
        draft: draft(),
        imageBytes: jpeg,
      );
      final oldPath = created.imagePath!;
      await db.customStatement(
        'CREATE TRIGGER fail_custom_update BEFORE UPDATE ON exercises '
        "WHEN OLD.id = '${created.id}' BEGIN "
        "SELECT RAISE(ABORT, 'forced update failure'); END",
      );
      final before = File(oldPath).parent.listSync().whereType<File>().length;

      await expectLater(
        repository.updateCustomExercise(
          id: created.id,
          draft: draft(),
          imageBytes: jpeg,
        ),
        throwsA(isA<Exception>()),
      );

      final current = await catalog.exerciseById(created.id);
      expect(current!.imagePath, oldPath);
      expect(File(oldPath).existsSync(), isTrue);
      final directory = File(oldPath).parent;
      expect(directory.listSync().whereType<File>(), hasLength(before));
    },
  );

  test('un custom ajeno no se puede editar ni cambiar de descanso', () async {
    await insertForeign();

    await expectLater(
      repository.updateCustomExercise(id: 'custom_foreign', draft: draft()),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      catalog.updateRestSeconds('custom_foreign', 120),
      throwsA(isA<StateError>()),
    );
    expect((await db.select(db.exercises).getSingle()).restSeconds, 90);
  });
}
