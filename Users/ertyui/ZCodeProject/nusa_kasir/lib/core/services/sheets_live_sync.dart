import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/transaction_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Live sync harian → tab "Transaksi" Google Sheets (v2.2.57+122).
///
/// Arsip 2-cloud (arsitektur user): Google Sheets = cloud PANAS (bulan
/// berjalan, user bisa baca realtime di spreadsheet), Supabase = cloud
/// DINGIN (backup SQLite via [AutoSyncService] — tidak diubah). Service ini
/// khusus tier panas:
///
///   `db.tableUpdates()` → debounce 2 dtk → kirim transaksi ke edge fn
///   `sheets-admin` action `append` (APPEND-ONLY, dedup by kolom Invoice di
///   server → idempotent: retry / 2 device / flush ganda tidak menduplikat).
///
/// Guard: hanya jalan bila (1) ada canonical UID, (2) spreadsheet sudah
/// di-link (SecureStore `nusa_sheets_id` diisi oleh SpreadsheetService
/// prepare). Bukan keduanya → senyap; sinkron penuh manual di layar
/// Spreadsheet tetap tersedia (Produk/Stok/Laporan ikut di situ).
///
/// Gagal = senyap (debugPrint) — tidak ada dialog/toast; baris yang gagal
/// terkirim akan dicoba lagi pada flush berikutnya karena tidak ada marker
/// lokal (server yang dedup).
class SheetsLiveSyncService {
  final AppDatabase db;

  static const _debounce = Duration(seconds: 2);
  static const _edgeFunction = 'sheets-admin';

  /// Batas transaksi yang dikirim per flush (terbaru). Dedup server by
  /// invoice membuat pengiriman ulang data lama tidak berefek.
  static const _maxRows = 200;

  StreamSubscription<dynamic>? _sub;
  Timer? _debounceTimer;
  bool _inFlight = false;
  bool _disposed = false;
  bool _pendingAfterFlight = false;

  SheetsLiveSyncService({required this.db});

  void start() {
    if (_sub != null) return;
    try {
      _sub = db.tableUpdates().listen((_) => _schedule());
    } catch (e) {
      debugPrint('[SheetsLive] watch start error: $e');
    }
  }

  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _debounceTimer?.cancel();
  }

  void _schedule() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => flushNow());
  }

  /// Kirim sekarang (dipanggil debounce; dipanggil juga saat app pause
  /// via [flushNow] publik).
  Future<void> flushNow() async {
    _debounceTimer?.cancel();
    if (_disposed) return;
    if (_inFlight) {
      // Jangan buang perubahan yang terjadi saat append berjalan.
      _pendingAfterFlight = true;
      return;
    }

    // Guard 1: identitas canonical (email/password atau Google).
    final uid = await SecureStore.resolveCanonicalUid();
    if (uid == null || uid.isEmpty) return;

    // Guard 2: spreadsheet sudah di-link (URL disimpan saat prepare).
    final url = await SecureStore.getSheetsId();
    if (url == null || url.isEmpty) return;
    final m = RegExp(r'/spreadsheets/d/([a-zA-Z0-9_-]+)').firstMatch(url);
    final spreadsheetId = m?.group(1);
    if (spreadsheetId == null || spreadsheetId.isEmpty) return;

    // Ambil transaksi terbaru (desc → potong _maxRows; server dedup by
    // invoice, jadi mengirim ulang yang lama tidak berefek).
    final rows = await _buildRows();
    if (rows.isEmpty) return;

    _inFlight = true;
    try {
      final res = await Supabase.instance.client.functions.invoke(
        _edgeFunction,
        body: {
          'action': 'append',
          'user_id': uid,
          'spreadsheet_id': spreadsheetId,
          'tab': 'Transaksi',
          'key_column_index': 0, // kolom Invoice
          'values': rows, // baris pertama = header (dedup otomatis)
        },
      );
      final data = res.data as Map<String, dynamic>?;
      if (res.status >= 400) {
        debugPrint(
            '[SheetsLive] ⚠ ${data?['error'] ?? 'HTTP ${res.status}'}');
      } else {
        final appended = data?['appended'];
        debugPrint('[SheetsLive] ✓ +$appended baris Transaksi');
      }
    } catch (e) {
      debugPrint('[SheetsLive] gagal (dicoba lagi flush berikutnya): $e');
    } finally {
      _inFlight = false;
      // Ada perubahan baru selama flight → flush lagi (coalesce 1 siklus).
      if (_pendingAfterFlight && !_disposed) {
        _pendingAfterFlight = false;
        _schedule();
      }
    }
  }

  /// Baris Transaksi — format PERSIS syncTransactions
  /// (spreadsheet_service.dart): header 9 kolom + data.
  Future<List<List<dynamic>>> _buildRows() async {
    final repo = TransactionRepository(db);
    List<Transaction> txs;
    try {
      txs = await repo.getTransactions();
    } catch (e) {
      debugPrint('[SheetsLive] baca transaksi gagal: $e');
      return [];
    }
    // Terbaru dulu, potong, lalu kirim urut lama→baru supaya append ke
    // sheet bersih tetap kronologis.
    final sorted = [...txs]
      ..sort((a, b) => b.date.compareTo(a.date));
    final latest = sorted.take(_maxRows).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (latest.isEmpty) return [];
    return [
      const [
        'Invoice', 'Tanggal', 'Total', 'Diskon', 'Metode',
        'Bayar', 'Kembali', 'Kasir', 'Status',
      ],
      for (final t in latest)
        [
          t.invoice,
          '${t.date.day}/${t.date.month}/${t.date.year} '
              '${t.date.hour.toString().padLeft(2, '0')}:'
              '${t.date.minute.toString().padLeft(2, '0')}',
          t.total,
          t.discount,
          t.paymentMethod,
          t.cashGiven ?? 0,
          t.cashReturn ?? 0,
          t.cashierName ?? '-',
          t.status,
        ],
    ];
  }
}
