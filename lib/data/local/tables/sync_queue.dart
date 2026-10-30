import 'package:drift/drift.dart';

class SyncQueue extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get operation => text()(); // insert, update, delete
  TextColumn get targetTable => text()(); 
  TextColumn get payload => text()(); // JSON string
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  DateTimeColumn get nextAttemptAt => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
