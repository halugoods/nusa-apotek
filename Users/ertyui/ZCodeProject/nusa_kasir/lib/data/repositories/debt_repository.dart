import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

class DebtRepository {
  final AppDatabase db;
  DebtRepository(this.db);

  /// Add a new debt (utang/pinjaman). Returns the debt id.
  Future<int> addDebt({
    required int customerId,
    required String customerName,
    required int amount,
    DateTime? dueDate,
    String? description,
  }) {
    return db
        .into(db.customerDebts)
        .insert(
          CustomerDebtsCompanion.insert(
            customerId: customerId,
            customerName: customerName,
            amount: amount,
            remainingAmount: amount,
            dueDate: Value(dueDate),
            description: Value(description),
          ),
        );
  }

  /// Get active (unpaid) debts, optionally filtered by customer.
  Future<List<CustomerDebt>> getActiveDebts({int? customerId}) {
    final q = db.select(db.customerDebts)
      ..where((t) => t.status.equals('Belum Lunas'));
    if (customerId != null) {
      q.where((t) => t.customerId.equals(customerId));
    }
    q.orderBy([
      (t) => OrderingTerm(expression: t.debtDate, mode: OrderingMode.desc),
    ]);
    return q.get();
  }

  /// Get all debts ordered by debtDate desc, optionally filtered by customer.
  Future<List<CustomerDebt>> getAllDebts({int? customerId}) {
    final q = db.select(db.customerDebts);
    if (customerId != null) {
      q.where((t) => t.customerId.equals(customerId));
    }
    q.orderBy([
      (t) => OrderingTerm(expression: t.debtDate, mode: OrderingMode.desc),
    ]);
    return q.get();
  }

  /// Add a payment towards a debt. Updates remainingAmount and auto-sets status to 'Lunas' if fully paid.
  Future<void> addPayment({
    required int debtId,
    required int amount,
    String method = 'Tunai',
    String? notes,
  }) async {
    if (amount <= 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Pembayaran harus lebih dari nol',
      );
    }
    if (method.trim().isEmpty) {
      throw ArgumentError.value(
        method,
        'method',
        'Metode pembayaran wajib diisi',
      );
    }

    await db.transaction(() async {
      final debt = await (db.select(
        db.customerDebts,
      )..where((t) => t.id.equals(debtId))).getSingleOrNull();
      if (debt == null) {
        throw StateError('Utang tidak ditemukan');
      }
      if (debt.status == 'Lunas' || debt.remainingAmount <= 0) {
        throw StateError('Utang sudah lunas');
      }
      if (amount > debt.remainingAmount) {
        throw ArgumentError.value(
          amount,
          'amount',
          'Pembayaran melebihi sisa utang',
        );
      }

      await db
          .into(db.debtPayments)
          .insert(
            DebtPaymentsCompanion.insert(
              debtId: debtId,
              amount: amount,
              method: Value(method.trim()),
              notes: Value(notes),
            ),
          );

      final newRemaining = debt.remainingAmount - amount;
      await (db.update(
        db.customerDebts,
      )..where((t) => t.id.equals(debtId))).write(
        CustomerDebtsCompanion(
          remainingAmount: Value(newRemaining),
          status: Value(newRemaining == 0 ? 'Lunas' : 'Belum Lunas'),
        ),
      );
    });
  }

  /// Get payment history for a specific debt.
  Future<List<DebtPayment>> getPayments(int debtId) {
    final q = db.select(db.debtPayments)..where((t) => t.debtId.equals(debtId));
    q.orderBy([
      (t) => OrderingTerm(expression: t.paidAt, mode: OrderingMode.desc),
    ]);
    return q.get();
  }

  /// Get sum of all remaining amounts for unpaid debts.
  Future<int> getTotalReceivables() async {
    final row =
        await (db.selectOnly(db.customerDebts)
              ..addColumns([db.customerDebts.remainingAmount.sum()])
              ..where(db.customerDebts.status.equals('Belum Lunas')))
            .getSingleOrNull();

    return row?.read(db.customerDebts.remainingAmount.sum()) ?? 0;
  }

  /// Get overdue debts (dueDate < now AND status != 'Lunas').
  Future<List<CustomerDebt>> getOverdueDebts() {
    final now = DateTime.now();
    final q = db.select(db.customerDebts)
      ..where(
        (t) =>
            t.dueDate.isSmallerThanValue(now) & t.status.equals('Belum Lunas'),
      );
    q.orderBy([
      (t) => OrderingTerm(expression: t.dueDate, mode: OrderingMode.asc),
    ]);
    return q.get();
  }

  /// Get outstanding debt total for a specific customer.
  Future<int> getCustomerOutstanding(int customerId) async {
    final row =
        await (db.selectOnly(db.customerDebts)
              ..addColumns([db.customerDebts.remainingAmount.sum()])
              ..where(
                db.customerDebts.customerId.equals(customerId) &
                    db.customerDebts.status.equals('Belum Lunas'),
              ))
            .getSingleOrNull();

    return row?.read(db.customerDebts.remainingAmount.sum()) ?? 0;
  }
}
