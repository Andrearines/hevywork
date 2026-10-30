import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/data/repositories/photo_repository.dart';

void main() {
  late AppDatabase db;
  late Directory tempDir;
  late List<({String operation, String table, String payload})> enqueued;
  late List<({String path, List<int> bytes})> uploaded;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('hevywork_photos');
    enqueued = [];
    uploaded = [];
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  PhotoRepository buildRepo({PhotoUploader? uploader}) => PhotoRepository(
        db,
        enqueue: (operation, table, payload) async {
          enqueued.add((
            operation: operation,
            table: table,
            payload: payload,
          ));
        },
        uploader: uploader,
        documentsDir: () async => tempDir,
      );

  group('addPhoto (RF-5/RF-7)', () {
    test('guarda el JPEG local, la fila pendiente y encola la metadata',
        () async {
      final repo = buildRepo();

      final photo = await repo.addPhoto(
        date: DateTime(2026, 10, 18, 9, 30),
        view: 'front',
        bytes: Uint8List.fromList(const [1, 2, 3]),
      );

      expect(File(photo.path).readAsBytesSync(), const [1, 2, 3]);
      expect(photo.date, DateTime(2026, 10, 18));
      expect(photo.uploadStatus, 'pending');
      expect(photo.storagePath, endsWith('/${photo.id}.jpg'));

      final rows = await db.select(db.progressPhotos).get();
      expect(rows, hasLength(1));

      final mutation = enqueued.single;
      expect(mutation.operation, 'upsert');
      expect(mutation.table, 'progress_photos');
      final payload = jsonDecode(mutation.payload) as Map<String, dynamic>;
      expect(payload['id'], photo.id);
      expect(payload['view'], 'front');
      expect(payload['path'], photo.storagePath);
    });

    test('rechaza vistas desconocidas y bytes vacíos', () async {
      final repo = buildRepo();

      expect(
        () => repo.addPhoto(
          date: DateTime(2026, 10, 18),
          view: 'top',
          bytes: Uint8List.fromList(const [1]),
        ),
        throwsArgumentError,
      );
      expect(
        () => repo.addPhoto(
          date: DateTime(2026, 10, 18),
          view: 'front',
          bytes: Uint8List(0),
        ),
        throwsArgumentError,
      );
    });
  });

  group('uploadPending (RF-7)', () {
    test('sube las pendientes, marca el estado y reintenta las que fallan',
        () async {
      final repo = buildRepo(
        uploader: (path, bytes) async {
          if (bytes.first == 2) throw Exception('sin red');
          uploaded.add((path: path, bytes: bytes));
        },
      );
      final ok = await repo.addPhoto(
        date: DateTime(2026, 10, 17),
        view: 'front',
        bytes: Uint8List.fromList(const [1]),
      );
      final failed = await repo.addPhoto(
        date: DateTime(2026, 10, 18),
        view: 'side',
        bytes: Uint8List.fromList(const [2]),
      );

      await repo.uploadPending();

      // Sin sesión, la clave del objeto usa el id local.
      expect(uploaded.single.path, '${ok.localUserId}/${ok.id}.jpg');
      final statuses = {
        for (final row in await db.select(db.progressPhotos).get())
          row.id: row.uploadStatus,
      };
      expect(statuses[ok.id], 'uploaded');
      expect(statuses[failed.id], 'pending');

      // El siguiente ciclo reintenta la que falló.
      final retry = buildRepo(
        uploader: (path, bytes) async {
          uploaded.add((path: path, bytes: bytes));
        },
      );
      await retry.uploadPending();

      expect(uploaded, hasLength(2));
      final after = {
        for (final row in await db.select(db.progressPhotos).get())
          row.id: row.uploadStatus,
      };
      expect(after[failed.id], 'uploaded');
    });
  });

  group('deletePhoto (RF-10)', () {
    test('borra el fichero, la fila y encola el delete', () async {
      final repo = buildRepo();
      final photo = await repo.addPhoto(
        date: DateTime(2026, 10, 18),
        view: 'back',
        bytes: Uint8List.fromList(const [9]),
      );

      await repo.deletePhoto(photo.id);

      expect(File(photo.path).existsSync(), isFalse);
      expect(await db.select(db.progressPhotos).get(), isEmpty);
      final mutation = enqueued.last;
      expect(mutation.operation, 'delete');
      final payload = jsonDecode(mutation.payload) as Map<String, dynamic>;
      expect(payload['id'], photo.id);
      expect(payload['path'], photo.storagePath);
    });
  });

  group('watchPhotos / watchDates / ensureLocal (RF-8/RF-9)', () {
    test('filtra por vista y devuelve los días en orden descendente', () async {
      final repo = buildRepo();
      await repo.addPhoto(
        date: DateTime(2026, 10, 1),
        view: 'front',
        bytes: Uint8List.fromList(const [1]),
      );
      await repo.addPhoto(
        date: DateTime(2026, 10, 1),
        view: 'side',
        bytes: Uint8List.fromList(const [2]),
      );
      await repo.addPhoto(
        date: DateTime(2026, 10, 15),
        view: 'back',
        bytes: Uint8List.fromList(const [3]),
      );

      final fronts = await repo.watchPhotos(view: 'front').first;
      expect(fronts, hasLength(1));
      expect(fronts.single.view, 'front');

      final dates = await repo.watchDates().first;
      expect(dates, [DateTime(2026, 10, 15), DateTime(2026, 10, 1)]);
    });

    test('ensureLocal devuelve la ruta local si el fichero existe', () async {
      final repo = buildRepo();
      final photo = await repo.addPhoto(
        date: DateTime(2026, 10, 18),
        view: 'front',
        bytes: Uint8List.fromList(const [4]),
      );

      expect(await repo.ensureLocal(photo), photo.path);
    });
  });
}
