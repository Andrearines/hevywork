import 'package:drift/drift.dart';
class LocalProfiles extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get localUserId => text()(); // UUID
  TextColumn get authUserId => text().nullable()(); // UUID
  TextColumn get displayName => text().nullable()();
  TextColumn get unitSystem =>
      text().withDefault(const Constant('metric'))(); // metric/imperial
  // Sesión activa reanudable (RF-9 de la 002): solo es estado local, no viaja
  // al remoto. Se limpia al cerrar o abandonar la sesión.
  TextColumn get lastActiveWorkoutId => text().nullable()(); // UUID
  BoolColumn get preferRpe => boolean().withDefault(const Constant(false))();
  // Datos para la estimación US Navy de composición (spec 009, RF-4).
  TextColumn get sex => text().nullable()(); // male/female
  RealColumn get heightCm => real().nullable()();
  TextColumn get avatarUrl => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
