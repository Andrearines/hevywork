import 'package:drift/drift.dart';

/// Cache local del mapa de fatiga (spec 007, RF-6): resultado del cálculo
/// por músculo canónico tras cada sync completado. Es dato derivado y no
/// viaja al remoto; Postgres solo guarda las sesiones que lo originan.
@DataClassName('MuscleFatigueRow')
class MuscleFatigue extends Table {
  TextColumn get localUserId => text()(); // UUID
  TextColumn get muscle => text()(); // ID canónico (RF-4)
  RealColumn get fatigue => real()(); // 0–1 normalizado (RF-2)
  RealColumn get raw => real()(); // valor crudo, para ordenar el mapa
  DateTimeColumn get computedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {localUserId, muscle};
}