import 'package:drift/drift.dart';
import 'connection/connection.dart' as conn;

part 'database.g.dart';

class Items extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get icon => text().nullable()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get showInMenuBar => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus =>
      text()(); // 'synced', 'pending_insert', 'pending_update', 'pending_delete'

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Items])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(conn.connect());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await customStatement(
          'ALTER TABLE items ADD COLUMN show_in_menu_bar INTEGER NOT NULL DEFAULT 1',
        );
      }
    },
  );

  // Query active items for the current signed-in user, or guest items when
  // there is no user.
  Stream<List<Item>> watchActiveItemsForUser(String? userId) {
    return (select(items)
          ..where(
            (t) =>
                t.deletedAt.isNull() &
                (userId == null ? t.userId.isNull() : t.userId.equals(userId)),
          )
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.isPinned, mode: OrderingMode.desc),
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  // Get single item by id
  Future<Item?> getItem(String id) {
    return (select(items)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // Get pending sync items for the current signed-in user only.
  Future<List<Item>> getPendingSyncItemsForUser(String userId) {
    return (select(items)..where(
          (t) => t.syncStatus.isNotValue('synced') & t.userId.equals(userId),
        ))
        .get();
  }

  // Insert or update item
  Future<void> saveItem(Insertable<Item> item) async {
    await into(items).insertOnConflictUpdate(item);
  }

  // Delete item locally (soft delete)
  Future<void> softDeleteItem(String id) async {
    final now = DateTime.now().toUtc();
    await (update(items)..where((t) => t.id.equals(id))).write(
      ItemsCompanion(
        deletedAt: Value(now),
        syncStatus: const Value('pending_delete'),
        updatedAt: Value(now),
      ),
    );
  }

  // Hard delete item (used when purging from server/sync confirmed)
  Future<void> hardDeleteItem(String id) async {
    await (delete(items)..where((t) => t.id.equals(id))).go();
  }
}
