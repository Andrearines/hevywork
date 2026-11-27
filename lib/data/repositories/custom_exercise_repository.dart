import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../domain/custom_exercise.dart';
import '../../domain/custom_exercise_image.dart';
import '../local/database.dart';

class CustomExerciseRepository {
  final AppDatabase _db;
  final Future<Directory> Function() documentsDir;
  final void Function()? onChanged;

  CustomExerciseRepository(
    this._db, {
    this.documentsDir = getApplicationDocumentsDirectory,
    this.onChanged,
  });

  Future<Exercise> createCustomExercise({
    required CustomExerciseDraft draft,
    Uint8List? imageBytes,
  }) async {
    final valid = draft.validate();
    final image = imageBytes == null
        ? null
        : validateCustomImageBytes(imageBytes);
    final profile = await _profile();
    final id = 'custom_${const Uuid().v4()}';
    final now = DateTime.now();
    String? imagePath;
    if (image != null) {
      imagePath = await _writeImage(profile.localUserId, id, image);
    }
    late final Exercise created;
    try {
      created = await _db
          .into(_db.exercises)
          .insertReturning(
            ExercisesCompanion.insert(
              id: id,
              name: valid.name,
              bodyPart: valid.bodyPart,
              equipment: valid.equipment,
              target: valid.target,
              muscleGroup: valid.muscleGroup,
              secondaryMuscles: Value(jsonEncode(valid.secondaryMuscles)),
              imagePath: Value(imagePath),
              createdAt: Value(now),
              origin: const Value('custom'),
              localUserId: Value(profile.localUserId),
              imageStoragePath: Value(
                image == null ? null : '${profile.localUserId}/$id',
              ),
              imageMimeType: Value(image?.mimeType),
              imageUploadStatus: Value(
                image == null ? 'none' : 'pending_upload',
              ),
              updatedAt: Value(now),
              restSeconds: Value(valid.restSeconds),
            ),
          );
    } catch (_) {
      await _deleteImage(imagePath);
      rethrow;
    }
    onChanged?.call();
    return created;
  }

  Future<Exercise> updateCustomExercise({
    required String id,
    required CustomExerciseDraft draft,
    Uint8List? imageBytes,
    bool removeImage = false,
  }) async {
    if (imageBytes != null && removeImage) {
      throw ArgumentError('No se puede reemplazar y quitar la imagen a la vez');
    }
    final valid = draft.validate();
    final image = imageBytes == null
        ? null
        : validateCustomImageBytes(imageBytes);
    final profile = await _profile();
    final current =
        await (_db.select(_db.exercises)..where(
              (t) =>
                  t.id.equals(id) &
                  t.origin.equals('custom') &
                  t.localUserId.equals(profile.localUserId),
            ))
            .getSingle();
    String? newImagePath;
    if (image != null) {
      newImagePath = await _writeImage(profile.localUserId, id, image);
    }
    final nextImagePath = removeImage
        ? null
        : newImagePath ?? current.imagePath;
    final hasUploadedImage =
        current.imageStoragePath != null &&
        (current.imageUploadStatus == 'uploaded' ||
            current.imageUploadStatus == 'pending_delete');
    late final List<Exercise> updated;
    try {
      updated =
          await (_db.update(_db.exercises)..where(
                (t) =>
                    t.id.equals(id) &
                    t.origin.equals('custom') &
                    t.localUserId.equals(profile.localUserId),
              ))
              .writeReturning(
                ExercisesCompanion(
                  name: Value(valid.name),
                  bodyPart: Value(valid.bodyPart),
                  equipment: Value(valid.equipment),
                  target: Value(valid.target),
                  muscleGroup: Value(valid.muscleGroup),
                  secondaryMuscles: Value(jsonEncode(valid.secondaryMuscles)),
                  imagePath: image != null || removeImage
                      ? Value(nextImagePath)
                      : const Value.absent(),
                  imageStoragePath: image != null
                      ? Value(
                          current.imageStoragePath ??
                              '${profile.localUserId}/$id',
                        )
                      : removeImage
                      ? Value(
                          hasUploadedImage ? current.imageStoragePath : null,
                        )
                      : const Value.absent(),
                  imageMimeType: image != null
                      ? Value(image.mimeType)
                      : removeImage
                      ? const Value(null)
                      : const Value.absent(),
                  imageUploadStatus: image != null
                      ? const Value('pending_upload')
                      : removeImage
                      ? Value(hasUploadedImage ? 'pending_delete' : 'none')
                      : const Value.absent(),
                  restSeconds: Value(valid.restSeconds),
                  updatedAt: Value(DateTime.now()),
                ),
              );
      if (updated.isEmpty) {
        throw StateError('El ejercicio personalizado ya no existe');
      }
    } catch (_) {
      await _deleteImage(newImagePath);
      rethrow;
    }
    if (current.imagePath != nextImagePath && (image != null || removeImage)) {
      try {
        await _deleteImage(current.imagePath);
      } catch (_) {}
    }
    onChanged?.call();
    return updated.single;
  }

  Future<String> _writeImage(
    String localUserId,
    String exerciseId,
    ValidatedCustomImage image,
  ) async {
    final directory = Directory(
      '${(await documentsDir()).path}${Platform.pathSeparator}'
      'custom_exercise_images${Platform.pathSeparator}$localUserId',
    );
    await directory.create(recursive: true);
    final path =
        '${directory.path}${Platform.pathSeparator}'
        '$exerciseId-${const Uuid().v4()}.${image.extension}';
    final temporary = File('$path.tmp');
    try {
      await temporary.writeAsBytes(image.bytes, flush: true);
      await temporary.rename(path);
      return path;
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  Future<void> _deleteImage(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<LocalProfile> _profile() =>
      (_db.select(_db.localProfiles)..where((t) => t.id.equals(1))).getSingle();
}
