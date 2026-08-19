import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables.dart';
part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Categories,
    Products,
    StockMovements,
    Transactions,
    Customers,
    Promos,
    Employees,
    Attendance,
    Expenses,
    ExpenseCategories,
    RecurringExpenses,
    Payroll,
    Waste,
    Liquidity,
    Suppliers,
    Branches,
    Settings,
    ActivationsLocal,
    SyncQueue,
    CashierSessions,
    OnlineOrders,
    CustomerDebts,
    DebtPayments,
    StockCounts,
    StockCountItems,
    ChatSessions,
    DiningTables,
    LaundryOrders,
    ServiceTickets,
    Appointments,
    Prescriptions,
    PrintOrders,
    PrintServiceTypes,
    OpenTabs,
    Roles,
    Refunds,
    PointHistories,
    PurchaseOrders,
    PurchaseOrderItems,
    MaterialPrices,
    InstallmentOptions,
    EstimateOptions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.test() : super(NativeDatabase.memory());
  @override
  int get schemaVersion => 43;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await _createTableIfMissing(
          m,
          'cashier_sessions',
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'employee_id INTEGER, '
              'opened_at INTEGER, '
              'closed_at INTEGER, '
              'opening_cash INTEGER, '
              'closing_cash INTEGER, '
              'expected_cash INTEGER, '
              'notes TEXT, '
              'status TEXT',
        );
      }
      if (from < 3) {
        await _addColumnIfMissing(m, 'attendance', 'final_cash', 'INTEGER');
      }
      if (from < 4) {
        await _addColumnIfMissing(m, 'products', 'is_online', 'INTEGER');
        await _createTableIfMissing(
          m,
          'online_orders',
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'invoice TEXT NOT NULL, '
              'customer_name TEXT NOT NULL, '
              'customer_phone TEXT NOT NULL, '
              'items TEXT NOT NULL, '
              'subtotal INTEGER DEFAULT 0, '
              'discount INTEGER DEFAULT 0, '
              'handling_fee INTEGER DEFAULT 0, '
              'total INTEGER NOT NULL, '
              'payment_method TEXT DEFAULT \'Tunai\', '
              'pickup_time TEXT, '
              'branch TEXT DEFAULT \'Pusat\', '
              'notes TEXT, '
              'status TEXT DEFAULT \'Online Baru\', '
              'processed_by TEXT, '
              'created_at INTEGER',
        );
      }
      if (from < 5) {
        await _addColumnIfMissing(m, 'transactions', 'status', 'TEXT');
        await _addColumnIfMissing(m, 'transactions', 'void_reason', 'TEXT');
        await _addColumnIfMissing(m, 'transactions', 'voided_at', 'INTEGER');
      }
      if (from < 6) {
        await _addColumnIfMissing(m, 'settings', 'pos_grid_columns', 'INTEGER');
        await _addColumnIfMissing(m, 'settings', 'bank_name', 'TEXT');
        await _addColumnIfMissing(m, 'settings', 'bank_account', 'TEXT');
        await _addColumnIfMissing(m, 'settings', 'bank_holder', 'TEXT');
      }
      if (from < 7) {
        await _addColumnIfMissing(m, 'products', 'expiry_date', 'INTEGER');
        await _addColumnIfMissing(m, 'products', 'product_type', 'TEXT');
      }
      if (from < 8) {
        await _addColumnIfMissing(m, 'products', 'variants_json', 'TEXT');
        await _addColumnIfMissing(m, 'products', 'wholesale_json', 'TEXT');
      }
      if (from < 9) {
        await _createTableIfMissing(
          m,
          'categories',
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'name TEXT NOT NULL, '
              'created_at INTEGER',
        );
      }
      if (from < 10) {
        await _addColumnIfMissing(m, 'settings', 'receipt_footer', 'TEXT');
        await _addColumnIfMissing(m, 'settings', 'store_logo_path', 'TEXT');
      }
      if (from < 11) {
        await _addColumnIfMissing(m, 'settings', 'wa_templates', 'TEXT');
        await _addColumnIfMissing(m, 'settings', 'points_per_rupiah', 'INTEGER');
        await _addColumnIfMissing(m, 'settings', 'silver_threshold', 'INTEGER');
        await _addColumnIfMissing(m, 'settings', 'gold_threshold', 'INTEGER');
        await _addColumnIfMissing(m, 'settings', 'platinum_threshold', 'INTEGER');
      }
      if (from < 12) {
        await _addColumnIfMissing(m, 'employees', 'phone', 'TEXT');
        await _addColumnIfMissing(m, 'attendance', 'status', 'TEXT');
      }
      if (from < 13) {
        await _addColumnIfMissing(m, 'employees', 'photo_path', 'TEXT');
        await _addColumnIfMissing(m, 'employees', 'base_salary', 'INTEGER');
        await _addColumnIfMissing(m, 'employees', 'start_date', 'INTEGER');
      }
      if (from < 14) {
        await _addColumnIfMissing(m, 'expenses', 'branch_id', 'INTEGER');
        await _addColumnIfMissing(m, 'liquidity', 'branch_id', 'INTEGER');
        await _createTableIfMissing(
          m,
          'expense_categories',
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'name TEXT NOT NULL, '
              'created_at INTEGER',
        );
        await _createTableIfMissing(
          m,
          'recurring_expenses',
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'name TEXT NOT NULL, '
              'amount INTEGER NOT NULL, '
              'frequency TEXT, '
              'start_date INTEGER, '
              'end_date INTEGER, '
              'category_id INTEGER, '
              'status TEXT, '
              'created_at INTEGER',
        );
      }
      if (from < 15) {
        await _createTableIfMissing(
          m,
          'customer_debts',
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'customer_id INTEGER NOT NULL, '
              'customer_name TEXT NOT NULL, '
              'amount INTEGER NOT NULL, '
              'paid INTEGER DEFAULT 0, '
              'description TEXT, '
              'status TEXT, '
              'created_at INTEGER',
        );
        await _createTableIfMissing(
          m,
          'debt_payments',
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'debt_id INTEGER NOT NULL, '
              'amount INTEGER NOT NULL, '
              'note TEXT, '
              'created_at INTEGER',
        );
      }
      if (from < 16) {
        // ShiftSessions was added in v16 but has been removed & merged into Presensi
        // (columns now in attendance table via v18 migration below)
      }
      if (from < 17) {
        await _createTableIfMissing(
          m,
          'stock_counts',
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'name TEXT, '
              'status TEXT, '
              'created_at INTEGER, '
              'counted_by TEXT',
        );
        await _createTableIfMissing(
          m,
          'stock_count_items',
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'stock_count_id INTEGER NOT NULL, '
              'product_id INTEGER, '
              'product_name TEXT, '
              'system_stock INTEGER, '
              'actual_stock INTEGER, '
              'difference INTEGER, '
              'note TEXT',
        );
      }
      if (from < 18) {
        await _addColumnIfMissing(m, 'attendance', 'expected_cash', 'INTEGER');
        await _addColumnIfMissing(m, 'attendance', 'shift_notes', 'TEXT');
      }
      if (from < 19) {
        await _addColumnIfMissing(m, 'branches', 'address', 'TEXT');
        await _addColumnIfMissing(m, 'branches', 'phone', 'TEXT');
        await _addColumnIfMissing(m, 'branches', 'status', 'TEXT');
        await _addColumnIfMissing(m, 'settings', 'qris_image_path', 'TEXT');
        await _addColumnIfMissing(m, 'settings', 'receipt_header', 'TEXT');
        await _addColumnIfMissing(m, 'settings', 'receipt_paper_size', 'TEXT');
        await _addColumnIfMissing(m, 'settings', 'receipt_show_logo', 'INTEGER');
        await _addColumnIfMissing(m, 'settings', 'receipt_show_cashier', 'INTEGER');
        await _addColumnIfMissing(m, 'settings', 'receipt_show_invoice', 'INTEGER');
        await _addColumnIfMissing(m, 'settings', 'receipt_show_date', 'INTEGER');
        await _addColumnIfMissing(m, 'settings', 'receipt_show_barcode', 'INTEGER');
      }
      if (from < 20) {
        await _addColumnIfMissing(m, 'employees', 'nfc_tag', 'TEXT');
      }
      if (from < 21) {
        await _addColumnIfMissing(m, 'settings', 'pin_length', 'INTEGER');
      }
      if (from < 22) {
        await _addColumnIfMissing(m, 'employees', 'work_start', 'TEXT');
        await _addColumnIfMissing(m, 'employees', 'work_end', 'TEXT');
      }
      if (from < 23) {
        await _createTableIfMissing(
          m,
          'chat_sessions',
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'title TEXT, '
              'created_at INTEGER, '
              'updated_at INTEGER, '
              'messages TEXT',
        );
      }
      if (from < 24) {
        await _createTableIfMissing(
          m,
          'dining_tables',
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'name TEXT NOT NULL, '
              'status TEXT, '
              'created_at INTEGER',
        );
        await _createTableIfMissing(
          m,
          'laundry_orders',
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'invoice TEXT NOT NULL, '
              'customer_name TEXT NOT NULL, '
              'customer_phone TEXT, '
              'items TEXT, '
              'weight_kg REAL, '
              'total INTEGER NOT NULL, '
              'paid INTEGER DEFAULT 0, '
              'status TEXT, '
              'notes TEXT, '
              'created_at INTEGER, '
              'pickup_at INTEGER, '
              'estimated_ready INTEGER',
        );
        await _createTableIfMissing(
          m,
          'service_tickets',
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'ticket_no TEXT, '
              'customer_name TEXT, '
              'customer_phone TEXT, '
              'vehicle_plate TEXT, '
              'vehicle_brand TEXT, '
              'vehicle_year INTEGER, '
              'service_type TEXT, '
              'technician TEXT, '
              'queue_number INTEGER, '
              'sparepart_cost INTEGER, '
              'service_cost INTEGER, '
              'status TEXT, '
              'notes TEXT, '
              'created_at INTEGER, '
              'estimated_ready INTEGER',
        );
        await _createTableIfMissing(
          m,
          'appointments',
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'customer_name TEXT NOT NULL, '
              'customer_phone TEXT, '
              'service_name TEXT, '
              'date TEXT, '
              'time TEXT, '
              'status TEXT, '
              'notes TEXT, '
              'created_at INTEGER, '
              'estimated_duration INTEGER, '
              'counter_id INTEGER',
        );
        await _createTableIfMissing(
          m,
          'prescriptions',
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'patient_name TEXT NOT NULL, '
              'doctor TEXT, '
              'items TEXT, '
              'total INTEGER, '
              'status TEXT, '
              'notes TEXT, '
              'created_at INTEGER',
        );
        await _createTableIfMissing(
          m,
          'print_orders',
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'invoice TEXT NOT NULL, '
              'service_name TEXT NOT NULL, '
              'customer_name TEXT, '
              'quantity INTEGER DEFAULT 1, '
              'price INTEGER NOT NULL, '
              'status TEXT, '
              'notes TEXT, '
              'created_at INTEGER, '
              'pickup_at INTEGER, '
              'width_cm REAL, '
              'length_cm REAL, '
              'estimate_ready TEXT',
        );
      }
      if (from < 25) {
        await _addColumnIfMissing(m, 'employees', 'requires_attendance', 'INTEGER');
      }
      if (from < 26) {
        await _addColumnIfMissing(m, 'employees', 'requires_cash_open', 'INTEGER');
        await _addColumnIfMissing(m, 'employees', 'requires_cash_close', 'INTEGER');
      }
      if (from < 27) {
        // ── Self-healing (v2.2.34): DB restore lama bisa bawa kolom order_type
        // sudah ada tapi user_version < 27 → ALTER TABLE mentah error
        // "duplicate column name". Guard semua kolom v27 (skip kalau ada).
        await _addColumnIfMissing(m, 'transactions', 'order_type', 'TEXT');
        await _addColumnIfMissing(m, 'transactions', 'table_id', 'INTEGER');
        await _addColumnIfMissing(m, 'transactions', 'notes', 'TEXT');
        await _addColumnIfMissing(m, 'settings', 'kitchen_printer_address', 'TEXT');
        await _addColumnIfMissing(m, 'settings', 'kitchen_printer_enabled', 'INTEGER');
        await _createTableIfMissing(
          m,
          'open_tabs',
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'table_id INTEGER, '
              'order_type TEXT DEFAULT \'Dine In\', '
              'items_json TEXT NOT NULL, '
              'total INTEGER DEFAULT 0, '
              'discount INTEGER DEFAULT 0, '
              'status TEXT DEFAULT \'Open\', '
              'created_at INTEGER, '
              'updated_at INTEGER',
        );
      }
      if (from < 28) {
        await _addColumnIfMissing(m, 'laundry_orders', 'estimated_ready', 'INTEGER');
      }
      if (from < 29) {
        await _addColumnIfMissing(m, 'products', 'price_type', 'TEXT');
      }
      if (from < 30) {
        await _addColumnIfMissing(m, 'appointments', 'estimated_duration', 'INTEGER');
        await _addColumnIfMissing(m, 'appointments', 'counter_id', 'INTEGER');
      }
      if (from < 31) {
        await _addColumnIfMissing(m, 'service_tickets', 'plate_number', 'TEXT');
        await _addColumnIfMissing(m, 'service_tickets', 'vehicle_brand', 'TEXT');
        await _addColumnIfMissing(m, 'service_tickets', 'vehicle_year', 'INTEGER');
        await _addColumnIfMissing(m, 'service_tickets', 'technician', 'TEXT');
        await _addColumnIfMissing(m, 'service_tickets', 'sparepart_cost', 'INTEGER');
        await _addColumnIfMissing(m, 'service_tickets', 'service_cost', 'INTEGER');
        await _addColumnIfMissing(m, 'service_tickets', 'queue_number', 'INTEGER');
      }
      if (from < 32) {
        // Promo mode: 'otomatis' | 'kode' | 'bebas' (hybrid discount 3-arah)
        await _addColumnIfMissing(m, 'promos', 'mode', 'TEXT');
      }
      if (from < 33) {
        // Diskon standalone per produk (% potongan dari harga jual)
        await _addColumnIfMissing(m, 'products', 'discount_percent', 'INTEGER');
      }
      if (from < 34) {
        // RBAC: roles pindah ke SQLite (ikut backup/restore cloud antar device)
        await _createTableIfMissing(
          m,
          'roles',
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'name TEXT NOT NULL, '
              'permissions TEXT, '
              'created_at INTEGER',
        );
        // Sales per kasir: atribusi transaksi ke karyawan/sesi shift
        await _addColumnIfMissing(m, 'transactions', 'employee_id', 'INTEGER');
        await _addColumnIfMissing(m, 'transactions', 'session_id', 'INTEGER');
        // Backfill employeeId dari cashier_name yang tersimpan.
        // NOTE: raw SQL wajib pakai nama kolom SQLite (snake_case) — drift
        // memetakan cashierName → cashier_name, employeeId → employee_id.
        await _runIfColumnExists(m, 'transactions', 'employee_id', '''
          UPDATE transactions
          SET employee_id = (SELECT e.id FROM employees e WHERE e.name = transactions.cashier_name LIMIT 1)
          WHERE employee_id IS NULL AND cashier_name IS NOT NULL AND cashier_name != ''
        ''');
      }
      if (from < 35) {
        // Diskon fleksibel: % (persen) atau nominal uang (Rp) langsung.
        // Kolom baru discount_type; data lama otomatis 'persen' via default.
        await _addColumnIfMissing(m, 'products', 'discount_type', 'TEXT');
      }
      if (from < 36) {
        // Retur/refund parsial: tabel refunds mencatat barang dikembalikan
        // (stok balik) + uang dikembalikan per transaksi, agar laporan omzet,
        // HPP, top produk, dan kas shift akurat.
        await _createTableIfMissing(
          m,
          'refunds',
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'transaction_id INTEGER NOT NULL, '
              'product_id INTEGER, '
              'product_name TEXT NOT NULL, '
              'quantity INTEGER NOT NULL, '
              'amount INTEGER NOT NULL, '
              'reason TEXT, '
              'created_at INTEGER',
        );
      }
      if (from < 37) {
        // Riwayat poin per pelanggan (dapat / pakai) — untuk tampilan
        // "Poin History" di detail pelanggan & info poin di struk.
        await _createTableIfMissing(
          m,
          'point_histories',
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'customer_id INTEGER NOT NULL, '
              'points INTEGER NOT NULL, '
              'type TEXT, '
              'note TEXT, '
              'created_at INTEGER',
        );
      }
      if (from < 38) {
        // Pembelian supplier (restok): header + item. Saat pembelian
        // dicatat, stok produk masuk & harga modal (buyPrice) diperbarui
        // ke harga beli terbaru.
        await _createTableIfMissing(
          m,
          'purchase_orders',
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'invoice TEXT NOT NULL, '
              'supplier_id INTEGER, '
              'supplier_name TEXT, '
              'total INTEGER NOT NULL, '
              'status TEXT, '
              'note TEXT, '
              'created_at INTEGER, '
              'extra_costs_json TEXT',
        );
        await _createTableIfMissing(
          m,
          'purchase_order_items',
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'purchase_order_id INTEGER NOT NULL, '
              'product_id INTEGER, '
              'product_name TEXT NOT NULL, '
              'quantity INTEGER NOT NULL, '
              'price INTEGER NOT NULL, '
              'is_material INTEGER DEFAULT 0',
        );
      }
      if (from < 39) {
        // Bahan pembelian (non-produk, mis. plastik): item pembelian kini
        // bisa berupa bahan (isMaterial=1, productId nullable) yang hanya
        // dicatat riwayatnya — tanpa menyentuh stok produk. Riwayat harga
        // beli bahan per supplier disimpan di MaterialPrices.
        await _addColumnIfMissing(m, 'purchase_order_items', 'is_material', 'INTEGER');
        await _createTableIfMissing(
          m,
          'material_prices',
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'material_name TEXT NOT NULL, '
              'supplier_id INTEGER, '
              'price INTEGER NOT NULL, '
              'qty INTEGER DEFAULT 1, '
              'date INTEGER, '
              'note TEXT',
        );
      }
      if (from < 40) {
        // Catat pembelian mode POS: produk bisa terikat supplier langganan
        // (supplierId) + biaya tambahan (packing/ongkir/stiker) disimpan di
        // header pembelian (extraCostsJson) untuk HPP akurat.
        await _addColumnIfMissing(m, 'products', 'supplier_id', 'INTEGER');
        await _addColumnIfMissing(m, 'purchase_orders', 'extra_costs_json', 'TEXT');
      }
      if (from < 41) {
        // Sub-header struk (biasanya alamat toko) — baris teks di bawah
        // header/nama toko, sebelum invoice/tanggal (v2.2.30).
        await _addColumnIfMissing(m, 'settings', 'receipt_sub_header', 'TEXT');
      }
      if (from < 42) {
        // Percetakan (fotocopy upgrade): dimensi cetak + estimasi selesai
        // di order, dan tabel jenis layanan custom (tanpa icon bulat).
        await _addColumnIfMissing(m, 'print_orders', 'width_cm', 'REAL');
        await _addColumnIfMissing(m, 'print_orders', 'length_cm', 'REAL');
        await _addColumnIfMissing(m, 'print_orders', 'estimate_ready', 'TEXT');
        await _createTableIfMissing(
          m,
          'print_service_types',
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'name TEXT NOT NULL, '
              'is_default INTEGER DEFAULT 0, '
              'created_at INTEGER',
        );
        // Seed 6 layanan default — bisa diubah/ditambah user (CRUD).
        // NOTE: raw SQL wajib pakai nama kolom SQLite (snake_case):
        // isDefault → is_default. Hanya seed kalau tabel masih kosong
        // (supaya tidak dobel saat DB sudah pernah punya tabel ini).
        final existing = await m.database
            .customSelect('SELECT COUNT(*) AS c FROM print_service_types')
            .getSingle();
        if ((existing.read<int>('c') ?? 0) == 0) {
          for (final name in ['Fotocopy', 'Print Warna', 'Print B/W', 'Jilid', 'Laminating', 'Scan']) {
            await customStatement(
                "INSERT INTO print_service_types (name, is_default) VALUES ('$name', 1)");
          }
        }
      }
      if (from < 43) {
        // Piutang & cicilan (v2.2.34): DP/persen/nominal + opsi cicilan
        // CRUD + link transaksi→debt (status bayar sinkron di riwayat).
        await _addColumnIfMissing(m, 'transactions', 'dp_amount', 'INTEGER');
        await _addColumnIfMissing(m, 'transactions', 'installment_months', 'INTEGER');
        await _addColumnIfMissing(m, 'transactions', 'installment_per_month', 'INTEGER');
        await _addColumnIfMissing(m, 'transactions', 'debt_id', 'INTEGER');
        await _addColumnIfMissing(m, 'customer_debts', 'installment_months', 'INTEGER');
        // Opsi cicilan (CRUD owner) — seed default 1/2/3/6/12 bulan.
        await _createTableIfMissing(
          m,
          'installment_options',
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'months INTEGER NOT NULL, '
              'label TEXT, '
              'is_default INTEGER DEFAULT 0',
        );
        final instCount = await m.database
            .customSelect('SELECT COUNT(*) AS c FROM installment_options')
            .getSingle();
        if ((instCount.read<int>('c') ?? 0) == 0) {
          for (final months in [1, 2, 3, 6, 12]) {
            await customStatement(
                "INSERT INTO installment_options (months, label, is_default) "
                "VALUES ($months, '$months× bulanan', 1)");
          }
        }
        // Preset estimasi selesai Order Cetak (CRUD) — seed default.
        await _createTableIfMissing(
          m,
          'estimate_options',
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'label TEXT NOT NULL UNIQUE',
        );
        final estCount = await m.database
            .customSelect('SELECT COUNT(*) AS c FROM estimate_options')
            .getSingle();
        if ((estCount.read<int>('c') ?? 0) == 0) {
          for (final label in ['1 jam', '2 jam', '3 jam', 'Besok 10:00', 'Besok 14:00', '3 hari', '1 minggu']) {
            await customStatement(
                "INSERT INTO estimate_options (label) VALUES ('$label')");
          }
        }
      }
    },
  );
}

