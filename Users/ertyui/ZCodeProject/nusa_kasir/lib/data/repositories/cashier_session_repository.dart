import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

class CashierSessionRepository {
  final AppDatabase db;
  CashierSessionRepository(this.db);

  /// Open a new cashier session with starting cash.
  Future<int> open({
    required int employeeId,
    required int startingCash,
    int? branchId,
  }) {
    return db.into(db.cashierSessions).insert(
          CashierSessionsCompanion.insert(
            employeeId: employeeId,
            startingCash: Value(startingCash),
            branchId: Value(branchId),
          ),
        );
  }

  /// Close an active cashier session.
  Future<void> close(int sessionId) =>
      (db.update(db.cashierSessions)..where((t) => t.id.equals(sessionId)))
          .write(CashierSessionsCompanion(
              closedAt: Value(DateTime.now())));

  /// Get the most recent cashier session (any day).
  Future<CashierSession?> getLast() async {
    final list = await (db.select(db.cashierSessions)
          ..orderBy([
            (t) => OrderingTerm(expression: t.openedAt, mode: OrderingMode.desc)
          ])
          ..limit(1))
        .get();
    return list.isNotEmpty ? list.first : null;
  }

  /// Get the currently active (not closed) session, if any.
  Future<CashierSession?> getActive() async {
    final list = await (db.select(db.cashierSessions)
          ..where((t) => t.closedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.openedAt, mode: OrderingMode.desc)
          ])
          ..limit(1))
        .get();
    return list.isNotEmpty ? list.first : null;
  }
}
