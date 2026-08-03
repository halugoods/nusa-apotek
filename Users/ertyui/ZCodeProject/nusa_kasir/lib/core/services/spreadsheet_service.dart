import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/finance_repository.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';
import 'package:nusa_kasir/data/repositories/report_repository.dart';
import 'package:nusa_kasir/data/repositories/transaction_repository.dart';
import 'package:nusa_kasir/data/repositories/supplier_repository.dart';
import 'package:nusa_kasir/data/repositories/customer_repository.dart';
import 'package:nusa_kasir/data/repositories/promo_repository.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';

/// Result of a sync operation — carries success/failure + user-facing message.
class SyncResult {
  final bool ok;
  final String tab;
  final String? error;

  const SyncResult({required this.ok, required this.tab, this.error});
}

class SpreadsheetService {
  final GoogleSignIn _signIn = GoogleSignIn(
    scopes: [SheetsApi.spreadsheetsScope],
  );

  final AppDatabase db;
  SpreadsheetService(this.db);

  /// Maximum number of retries for transient API failures.
  static const _maxRetries = 3;

  /// Timeout for individual API calls.
  static const _apiTimeout = Duration(seconds: 30);

  Future<GoogleSignInAccount?> signIn() => _signIn.signIn();

  /// Try to restore previous session silently.
  Future<GoogleSignInAccount?> signInSilently() => _signIn.signInSilently();

  Future<void> signOut() => _signIn.disconnect();

  bool get isSignedIn => _signIn.currentUser != null;

  Future<SheetsApi?> _client() async {
    try {
      final authClient = await _signIn.authenticatedClient();
      if (authClient == null) {
        debugPrint('[Spreadsheet] authenticatedClient() returned null — no Sheets scope on token');
        return null;
      }
      return SheetsApi(authClient);
    } catch (e) {
      debugPrint('[Spreadsheet] _client() threw: $e');
      return null;
    }
  }

  /// Verifies the current sign-in actually has Sheets access.
  /// Returns empty string on success, or user-facing error message.
  Future<String> verifyAccess() async {
    final api = await _client();
    if (api == null) {
      return 'Token tidak memiliki akses Google Sheets.\n'
          'Pastikan Anda menyetujui izin "Spreadsheet" saat login Google.';
    }
    // Token is valid — authenticatedClient() succeeded
    return '';
  }