// ── Self-healing migration guards ──────────────────────────────────────────
// DB hasil restore cloud/backup lama bisa membawa struktur kolom yang SUDAH
// ada padahal `user_version` masih di bawah target (mis. kolom order_type ada
// tapi user_version < 27). Kalau `ALTER TABLE ... ADD COLUMN` dibiarkan jalan,
// SQLite melempar "duplicate column name" → migrasi gagal → seluruh aplikasi
// tidak bisa dipakai. Guard berikut mengecek pragma table_info dulu: kolom
// sudah ada → skip; belum ada → tambah. Idempoten & aman dipanggil ulang.

/// Run [sql] if column [column] does not exist yet in [table].
/// Raw SQL wajib pakai nama kolom SQLite (snake_case), bukan nama Dart.
Future<void> _runIfColumnMissing(
  Migrator m,
  String table,
  String column,
  String sql,
) async {
  final has = await m.database
      .customSelect('PRAGMA table_info($table)')
      .get()
      .then((rows) => rows.any((r) => r.read<String>('name') == column));
  if (!has) {
    await m.database.customStatement(sql);
  }
}

/// `ALTER TABLE [table] ADD COLUMN [column] [sqlType]` — skip jika kolom ada.
/// Drift memetakan nama Dart ke snake_case; [sqlType] contoh: 'TEXT', 'INTEGER'.
Future<void> _addColumnIfMissing(
  Migrator m,
  String table,
  String column,
  String sqlType,
) {
  return _runIfColumnMissing(
    m,
    table,
    column,
    'ALTER TABLE "$table" ADD COLUMN "$column" $sqlType',
  );
}

/// `CREATE TABLE IF NOT EXISTS [name] ([definition])` — tidak error bila ada.
Future<void> _createTableIfMissing(
  Migrator m,
  String name,
  String definition,
) {
  return m.database.customStatement(
    'CREATE TABLE IF NOT EXISTS "$name" ($definition)',
  );
}

/// Backfill [table].[column] dengan [sql] jika kolom ada (setelah
/// [_addColumnIfMissing]). Digunakan untuk data lama yang nilainya kosong.
Future<void> _runIfColumnExists(
  Migrator m,
  String table,
  String column,
  String sql,
) async {
  final has = await m.database
      .customSelect('PRAGMA table_info($table)')
      .get()
      .then((rows) => rows.any((r) => r.read<String>('name') == column));
  if (has) {
    await m.database.customStatement(sql);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = p.join(dir.path, 'nusa_kasir.sqlite');
    return NativeDatabase.createInBackground(File(file));
  });
}
