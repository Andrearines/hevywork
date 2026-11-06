import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/workout_repository.dart';
import 'package:hevywork/data/sync/sync_payload.dart';

void main() {
  late AppDatabase db;
  late WorkoutRepository repo;
  late List<({String operation, String table, String payload})> enqueued;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    enqueued = [];
    repo = WorkoutRepository(db, enqueue: (operation, table, payload) async {
      enqueued.add((operation: operation, table: table, payload: payload));
    });
    await db.into(db.exercises).insert(
          ExercisesCompanion.insert(
            id: 'bench-press',
            name: 'Press de banca',
            bodyPart: 'chest',
            equipment: 'barbell',
            target: 'pectorals',
            muscleGroup: 'chest',
          ),
        );
  });

  tearDown(() => db.close());

  Map<String, dynamic> payloadOf(int index) =>
      jsonDecode(enqueued[index].payload) as Map<String, dynamic>;

  Future<Workout> startWithExercise() async {
    final workout = await repo.startWorkout();
    await repo.addExercise(workoutId: workout.id, exerciseId: 'bench-press');
    return workout;
  }

  group('RF-5: nueva sesión', () {
    test('crea un workout activo con el local_user_id del perfil', () async {
      final workout = await repo.startWorkout();

      expect(workout.status, 'active');
      expect(workout.endedAt, isNull);
      expect(
        workout.startedAt.isAfter(DateTime.now().add(const Duration(minutes: 1))),
        isFalse,
      );

      final profile = await db.select(db.localProfiles).getSingle();
      expect(workout.localUserId, profile.localUserId);

      final stored = await (db.select(db.workouts)
            ..where((t) => t.id.equals(workout.id)))
          .getSingle();
      expect(stored.status, 'active');

      expect(enqueued, hasLength(1));
      expect(enqueued.single.operation, 'upsert');
      expect(enqueued.single.table, 'workouts');

      final payload = payloadOf(0);
      expect(payload['id'], workout.id);
      expect(payload['status'], 'active');
      expect(payload['started_at'], workout.startedAt.toIso8601String());
      expect(payload['client_updated_at'], workout.updatedAt.toIso8601String());
    });

    test('el payload encolado es válido para el mapeo RF-13', () async {
      final workout = await repo.startWorkout();

      final row = buildRemoteRow(
        table: 'workouts',
        payloadJson: enqueued.single.payload,
        userId: 'user-1',
      );

      expect(row['id'], workout.id);
      expect(row['user_id'], 'user-1');
      expect(row['status'], 'active');
      expect(row['client_updated_at'], workout.updatedAt.toIso8601String());
    });
  });

  group('RF-19: una sola sesión activa', () {
    test('al iniciar otra, la anterior queda abandonada', () async {
      final first = await repo.startWorkout();
      final second = await repo.startWorkout();

      final stored = await (db.select(db.workouts)
            ..where((t) => t.id.equals(first.id)))
          .getSingle();
      expect(stored.status, 'abandoned');
      expect(stored.endedAt, isNotNull);
      expect(second.status, 'active');

      expect(enqueued, hasLength(3));
      expect(payloadOf(1)['status'], 'abandoned');
      expect(payloadOf(2)['status'], 'active');
    });
  });

  group('RF-6: ejercicios de la sesión', () {
    test('asigna order_index correlativo y lo encola', () async {
      final workout = await startWithExercise();

      final second = await repo.addExercise(
        workoutId: workout.id,
        exerciseId: 'bench-press',
      );

      final items = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(workout.id)))
          .get();
      expect(items.map((e) => e.orderIndex), [1, 2]);
      expect(second.orderIndex, 2);

      final payload = payloadOf(enqueued.length - 1);
      expect(payload['id'], second.id);
      expect(payload['workout_id'], workout.id);
      expect(payload['exercise_id'], 'bench-press');
      expect(payload['order_index'], 2);
      expect(payload.containsKey('target_sets'), isFalse);
    });
  });

  group('RF-7: registro de series', () {
    test('guarda la serie completada, redondea el peso y encola el mapa',
        () async {
      final workout = await startWithExercise();
      final item = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(workout.id)))
          .getSingle();

      final set = await repo.logSet(
        workoutExerciseId: item.id,
        weightKg: 80.0009,
        reps: 8,
        rir: 2,
        setType: 'failure',
      );

      expect(set.completed, isTrue);
      expect(set.setType, 'failure');
      expect(set.weightKg, closeTo(80.001, 1e-9));
      expect(set.orderIndex, 1);

      final payload = payloadOf(enqueued.length - 1);
      expect(payload['set_type'], 'failure');
      expect(payload['reps'], 8);
      expect(payload['weight_kg'], 80.001);
      expect(payload['rir'], 2);
      expect(payload['completed'], isTrue);

      final row = buildRemoteRow(
        table: 'workout_sets',
        payloadJson: enqueued.last.payload,
        userId: 'user-1',
      );
      expect(row['user_id'], 'user-1');
      expect(row['workout_exercise_id'], item.id);
      expect(row['rir'], 2);
      expect(row['weight_kg'], 80.001);
    });

    test('el order_index sigue al de las series existentes', () async {
      final workout = await startWithExercise();
      final item = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(workout.id)))
          .getSingle();

      await repo.logSet(
        workoutExerciseId: item.id,
        weightKg: 70,
        reps: 10,
        rir: 3,
      );
      final second = await repo.logSet(
        workoutExerciseId: item.id,
        weightKg: 75,
        reps: 8,
        rir: 2,
      );

      expect(second.orderIndex, 2);
    });

    test('rechaza tipo, repeticiones, peso y RIR fuera de la RF-7', () async {
      final workout = await startWithExercise();
      final item = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(workout.id)))
          .getSingle();

      await expectLater(
        repo.logSet(
          workoutExerciseId: item.id,
          weightKg: 70,
          reps: 10,
          rir: 2,
          setType: 'cardio',
        ),
        throwsA(isA<SetValidationException>()),
      );
      await expectLater(
        repo.logSet(
          workoutExerciseId: item.id,
          weightKg: 70,
          reps: 0,
          rir: 2,
        ),
        throwsA(isA<SetValidationException>()),
      );
      await expectLater(
        repo.logSet(
          workoutExerciseId: item.id,
          weightKg: -1,
          reps: 10,
          rir: 2,
        ),
        throwsA(isA<SetValidationException>()),
      );
      await expectLater(
        repo.logSet(
          workoutExerciseId: item.id,
          weightKg: 70,
          reps: 10,
          rir: 11,
        ),
        throwsA(isA<SetValidationException>()),
      );

      expect(await db.select(db.workoutSets).get(), isEmpty);
      expect(enqueued, hasLength(2));
    });
  });

  group('RF-1: deshacer la última serie', () {
    test('pasa la última completada a false sin borrarla y lo re-encola',
        () async {
      final workout = await startWithExercise();
      final item = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(workout.id)))
          .getSingle();
      final first = await repo.logSet(
        workoutExerciseId: item.id,
        weightKg: 70,
        reps: 10,
        rir: 3,
      );
      final second = await repo.logSet(
        workoutExerciseId: item.id,
        weightKg: 75,
        reps: 8,
        rir: 2,
      );

      final undone = await repo.undoLastSet(workout.id);

      expect(undone, isNotNull);
      expect(undone!.id, second.id);
      expect(undone.completed, isFalse);
      expect(
        undone.updatedAt.isBefore(second.updatedAt),
        isFalse,
      );

      final sets = await (db.select(db.workoutSets)
            ..where((t) => t.workoutExerciseId.equals(item.id)))
          .get();
      expect(sets, hasLength(2));
      expect(
        sets.where((set) => set.completed).map((set) => set.id),
        [first.id],
      );

      expect(enqueued.last.operation, 'upsert');
      expect(enqueued.last.table, 'workout_sets');
      final payload = payloadOf(enqueued.length - 1);
      expect(payload['id'], second.id);
      expect(payload['completed'], isFalse);
    });

    test('en cascada deshace varias series seguidas', () async {
      final workout = await startWithExercise();
      final item = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(workout.id)))
          .getSingle();
      for (var i = 0; i < 3; i++) {
        await repo.logSet(
          workoutExerciseId: item.id,
          weightKg: 70,
          reps: 10,
          rir: 3,
        );
      }

      final firstUndo = await repo.undoLastSet(workout.id);
      final secondUndo = await repo.undoLastSet(workout.id);
      final thirdUndo = await repo.undoLastSet(workout.id);
      final fourthUndo = await repo.undoLastSet(workout.id);

      expect(firstUndo!.orderIndex, 3);
      expect(secondUndo!.orderIndex, 2);
      expect(thirdUndo!.orderIndex, 1);
      expect(thirdUndo.completed, isFalse);
      expect(fourthUndo, isNull);
    });

    test('sin series completadas no cambia nada', () async {
      final workout = await startWithExercise();

      expect(await repo.undoLastSet(workout.id), isNull);

      expect(await db.select(db.workoutSets).get(), isEmpty);
      expect(enqueued, hasLength(2));
    });
  });

  group('RF-3/RF-4: edición de series', () {
    test('actualiza los valores, redondea y re-encola con updated_at',
        () async {
      final workout = await startWithExercise();
      final item = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(workout.id)))
          .getSingle();
      final set = await repo.logSet(
        workoutExerciseId: item.id,
        weightKg: 70,
        reps: 10,
        rir: 3,
      );

      final updated = await repo.updateSet(
        setId: set.id,
        weightKg: 72.5009,
        reps: 6,
        rir: 1,
        setType: 'failure',
      );

      expect(updated.reps, 6);
      expect(updated.weightKg, closeTo(72.501, 1e-9));
      expect(updated.setType, 'failure');
      expect(updated.rir, 1);
      expect(updated.completed, isTrue);
      expect(updated.updatedAt.isBefore(set.updatedAt), isFalse);

      final stored = await (db.select(db.workoutSets)
            ..where((t) => t.id.equals(set.id)))
          .getSingle();
      expect(stored.reps, 6);
      expect(stored.weightKg, closeTo(72.501, 1e-9));

      expect(enqueued.last.operation, 'upsert');
      expect(enqueued.last.table, 'workout_sets');
      final payload = payloadOf(enqueued.length - 1);
      expect(payload['id'], set.id);
      expect(payload['reps'], 6);
      expect(payload['weight_kg'], 72.501);
      expect(payload['rir'], 1);
      expect(payload['set_type'], 'failure');
      expect(payload['completed'], isTrue);
    });

    test('rechaza los mismos rangos que la RF-7', () async {
      final workout = await startWithExercise();
      final item = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(workout.id)))
          .getSingle();
      final set = await repo.logSet(
        workoutExerciseId: item.id,
        weightKg: 70,
        reps: 10,
        rir: 3,
      );

      await expectLater(
        repo.updateSet(setId: set.id, weightKg: 70, reps: 0, rir: 2),
        throwsA(isA<SetValidationException>()),
      );
      await expectLater(
        repo.updateSet(setId: set.id, weightKg: -1, reps: 10, rir: 2),
        throwsA(isA<SetValidationException>()),
      );
      await expectLater(
        repo.updateSet(setId: set.id, weightKg: 70, reps: 10, rir: 11),
        throwsA(isA<SetValidationException>()),
      );
      await expectLater(
        repo.updateSet(
          setId: set.id,
          weightKg: 70,
          reps: 10,
          rir: 2,
          setType: 'cardio',
        ),
        throwsA(isA<SetValidationException>()),
      );

      final stored = await (db.select(db.workoutSets)
            ..where((t) => t.id.equals(set.id)))
          .getSingle();
      expect(stored.reps, 10);
      expect(stored.setType, 'normal');
      expect(enqueued, hasLength(3));
    });

    test('editar una serie deshecha la vuelve a confirmar', () async {
      final workout = await startWithExercise();
      final item = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(workout.id)))
          .getSingle();
      final set = await repo.logSet(
        workoutExerciseId: item.id,
        weightKg: 70,
        reps: 10,
        rir: 3,
      );
      await repo.undoLastSet(workout.id);

      final updated = await repo.updateSet(
        setId: set.id,
        weightKg: 70,
        reps: 8,
        rir: 2,
      );

      expect(updated.completed, isTrue);
      expect(updated.reps, 8);
    });

    test('una sesión cerrada no admite deshacer ni edición', () async {
      final workout = await startWithExercise();
      final item = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(workout.id)))
          .getSingle();
      final set = await repo.logSet(
        workoutExerciseId: item.id,
        weightKg: 70,
        reps: 10,
        rir: 3,
      );
      await repo.finishWorkout(workout.id);

      await expectLater(
        repo.undoLastSet(workout.id),
        throwsA(isA<SessionNotEditableException>()),
      );
      await expectLater(
        repo.updateSet(setId: set.id, weightKg: 80, reps: 8, rir: 2),
        throwsA(isA<SessionNotEditableException>()),
      );

      final stored = await (db.select(db.workoutSets)
            ..where((t) => t.id.equals(set.id)))
          .getSingle();
      expect(stored.completed, isTrue);
      expect(stored.reps, 10);
    });
  });

  group('RF-10: cierre de la sesión', () {
    test('sin series completadas borra la sesión y lo encola como delete',
        () async {
      final workout = await startWithExercise();

      final saved = await repo.finishWorkout(workout.id);

      expect(saved, isFalse);
      expect(await db.select(db.workouts).get(), isEmpty);
      expect(await db.select(db.workoutExercises).get(), isEmpty);

      expect(enqueued.last.operation, 'delete');
      expect(enqueued.last.table, 'workouts');
      expect(payloadOf(enqueued.length - 1)['id'], workout.id);
    });

    test('una serie pendiente no cuenta como completada', () async {
      final workout = await startWithExercise();
      final item = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(workout.id)))
          .getSingle();
      await db.into(db.workoutSets).insert(
            WorkoutSetsCompanion.insert(
              id: 'pending-set',
              workoutExerciseId: item.id,
              orderIndex: 1,
              weightKg: const Value(80),
              reps: const Value(8),
              rir: const Value(2),
              completed: const Value(false),
            ),
          );

      final saved = await repo.finishWorkout(workout.id);

      expect(saved, isFalse);
      expect(await db.select(db.workouts).get(), isEmpty);
      expect(await db.select(db.workoutSets).get(), isEmpty);
    });

    test('con series completadas la sesión queda finished', () async {
      final workout = await startWithExercise();
      final item = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(workout.id)))
          .getSingle();
      await repo.logSet(
        workoutExerciseId: item.id,
        weightKg: 80,
        reps: 8,
        rir: 2,
      );

      final saved = await repo.finishWorkout(workout.id);

      expect(saved, isTrue);
      final stored = await (db.select(db.workouts)
            ..where((t) => t.id.equals(workout.id)))
          .getSingle();
      expect(stored.status, 'finished');
      expect(stored.endedAt, isNotNull);

      expect(enqueued.last.operation, 'upsert');
      expect(enqueued.last.table, 'workouts');
      expect(payloadOf(enqueued.length - 1)['status'], 'finished');
      expect(payloadOf(enqueued.length - 1)['ended_at'], isNotNull);
    });
  });

  group('RF-12: borrar sesión del historial', () {
    Future<Workout> finishedWorkout() async {
      final workout = await startWithExercise();
      final item = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(workout.id)))
          .getSingle();
      await repo.logSet(
        workoutExerciseId: item.id,
        weightKg: 80,
        reps: 8,
        rir: 2,
      );
      await repo.finishWorkout(workout.id);
      enqueued.clear();
      return workout;
    }

    test('borra la sesión con ejercicios y series y encola el delete',
        () async {
      final workout = await finishedWorkout();

      await repo.deleteWorkout(workout.id);

      expect(await db.select(db.workouts).get(), isEmpty);
      expect(await db.select(db.workoutExercises).get(), isEmpty);
      expect(await db.select(db.workoutSets).get(), isEmpty);
      expect(enqueued, hasLength(1));
      expect(enqueued.single.operation, 'delete');
      expect(enqueued.single.table, 'workouts');
      expect(payloadOf(0)['id'], workout.id);
    });

    test('la sesión activa no se borra', () async {
      final workout = await startWithExercise();
      enqueued.clear();

      await repo.deleteWorkout(workout.id);

      expect(await db.select(db.workouts).get(), hasLength(1));
      expect(enqueued, isEmpty);
    });

    test('un id inexistente no hace nada', () async {
      await repo.deleteWorkout('no-existe');

      expect(enqueued, isEmpty);
    });
  });

  group('RF-5: temporizador de descanso local', () {
    test('persiste el estado sin tocar updated_at ni encolar', () async {
      final workout = await startWithExercise();
      final initial = await (db.select(db.workouts)
            ..where((t) => t.id.equals(workout.id)))
          .getSingle();
      final endsAt = DateTime.now().add(const Duration(seconds: 90));

      await repo.saveRestTimer(workout.id, endsAt: endsAt);

      var stored = await (db.select(db.workouts)
            ..where((t) => t.id.equals(workout.id)))
          .getSingle();
      expect(stored.restPausedSeconds, isNull);
      expect(stored.restEndsAt, isNotNull);
      expect(
        stored.restEndsAt!.difference(endsAt).inSeconds.abs(),
        lessThanOrEqualTo(1),
      );
      expect(stored.updatedAt, initial.updatedAt);
      // El descanso es estado local: no se encola ninguna mutación.
      expect(enqueued, hasLength(2));

      await repo.saveRestTimer(
        workout.id,
        pausedRemaining: const Duration(seconds: 30),
      );

      stored = await (db.select(db.workouts)
            ..where((t) => t.id.equals(workout.id)))
          .getSingle();
      expect(stored.restEndsAt, isNull);
      expect(stored.restPausedSeconds, 30);
      expect(enqueued, hasLength(2));
    });
  });

  group('RF-9 a RF-11: reanudar la sesión tras cierre', () {
    Future<LocalProfile> profile() => (db.select(db.localProfiles)
          ..where((t) => t.id.equals(1)))
        .getSingle();

    test('startWorkout guarda el marcador y no encola nada extra (RF-9)',
        () async {
      final workout = await repo.startWorkout();

      expect((await profile()).lastActiveWorkoutId, workout.id);
      expect(enqueued, hasLength(1));
    });

    test('restoreLastActiveWorkout devuelve la sesión activa marcada (RF-10)',
        () async {
      final workout = await repo.startWorkout();

      final restored = await repo.restoreLastActiveWorkout();

      expect(restored!.id, workout.id);
      expect(restored.status, 'active');
      expect(restored.endedAt, isNull);
    });

    test('restore limpia un marcador huérfano y devuelve null', () async {
      await (db.update(db.localProfiles)..where((t) => t.id.equals(1)))
          .write(
        const LocalProfilesCompanion(lastActiveWorkoutId: Value('no-existe')),
      );
      expect(await repo.restoreLastActiveWorkout(), isNull);
      expect((await profile()).lastActiveWorkoutId, isNull);

      final workout = await startWithExercise();
      final item = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(workout.id)))
          .getSingle();
      // Sesión cerrada con series: queda `finished`, ya no reanudable.
      await repo.logSet(
        workoutExerciseId: item.id,
        weightKg: 80,
        reps: 8,
        rir: 2,
      );
      await repo.finishWorkout(workout.id);
      await (db.update(db.localProfiles)..where((t) => t.id.equals(1)))
          .write(LocalProfilesCompanion(lastActiveWorkoutId: Value(workout.id)));

      expect(await repo.restoreLastActiveWorkout(), isNull);
      expect((await profile()).lastActiveWorkoutId, isNull);
    });

    test('finishWorkout limpia el marcador (RF-10)', () async {
      final workout = await startWithExercise();
      final item = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(workout.id)))
          .getSingle();
      await repo.logSet(
        workoutExerciseId: item.id,
        weightKg: 80,
        reps: 8,
        rir: 2,
      );

      await repo.finishWorkout(workout.id);

      expect((await profile()).lastActiveWorkoutId, isNull);
    });

    test('finishWorkout sin series borra la sesión y el marcador', () async {
      final workout = await repo.startWorkout();

      final saved = await repo.finishWorkout(workout.id);

      expect(saved, isFalse);
      expect((await profile()).lastActiveWorkoutId, isNull);
    });

    test('abandonWorkout deja la sesión abandoned y limpia el marcador '
        '(RF-19/RF-11)', () async {
      final workout = await repo.startWorkout();

      await repo.abandonWorkout(workout.id);

      final stored = await (db.select(db.workouts)
            ..where((t) => t.id.equals(workout.id)))
          .getSingle();
      expect(stored.status, 'abandoned');
      expect(stored.endedAt, isNotNull);
      expect((await profile()).lastActiveWorkoutId, isNull);
      expect(enqueued.last.operation, 'upsert');
      expect(enqueued.last.table, 'workouts');
      expect(payloadOf(enqueued.length - 1)['status'], 'abandoned');
    });

    test('abandonWorkout no-op si la sesión ya está cerrada', () async {
      final workout = await repo.startWorkout();
      await repo.abandonWorkout(workout.id);
      final enqueuedBefore = enqueued.length;

      await repo.abandonWorkout(workout.id);

      expect(enqueued, hasLength(enqueuedBefore));
    });
  });

  group('RF-9 de la 008: feed de sesiones terminadas', () {
    test('sin sesiones terminadas emite una lista vacía', () async {
      expect(await repo.watchFinishedWorkouts().first, isEmpty);
    });

    test('resume duración, series, tonelaje y destacados', () async {
      final workout = await repo.startWorkout(name: 'Push');
      // Fecha el inicio 42 min atrás para una duración determinista.
      await (db.update(db.workouts)..where((t) => t.id.equals(workout.id)))
          .write(WorkoutsCompanion(
        startedAt: Value(DateTime.now().subtract(const Duration(minutes: 42))),
      ));
      await repo.addExercise(workoutId: workout.id, exerciseId: 'bench-press');
      final item = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(workout.id)))
          .getSingle();
      await repo.logSet(workoutExerciseId: item.id, weightKg: 80, reps: 8, rir: 2);
      await repo.logSet(
        workoutExerciseId: item.id,
        weightKg: 40,
        reps: 10,
        rir: 5,
        setType: 'warmup',
      );
      await repo.logSet(workoutExerciseId: item.id, weightKg: 85, reps: 6, rir: 1);

      await repo.finishWorkout(workout.id);

      final summaries = await repo.watchFinishedWorkouts().first;
      expect(summaries, hasLength(1));
      final summary = summaries.single;
      expect(summary.id, workout.id);
      expect(summary.title, 'Push');
      expect(summary.duration.inMinutes, inInclusiveRange(41, 43));
      // Todas las series completadas cuentan (incluido el calentamiento)…
      expect(summary.setCount, 3);
      // …pero el calentamiento no suma tonelaje ni destaca.
      expect(summary.volumeKg, closeTo(80 * 8 + 85 * 6, 0.001));
      expect(summary.highlights, hasLength(1));
      final highlight = summary.highlights.single;
      expect(highlight.name, 'Press de banca');
      expect(highlight.weightKg, 85);
      expect(highlight.reps, 6);
      expect(highlight.rir, 1);
    });

    test('ordena de más reciente a más antigua y omite no terminadas', () async {
      // Sesión A terminada hace dos horas.
      final old = await startWithExercise();
      final oldItem = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(old.id)))
          .getSingle();
      await repo.logSet(workoutExerciseId: oldItem.id, weightKg: 70, reps: 10, rir: 3);
      await repo.finishWorkout(old.id);
      await (db.update(db.workouts)..where((t) => t.id.equals(old.id)))
          .write(WorkoutsCompanion(
        endedAt: Value(DateTime.now().subtract(const Duration(hours: 2))),
      ));

      // Sesión B terminada ahora mismo.
      final recent = await startWithExercise();
      final recentItem = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(recent.id)))
          .getSingle();
      await repo.logSet(workoutExerciseId: recentItem.id, weightKg: 80, reps: 8, rir: 2);
      await repo.finishWorkout(recent.id);

      // Una sesión a medio empezar y otra abandonada no entran en el feed.
      await repo.startWorkout();
      await repo.abandonWorkout((await repo.startWorkout()).id);
      final active = await repo.startWorkout();
      await repo.addExercise(workoutId: active.id, exerciseId: 'bench-press');

      final summaries = await repo.watchFinishedWorkouts().first;
      expect(summaries.map((s) => s.id), [recent.id, old.id]);
    });
  });

  group('RF-13/RF-14 de la 008: previo de la sesión anterior', () {
    test('devuelve el previo por ejercicio de la última sesión anterior',
        () async {
      final previous = await startWithExercise();
      final previousItem = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(previous.id)))
          .getSingle();
      await repo.logSet(
          workoutExerciseId: previousItem.id, weightKg: 70, reps: 10, rir: 3);
      await repo.logSet(
          workoutExerciseId: previousItem.id, weightKg: 75, reps: 8, rir: 2);
      await repo.finishWorkout(previous.id);

      final current = await repo.startWorkout();

      final previousSets = await repo.previousSets(
        before: current.startedAt.add(const Duration(seconds: 1)),
      );

      expect(previousSets['bench-press'], isNotNull);
      expect(previousSets['bench-press']!.map((s) => s.weightKg), [70, 75]);
      expect(previousSets['bench-press']!.map((s) => s.reps), [10, 8]);
    });

    test('ignora calentamientos y sesiones sin terminar', () async {
      final finished = await startWithExercise();
      final finishedItem = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(finished.id)))
          .getSingle();
      await repo.logSet(
        workoutExerciseId: finishedItem.id,
        weightKg: 40,
        reps: 12,
        rir: 5,
        setType: 'warmup',
      );
      await repo.logSet(
          workoutExerciseId: finishedItem.id, weightKg: 80, reps: 6, rir: 1);
      await repo.finishWorkout(finished.id);

      final current = await repo.startWorkout();

      final previous = await repo.previousSets(
        before: current.startedAt.add(const Duration(seconds: 1)),
      );

      expect(previous['bench-press'], hasLength(1));
      expect(previous['bench-press']!.single.weightKg, 80);
      expect(previous['bench-press']!.single.reps, 6);
    });
  });

  group('spec 012: sesión pasada', () {
    final past = DateTime(2020, 3, 15, 17);

    const benchDraft = PastExerciseDraft(
      exerciseId: 'bench-press',
      sets: [
        PastSetDraft(weightKg: 60, reps: 8, rir: 2),
        PastSetDraft(weightKg: 65, reps: 6, rir: 1),
      ],
    );

    test('crea una sesión finished con sus series completadas y la encola',
        () async {
      final workout = await repo.createPastWorkout(
        startedAt: past,
        duration: const Duration(minutes: 60),
        exercises: const [benchDraft],
      );

      expect(workout.status, 'finished');
      expect(workout.startedAt, past);
      expect(workout.endedAt, past.add(const Duration(minutes: 60)));
      expect(workout.endedAt!.isAfter(DateTime.now()), isFalse);
      expect(workout.routineId, isNull);
      expect(workout.name, isNull);

      final profile = await db.select(db.localProfiles).getSingle();
      expect(workout.localUserId, profile.localUserId);

      final items = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(workout.id)))
          .get();
      expect(items, hasLength(1));
      expect(items.single.orderIndex, 1);

      final sets = await (db.select(db.workoutSets)
            ..where((t) => t.workoutExerciseId.equals(items.single.id)))
          .get();
      expect([for (final s in sets) s.orderIndex], [1, 2]);
      expect(sets.every((s) => s.completed), isTrue);
      expect([for (final s in sets) s.weightKg], [60.0, 65.0]);
      expect([for (final s in sets) s.reps], [8, 6]);

      expect(enqueued, hasLength(4));
      expect(
        [for (final e in enqueued) e.table],
        ['workouts', 'workout_exercises', 'workout_sets', 'workout_sets'],
      );
      expect(enqueued.every((e) => e.operation == 'upsert'), isTrue);
      expect(payloadOf(0)['status'], 'finished');
      expect(
        payloadOf(0)['ended_at'],
        past.add(const Duration(minutes: 60)).toIso8601String(),
      );
      expect(payloadOf(3)['completed'], true);
    });

    test('el payload encolado es válido para el mapeo RF-13', () async {
      await repo.createPastWorkout(
        startedAt: past,
        duration: const Duration(minutes: 60),
        exercises: const [benchDraft],
      );

      final row = buildRemoteRow(
        table: 'workouts',
        payloadJson: enqueued.first.payload,
        userId: 'user-1',
      );

      expect(row['user_id'], 'user-1');
      expect(row['status'], 'finished');
      expect(row['started_at'], past.toIso8601String());
    });

    test('no toca la sesión activa ni su marcador', () async {
      final active = await repo.startWorkout();

      final pastWorkout = await repo.createPastWorkout(
        startedAt: past,
        duration: const Duration(minutes: 60),
        exercises: const [benchDraft],
      );

      final storedActive = await (db.select(db.workouts)
            ..where((t) => t.id.equals(active.id)))
          .getSingle();
      expect(storedActive.status, 'active');
      expect(storedActive.endedAt, isNull);

      final profile = await db.select(db.localProfiles).getSingle();
      expect(profile.lastActiveWorkoutId, active.id);
      expect(pastWorkout.status, 'finished');
    });

    test('rechaza un borrador sin ejercicios sin escribir nada', () async {
      await expectLater(
        repo.createPastWorkout(
          startedAt: past,
          duration: const Duration(minutes: 60),
          exercises: const [],
        ),
        throwsA(
          isA<PastWorkoutValidationException>().having(
            (e) => e.message,
            'message',
            contains('al menos un ejercicio'),
          ),
        ),
      );

      final workouts = await db.select(db.workouts).get();
      expect(workouts, isEmpty);
      expect(enqueued, isEmpty);
    });

    test('rechaza un ejercicio sin series', () async {
      await expectLater(
        repo.createPastWorkout(
          startedAt: past,
          duration: const Duration(minutes: 60),
          exercises: const [
            PastExerciseDraft(exerciseId: 'bench-press', sets: []),
          ],
        ),
        throwsA(isA<PastWorkoutValidationException>()),
      );

      final workouts = await db.select(db.workouts).get();
      expect(workouts, isEmpty);
    });

    test('rechaza una duración fuera de rango', () async {
      await expectLater(
        repo.createPastWorkout(
          startedAt: past,
          duration: const Duration(minutes: 0),
          exercises: const [benchDraft],
        ),
        throwsA(
          isA<PastWorkoutValidationException>().having(
            (e) => e.message,
            'message',
            contains('duración'),
          ),
        ),
      );

      final workouts = await db.select(db.workouts).get();
      expect(workouts, isEmpty);
    });

    test('rechaza una hora de inicio futura', () async {
      final future = DateTime.now().add(const Duration(hours: 2));

      await expectLater(
        repo.createPastWorkout(
          startedAt: future,
          duration: const Duration(minutes: 60),
          exercises: const [benchDraft],
        ),
        throwsA(
          isA<PastWorkoutValidationException>().having(
            (e) => e.message,
            'message',
            contains('futura'),
          ),
        ),
      );

      final workouts = await db.select(db.workouts).get();
      expect(workouts, isEmpty);
    });

    test('rechaza una serie que incumple la RF-7', () async {
      await expectLater(
        repo.createPastWorkout(
          startedAt: past,
          duration: const Duration(minutes: 60),
          exercises: const [
            PastExerciseDraft(
              exerciseId: 'bench-press',
              sets: [PastSetDraft(weightKg: 60, reps: 0, rir: 2)],
            ),
          ],
        ),
        throwsA(isA<SetValidationException>()),
      );

      final workouts = await db.select(db.workouts).get();
      expect(workouts, isEmpty);
    });

    test('una sesión pasada no es editable (RF-7)', () async {
      final workout = await repo.createPastWorkout(
        startedAt: past,
        duration: const Duration(minutes: 60),
        exercises: const [benchDraft],
      );
      final item = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(workout.id)))
          .getSingle();
      final sets = await (db.select(db.workoutSets)
            ..where((t) => t.workoutExerciseId.equals(item.id)))
          .get();
      final set = sets.first;

      await expectLater(
        repo.updateSet(
          setId: set.id,
          weightKg: 70,
          reps: 5,
          rir: 2,
        ),
        throwsA(isA<SessionNotEditableException>()),
      );

      final stored = await (db.select(db.workoutSets)
            ..where((t) => t.id.equals(set.id)))
          .getSingle();
      expect(stored.weightKg, 60.0);
    });
  });

  group('T-001 · persistencia de series (RF-5/RF-6/RF-7)', () {
    Future<WorkoutSet> logSet(
      Workout workout,
      double weightKg,
      int reps,
      int rir,
    ) async {
      final item = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(workout.id)))
          .getSingle();
      return repo.logSet(
        workoutExerciseId: item.id,
        weightKg: weightKg,
        reps: reps,
        rir: rir,
      );
    }

    Future<List<WorkoutSet>> setsOfWorkout(Workout workout) async {
      final item = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(workout.id)))
          .getSingle();
      return (db.select(db.workoutSets)
            ..where((t) => t.workoutExerciseId.equals(item.id))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();
    }

    test('borrar una serie la quita de la BD, reindexa 1..n y encola el '
        'delete (RF-5)', () async {
      final workout = await startWithExercise();
      final first = await logSet(workout, 70, 10, 3);
      final second = await logSet(workout, 75, 8, 2);
      final third = await logSet(workout, 80, 6, 1);
      expect([first.orderIndex, second.orderIndex, third.orderIndex], [1, 2, 3]);

      await repo.deleteSet(second.id);

      final rows = await setsOfWorkout(workout);
      expect(rows.map((s) => s.id), [first.id, third.id]);
      expect(rows.map((s) => s.orderIndex), [1, 2]);
      expect(rows.map((s) => s.weightKg), [70.0, 80.0]);

      expect(enqueued.last.operation, 'delete');
      expect(enqueued.last.table, 'workout_sets');
      expect(payloadOf(enqueued.length - 1)['id'], second.id);
    });

    test('borrar la primera serie deja el resto en 1..n sin huecos (RF-5)',
        () async {
      final workout = await startWithExercise();
      final first = await logSet(workout, 70, 10, 3);
      final second = await logSet(workout, 75, 8, 2);
      final third = await logSet(workout, 80, 6, 1);

      await repo.deleteSet(first.id);

      final rows = await setsOfWorkout(workout);
      expect(rows.map((s) => s.id), [second.id, third.id]);
      expect(rows.map((s) => s.orderIndex), [1, 2]);
    });

    test('las series pendientes sobreviven a una instancia nueva del '
        'repositorio con valores, tipo y orden (RF-7)', () async {
      final workout = await startWithExercise();
      final item = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(workout.id)))
          .getSingle();
      await repo.logSet(
        workoutExerciseId: item.id,
        weightKg: 60,
        reps: 8,
        rir: 2,
        restSeconds: 90,
        routineSetId: 'routine-set-1',
        completed: false,
      );
      await repo.logSet(
        workoutExerciseId: item.id,
        weightKg: 65,
        reps: 6,
        rir: 1,
        setType: 'warmup',
        completed: false,
      );

      // «Reiniciar»: una instancia nueva del repositorio sobre la misma BD.
      final restarted = WorkoutRepository(
        db,
        enqueue: (operation, table, payload) async {
          enqueued.add((operation: operation, table: table, payload: payload));
        },
      );

      final rows = await setsOfWorkout(workout);
      expect(rows, hasLength(2));
      expect(rows.map((s) => s.completed), [false, false]);
      expect(rows.map((s) => s.weightKg), [60.0, 65.0]);
      expect(rows.map((s) => s.reps), [8, 6]);
      expect(rows.map((s) => s.rir), [2, 1]);
      expect(rows.map((s) => s.setType), ['normal', 'warmup']);
      expect(rows.map((s) => s.orderIndex), [1, 2]);
      expect(rows.map((s) => s.restSeconds), [90, null]);
      expect(rows.map((s) => s.routineSetId), ['routine-set-1', null]);

      final streamed = await restarted.watchSets(workout.id).first;
      expect(streamed.map((s) => s.id), rows.map((s) => s.id));
      expect(streamed.every((s) => !s.completed), isTrue);
    });

    test('borrar en una sesión cerrada no cambia filas ni encola (RF-6)',
        () async {
      final workout = await startWithExercise();
      final set = await logSet(workout, 70, 10, 3);
      await repo.finishWorkout(workout.id);
      final enqueuedBefore = enqueued.length;

      await expectLater(
        repo.deleteSet(set.id),
        throwsA(isA<SessionNotEditableException>()),
      );

      final stored = await (db.select(db.workoutSets)
            ..where((t) => t.id.equals(set.id)))
          .getSingle();
      expect(stored.completed, isTrue);
      expect(stored.reps, 10);
      expect(enqueued, hasLength(enqueuedBefore));
    });

    test('confirmar una serie inválida no escribe nada ni encola (RF-6)',
        () async {
      final workout = await startWithExercise();
      final item = await (db.select(db.workoutExercises)
            ..where((t) => t.workoutId.equals(workout.id)))
          .getSingle();
      final set = await repo.logSet(
        workoutExerciseId: item.id,
        weightKg: 70,
        reps: 10,
        rir: 3,
      );
      final enqueuedBefore = enqueued.length;

      await expectLater(
        repo.updateSet(setId: set.id, weightKg: 70, reps: 0, rir: 3),
        throwsA(isA<SetValidationException>()),
      );

      final stored = await (db.select(db.workoutSets)
            ..where((t) => t.id.equals(set.id)))
          .getSingle();
      expect(stored.reps, 10);
      expect(stored.weightKg, 70);
      expect(enqueued, hasLength(enqueuedBefore));
    });
  });
}