  /// Run an API call with retry + timeout.
  Future<T> _withRetry<T>(
    Future<T> Function() fn,
    String debugLabel,
  ) async {
    String? lastError;
    for (var attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        return await fn().timeout(_apiTimeout);
      } catch (e) {
        lastError = e.toString();
        debugPrint('[Spreadsheet] $debugLabel attempt $attempt/$_maxRetries failed: $e');
        if (attempt < _maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2)); // exponential backoff
        }
      }
    }
    throw Exception(lastError ?? 'Unknown error in $debugLabel');
  }

  /// Translate Google API errors into user-facing messages.
  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('apinotenabled') || msg.contains('403') || msg.contains('disabled')) {
      return 'Google Sheets API belum diaktifkan. Buka menu "Bantuan" untuk panduan setup.';
    }
    if (msg.contains('quota') || msg.contains('429')) {
      return 'Kuota Google Sheets tercapai. Coba beberapa saat lagi.';
    }
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return 'Koneksi ke Google lambat. Periksa internet dan coba lagi.';
    }
    if (msg.contains('not found') || msg.contains('404')) {
      return 'Spreadsheet tidak ditemukan — mungkin sudah dihapus. Coba buat ulang.';
    }
    return 'Gagal sinkron: $msg';
  }

  /// Find or create a per-user spreadsheet.
  Future<String?> findOrCreate(String email) async {
    final api = await _client();
    if (api == null) return null;
    final shortName = email.split('@').first;
    final title = 'NUSA Kasir - $shortName';
    try {
      final sheet = await _withRetry(
        () => api.spreadsheets.create(Spreadsheet(
          properties: SpreadsheetProperties(title: title),
          sheets: [
            Sheet(properties: SheetProperties(title: 'Produk')),
            Sheet(properties: SheetProperties(title: 'Transaksi')),
            Sheet(properties: SheetProperties(title: 'Stok')),
            Sheet(properties: SheetProperties(title: 'Laporan')),
            Sheet(properties: SheetProperties(title: 'Keuangan')),
            Sheet(properties: SheetProperties(title: 'Karyawan')),
            Sheet(properties: SheetProperties(title: 'Pelanggan')),
            Sheet(properties: SheetProperties(title: 'Supplier')),
            Sheet(properties: SheetProperties(title: 'Promo')),
            Sheet(properties: SheetProperties(title: 'Presensi')),
          ],
        )),
        'findOrCreate',
      );
      return sheet.spreadsheetId;
    } catch (e) {
      debugPrint('[Spreadsheet] findOrCreate API call failed: $e');
      rethrow;
    }
  }

  /// Write data to a sheet range with retry.
  Future<void> _writeValues(
    SheetsApi api,
    String spreadsheetId,
    String range,
    List<List<dynamic>> rows,
    String tabName,
  ) async {
    await _withRetry(
      () => api.spreadsheets.values.update(
        ValueRange(range: range, values: rows),
        spreadsheetId,
        range,
        valueInputOption: 'USER_ENTERED',
      ),
      'sync$tabName',
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  SYNC PER TAB
  // ═══════════════════════════════════════════════════════════

  Future<SyncResult> syncProducts(String spreadsheetId) async {
    const tab = 'Produk';
    try {
      final api = await _client();
      if (api == null) return SyncResult(ok: false, tab: tab, error: 'Tidak terhubung ke Google');
      final repo = ProductRepository(db);
      final products = await repo.getProducts();
      final rows = <List<dynamic>>[
        ['ID', 'Nama', 'SKU', 'Barcode', 'Kategori', 'Harga Beli', 'Harga Jual', 'Stok', 'Stok Min'],
        for (final p in products)
          [p.id, p.name, p.sku ?? '', p.barcode ?? '', p.category, p.buyPrice, p.sellPrice, p.stock, p.minStock],
      ];
      await _writeValues(api, spreadsheetId, '$tab!A1', rows, tab);
      return SyncResult(ok: true, tab: tab);
    } catch (e) {
      debugPrint('[Spreadsheet] syncProducts: $e');
      return SyncResult(ok: false, tab: tab, error: _friendlyError(e));
    }
  }

  Future<SyncResult> syncTransactions(String spreadsheetId) async {
    const tab = 'Transaksi';
    try {
      final api = await _client();
      if (api == null) return SyncResult(ok: false, tab: tab, error: 'Tidak terhubung ke Google');
      final repo = TransactionRepository(db);
      final txs = await repo.getTransactions();
      final rows = <List<dynamic>>[
        ['Invoice', 'Tanggal', 'Total', 'Diskon', 'Metode', 'Bayar', 'Kembali', 'Kasir', 'Status'],
        for (final t in txs)
          [t.invoice, '${t.date.day}/${t.date.month}/${t.date.year} ${t.date.hour.toString().padLeft(2, '0')}:${t.date.minute.toString().padLeft(2, '0')}', t.total, t.discount, t.paymentMethod, t.cashGiven ?? 0, t.cashReturn ?? 0, t.cashierName ?? '-', t.status],
      ];
      await _writeValues(api, spreadsheetId, '$tab!A1', rows, tab);
      return SyncResult(ok: true, tab: tab);
    } catch (e) {
      debugPrint('[Spreadsheet] syncTransactions: $e');
      return SyncResult(ok: false, tab: tab, error: _friendlyError(e));
    }
  }

  Future<SyncResult> syncStock(String spreadsheetId) async {
    const tab = 'Stok';
    try {
      final api = await _client();
      if (api == null) return SyncResult(ok: false, tab: tab, error: 'Tidak terhubung ke Google');
      final movements = await (db.select(db.stockMovements)
            ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
          .get();
      final products = await ProductRepository(db).getProducts();
      final nameOf = {for (final p in products) p.id: p.name};
      final rows = <List<dynamic>>[
        ['Tanggal', 'Produk', 'Tipe', 'Qty', 'Catatan'],
        for (final m in movements)
          ['${m.date.day}/${m.date.month}/${m.date.year} ${m.date.hour}:${m.date.minute}', nameOf[m.productId] ?? '#${m.productId}', m.type, m.qty, m.note ?? ''],
      ];
      await _writeValues(api, spreadsheetId, '$tab!A1', rows, tab);
      return SyncResult(ok: true, tab: tab);
    } catch (e) {
      debugPrint('[Spreadsheet] syncStock: $e');
      return SyncResult(ok: false, tab: tab, error: _friendlyError(e));
    }
  }

  Future<SyncResult> syncLaporan(String spreadsheetId) async {
    const tab = 'Laporan';
    try {
      final api = await _client();
      if (api == null) return SyncResult(ok: false, tab: tab, error: 'Tidak terhubung ke Google');
      final reportRepo = ReportRepository(db);
      final summary = await reportRepo.summary();
      final pl = await reportRepo.profitLoss();
      final rows = <List<dynamic>>[
        ['Metrik', 'Nilai'],
        ['Omzet', summary['omzet']],
        ['Jumlah Transaksi', summary['count']],
        ['Rata-rata Transaksi', summary['avg']],
        ['', ''],
        ['--- Laba Rugi ---', ''],
        ['Pendapatan', pl['pendapatan']],
        ['HPP', pl['hpp']],
        ['Laba Kotor', pl['labaKotor']],
        ['Pengeluaran', pl['expenses']],
        ['Payroll', pl['payroll']],
        ['Waste', pl['waste']],
        ['Likuiditas Masuk', pl['liquidityIn']],
        ['Likuiditas Keluar', pl['liquidityOut']],
        ['Total Beban', pl['totalBeban']],
        ['Laba Bersih', pl['labaBersih']],
      ];
      await _writeValues(api, spreadsheetId, '$tab!A1', rows, tab);
      return SyncResult(ok: true, tab: tab);
    } catch (e) {
      debugPrint('[Spreadsheet] syncLaporan: $e');
      return SyncResult(ok: false, tab: tab, error: _friendlyError(e));
    }
  }

  Future<SyncResult> syncKeuangan(String spreadsheetId) async {
    const tab = 'Keuangan';
    try {
      final api = await _client();
      if (api == null) return SyncResult(ok: false, tab: tab, error: 'Tidak terhubung ke Google');
      final repo = FinanceRepository(db);
      final expenses = await repo.getExpenses();
      final payroll = await repo.getPayroll();
      final waste = await repo.getWaste();
      final recurring = await repo.getRecurring();
      final liquidity = await repo.getLiquidity();
      final rows = <List<dynamic>>[
        ['TIPE', 'KATEGORI', 'KETERANGAN', 'JUMLAH', 'TANGGAL / INFO'],
        ...expenses.map((e) => ['Pengeluaran', e.category, e.description, e.amount, '${e.date.day}/${e.date.month}/${e.date.year}']),
        ...payroll.map((p) => ['Payroll', 'Karyawan #${p.employeeId}', p.period, p.salary + p.bonus - p.deduction, p.status]),
        ...waste.map((w) => ['Waste', 'Produk #${w.productId}', w.reason ?? '', w.qty, '${w.date.day}/${w.date.month}/${w.date.year}']),
        ...recurring.where((r) => r.active).map((r) => ['Berulang', r.category, r.description, r.amount, 'Next: ${r.nextDate.day}/${r.nextDate.month}/${r.nextDate.year}']),
        ...liquidity.map((l) => [l.type == 'in' ? 'Likuiditas Masuk' : 'Likuiditas Keluar', l.category, l.description, l.amount, '${l.date.day}/${l.date.month}/${l.date.year}']),
      ];
      await _writeValues(api, spreadsheetId, '$tab!A1', rows, tab);
      return SyncResult(ok: true, tab: tab);
    } catch (e) {
      debugPrint('[Spreadsheet] syncKeuangan: $e');
      return SyncResult(ok: false, tab: tab, error: _friendlyError(e));
    }
  }

  Future<SyncResult> syncKaryawan(String spreadsheetId) async {
    const tab = 'Karyawan';
    try {
      final api = await _client();
      if (api == null) return SyncResult(ok: false, tab: tab, error: 'Tidak terhubung ke Google');
      final emps = await (db.select(db.employees)
            ..orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]))
          .get();
      final rows = <List<dynamic>>[
        ['ID', 'Nama', 'Role', 'Status', 'No WA', 'Gaji Pokok', 'Mulai Kerja'],
        for (final e in emps)
          [e.id, e.name, e.role, e.status ?? 'Aktif', e.phone ?? '',
           e.baseSalary != null ? formatRupiah(e.baseSalary!) : '',
           e.startDate != null ? '${e.startDate!.day}/${e.startDate!.month}/${e.startDate!.year}' : ''],
      ];
      await _writeValues(api, spreadsheetId, '$tab!A1', rows, tab);
      return SyncResult(ok: true, tab: tab);
    } catch (e) {
      debugPrint('[Spreadsheet] syncKaryawan: $e');
      return SyncResult(ok: false, tab: tab, error: _friendlyError(e));
    }
  }

  Future<SyncResult> syncPelanggan(String spreadsheetId) async {
    const tab = 'Pelanggan';
    try {
      final api = await _client();
      if (api == null) return SyncResult(ok: false, tab: tab, error: 'Tidak terhubung ke Google');
      final custRepo = CustomerRepository(db);
      final customers = await custRepo.getCustomers();
      final rows = <List<dynamic>>[
        ['ID', 'Nama', 'No HP', 'Level', 'Total Belanja', 'Poin'],
        for (final c in customers)
          [c.id, c.name, c.phone ?? '', c.level, c.totalSpent, c.points],
      ];
      await _writeValues(api, spreadsheetId, '$tab!A1', rows, tab);
      return SyncResult(ok: true, tab: tab);
    } catch (e) {
      debugPrint('[Spreadsheet] syncPelanggan: $e');
      return SyncResult(ok: false, tab: tab, error: _friendlyError(e));
    }
  }

  Future<SyncResult> syncSupplier(String spreadsheetId) async {
    const tab = 'Supplier';
    try {
      final api = await _client();
      if (api == null) return SyncResult(ok: false, tab: tab, error: 'Tidak terhubung ke Google');
      final suppRepo = SupplierRepository(db);
      final suppliers = await suppRepo.getSuppliers();
      final rows = <List<dynamic>>[
        ['ID', 'Nama', 'Kontak', 'No HP', 'Alamat', 'Catatan'],
        for (final s in suppliers)
          [s.id, s.name, s.contactPerson ?? '', s.phone ?? '', s.address ?? '', s.note ?? ''],
      ];
      await _writeValues(api, spreadsheetId, '$tab!A1', rows, tab);
      return SyncResult(ok: true, tab: tab);
    } catch (e) {
      debugPrint('[Spreadsheet] syncSupplier: $e');
      return SyncResult(ok: false, tab: tab, error: _friendlyError(e));
    }
  }

  Future<SyncResult> syncPromo(String spreadsheetId) async {
    const tab = 'Promo';
    try {
      final api = await _client();
      if (api == null) return SyncResult(ok: false, tab: tab, error: 'Tidak terhubung ke Google');
      final promoRepo = PromoRepository(db);
      final promos = await promoRepo.getPromos();
      final rows = <List<dynamic>>[
        ['ID', 'Nama', 'Kode', 'Tipe', 'Nilai', 'Min Belanja', 'Berlaku', 'Kadaluarsa', 'Status', 'Terpakai'],
        for (final p in promos)
          [p.id, p.name, p.code, p.type, p.value, p.minBelanja,
           p.startDate != null ? '${p.startDate!.day}/${p.startDate!.month}/${p.startDate!.year}' : '',
           p.endDate != null ? '${p.endDate!.day}/${p.endDate!.month}/${p.endDate!.year}' : '',
           p.status, p.usedCount],
      ];
      await _writeValues(api, spreadsheetId, '$tab!A1', rows, tab);
      return SyncResult(ok: true, tab: tab);
    } catch (e) {
      debugPrint('[Spreadsheet] syncPromo: $e');
      return SyncResult(ok: false, tab: tab, error: _friendlyError(e));
    }
  }

  Future<SyncResult> syncPresensi(String spreadsheetId) async {
    const tab = 'Presensi';
    try {
      final api = await _client();
      if (api == null) return SyncResult(ok: false, tab: tab, error: 'Tidak terhubung ke Google');
      final atts = await (db.select(db.attendance)
            ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
          .get();
      final emps = await (db.select(db.employees)).get();
      final nameOf = {for (final e in emps) e.id: e.name};
      final rows = <List<dynamic>>[
        ['Tanggal', 'Karyawan', 'Role', 'Jam Masuk', 'Jam Pulang', 'Kas Awal', 'Kas Akhir', 'Status'],
        for (final a in atts)
          ['${a.date.day}/${a.date.month}/${a.date.year}', nameOf[a.employeeId] ?? '#${a.employeeId}',
           emps.where((e) => e.id == a.employeeId).firstOrNull?.role ?? '',
           a.checkIn ?? '-', a.checkOut ?? '-',
           a.pettyCash != null ? formatRupiah(a.pettyCash!) : '-',
           a.finalCash != null ? formatRupiah(a.finalCash!) : '-',
           a.status ?? 'Hadir'],
      ];
      await _writeValues(api, spreadsheetId, '$tab!A1', rows, tab);
      return SyncResult(ok: true, tab: tab);
    } catch (e) {
      debugPrint('[Spreadsheet] syncPresensi: $e');
      return SyncResult(ok: false, tab: tab, error: _friendlyError(e));
    }
  }

  /// Convenience: sync all tabs sequentially. Returns list of per-tab results.
  Future<List<SyncResult>> syncAll(String spreadsheetId) async {
    final results = <SyncResult>[];
    results.add(await syncProducts(spreadsheetId));
    results.add(await syncTransactions(spreadsheetId));
    results.add(await syncStock(spreadsheetId));
    results.add(await syncLaporan(spreadsheetId));
    results.add(await syncKeuangan(spreadsheetId));
    results.add(await syncKaryawan(spreadsheetId));
    results.add(await syncPelanggan(spreadsheetId));
    results.add(await syncSupplier(spreadsheetId));
    results.add(await syncPromo(spreadsheetId));
    results.add(await syncPresensi(spreadsheetId));
    return results;
  }
}
