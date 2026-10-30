import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/body_metric_repository.dart';

void main() {
  late AppDatabase db;
  late BodyMetricRepository repo;
  late List<({String operation, String table, String payload})> enqueued;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    enqueued = [];
    Future<void> enqueue(
      String operation,
      String table,
      String payload,
    ) async {
      enqueued.add((operation: operation, table: table, payload: payload));
    }
    repo = BodyMetricRepository(db, enqueue: enqueue);
  });

  tearDown(() => db.close());

  test('upsert guarda el día civil y encola un upsert (RF-1/RF-2)', () async {
    await repo.upsert(
      date: DateTime(2026, 10, 5, 8, 30),
      weightKg: 82,
      measures: const {'chest': 102.5},
      notes: '  Mañana  ',
    );

    final rows = await db.select(db.bodyMetrics).get();
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row.date, DateTime(2026, 10, 5));
    expect(row.weightKg, 82);
    expect(row.measuresJson, contains('102.5'));
    expect(row.notes, 'Mañana');
    expect(row.localUserId,
        (await db.select(db.localProfiles).getSingle()).localUserId);

    final last = enqueued.last;
    expect(last.operation, 'upsert');
    expect(last.table, 'body_metrics');
    final payload = jsonDecode(last.payload) as Map<String, dynamic>;
    expect(payload['date'], '2026-10-05T00:00:00.000');
    expect(payload['weight_kg'], 82);
    expect(payload['measures_json'], {'chest': 102.5});
    expect(payload['notes'], 'Mañana');
  });

  test('dos registros el mismo día: el último gana (caso límite 006)',
      () async {
    await repo.upsert(
      date: DateTime(2026, 10, 5),
      weightKg: 80,
      measures: const {'chest': 100},
    );
    await repo.upsert(date: DateTime(2026, 10, 5, 20), weightKg: 81);

    final rows = await db.select(db.bodyMetrics).get();
    expect(rows, hasLength(1));
    expect(rows.single.weightKg, 81);
    expect(rows.single.measuresJson, isNull);
  });

  test('puede haber un registro sin peso, solo medidas', () async {
    await repo.upsert(
      date: DateTime(2026, 10, 5),
      measures: const {'waist': 80},
    );

    final rows = await db.select(db.bodyMetrics).get();
    expect(rows.single.weightKg, isNull);
    expect(rows.single.measuresJson, contains('80'));
  });

  test('guarda composición corporal y la encola (RF-1/RF-2)', () async {
    await repo.upsert(
      date: DateTime(2026, 10, 5),
      weightKg: 80,
      bodyFatPct: 18.5,
      leanMassKg: 65.2,
    );

    final row = (await db.select(db.bodyMetrics).get()).single;
    expect(row.bodyFatPct, 18.5);
    expect(row.leanMassKg, 65.2);

    final payload =
        jsonDecode(enqueued.last.payload) as Map<String, dynamic>;
    expect(payload['body_fat_pct'], 18.5);
    expect(payload['lean_mass_kg'], 65.2);
  });

  test('un registro puede ser solo composición', () async {
    await repo.upsert(date: DateTime(2026, 10, 5), bodyFatPct: 20);

    final row = (await db.select(db.bodyMetrics).get()).single;
    expect(row.bodyFatPct, 20);
    expect(row.weightKg, isNull);
  });

  test('rechaza % de grasa y masa magra fuera de rango', () async {
    await expectLater(
      repo.upsert(date: DateTime(2026, 10, 5), bodyFatPct: 71),
      throwsArgumentError,
    );
    await expectLater(
      repo.upsert(date: DateTime(2026, 10, 5), bodyFatPct: -1),
      throwsArgumentError,
    );
    await expectLater(
      repo.upsert(date: DateTime(2026, 10, 5), leanMassKg: 0),
      throwsArgumentError,
    );
  });

  test('no admite peso sin sentido, medidas desconocidas ni registro vacío',
      () async {
    await expectLater(
      repo.upsert(date: DateTime(2026, 10, 5), weightKg: 0),
      throwsArgumentError,
    );
    await expectLater(
      repo.upsert(date: DateTime(2026, 10, 5), weightKg: -3),
      throwsArgumentError,
    );
    await expectLater(
      repo.upsert(
        date: DateTime(2026, 10, 5),
        measures: const {'pecho': 100},
      ),
      throwsArgumentError,
    );
    await expectLater(
      repo.upsert(date: DateTime(2026, 10, 5)),
      throwsArgumentError,
    );
    await expectLater(
      repo.upsert(date: DateTime(2026, 10, 5), notes: '   '),
      throwsArgumentError,
    );
  });

  test('editar cualquier registro conserva su createdAt (RF-2)', () async {
    await repo.upsert(
      date: DateTime(2026, 10, 2),
      weightKg: 80,
    );
    final createdAt =
        (await db.select(db.bodyMetrics).get()).single.createdAt;
    await repo.upsert(
      date: DateTime(2026, 10, 2),
      weightKg: 79.5,
      measures: const {'chest': 100},
    );

    final rows = await db.select(db.bodyMetrics).get();
    expect(rows, hasLength(1));
    expect(rows.single.weightKg, 79.5);
    expect(rows.single.createdAt, createdAt);
  });

  test('borrar un registro cualquiera lo elimina y encola el delete (RF-2)',
      () async {
    await repo.upsert(date: DateTime(2026, 10, 1), weightKg: 80);
    await repo.upsert(date: DateTime(2026, 10, 3), weightKg: 79);
    enqueued.clear();

    await repo.delete(DateTime(2026, 10, 1));

    final rows = await db.select(db.bodyMetrics).get();
    expect(rows, hasLength(1));
    expect(rows.single.weightKg, 79);
    expect(enqueued.single.operation, 'delete');
    expect(enqueued.single.table, 'body_metrics');
    expect(
      jsonDecode(enqueued.single.payload),
      {'date': '2026-10-01T00:00:00.000'},
    );
  });

  test('borrar un día sin registro encola el delete igualmente', () async {
    await repo.delete(DateTime(2026, 10, 1));
    expect(enqueued.single.operation, 'delete');
  });

  test('latestWeightKg devuelve el más reciente y salta días sin peso',
      () async {
    await repo.upsert(date: DateTime(2026, 10, 1), weightKg: 82);
    await repo.upsert(date: DateTime(2026, 10, 3), measures: const {'chest': 100});
    await repo.upsert(date: DateTime(2026, 10, 5), weightKg: 81);

    expect(await repo.latestWeightKg(), 81);
  });

  test('latestWeightKg es null sin mediciones de peso', () async {
    expect(await repo.latestWeightKg(), isNull);
    await repo.upsert(date: DateTime(2026, 10, 3), measures: const {'waist': 80});
    expect(await repo.latestWeightKg(), isNull);
  });

  test('watchRecords emite los registros de más reciente a más antiguo',
      () async {
    await repo.upsert(date: DateTime(2026, 10, 1), weightKg: 82);
    await repo.upsert(date: DateTime(2026, 10, 5), weightKg: 81);

    final stream = repo.watchRecords();
    final records = await stream.first;
    expect(records.map((r) => r.date).toList(), [
      DateTime(2026, 10, 5),
      DateTime(2026, 10, 1),
    ]);
  });
}