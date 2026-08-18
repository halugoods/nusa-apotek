import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Regression test for the v2.2.34 self-healing migration guards.
///
/// Symptom (7 variants): "Gagal menyimpan: SqliteException(1): while executing,
/// duplicate column name: order_type ... ALTER TABLE "transactions" ADD COLUMN
/// "order_type" TEXT NULL".
///
/// Root cause: a restored/older DB can carry the `order_type` column (written
/// by a newer app run) while `PRAGMA user_version` is still below 27. Drift
/// then runs `ALTER TABLE ... ADD COLUMN order_type` again → duplicate column
/// → migration fails → DB unusable.
///
/// The fix in app_database.dart guards every addColumn/createTable with a
/// PRAGMA table_info check: skip when the column already exists. These tests
/// replay the same SQL pattern against a synthetic "stuck" schema.
void main() {
  test('v27 guard: skip ADD COLUMN order_type when column already exists', () {
    final db = sqlite3.openInMemory();

    // Stuck DB: column already present (newer app wrote it), but
    // user_version is still < 27 (migration never completed).
    db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_type TEXT NULL,
        table_id INTEGER NULL,
        notes TEXT NULL
      )
    ''');
    db.execute('PRAGMA user_version = 26');

    // The old unguarded statement — would throw duplicate column.
    expect(
      () => db.execute('ALTER TABLE transactions ADD COLUMN order_type TEXT'),
      throwsA(isA<SqliteException>()),
    );

    // Guarded flow: check table_info, skip if present.
    final hasOrderType = db
        .select('PRAGMA table_info(transactions)')
        .any((row) => row['name'] == 'order_type');
    expect(hasOrderType, isTrue);

    if (!hasOrderType) {
      db.execute('ALTER TABLE transactions ADD COLUMN order_type TEXT');
    }
    // No exception raised — migration can continue.
    db.execute('PRAGMA user_version = 42');

    expect(db.select('PRAGMA user_version;').first.values.first, 42);
    db.close();
  });

  test('v27 guard: ADD COLUMN runs when column missing', () {
    final db = sqlite3.openInMemory();

    // Clean older DB: column genuinely absent.
    db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT
      )
    ''');
    db.execute('PRAGMA user_version = 26');

    final hasOrderType = db
        .select('PRAGMA table_info(transactions)')
        .any((row) => row['name'] == 'order_type');
    expect(hasOrderType, isFalse);

    if (!hasOrderType) {
      db.execute('ALTER TABLE transactions ADD COLUMN order_type TEXT');
    }

    final colsAfter =
        db.select('PRAGMA table_info(transactions)').map((r) => r['name']).toList();
    expect(colsAfter, contains('order_type'));
    db.close();
  });

  test('v27 guard: create open_tabs is idempotent (IF NOT EXISTS)', () {
    final db = sqlite3.openInMemory();
    db.execute('PRAGMA user_version = 26');

    db.execute(
      'CREATE TABLE IF NOT EXISTS "open_tabs" '
      '(id INTEGER PRIMARY KEY AUTOINCREMENT, order_type TEXT, items_json TEXT)',
    );
    // Run twice — no "table already exists" error.
    db.execute(
      'CREATE TABLE IF NOT EXISTS "open_tabs" '
      '(id INTEGER PRIMARY KEY AUTOINCREMENT, order_type TEXT, items_json TEXT)',
    );

    final tables =
        db.select("SELECT name FROM sqlite_master WHERE type='table' AND name='open_tabs'");
    expect(tables.length, 1);
    db.close();
  });

  test('print_service_types seed only runs when table empty', () {
    final db = sqlite3.openInMemory();
    db.execute('''
      CREATE TABLE print_service_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        is_default INTEGER DEFAULT 0
      )
    ''');
    // Table already has data (e.g. restored DB) — seed must not duplicate.
    db.execute(
        "INSERT INTO print_service_types (name, is_default) VALUES ('Custom', 0)");

    final count =
        db.select('SELECT COUNT(*) AS c FROM print_service_types').first['c'] as int;
    if (count == 0) {
      for (final name in ['Fotocopy', 'Print Warna', 'Print B/W', 'Jilid', 'Laminating', 'Scan']) {
        db.execute("INSERT INTO print_service_types (name, is_default) VALUES ('$name', 1)");
      }
    }

    final after =
        db.select('SELECT COUNT(*) AS c FROM print_service_types').first['c'] as int;
    expect(after, 1, reason: 'no duplicate seed when table already has rows');
    db.close();
  });
}
