import 'package:drift/drift.dart';

/// Foto de progreso (spec 009, RF-5): una fila por foto con su vista
/// (front/side/back), el día civil y la ruta local del fichero JPEG. El
/// fichero se comprime con `image_picker` (< 500 KB) y se guarda en el
/// directorio de documentos; `storage_path` es la clave en el bucket
/// privado `progress-photos` (`<user_id>/<id>.jpg`) y `upload_status`
/// refleja la cola de subida en segundo plano (RF-7).
class ProgressPhotos extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get localUserId => text()(); // UUID
  DateTimeColumn get date => dateTime()(); // Día civil, medianoche local.
  TextColumn get view => text()(); // front, side, back
  TextColumn get path => text()(); // Ruta local del fichero.
  TextColumn get storagePath => text()(); // Clave en Storage.
  TextColumn get uploadStatus =>
      text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
