import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Regression test for the v34 login-killer bug.
///
/// The v34 migration's backfill used Dart column names (`employeeId`,
/// `cashierName`) in raw SQL, but drift stores SQLite columns as
/// snake_case (`employee_id`, `cashier_name`). On upgraded devices the
/// UPDATE threw `no such column`, the migration rolled back, and every
/// DB query (including both PIN and fingerprint login lookups) failed.
///
/// This test replays the exact statements against a v33-shaped schema.
void main() {
  test('v34 backfill SQL must use snake_case column names', () {
    final db = sqlite3.openInMemory();

    // v33 schema — only the columns involved in the backfill matter.
    db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cashier_name TEXT NULL
      )
    ''');
    db.execute('''
      CREATE TABLE employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');
    db.execute("INSERT INTO employees (id, name) VALUES (1, 'Siti')");
    db.execute("INSERT INTO transactions (id, cashier_name) VALUES (10, 'Siti')");

    // The buggy statement — references Dart names, not SQLite columns.
    final broken = '''
      UPDATE transactions
      SET employeeId = (SELECT e.id FROM employees e WHERE e.name = transactions.cashierName LIMIT 1)
      WHERE employeeId IS NULL AND cashierName IS NOT NULL AND cashierName != ''
    ''';
    // The fixed statement — snake_case column names.
    final fixed = '''
      UPDATE transactions
      SET employee_id = (SELECT e.id FROM employees e WHERE e.name = transactions.cashier_name LIMIT 1)
      WHERE employee_id IS NULL AND cashier_name IS NOT NULL AND cashier_name != ''
    ''';

    // Sanity: employee_id doesn't exist in v33 yet (it's added by addColumn
    // before the backfill in the real migration).
    expect(() => db.execute(broken), throwsA(isA<SqliteException>()));

    // Real migration flow: add the column first, then backfill.
    db.execute('ALTER TABLE transactions ADD COLUMN employee_id INTEGER NULL');
    db.execute(fixed);

    final row =
        db.select('SELECT employee_id FROM transactions WHERE id = 10').first;
    expect(row['employee_id'], 1, reason: 'backfill must match cashier to employee');

    db.close();  });
}
