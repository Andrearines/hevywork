import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/sync/sync_engine.dart';
import 'package:hevywork/data/sync/sync_payload.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  SyncQueueCompanion queueItem({
    required String id,
    String operation = 'insert',
    String table = 'workouts',
    String payload = '{"id":"w1"}',
    int attempts = 0,
    String status = 'pending',
    DateTime? nextAttemptAt,
  }) {
    return SyncQueueCompanion.insert(
      id: id,
      operation: operation,
      targetTable: table,
      payload: payload,
      attempts: Value(attempts),
      status: Value(status),
      nextAttemptAt: nextAttemptAt ?? DateTime.now(),
    );
  }

  group('buildRemoteRow (RF-13)', () {
    test(
      'workouts: inyecta user_id/client_updated_at y conserva routine_id',
      () {
        final row = buildRemoteRow(
          table: 'workouts',
          payloadJson: jsonEncode({
            'id': 'w1',
            'routine_id': 'r1',
            'name': 'Pierna',
            'target_sets': 3,
            'status': 'active',
            'started_at': '2026-10-06T10:00:00',
            'updated_at': '2026-10-06T10:05:00',
            'notes': null,
          }),
          userId: 'user-1',
        );

        expect(row, {
          'id': 'w1',
          'routine_id': 'r1',
          'name': 'Pierna',
          'status': 'active',
          'started_at': '2026-10-06T10:00:00',
          'user_id': 'user-1',
          'client_updated_at': '2026-10-06T10:05:00',
        });
      },
    );

    test('workout_sets: rir y weight_kg son NOT NULL en Postgres', () {
      final row = buildRemoteRow(
        table: 'workout_sets',
        payloadJson: jsonEncode({
          'id': 's1',
          'workout_exercise_id': 'we1',
          'order_index': 0,
          'set_type': 'normal',
          'reps': 8,
          'completed': true,
        }),
        userId: 'user-1',
      );

      expect(row['rir'], 0);
      expect(row['weight_kg'], 0);
      expect(row['user_id'], 'user-1');
      expect(row.containsKey('created_at'), isFalse);
    });

    test('profiles: el id es el auth.uid que exige RLS', () {
      final row = buildRemoteRow(
        table: 'profiles',
        payloadJson: jsonEncode({
          'display_name': 'Ana',
          'unit_system': 'imperial',
          'sex': 'female',
        }),
        userId: 'user-1',
      );

      expect(row, {
        'id': 'user-1',
        'display_name': 'Ana',
        'unit_system': 'imperial',
        'sex': 'female',
      });
    });

    test('profiles: los nulos se propagan para poder borrar un dato', () {
      final row = buildRemoteRow(
        table: 'profiles',
        payloadJson: jsonEncode({
          'display_name': null,
          'unit_system': 'metric',
          'sex': null,
          'height_cm': null,
        }),
        userId: 'user-1',
      );

      expect(row, {
        'id': 'user-1',
        'display_name': null,
        'unit_system': 'metric',
        'sex': null,
        'height_cm': null,
      });
    });

    test('routines: inyecta user_id, lleva la metadata y descarta nulos', () {
      final row = buildRemoteRow(
        table: 'routines',
        payloadJson: jsonEncode({
          'id': 'r1',
          'name': 'Tren superior',
          'description': 'Fuerza',
          'category': 'PPL',
          'level': 'Intermedio',
          'goal': 'Fuerza',
          'target_days': 6,
          'updated_at': '2026-10-06T10:05:00',
        }),
        userId: 'user-1',
      );

      expect(row, {
        'id': 'r1',
        'user_id': 'user-1',
        'name': 'Tren superior',
        'description': 'Fuerza',
        'category': 'PPL',
        'level': 'Intermedio',
        'goal': 'Fuerza',
        'target_days': 6,
      });

      // Rutina antigua sin metadata: los campos nulos no viajan.
      final legacy = buildRemoteRow(
        table: 'routines',
        payloadJson: jsonEncode({
          'id': 'r2',
          'name': 'Vieja',
          'category': null,
          'level': null,
          'goal': null,
          'target_days': null,
        }),
        userId: 'user-1',
      );

      expect(legacy, {'id': 'r2', 'user_id': 'user-1', 'name': 'Vieja'});
    });

    test('routine_exercises: lleva el objetivo y descarta nulos', () {
      final row = buildRemoteRow(
        table: 'routine_exercises',
        payloadJson: jsonEncode({
          'id': 're1',
          'routine_id': 'r1',
          'exercise_id': 'bench-press',
          'order_index': 1,
          'target_sets': 3,
          'target_reps': 8,
          'target_rir': 2,
          'suggested_weight_kg': null,
          'auto_progress': true,
        }),
        userId: 'user-1',
      );

      expect(row, {
        'id': 're1',
        'user_id': 'user-1',
        'routine_id': 'r1',
        'exercise_id': 'bench-press',
        'order_index': 1,
        'target_sets': 3,
        'target_reps': 8,
        'target_rir': 2,
        'auto_progress': true,
      });
    });

    test(
      'goals: lleva el progreso recalculado y descarta la baseline local',
      () {
        final row = buildRemoteRow(
          table: 'goals',
          payloadJson: jsonEncode({
            'id': 'g1',
            'type': 'strength',
            'target_value': 80,
            'deadline': '2026-12-31T00:00:00',
            'period': null,
            'metric_ref': 'bench-press',
            'status': 'active',
            'current_value': 76.5,
            'baseline_value': 90,
          }),
          userId: 'user-1',
        );

        expect(row, {
          'id': 'g1',
          'user_id': 'user-1',
          'type': 'strength',
          'target_value': 80,
          'deadline': '2026-12-31T00:00:00',
          'metric_ref': 'bench-press',
          'status': 'active',
          'current_value': 76.5,
        });
      },
    );

    test('body_metrics: clave por fecha con peso, medidas y notas', () {
      final row = buildRemoteRow(
        table: 'body_metrics',
        payloadJson: jsonEncode({
          'id': 'bm1',
          'date': '2026-10-01T00:00:00.000',
          'weight_kg': 82,
          'measures_json': {'chest': 102.5},
          'notes': 'Mañana',
          'baseline_value': 90,
        }),
        userId: 'user-1',
      );

      expect(row, {
        'user_id': 'user-1',
        'date': '2026-10-01T00:00:00.000',
        'weight_kg': 82,
        'measures_json': {'chest': 102.5},
        'notes': 'Mañana',
      });
    });

    test('body_metrics: el delete solo necesita la fecha', () {
      final row = buildRemoteRow(
        table: 'body_metrics',
        payloadJson: jsonEncode({'date': '2026-10-01T00:00:00.000'}),
        userId: 'user-1',
      );

      expect(row, {'user_id': 'user-1', 'date': '2026-10-01T00:00:00.000'});
    });

    test('workout_exercises: conserva el objetivo clonado de la rutina', () {
      final row = buildRemoteRow(
        table: 'workout_exercises',
        payloadJson: jsonEncode({
          'id': 'we1',
          'workout_id': 'w1',
          'exercise_id': 'bench-press',
          'order_index': 1,
          'target_sets': 3,
          'target_reps': 8,
          'target_rir': 2,
          'suggested_weight_kg': 60,
          'notes': null,
        }),
        userId: 'user-1',
      );

      expect(row, {
        'id': 'we1',
        'user_id': 'user-1',
        'workout_id': 'w1',
        'exercise_id': 'bench-press',
        'order_index': 1,
        'target_sets': 3,
        'target_reps': 8,
        'target_rir': 2,
        'suggested_weight_kg': 60,
      });
    });

    test('tabla desconocida o payload sin id no se pueden subir', () {
      expect(
        () => buildRemoteRow(
          table: 'exercises',
          payloadJson: '{"id":"0001"}',
          userId: 'user-1',
        ),
        throwsStateError,
      );
      expect(
        () => buildRemoteRow(
          table: 'workouts',
          payloadJson: '{"status":"active"}',
          userId: 'user-1',
        ),
        throwsStateError,
      );
    });
  });

  group('SyncEngine (RF-11 a RF-15)', () {
    test('el upsert exitoso borra el item de la cola (RF-13)', () async {
      final pushed = <Map<String, dynamic>>[];
      final engine = SyncEngine(
        db,
        null,
        pusher: (table, operation, row) async => pushed.add(row),
        userIdProvider: () => 'user-1',
      );

      await db.into(db.syncQueue).insert(queueItem(id: 'q1'));
      await engine.processQueue();

      expect(pushed, hasLength(1));
      expect(pushed.single['user_id'], 'user-1');
      expect(await db.select(db.syncQueue).get(), isEmpty);
    });

    test('una operación delete llega como delete, no como upsert', () async {
      late String pushedOperation;
      late String pushedTable;
      final engine = SyncEngine(
        db,
        null,
        pusher: (table, operation, row) async {
          pushedOperation = operation;
          pushedTable = table;
        },
        userIdProvider: () => 'user-1',
      );

      await db
          .into(db.syncQueue)
          .insert(
            queueItem(id: 'q1', operation: 'delete', payload: '{"id":"w1"}'),
          );
      await engine.processQueue();

      expect(pushedOperation, 'delete');
      expect(pushedTable, 'workouts');
    });

    test(
      'un fallo incrementa attempts y programa el reintento (RF-14)',
      () async {
        final engine = SyncEngine(
          db,
          null,
          pusher: (table, operation, row) async => throw Exception('sin red'),
          userIdProvider: () => 'user-1',
        );

        await db.into(db.syncQueue).insert(queueItem(id: 'q1'));
        final before = DateTime.now();
        await engine.processQueue();

        final item = (await db.select(db.syncQueue).get()).single;
        expect(item.attempts, 1);
        expect(item.status, 'pending');
        expect(
          item.nextAttemptAt.difference(before).inSeconds,
          inInclusiveRange(0, 2),
        );

        await engine.processQueue();
        expect((await db.select(db.syncQueue).get()).single.attempts, 1);
      },
    );

    test('el backoff tiene techo de 60 s (RF-14)', () async {
      final engine = SyncEngine(
        db,
        null,
        pusher: (table, operation, row) async => throw Exception('sin red'),
        userIdProvider: () => 'user-1',
      );

      await db.into(db.syncQueue).insert(queueItem(id: 'q1', attempts: 9));
      final before = DateTime.now();
      await engine.processQueue();

      final item = (await db.select(db.syncQueue).get()).single;
      final delay = item.nextAttemptAt.difference(before);
      expect(delay.inSeconds, inInclusiveRange(55, 61));
    });

    test('al pasar de 10 fallos marca dead_letter y avisa (RF-15)', () async {
      final engine = SyncEngine(
        db,
        null,
        pusher: (table, operation, row) async => throw Exception('sin red'),
        userIdProvider: () => 'user-1',
      );
      final notices = <String>[];
      final subscription = engine.notices.listen(notices.add);

      await db.into(db.syncQueue).insert(queueItem(id: 'q1', attempts: 10));
      await engine.processQueue();
      await Future<void>.delayed(Duration.zero);

      final item = (await db.select(db.syncQueue).get()).single;
      expect(item.attempts, 11);
      expect(item.status, 'dead_letter');
      expect(notices, hasLength(1));

      await engine.processQueue();
      expect((await db.select(db.syncQueue).get()).single.attempts, 11);

      await subscription.cancel();
    });

    test('enqueueMutation encola y dispara el envío (RF-11/RF-12)', () async {
      final pushed = <String>[];
      final engine = SyncEngine(
        db,
        null,
        pusher: (table, operation, row) async => pushed.add(table),
        userIdProvider: () => 'user-1',
      );

      await engine.enqueueMutation('insert', 'workouts', '{"id":"w1"}');
      await Future<void>.delayed(Duration.zero);

      expect(pushed, ['workouts']);
      expect(await db.select(db.syncQueue).get(), isEmpty);
    });

    test('sin Supabase configurado la cola espera en local', () async {
      final engine = SyncEngine(db, null);

      await db.into(db.syncQueue).insert(queueItem(id: 'q1'));
      await engine.processQueue();

      expect((await db.select(db.syncQueue).get()).single.attempts, 0);
    });

    test(
      'tras subir cambios invoca onSyncCompleted (RF-6 de la 007)',
      () async {
        var completed = 0;
        final engine = SyncEngine(
          db,
          null,
          pusher: (table, operation, row) async {},
          userIdProvider: () => 'user-1',
          onSyncCompleted: () async => completed++,
        );

        await db.into(db.syncQueue).insert(queueItem(id: 'q1'));
        await engine.processQueue();
        expect(completed, 1);

        // Sin cambios pendientes no se recalcula.
        await engine.processQueue();
        expect(completed, 1);
      },
    );

    test('un fallo del recálculo no rompe el sync (RF-6 de la 007)', () async {
      final engine = SyncEngine(
        db,
        null,
        pusher: (table, operation, row) async {},
        userIdProvider: () => 'user-1',
        onSyncCompleted: () async => throw Exception('boom'),
      );

      await db.into(db.syncQueue).insert(queueItem(id: 'q1'));
      await engine.processQueue();

      expect(await db.select(db.syncQueue).get(), isEmpty);
    });
  });
}
