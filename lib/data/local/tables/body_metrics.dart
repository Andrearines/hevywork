import 'package:drift/drift.dart';

/// Registro diario de peso y medidas corporales (spec 006, RF-1): una fila
/// por día y usuario, idempotente por `(local_user_id, date)`. El peso es
/// opcional (un día puede registrar solo medidas) y las medidas viajan como
/// JSON `{muscle_group: cm}`.
class BodyMetrics extends Table {
  TextColumn get localUserId => text()(); // UUID
  DateTimeColumn get date => dateTime()(); // Día civil, medianoche UTC.
  RealColumn get weightKg => real().nullable()(); // kg
  RealColumn get bodyFatPct => real().nullable()(); // % grasa (spec 009)
  RealColumn get leanMassKg => real().nullable()(); // masa magra en kg
  TextColumn get measuresJson => text().nullable()(); // {"chest": 102.5}
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {localUserId, date};
}