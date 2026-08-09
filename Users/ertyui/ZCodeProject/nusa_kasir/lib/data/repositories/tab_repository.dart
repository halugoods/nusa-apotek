import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

class TabRepository {
  final AppDatabase db;
  TabRepository(this.db);

  Future<int> save({
    int? tableId,
    required String orderType,
    required List<Map<String, dynamic>> items,
    required int total,
    int discount = 0,
  }) {
    final c = OpenTabsCompanion.insert(itemsJson: jsonEncode(items)).copyWith(
      tableId: tableId != null ? Value(tableId) : const Value.absent(),
      orderType: Value(orderType),
      total: Value(total),
      discount: Value(discount),
      status: const Value('Open'),
    );
    return db.into(db.openTabs).insert(c);
  }

  Future<List<OpenTab>> getAll() =>
      (db.select(db.openTabs)
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
          .get();

  Future<List<OpenTab>> getOpen() =>
      (db.select(db.openTabs)
            ..where((t) => t.status.equals('Open'))
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
          .get();

  Future<List<OpenTab>> getByTable(int tableId) =>
      (db.select(db.openTabs)
            ..where((t) => t.tableId.equals(tableId) & t.status.equals('Open'))
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
          .get();

  Future<OpenTab?> byId(int id) =>
      (db.select(db.openTabs)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> update(int id, {String? itemsJson, int? total, String? tableId}) async {
    var c = const OpenTabsCompanion();
    if (itemsJson != null) c = c.copyWith(itemsJson: Value(itemsJson));
    if (total != null) c = c.copyWith(total: Value(total));
    if (tableId != null) c = c.copyWith(tableId: Value(int.parse(tableId)));
    c = c.copyWith(updatedAt: Value(DateTime.now()));
    await (db.update(db.openTabs)..where((t) => t.id.equals(id))).write(c);
  }

  Future<void> complete(int id) async {
    await (db.update(db.openTabs)..where((t) => t.id.equals(id)))
        .write(OpenTabsCompanion(
      status: const Value('Completed'),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> delete(int id) =>
      (db.delete(db.openTabs)..where((t) => t.id.equals(id))).go();

  /// Count open tabs for a specific table.
  Future<int> countByTable(int tableId) async {
    final rows = await (db.select(db.openTabs)
          ..where((t) => t.tableId.equals(tableId) & t.status.equals('Open')))
        .get();
    return rows.length;
  }
}
