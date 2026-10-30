import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/profile_repository.dart';

void main() {
  late AppDatabase db;
  late ProfileRepository repo;
  late List<({String operation, String table, String payload})> enqueued;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    enqueued = [];
    Future<void> enqueue(String operation, String table, String payload) async {
      enqueued.add((operation: operation, table: table, payload: payload));
    }

    repo = ProfileRepository(db, enqueue: enqueue);
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            id: 'bench-press',
            name: 'Press de banca',
            bodyPart: 'chest',
            equipment: 'barbell',
            target: 'pectorals',
            muscleGroup: 'chest',
          ),
        );
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            id: 'squat',
            name: 'Sentadilla',
            bodyPart: 'upper legs',
            equipment: 'barbell',
            target: 'glutes',
            muscleGroup: 'quads',
          ),
        );
  });

  tearDown(() => db.close());

  Future<void> seedFinishedWorkout({
    required String id,
    required DateTime endedAt,
    required List<({String exerciseId, double weight, int reps, int rir})> sets,
  }) async {
    await db
        .into(db.workouts)
        .insert(
          WorkoutsCompanion.insert(
            id: id,
            localUserId: 'perfil-1',
            startedAt: endedAt.subtract(const Duration(hours: 1)),
            status: const Value('finished'),
            endedAt: Value(endedAt),
          ),
        );
    for (var i = 0; i < sets.length; i++) {
      final set = sets[i];
      final itemId = '$id-item-$i';
      await db
          .into(db.workoutExercises)
          .insert(
            WorkoutExercisesCompanion.insert(
              id: itemId,
              workoutId: id,
              exerciseId: set.exerciseId,
              orderIndex: i,
            ),
          );
      await db
          .into(db.workoutSets)
          .insert(
            WorkoutSetsCompanion.insert(
              id: '$itemId-set',
              workoutExerciseId: itemId,
              orderIndex: 1,
              weightKg: Value(set.weight),
              reps: Value(set.reps),
              rir: Value(set.rir),
              completed: const Value(true),
            ),
          );
    }
  }

  group('perfil local', () {
    test('setDisplayName guarda y encola en profiles', () async {
      await repo.setDisplayName('  Ana  ');

      final profile = await repo.watchProfile().first;
      expect(profile.displayName, 'Ana');
      expect(enqueued, hasLength(1));
      expect(enqueued.single.table, 'profiles');
      final payload = jsonDecode(enqueued.single.payload) as Map;
      expect(payload['display_name'], 'Ana');
      expect(payload['unit_system'], 'metric');
    });

    test('setDisplayName vacío limpia el nombre', () async {
      await repo.setDisplayName('Ana');
      await repo.setDisplayName('   ');

      final profile = await repo.watchProfile().first;
      expect(profile.displayName, isNull);
    });

    test('setUnitSystem persiste y encola; setPreferRpe no encola', () async {
      await repo.setUnitSystem('imperial');
      await repo.setPreferRpe(true);

      final profile = await repo.watchProfile().first;
      expect(profile.unitSystem, 'imperial');
      expect(profile.preferRpe, isTrue);
      expect(enqueued, hasLength(1));
      final payload = jsonDecode(enqueued.single.payload) as Map;
      expect(payload['unit_system'], 'imperial');
    });
  });

  group('watchStats', () {
    test('agrega sesiones, volumen y PR de sesiones terminadas', () async {
      await seedFinishedWorkout(
        id: 'w1',
        endedAt: DateTime(2026, 10, 8, 19),
        sets: [(exerciseId: 'bench-press', weight: 60, reps: 8, rir: 2)],
      );
      await seedFinishedWorkout(
        id: 'w2',
        endedAt: DateTime(2026, 10, 6, 19),
        sets: [
          (exerciseId: 'bench-press', weight: 70, reps: 5, rir: 1),
          (exerciseId: 'squat', weight: 100, reps: 5, rir: 2),
        ],
      );

      final stats = await repo.watchStats().first;

      expect(stats.finishedSessions, 2);
      expect(stats.totalVolumeKg, 480 + 350 + 500);
      expect(stats.records.first.exerciseId, 'bench-press');
      expect(stats.records.first.exerciseName, 'Press de banca');
      expect(stats.records.first.weightKg, 70);
    });

    test('sin sesiones devuelve stats vacías', () async {
      final stats = await repo.watchStats().first;
      expect(stats.finishedSessions, 0);
      expect(stats.totalVolumeKg, 0);
      expect(stats.records, isEmpty);
    });
  });

  group('exportCsv', () {
    test('incluye workouts y body_metrics', () async {
      await seedFinishedWorkout(
        id: 'w1',
        endedAt: DateTime(2026, 10, 8, 19),
        sets: [(exerciseId: 'squat', weight: 100, reps: 5, rir: 2)],
      );

      final csv = await repo.exportCsv();
      expect(csv, contains('workouts'));
      expect(csv, contains('w1'));
      expect(csv, contains('body_metrics'));
    });
  });
}
