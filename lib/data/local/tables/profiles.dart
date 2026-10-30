import 'package:drift/drift.dart';

class Profiles extends Table {
  TextColumn get userId => text()(); // UUID from Supabase auth.users
  TextColumn get username => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {userId};
}
