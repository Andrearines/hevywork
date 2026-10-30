import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/progress_photos.dart';
import '../local/database.dart';
import 'workout_repository.dart' show MutationEnqueuer;

/// Sube los bytes de una foto al bucket privado (spec 009, RF-7). Se
/// inyecta en los tests para evitar la red.
typedef PhotoUploader = Future<void> Function(
  String storagePath,
  Uint8List bytes,
);

/// Fotos de progreso (spec 009, RF-5 a RF-10): guarda el JPEG comprimido
/// en el directorio de documentos, mantiene la fila local con su estado de
/// subida y encola la metadata para Supabase. La UI nunca espera a la red.
class PhotoRepository {
  final AppDatabase _db;
  final SupabaseClient? _supabase;
  final MutationEnqueuer? enqueue;
  final PhotoUploader? uploader;
  final Future<Directory> Function() documentsDir;

  PhotoRepository(
    this._db, {
    this._supabase,
    this.enqueue,
    this.uploader,
    this.documentsDir = getApplicationDocumentsDirectory,
  });

  static const String bucket = 'progress-photos';

  Stream<List<ProgressPhoto>> watchPhotos({String? view}) {
    final query = _db.select(_db.progressPhotos)
      ..orderBy([
        (t) => OrderingTerm.desc(t.date),
        (t) => OrderingTerm.desc(t.createdAt),
      ]);
    if (view != null) {
      query.where((t) => t.view.equals(view));
    }
    return query.watch();
  }

  /// Días (civil) que tienen al menos una foto, para el comparador (RF-8).
  Stream<List<DateTime>> watchDates() => (_db.select(_db.progressPhotos)
        ..orderBy([(t) => OrderingTerm.desc(t.date)]))
      .watch()
      .map((rows) {
        final seen = <DateTime>{};
        return [
          for (final row in rows)
            if (seen.add(row.date)) row.date,
        ];
      });

  /// La clave del objeto en Storage para una foto suya (RF-6).
  static String storagePathFor(String userId, String id) => '$userId/$id.jpg';

  /// Guarda una foto comprimida localmente (RF-7): crea la fila pendiente,
  /// escribe el fichero y encola la metadata. El `image_picker` ya comprime
  /// por debajo; se espera un JPEG por debajo de 500 KB.
  Future<ProgressPhoto> addPhoto({
    required DateTime date,
    required String view,
    required Uint8List bytes,
  }) async {
    if (!isPhotoView(view)) {
      throw ArgumentError.value(view, 'view');
    }
    if (bytes.isEmpty) {
      throw ArgumentError('La foto está vacía');
    }
    final now = DateTime.now();
    final profile = await _profile();
    final id = const Uuid().v4();
    final storagePath = storagePathFor(profile.localUserId, id);
    final file = await _writeFile(id, bytes);
    final day = DateTime(date.year, date.month, date.day);

    await _db.into(_db.progressPhotos).insert(
          ProgressPhotosCompanion.insert(
            id: id,
            localUserId: profile.localUserId,
            date: day,
            view: view,
            path: file.path,
            storagePath: storagePath,
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _enqueueRow('upsert', 'progress_photos', {
      'id': id,
      'date': day.toIso8601String(),
      'view': view,
      'path': storagePath,
    });
    return ProgressPhoto(
      id: id,
      localUserId: profile.localUserId,
      date: day,
      view: view,
      path: file.path,
      storagePath: storagePath,
      uploadStatus: 'pending',
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Sube a Storage las fotos aún pendientes (RF-7). Se llama en cada ciclo
  /// de sync con sesión; un fallo deja la foto pendiente para el siguiente.
  Future<void> uploadPending() async {
    final pending = await (_db.select(_db.progressPhotos)
          ..where((t) => t.uploadStatus.equals('pending')))
        .get();
    final uploader = this.uploader;
    if (pending.isEmpty || uploader == null) return;
    for (final photo in pending) {
      final file = File(photo.path);
      if (!file.existsSync()) continue;
      try {
        await uploader(await _remotePath(photo), await file.readAsBytes());
        await (_db.update(_db.progressPhotos)
              ..where((t) => t.id.equals(photo.id)))
            .write(
          ProgressPhotosCompanion(
            uploadStatus: const Value('uploaded'),
            updatedAt: Value(DateTime.now()),
          ),
        );
      } catch (_) {
        // Sin red o fallo transitorio: queda pendiente para el próximo ciclo.
      }
    }
  }

  /// Devuelve la ruta local de la foto, descargándola desde Storage si no
  /// está en el dispositivo (RF-9: caché en disco para uso sin conexión).
  Future<String?> ensureLocal(ProgressPhoto photo) async {
    final file = File(photo.path);
    if (file.existsSync()) return photo.path;
    final supabase = _supabase;
    if (supabase == null) return null;
    try {
      final bytes = await supabase.storage.from(bucket).download(
            await _remotePath(photo),
          );
      await _writeFile(photo.id, bytes);
      return photo.path;
    } catch (_) {
      return null;
    }
  }

  /// Borra la foto local, de Storage y en la tabla remota (RF-10). El
  /// objeto remoto se elimina al consumir la cola de sync; si no hay red,
  /// la cola lo reintenta sin perder la intención de borrado.
  Future<void> deletePhoto(String id) async {
    final photo = await (_db.select(_db.progressPhotos)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (photo == null) return;
    await _deleteFile(photo.path);
    await (_db.delete(_db.progressPhotos)..where((t) => t.id.equals(id)))
        .go();
    await _enqueueRow('delete', 'progress_photos', {
      'id': id,
      'path': photo.storagePath,
    });
  }

  Future<void> deleteAllPhotos() async {
    final photos = await _db.select(_db.progressPhotos).get();
    if (photos.isEmpty) return;
    for (final photo in photos) {
      await _deleteFile(photo.path);
      await _enqueueRow('delete', 'progress_photos', {
        'id': photo.id,
        'path': photo.storagePath,
      });
    }
    await _db.delete(_db.progressPhotos).go();
  }

  /// Clave real del objeto en Storage: la carpeta es el `auth.uid()` de la
  /// sesión activa (política del bucket); sin sesión se usa el id local
  /// con el que se creó la fila.
  Future<String> _remotePath(ProgressPhoto photo) async {
    final uid = _supabase?.auth.currentUser?.id;
    return uid == null ? photo.storagePath : storagePathFor(uid, photo.id);
  }

  Future<File> _writeFile(String id, Uint8List bytes) async {
    final dir = Directory(
      '${(await documentsDir()).path}${Platform.pathSeparator}'
      'progress_photos',
    );
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final file = File('${dir.path}${Platform.pathSeparator}$id.jpg');
    return file.writeAsBytes(bytes, flush: true);
  }

  Future<void> _deleteFile(String path) async {
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  Future<LocalProfile> _profile() async =>
      (_db.select(_db.localProfiles)..where((t) => t.id.equals(1))).getSingle();

  Future<void> _enqueueRow(
    String operation,
    String table,
    Map<String, dynamic> payload,
  ) async {
    await enqueue?.call(operation, table, jsonEncode(payload));
  }
}
