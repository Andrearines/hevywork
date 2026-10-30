import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/data/local/database.dart';

const _legacyTables = [
  '''
  CREATE TABLE "exercises" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "target" TEXT NOT NULL,
    "muscle_group" TEXT NOT NULL,
    "secondary_muscles" TEXT NOT NULL,
    "equipment" TEXT NOT NULL,
    "asset_image" TEXT NULL,
    "asset_gif" TEXT NULL,
    "body_part" TEXT NOT NULL DEFAULT '',
    PRIMARY KEY ("id")
  )
  ''',
  '''
  CREATE TABLE "exercise_instructions" (
    "exercise_id" TEXT NOT NULL REFERENCES exercises (id),
    "locale" TEXT NOT NULL,
    "step" INTEGER NOT NULL,
    "text" TEXT NOT NULL,
    PRIMARY KEY ("exercise_id", "locale", "step")
  )
  ''',
  '''
  CREATE TABLE "workouts" (
    "id" TEXT NOT NULL,
    "local_user_id" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'active',
    "started_at" INTEGER NOT NULL,
    "ended_at" INTEGER NULL,
    "notes" TEXT NULL,
    "client_updated_at" INTEGER NOT NULL,
    "server_updated_at" INTEGER NULL,
    "dirty" INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY ("id")
  )
  ''',
  '''
  CREATE TABLE "workout_exercises" (
    "id" TEXT NOT NULL,
    "local_user_id" TEXT NOT NULL,
    "workout_id" TEXT NOT NULL REFERENCES workouts (id) ON DELETE CASCADE,
    "exercise_id" TEXT NOT NULL,
    "order_index" INTEGER NOT NULL,
    "notes" TEXT NULL,
    "dirty" INTEGER NOT NULL DEFAULT 0,
    "server_updated_at" INTEGER NULL,
    "rest_timer_seconds" INTEGER NULL,
    "rest_timer_running" INTEGER NULL,
    "rest_timer_started_at" INTEGER NULL,
    PRIMARY KEY ("id")
  )
  ''',
  '''
  CREATE TABLE "workout_sets" (
    "id" TEXT NOT NULL,
    "local_user_id" TEXT NOT NULL,
    "workout_exercise_id" TEXT NOT NULL REFERENCES workout_exercises (id) ON DELETE CASCADE,
    "order_index" INTEGER NOT NULL,
    "set_type" TEXT NOT NULL DEFAULT 'normal',
    "reps" INTEGER NOT NULL,
    "weight_kg" REAL NULL,
    "rir" INTEGER NULL,
    "completed" INTEGER NOT NULL DEFAULT 1,
    "dirty" INTEGER NOT NULL DEFAULT 0,
    "server_updated_at" INTEGER NULL,
    PRIMARY KEY ("id")
  )
  ''',
  '''
  CREATE TABLE "local_profiles" (
    "id" INTEGER NOT NULL CHECK(id = 1),
    "local_user_id" TEXT NOT NULL,
    "auth_user_id" TEXT NULL,
    "display_name" TEXT NULL,
    "unit_system" TEXT NOT NULL DEFAULT 'metric',
    "catalog_version" INTEGER NOT NULL DEFAULT 0,
    "last_active_workout_id" TEXT NULL,
    PRIMARY KEY ("id")
  )
  ''',
  '''
  CREATE TABLE "sync_queue" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "table_name" TEXT NOT NULL,
    "record_id" TEXT NOT NULL,
    "op" TEXT NOT NULL,
    "payload" TEXT NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "next_attempt_at" INTEGER NOT NULL DEFAULT 0,
    "dead_letter" INTEGER NOT NULL DEFAULT 0,
    UNIQUE ("table_name", "record_id", "op")
  )
  ''',
  '''
  CREATE VIRTUAL TABLE "exercises_fts" USING fts5(
    id, name, body_part, target, muscle_group, equipment,
    content=exercises
  )
  ''',
  '''
  CREATE TRIGGER exercises_ai AFTER INSERT ON exercises BEGIN
    INSERT INTO exercises_fts(rowid, id, name) VALUES (new.rowid, new.id, new.name);
  END
  ''',
];

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late File file;

  setUp(() {
    file = File(
      '${Directory.systemTemp.path}/hevywork_migration_'
      '${DateTime.now().microsecondsSinceEpoch}_$pid.sqlite',
    );
  });

  tearDown(() {
    if (file.existsSync()) file.deleteSync();
  });

  Future<void> createLegacyFile() async {
    final legacy = AppDatabase(NativeDatabase(file, enableMigrations: false));
    for (final statement in _legacyTables) {
      await legacy.customStatement(statement);
    }
    await legacy.customStatement(
      "INSERT INTO exercises VALUES "
      "('0001', 'Press de banca con barra', 'pectorals', 'pecho', '[]', "
      "'barbell', 'images/0001.jpg', 'videos/0001.gif', 'chest')",
    );
    await legacy.customStatement(
      "INSERT INTO exercise_instructions VALUES "
      "('0001', 'es', 1, 'Aprieta la barra sobre el pecho')",
    );
    await legacy.customStatement(
      "INSERT INTO local_profiles (local_user_id) "
      "VALUES ('perfil-antiguo')",
    );
    await legacy.customStatement('PRAGMA user_version = 2');
    await legacy.close();
  }

  test(
    'una base local con esquema antiguo se reconstruye al abrirla',
    () async {
      await createLegacyFile();

      final db = AppDatabase(NativeDatabase(file));
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), 17);

      final columns = await db
          .customSelect("SELECT name FROM pragma_table_info('exercises')")
          .get();
      expect(
        columns.map((row) => row.read<String>('name')),
        containsAll(['image_path', 'gif_path', 'attribution', 'rest_seconds']),
      );

      final steps = await db
          .customSelect(
            'SELECT language, step_number, instruction FROM exercise_instructions',
          )
          .get();
      expect(steps, isEmpty);

      final exercises = await db.select(db.exercises).get();
      expect(exercises, isEmpty);

      final profiles = await db.select(db.localProfiles).get();
      expect(profiles, hasLength(1));
      expect(profiles.single.localUserId, isNot('perfil-antiguo'));

      final leftovers = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE name IN "
            "('exercises_fts', 'exercises_ai')",
          )
          .get();
      expect(leftovers, isEmpty);

      await db.close();
    },
  );

  test('una base con el esquema actual solo sube de versión', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            id: '0001',
            name: 'Press de banca con barra',
            bodyPart: 'chest',
            equipment: 'barbell',
            target: 'pectorals',
            muscleGroup: 'pecho',
          ),
        );
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final exercises = await reopened.select(reopened.exercises).get();
    expect(exercises, hasLength(1));
    expect(exercises.single.imagePath, isNull);

    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 17);

    final profiles = await reopened.select(reopened.localProfiles).get();
    expect(profiles, hasLength(1));

    await reopened.close();
  });

  test('una base v3 sube a v4 con el descanso y sin perder datos', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            id: '0001',
            name: 'Press de banca con barra',
            bodyPart: 'chest',
            equipment: 'barbell',
            target: 'pectorals',
            muscleGroup: 'pecho',
          ),
        );
    // Simula una base creada antes de la spec 002 (v3).
    await db.customStatement('ALTER TABLE exercises DROP COLUMN rest_seconds');
    await db.customStatement('ALTER TABLE workouts DROP COLUMN rest_ends_at');
    await db.customStatement(
      'ALTER TABLE workouts DROP COLUMN rest_paused_seconds',
    );
    await db.customStatement(
      'ALTER TABLE local_profiles DROP COLUMN last_active_workout_id',
    );
    await db.customStatement('DROP TABLE routine_sets');
    await db.customStatement(
      'ALTER TABLE workout_sets DROP COLUMN routine_set_id',
    );
    await db.customStatement(
      'ALTER TABLE workout_sets DROP COLUMN rest_seconds',
    );
    await db.customStatement(
      'ALTER TABLE local_profiles DROP COLUMN prefer_rpe',
    );
    await db.customStatement('PRAGMA user_version = 3');
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 17);

    final exercise = await reopened.select(reopened.exercises).getSingle();
    expect(exercise.id, '0001');
    expect(exercise.restSeconds, 90);

    final workoutColumns = await reopened
        .customSelect("SELECT name FROM pragma_table_info('workouts')")
        .get();
    expect(
      workoutColumns.map((row) => row.read<String>('name')),
      containsAll(['rest_ends_at', 'rest_paused_seconds']),
    );

    final profileColumns = await reopened
        .customSelect("SELECT name FROM pragma_table_info('local_profiles')")
        .get();
    expect(
      profileColumns.map((row) => row.read<String>('name')),
      contains('last_active_workout_id'),
    );

    // El CHECK del rango (15–300) se aplica también tras la migración.
    await expectLater(
      reopened
          .into(reopened.exercises)
          .insert(
            ExercisesCompanion.insert(
              id: '0002',
              name: 'Sentadilla',
              bodyPart: 'legs',
              equipment: 'barbell',
              target: 'quads',
              muscleGroup: 'piernas',
              restSeconds: const Value(400),
            ),
          ),
      throwsA(isA<SqliteException>()),
    );

    await reopened.close();
  });

  test(
    'una base v4 sube a v5 con el marcador de reanudación sin perder datos',
    () async {
      final db = AppDatabase(NativeDatabase(file));
      await db
          .into(db.workouts)
          .insertReturning(
            WorkoutsCompanion.insert(
              id: 'w-0001',
              localUserId: 'perfil-1',
              name: const Value('Tren inferior'),
              startedAt: DateTime(2026, 10, 5),
              status: const Value('active'),
            ),
          );
      // Simula una base creada sin el marcador del RF-9 (v4).
      await db.customStatement(
        'ALTER TABLE local_profiles DROP COLUMN last_active_workout_id',
      );
      await db.customStatement('DROP TABLE routine_sets');
      await db.customStatement(
        'ALTER TABLE workout_sets DROP COLUMN routine_set_id',
      );
      await db.customStatement(
        'ALTER TABLE workout_sets DROP COLUMN rest_seconds',
      );
      await db.customStatement(
        'ALTER TABLE local_profiles DROP COLUMN prefer_rpe',
      );
      await db.customStatement('PRAGMA user_version = 4');
      await db.close();

      final reopened = AppDatabase(NativeDatabase(file));
      final version = await reopened
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 17);

      final profiles = await reopened.select(reopened.localProfiles).get();
      expect(profiles, hasLength(1));
      expect(profiles.single.lastActiveWorkoutId, isNull);

      final stored = await reopened.select(reopened.workouts).getSingleOrNull();
      expect(stored!.id, 'w-0001');
      expect(stored.status, 'active');

      await reopened.close();
    },
  );

  test('una base v5 sube a v6 creando rutinas y sus ejercicios', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db.customStatement('DROP TABLE routine_sets');
    await db.customStatement('DROP TABLE routine_exercises');
    await db.customStatement('DROP TABLE routines');
    await db.customStatement(
      'ALTER TABLE workout_sets DROP COLUMN routine_set_id',
    );
    await db.customStatement(
      'ALTER TABLE workout_sets DROP COLUMN rest_seconds',
    );
    await db.customStatement(
      'ALTER TABLE local_profiles DROP COLUMN prefer_rpe',
    );
    await db.customStatement('PRAGMA user_version = 5');
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 17);

    final routineColumns = await reopened
        .customSelect("SELECT name FROM pragma_table_info('routines')")
        .get();
    expect(
      routineColumns.map((row) => row.read<String>('name')),
      containsAll(['id', 'local_user_id', 'name', 'description']),
    );

    final exerciseColumns = await reopened
        .customSelect("SELECT name FROM pragma_table_info('routine_exercises')")
        .get();
    expect(
      exerciseColumns.map((row) => row.read<String>('name')),
      containsAll([
        'id',
        'routine_id',
        'exercise_id',
        'order_index',
        'target_sets',
        'target_reps',
        'target_rir',
        'suggested_weight_kg',
        'auto_progress',
      ]),
    );

    await reopened
        .into(reopened.routines)
        .insert(
          RoutinesCompanion.insert(
            id: 'r-0001',
            localUserId: 'perfil-1',
            name: 'Tren superior',
          ),
        );

    await reopened.close();
  });

  test('una base v6 sube a v10 creando metas y el registro diario', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db.customStatement('DROP TABLE body_metrics');
    await db.customStatement('DROP TABLE goals');
    await db.customStatement('DROP TABLE routine_sets');
    await db.customStatement(
      'ALTER TABLE workout_sets DROP COLUMN routine_set_id',
    );
    await db.customStatement(
      'ALTER TABLE workout_sets DROP COLUMN rest_seconds',
    );
    await db.customStatement(
      'ALTER TABLE local_profiles DROP COLUMN prefer_rpe',
    );
    await db.customStatement('PRAGMA user_version = 6');
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 17);

    final goalColumns = await reopened
        .customSelect("SELECT name FROM pragma_table_info('goals')")
        .get();
    expect(
      goalColumns.map((row) => row.read<String>('name')),
      containsAll([
        'id',
        'local_user_id',
        'type',
        'target_value',
        'deadline',
        'period',
        'metric_ref',
        'status',
        'current_value',
        'baseline_value',
      ]),
    );

    final metricColumns = await reopened
        .customSelect("SELECT name FROM pragma_table_info('body_metrics')")
        .get();
    expect(
      metricColumns.map((row) => row.read<String>('name')),
      containsAll([
        'local_user_id',
        'date',
        'weight_kg',
        'measures_json',
        'notes',
      ]),
    );

    await reopened
        .into(reopened.goals)
        .insert(
          GoalsCompanion.insert(
            id: 'g-0001',
            localUserId: 'perfil-1',
            type: 'strength',
            targetValue: 80,
          ),
        );
    await reopened
        .into(reopened.bodyMetrics)
        .insert(
          BodyMetricsCompanion.insert(
            localUserId: 'perfil-1',
            date: DateTime(2026, 10, 1),
          ),
        );

    await reopened.close();
  });

  test('una base v9 consolida el peso previo en body_metrics', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db.customStatement('DROP TABLE body_metrics');
    await db.customStatement(
      'CREATE TABLE body_weight ('
      'id TEXT NOT NULL PRIMARY KEY, '
      'local_user_id TEXT NOT NULL, '
      'weight_kg REAL NOT NULL, '
      'measured_at INTEGER NOT NULL, '
      'created_at INTEGER NOT NULL, '
      'updated_at INTEGER NOT NULL)',
    );
    // El mismo formato que guarda drift: DateTime como epoch en segundos.
    final measured = DateTime(2026, 10, 1).millisecondsSinceEpoch ~/ 1000;
    final stamp = DateTime(2026, 10, 1, 7).millisecondsSinceEpoch ~/ 1000;
    await db.customStatement(
      "INSERT INTO body_weight VALUES "
      "('bw-0001', 'perfil-1', 82, $measured, $stamp, $stamp)",
    );
    await db.customStatement(
      'ALTER TABLE local_profiles DROP COLUMN prefer_rpe',
    );
    await db.customStatement('PRAGMA user_version = 9');
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 17);

    final rows = await reopened.select(reopened.bodyMetrics).get();
    expect(rows, hasLength(1));
    expect(rows.single.localUserId, 'perfil-1');
    expect(rows.single.weightKg, 82);
    expect(rows.single.measuresJson, isNull);
    expect(rows.single.date.year, 2026);
    expect(rows.single.date.month, 10);
    expect(rows.single.date.day, 1);

    final leftover = await reopened
        .customSelect(
          "SELECT name FROM sqlite_master WHERE name = 'body_weight'",
        )
        .get();
    expect(leftover, isEmpty);

    await reopened.close();
  });

  test('una base v10 crea el cache local de fatiga (spec 007)', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db.customStatement('DROP TABLE muscle_fatigue');
    await db.customStatement(
      'ALTER TABLE local_profiles DROP COLUMN prefer_rpe',
    );
    await db.customStatement('PRAGMA user_version = 10');
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 17);

    final columns = await reopened
        .customSelect("SELECT name FROM pragma_table_info('muscle_fatigue')")
        .get();
    expect(
      columns.map((row) => row.read<String>('name')),
      containsAll(['local_user_id', 'muscle', 'fatigue', 'raw', 'computed_at']),
    );

    await reopened
        .into(reopened.muscleFatigue)
        .insert(
          MuscleFatigueCompanion.insert(
            localUserId: 'perfil-1',
            muscle: 'pectoralis_major',
            fatigue: 1.0,
            raw: 1000,
            computedAt: DateTime(2026, 10, 9),
          ),
        );

    await reopened.close();
  });

  test('una base v7 sube a v8 creando las series planificadas', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db.customStatement('DROP TABLE routine_sets');
    await db.customStatement(
      'ALTER TABLE workout_sets DROP COLUMN routine_set_id',
    );
    await db.customStatement(
      'ALTER TABLE workout_sets DROP COLUMN rest_seconds',
    );
    await db.customStatement(
      'ALTER TABLE local_profiles DROP COLUMN prefer_rpe',
    );
    await db.customStatement('PRAGMA user_version = 7');
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 17);

    final setColumns = await reopened
        .customSelect("SELECT name FROM pragma_table_info('routine_sets')")
        .get();
    expect(
      setColumns.map((row) => row.read<String>('name')),
      containsAll([
        'id',
        'routine_exercise_id',
        'order_index',
        'set_type',
        'weight_kg',
        'reps',
        'rir',
        'rest_seconds',
      ]),
    );

    final workoutSetColumns = await reopened
        .customSelect("SELECT name FROM pragma_table_info('workout_sets')")
        .get();
    expect(
      workoutSetColumns.map((row) => row.read<String>('name')),
      containsAll(['rest_seconds', 'routine_set_id']),
    );

    await reopened.close();
  });

  test(
    'una base v8 sube a v9 añadiendo el vínculo de serie de rutina',
    () async {
      final db = AppDatabase(NativeDatabase(file));
      await db.customStatement(
        'ALTER TABLE workout_sets DROP COLUMN routine_set_id',
      );
      await db.customStatement(
        'ALTER TABLE local_profiles DROP COLUMN prefer_rpe',
      );
      await db.customStatement('PRAGMA user_version = 8');
      await db.close();

      final reopened = AppDatabase(NativeDatabase(file));
      final version = await reopened
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 17);

      final columns = await reopened
          .customSelect("SELECT name FROM pragma_table_info('workout_sets')")
          .get();
      expect(
        columns.map((row) => row.read<String>('name')),
        contains('routine_set_id'),
      );

      await reopened.close();
    },
  );

  test('una base v11 sube a v13 con la preferencia RIR/RPE', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db.customStatement(
      'ALTER TABLE local_profiles DROP COLUMN prefer_rpe',
    );
    await db.customStatement('PRAGMA user_version = 11');
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 17);

    final columns = await reopened
        .customSelect("SELECT name FROM pragma_table_info('local_profiles')")
        .get();
    expect(
      columns.map((row) => row.read<String>('name')),
      contains('prefer_rpe'),
    );

    final profiles = await reopened.select(reopened.localProfiles).get();
    expect(profiles, hasLength(1));
    expect(profiles.single.preferRpe, isFalse);

    await reopened.close();
  });

  test('una base v11 sube a v13 con la metadata de la rutina', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db.customStatement(
      'ALTER TABLE local_profiles DROP COLUMN prefer_rpe',
    );
    for (final column in ['category', 'level', 'goal', 'target_days']) {
      await db.customStatement('ALTER TABLE routines DROP COLUMN $column');
    }
    await db.customStatement('PRAGMA user_version = 11');
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 17);

    final columns = await reopened
        .customSelect("SELECT name FROM pragma_table_info('routines')")
        .get();
    expect(
      columns.map((row) => row.read<String>('name')).toSet(),
      containsAll(['category', 'level', 'goal', 'target_days']),
    );

    // Una rutina previa (sin metadata) se lee completa, con los campos a
    // null y sin huecos.
    await reopened
        .into(reopened.routines)
        .insert(
          RoutinesCompanion.insert(
            id: 'rutina-sin-metadata',
            localUserId: 'usuario',
            name: 'Vieja',
          ),
        );
    final rows = await reopened.select(reopened.routines).get();
    expect(rows.single.name, 'Vieja');
    expect(rows.single.category, isNull);
    expect(rows.single.level, isNull);
    expect(rows.single.goal, isNull);
    expect(rows.single.targetDays, isNull);

    await reopened.close();
  });

  test('una base v13 sube a v14 con la tabla de fotos de progreso', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db.customStatement('DROP TABLE progress_photos');
    await db.customStatement('PRAGMA user_version = 13');
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 17);

    await reopened
        .into(reopened.progressPhotos)
        .insert(
          ProgressPhotosCompanion.insert(
            id: 'foto-1',
            localUserId: 'usuario',
            date: DateTime(2026, 10, 18),
            view: 'front',
            path: '/tmp/foto-1.jpg',
            storagePath: 'usuario/foto-1.jpg',
          ),
        );
    final rows = await reopened.select(reopened.progressPhotos).get();
    expect(rows.single.uploadStatus, 'pending');

    await reopened.close();
  });

  test('una base v14 sube a v15 con composición y datos del atleta', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db.customStatement(
      'ALTER TABLE body_metrics DROP COLUMN body_fat_pct',
    );
    await db.customStatement(
      'ALTER TABLE body_metrics DROP COLUMN lean_mass_kg',
    );
    await db.customStatement('ALTER TABLE local_profiles DROP COLUMN sex');
    await db.customStatement(
      'ALTER TABLE local_profiles DROP COLUMN height_cm',
    );
    await db.customStatement('PRAGMA user_version = 14');
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 17);

    final metricColumns = await reopened
        .customSelect("SELECT name FROM pragma_table_info('body_metrics')")
        .get();
    expect(
      metricColumns.map((row) => row.read<String>('name')).toSet(),
      containsAll(['body_fat_pct', 'lean_mass_kg']),
    );

    final profileColumns = await reopened
        .customSelect("SELECT name FROM pragma_table_info('local_profiles')")
        .get();
    expect(
      profileColumns.map((row) => row.read<String>('name')).toSet(),
      containsAll(['sex', 'height_cm']),
    );

    // Un registro previo se lee sin huecos y admite composición.
    await reopened
        .into(reopened.bodyMetrics)
        .insert(
          BodyMetricsCompanion.insert(
            localUserId: 'usuario',
            date: DateTime(2026, 10, 5),
            bodyFatPct: const Value(18.5),
            leanMassKg: const Value(65.2),
          ),
        );
    final rows = await reopened.select(reopened.bodyMetrics).get();
    expect(rows.single.bodyFatPct, 18.5);
    expect(rows.single.leanMassKg, 65.2);

    await reopened.close();
  });

  test(
    'una base v15 sube a v16 con el cache de plantillas (spec 010)',
    () async {
      final db = AppDatabase(NativeDatabase(file));
      await db.customStatement('DROP TABLE IF EXISTS template_sets');
      await db.customStatement('DROP TABLE IF EXISTS template_exercises');
      await db.customStatement('DROP TABLE IF EXISTS template_days');
      await db.customStatement('DROP TABLE IF EXISTS templates');
      await db.customStatement('PRAGMA user_version = 15');
      await db.close();

      final reopened = AppDatabase(NativeDatabase(file));
      final version = await reopened
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 17);

      final tables = await reopened
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name LIKE 'template%'",
          )
          .get();
      expect(
        tables.map((row) => row.read<String>('name')).toSet(),
        containsAll([
          'templates',
          'template_days',
          'template_exercises',
          'template_sets',
        ]),
      );

      await reopened.close();
    },
  );

  test('una migración interrumpida (columna creada, versión atrasada) se '
      'repara sin romper la apertura', () async {
    // Escenario real: la app se cerró a mitad de un `onUpgrade` y la base
    // quedó con el esquema ya avanzado pero el `user_version` atrasado. Sin
    // la guarda idempotente, el `ALTER TABLE` fallaba con «duplicate column
    // name: prefer_rpe» y la app no arrancaba.
    final db = AppDatabase(NativeDatabase(file));
    await db.select(db.localProfiles).get();
    await db.customStatement('PRAGMA user_version = 11');
    await db.close();

    final reopened = AppDatabase(NativeDatabase(file));
    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 17);

    final profiles = await reopened.select(reopened.localProfiles).get();
    expect(profiles, hasLength(1));
    expect(profiles.single.preferRpe, isFalse);

    await reopened.close();
  });
}
