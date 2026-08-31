import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/finance_repository.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';
import 'package:nusa_kasir/data/repositories/report_repository.dart';
import 'package:nusa_kasir/data/repositories/transaction_repository.dart';
import 'package:nusa_kasir/data/repositories/supplier_repository.dart';
import 'package:nusa_kasir/data/repositories/customer_repository.dart';
import 'package:nusa_kasir/data/repositories/promo_repository.dart';
import 'package:nusa_kasir/data/repositories/settings_repository.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';

/// Result of a sync operation — carries success/failure + user-facing message.
class SyncResult {
  final bool ok;
  final String tab;
  final String? error;

  const SyncResult({required this.ok, required this.tab, this.error});
}

/// Hasil persiapan/akses spreadsheet (create atau buka link yang sudah ada).
class SpreadsheetLinkResult {
  final String spreadsheetId;
  final String url;
  final bool createdNow;
  final String? error;

  const SpreadsheetLinkResult({
    required this.spreadsheetId,
    required this.url,
    this.createdNow = false,
    this.error,
  });
}

/// Google Sheets Terpusat (v2.2.57+121) — Company API via edge fn
/// `sheets-admin` di nusa-online.
///
/// App TIDAK login Google lagi. Server (service account milik NUSA) yang
/// membuat & mengisi spreadsheet tiap user; app cukup kirim `user_id`
/// (canonical UID) + rows + request format JSON, server yang menulis ke
/// Google Sheets atas nama service account.
///
/// Alur:
///   1. `prepare(userId, email, storeName, variant)` → create atau buka
///      link kontinu (1 spreadsheet per user, dibuat sekali, dipakai terus).
///   2. `syncXxx` → bangun rows + request format → `_sendTab` kirim ke
///      edge fn action `write` (validasi kepemilikan spreadsheet).
///
/// Request format dikirim sebagai JSON polos (Map) dan diteruskan verbatim
/// oleh server ke Google Sheets batchUpdate — lihat `_formatSheet`.
class SpreadsheetService {
  final AppDatabase db;
  SpreadsheetService(this.db);

  /// Maximum number of retries for transient API failures.
  static const _maxRetries = 2;

  /// Timeout for individual API calls.
  static const _apiTimeout = Duration(seconds: 30);

  static const String _edgeFunction = 'sheets-admin';

  /// Identitas canonical (nusa_account_uid → nusa_google_user_id).
  static Future<String?> uid() => SecureStore.resolveCanonicalUid();

  /// Email Google user yang dipakai saat login app (untuk share spreadsheet).
  Future<String> email() async {
    final saved = await SecureStore.getSheetsEmail();
    if (saved != null && saved.isNotEmpty) return saved;
    final googleEmail = await SecureStore.read(key: 'nusa_google_email');
    return googleEmail ?? '';
  }

  Future<String> storeName() async =>
      SettingsRepository(db).getStoreName().catchError((_) => '');

  /// Run an API call with retry + timeout.
  Future<T> _withRetry<T>(Future<T> Function() fn, String debugLabel) async {
    String? lastError;
    for (var attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        return await fn().timeout(_apiTimeout);
      } catch (e) {
        lastError = e.toString();
        debugPrint('[Spreadsheet] $debugLabel attempt $attempt/$_maxRetries failed: $e');
        if (attempt < _maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    }
    throw Exception(lastError ?? 'Unknown error in $debugLabel');
  }

  /// Translate edge function errors into user-facing messages.
  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('belum aktif') || msg.contains('hubungi admin')) {
      return 'Fitur spreadsheet belum aktif. Hubungi admin NUSA untuk mengaktifkan.';
    }
    if (msg.contains('quota') || msg.contains('429')) {
      return 'Kuota Google Sheets tercapai. Coba beberapa saat lagi.';
    }
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return 'Koneksi ke server lambat. Periksa internet dan coba lagi.';
    }
    if (msg.contains('403')) {
      return 'Spreadsheet bukan milik Anda — sinkronisasi ditolak server.';
    }
    return 'Gagal sinkron: $msg';
  }

  /// Invoke edge fn `sheets-admin` dengan retry untuk error transient.
  Future<Map<String, dynamic>> _invoke(String action, Map<String, dynamic> body) async {
    return _withRetry(() async {
      final res = await Supabase.instance.client.functions.invoke(
        _edgeFunction,
        body: {'action': action, ...body},
      );
      final data = res.data as Map<String, dynamic>?;
      if (res.status >= 400) {
        final err = (data?['error'] as String?) ?? 'HTTP ${res.status}';
        throw Exception(err);
      }
      return data ?? <String, dynamic>{};
    }, action);
  }

  /// Pastikan spreadsheet user ada (create kalau belum) → balikin link.
  /// Link KONTINU: 1 spreadsheet per user, dibuat sekali, dipakai terus.
  Future<SpreadsheetLinkResult> prepare({
    required String userId,
    required String email,
    required String storeName,
  }) async {
    try {
      // 1. Coba ambil link yang sudah ada.
      Map<String, dynamic>? existing;
      try {
        existing = await _invoke('get_link', {'user_id': userId});
      } catch (_) {
        existing = null; // 404 = belum ada
      }
      if (existing != null &&
          existing['spreadsheet_id'] is String &&
          existing['spreadsheet_url'] is String) {
        return SpreadsheetLinkResult(
          spreadsheetId: existing['spreadsheet_id'] as String,
          url: existing['spreadsheet_url'] as String,
        );
      }

      // 2. Belum ada → buat.
      final created = await _invoke('create_spreadsheet', {
        'user_id': userId,
        'email': email,
        'store_name': storeName,
        'variant': NusaConfig.productId,
      });
      final id = created['spreadsheet_id'] as String?;
      final url = created['spreadsheet_url'] as String?;
      if (id == null || url == null) {
        return const SpreadsheetLinkResult(
          spreadsheetId: '',
          url: '',
          error: 'Server belum siap membuat spreadsheet.',
        );
      }
      await SecureStore.saveSheetsId(url);
      return SpreadsheetLinkResult(
        spreadsheetId: id,
        url: url,
        createdNow: created['created_now'] == true,
      );
    } catch (e) {
      debugPrint('[Spreadsheet] prepare: $e');
      return SpreadsheetLinkResult(
        spreadsheetId: '',
        url: '',
        error: _friendlyError(e),
      );
    }
  }

  /// Kirim data + request format satu tab ke server (action `write`).
  Future<void> _sendTab(
    String userId,
    String spreadsheetId,
    String tab,
    List<List<dynamic>> rows,
    List<Map<String, dynamic>> requests,
  ) async {
    await _invoke('write', {
      'user_id': userId,
      'spreadsheet_id': spreadsheetId,
      'tab': tab,
      'values': rows,
      'requests': requests,
    });
  }

  // ── Cold tier: arsip bulan lama (Blok 4 MASTER LIST) ────────────────

  /// Daftar arsip bulanan user (bulan + tab + jumlah baris).
  /// [bulan]/[tab] opsional untuk filter.
  Future<List<Map<String, dynamic>>> fetchArchives({
    String? bulan,
    String? tab,
  }) async {
    final userId = await SpreadsheetService.uid();
    if (userId == null || userId.isEmpty) return [];
    final body = <String, dynamic>{'user_id': userId};
    if (bulan != null) body['bulan'] = bulan;
    if (tab != null) body['tab'] = tab;
    final res = await _invoke('get_archives', body);
    final list = res['archives'] as List?;
    return list?.whereType<Map<String, dynamic>>().toList() ?? [];
  }

  /// Ambil ISI arsip satu bulan+tab (rows JSON dari Supabase).
  Future<List<List<dynamic>>> fetchArchiveRows({
    required String bulan,
    required String tab,
  }) async {
    final userId = await SpreadsheetService.uid();
    if (userId == null || userId.isEmpty) return [];
    final res = await _invoke('get_archives', {
      'user_id': userId,
      'bulan': bulan,
      'tab': tab,
    });
    final list = res['archives'] as List?;
    if (list == null || list.isEmpty) return [];
    final rows = (list.first as Map<String, dynamic>)['rows'] as List?;
    return rows?.map((r) => (r as List).toList()).toList() ?? [];
  }

  /// ── Formatting builder ─────────────────────────────────────────────
  /// Bangun request batchUpdate JSON (diteruskan verbatim oleh server ke
  /// Google Sheets API). `sheetId` = index tab (0-based, sesuai urutan
  /// tab yang dibuat server di `create_spreadsheet`).

  static const _tabIndexes = {
    'Laporan': 0,
    'Produk': 1,
    'Transaksi': 2,
    'Stok': 3,
    'Keuangan': 4,
    'Karyawan': 5,
    'Pelanggan': 6,
    'Supplier': 7,
    'Promo': 8,
    'Presensi': 9,
  };

  /// Header tab standar: freeze baris 1 + warna biru + teks putih + lebar kolom.
  List<Map<String, dynamic>> headerRequests(
    String tab, {
    required int columnCount,
    List<double>? widths,
  }) {
    final sheetId = _tabIndexes[tab] ?? 0;
    return [
      {
        'updateSheetProperties': {
          'properties': {
            'sheetId': sheetId,
            'gridProperties': {'frozenRowCount': 1},
          },
          'fields': 'gridProperties.frozenRowCount',
        },
      },
      {
        'repeatCell': {
          'range': {
            'sheetId': sheetId,
            'startRowIndex': 0,
            'endRowIndex': 1,
            'startColumnIndex': 0,
            'endColumnIndex': columnCount,
          },
          'cell': {
            'userEnteredFormat': {
              'backgroundColor': {'red': 0.10, 'green': 0.30, 'blue': 0.55},
              'textFormat': {
                'foregroundColor': {'red': 1, 'green': 1, 'blue': 1},
                'bold': true,
                'fontSize': 11,
              },
              'horizontalAlignment': 'CENTER',
              'verticalAlignment': 'MIDDLE',
            },
          },
          'fields':
              'userEnteredFormat(backgroundColor,textFormat,horizontalAlignment,verticalAlignment)',
        },
      },
      if (widths != null)
        for (final (i, w) in widths.indexed)
          {
            'updateDimensionProperties': {
              'range': {
                'sheetId': sheetId,
                'dimension': 'COLUMNS',
                'startIndex': i,
                'endIndex': i + 1,
              },
              'properties': {'pixelSize': (w * 7).round()},
              'fields': 'pixelSize',
            },
          },
    ];
  }

  /// Merge sel (untuk title bar).
  Map<String, dynamic> _merge(
    int sheetId,
    int r0,
    int r1,
    int c0,
    int c1,
  ) =>
      {
        'mergeCells': {
          'range': {
            'sheetId': sheetId,
            'startRowIndex': r0,
            'endRowIndex': r1,
            'startColumnIndex': c0,
            'endColumnIndex': c1,
          },
          'mergeType': 'MERGE_ALL',
        },
      };

  /// Isi sel dengan teks + styling (warna latar, warna teks, bold, ukuran,
  /// alignment, format angka, wrap).
  Map<String, dynamic> _cell({
    required int sheetId,
    required int row,
    required int col,
    required String value,
    double? red,
    double? green,
    double? blue,
    String? fg,
    bool bold = false,
    double? fontSize,
    String? halign,
    String? valign,
    String? numberFormat,
    bool wrap = false,
  }) {
    final bg = (red == null && green == null && blue == null)
        ? null
        : {'red': red, 'green': green, 'blue': blue};
    Map<String, dynamic>? fgColor;
    if (fg != null) {
      final f = fg.replaceFirst('#', '');
      final r = int.parse(f.substring(0, 2), radix: 16) / 255.0;
      final g = int.parse(f.substring(2, 4), radix: 16) / 255.0;
      final b = int.parse(f.substring(4, 6), radix: 16) / 255.0;
      fgColor = {'red': r, 'green': g, 'blue': b};
    }
    return {
      'updateCells': {
        'range': {
          'sheetId': sheetId,
          'startRowIndex': row,
          'endRowIndex': row + 1,
          'startColumnIndex': col,
          'endColumnIndex': col + 1,
        },
        'rows': [
          {
            'values': [
              {
                'userEnteredValue': {'stringValue': value},
                if (bg != null) 'userEnteredFormat': {
                  'backgroundColor': bg,
                  'textFormat': {
                    if (fgColor != null) 'foregroundColor': fgColor,
                    if (bold) 'bold': true,
                    if (fontSize != null) 'fontSize': fontSize,
                  },
                  if (halign != null) 'horizontalAlignment': halign,
                  if (valign != null) 'verticalAlignment': valign,
                  if (numberFormat != null) 'numberFormat': {
                    'type': 'NUMBER',
                    'pattern': numberFormat,
                  },
                  if (wrap) 'wrapStrategy': 'WRAP',
                },
              },
            ],
          },
        ],
        'fields':
            'userEnteredValue,userEnteredFormat(backgroundColor,textFormat,horizontalAlignment,verticalAlignment,numberFormat,wrapStrategy)',
      },
    };
  }

  // ═══════════════════════════════════════════════════════════
  //  SYNC PER TAB
  // ═══════════════════════════════════════════════════════════

  Future<SyncResult> syncProducts(
    String userId,
    String spreadsheetId, {
    List<Map<String, dynamic>>? formatRequests,
  }) async {
    const tab = 'Produk';
    try {
      final repo = ProductRepository(db);
      final products = await repo.getProducts();
      final rows = <List<dynamic>>[
        ['ID', 'Nama', 'SKU', 'Barcode', 'Kategori', 'Harga Beli', 'Harga Jual', 'Stok', 'Stok Min'],
        for (final p in products)
          [p.id, p.name, p.sku ?? '', p.barcode ?? '', p.category, p.buyPrice, p.sellPrice, p.stock, p.minStock],
      ];
      await _sendTab(
        userId,
        spreadsheetId,
        tab,
        rows,
        formatRequests ?? headerRequests(tab, columnCount: 9),
      );
      return const SyncResult(ok: true, tab: tab);
    } catch (e) {
      debugPrint('[Spreadsheet] syncProducts: $e');
      return SyncResult(ok: false, tab: tab, error: _friendlyError(e));
    }
  }

  Future<SyncResult> syncTransactions(
    String userId,
    String spreadsheetId, {
    List<Map<String, dynamic>>? formatRequests,
  }) async {
    const tab = 'Transaksi';
    try {
      final repo = TransactionRepository(db);
      final txs = await repo.getTransactions();
      final rows = <List<dynamic>>[
        ['Invoice', 'Tanggal', 'Total', 'Diskon', 'Metode', 'Bayar', 'Kembali', 'Kasir', 'Status'],
        for (final t in txs)
          [t.invoice, '${t.date.day}/${t.date.month}/${t.date.year} ${t.date.hour.toString().padLeft(2, '0')}:${t.date.minute.toString().padLeft(2, '0')}', t.total, t.discount, t.paymentMethod, t.cashGiven ?? 0, t.cashReturn ?? 0, t.cashierName ?? '-', t.status],
      ];
      await _sendTab(
        userId,
        spreadsheetId,
        tab,
        rows,
        formatRequests ?? headerRequests(tab, columnCount: 9),
      );
      return const SyncResult(ok: true, tab: tab);
    } catch (e) {
      debugPrint('[Spreadsheet] syncTransactions: $e');
      return SyncResult(ok: false, tab: tab, error: _friendlyError(e));
    }
  }

  Future<SyncResult> syncStock(
    String userId,
    String spreadsheetId, {
    List<Map<String, dynamic>>? formatRequests,
  }) async {
    const tab = 'Stok';
    try {
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
      await _sendTab(
        userId,
        spreadsheetId,
        tab,
        rows,
        formatRequests ?? headerRequests(tab, columnCount: 5),
      );
      return const SyncResult(ok: true, tab: tab);
    } catch (e) {
      debugPrint('[Spreadsheet] syncStock: $e');
      return SyncResult(ok: false, tab: tab, error: _friendlyError(e));
    }
  }

  /// ── Template Laporan (NON-FLAT, flagship) ─────────────────────────
  /// Bukan tabel metrik flat lagi: KPI cards berwarna, section Laba Rugi
  /// dengan header + zebra, ranking Top Produk. Dibangun dengan request
  /// format JSON yang dikirim server (batchUpdate verbatim).
  Future<SyncResult> syncLaporan(
    String userId,
    String spreadsheetId,
    String storeName, {
    List<Map<String, dynamic>>? formatRequests,
  }) async {
    const tab = 'Laporan';
    const sheetId = 0;
    try {
      final reportRepo = ReportRepository(db);
      final summary = await reportRepo.summary();
      final pl = await reportRepo.profitLoss();
      final top = await reportRepo.topProducts();

      final rupiah = (int v) => 'Rp ${formatRupiah(v)}';
      final omzet = (summary['omzet'] as int?) ?? 0;
      final count = (summary['count'] as int?) ?? 0;
      final avg = (summary['avg'] as int?) ?? 0;
      final title = storeName.trim().isEmpty ? 'LAPORAN NUSA' : 'LAPORAN NUSA — ${storeName.trim()}';

      // Baris (0-based):
      //  0  title bar (merged A:E)
      //  1  KPI label row (Omzet | Transaksi | Rata-rata | Laba Bersih)  → merged A:C / D:E
      //  2  KPI value row
      //  3  (spacer)
      //  4  section header "Laba Rugi" (merged A:E)
      //  5+ P&L rows: [label (A), '', '', value (D), '']
      //  blank + section "Produk Terlaris" (merged A:E)
      //  rank rows
      final rows = <List<dynamic>>[];
      rows.add([title, '', '', '', '']);
      rows.add(['OMZET', '', 'TRANSAKSI', '', 'RATA-RATA']);
      rows.add([rupiah(omzet), '', '$count', '', rupiah(avg)]);
      rows.add(['', '', '', '', '']);

      // Laba Rugi — 12 baris tetap (label) + nilai.
      rows.add(['LABA RUGI', '', '', '', '']);
      const plKeys = [
        'pendapatan', 'hpp', 'retur', 'hppRetur', 'labaKotor',
        'expenses', 'payroll', 'waste', 'liquidityIn',
        'liquidityOut', 'totalBeban', 'labaBersih',
      ];
      for (final k in plKeys) {
        rows.add([_plLabel(k), '', '', rupiah((pl[k] as int?) ?? 0), '']);
      }

      // Produk Terlaris — Top 5.
      rows.add(['', '', '', '', '']);
      rows.add(['PRODUK TERLARIS', '', '', '', '']);
      rows.add(['#', 'Nama', 'Kategori', 'Terjual', 'Omzet']);
      for (final (i, p) in top.take(5).toList().indexed) {
        rows.add([(i + 1).toString(), p['name'], p['category'], '${p['qty']}', rupiah((p['revenue'] as int?) ?? 0)]);
      }

      // ── Request format ──
      final reqs = <Map<String, dynamic>>[
        // Freeze baris atas (title + KPI tetap terlihat saat scroll).
        {
          'updateSheetProperties': {
            'properties': {
              'sheetId': sheetId,
              'gridProperties': {'frozenRowCount': 3},
            },
            'fields': 'gridProperties.frozenRowCount',
          },
        },
        // Title bar: merge A:E, warna gelap, teks putih besar.
        _merge(sheetId, 0, 1, 0, 5),
        _cell(
          sheetId: sheetId, row: 0, col: 0, value: title,
          red: 0.08, green: 0.20, blue: 0.40,
          fg: '#FFFFFF', bold: true, fontSize: 16,
          halign: 'CENTER', valign: 'MIDDLE',
        ),
        // KPI label row: warna soft, bold kecil.
        _cell(sheetId: sheetId, row: 1, col: 0, value: 'OMZET',
            red: 0.86, green: 0.92, blue: 0.86, bold: true, fontSize: 11,
            halign: 'CENTER', valign: 'MIDDLE'),
        _cell(sheetId: sheetId, row: 1, col: 2, value: 'TRANSAKSI',
            red: 0.86, green: 0.90, blue: 0.95, bold: true, fontSize: 11,
            halign: 'CENTER', valign: 'MIDDLE'),
        _cell(sheetId: sheetId, row: 1, col: 4, value: 'RATA-RATA',
            red: 0.91, green: 0.88, blue: 0.96, bold: true, fontSize: 11,
            halign: 'CENTER', valign: 'MIDDLE'),
        // KPI value row: angka besar + warna latar lebih kuat.
        _cell(sheetId: sheetId, row: 2, col: 0, value: 'Rp $omzet',
            red: 0.62, green: 0.80, blue: 0.62, bold: true, fontSize: 15,
            halign: 'CENTER', valign: 'MIDDLE'),
        _cell(sheetId: sheetId, row: 2, col: 2, value: '$count',
            red: 0.62, green: 0.75, blue: 0.90, bold: true, fontSize: 15,
            halign: 'CENTER', valign: 'MIDDLE'),
        _cell(sheetId: sheetId, row: 2, col: 4, value: 'Rp $avg',
            red: 0.75, green: 0.70, blue: 0.90, bold: true, fontSize: 15,
            halign: 'CENTER', valign: 'MIDDLE'),
        // Section header Laba Rugi.
        _merge(sheetId, 4, 5, 0, 5),
        _cell(sheetId: sheetId, row: 4, col: 0, value: 'LABA RUGI',
            red: 0.10, green: 0.30, blue: 0.55,
            fg: '#FFFFFF', bold: true, fontSize: 13,
            halign: 'LEFT', valign: 'MIDDLE'),
        // Section header Produk Terlaris.
        _merge(sheetId, 17, 18, 0, 5),
        _cell(sheetId: sheetId, row: 17, col: 0, value: 'PRODUK TERLARIS',
            red: 0.16, green: 0.46, blue: 0.35,
            fg: '#FFFFFF', bold: true, fontSize: 13,
            halign: 'LEFT', valign: 'MIDDLE'),
        // Kolom lebar (px).
        for (final (i, w) in const [42.0, 30.0, 14.0, 26.0, 24.0].indexed)
          {
            'updateDimensionProperties': {
              'range': {
                'sheetId': sheetId,
                'dimension': 'COLUMNS',
                'startIndex': i,
                'endIndex': i + 1,
              },
              'properties': {'pixelSize': (w * 7).round()},
              'fields': 'pixelSize',
            },
          },
      ];

      // Zebra + bold untuk baris Laba Rugi (row 5..16).
      for (final i in List.generate(12, (x) => x)) {
        final r = 5 + i;
        final bold = plKeys[i] == 'labaBersih' || plKeys[i] == 'labaKotor';
        reqs.add(_cell(
          sheetId: sheetId, row: r, col: 0, value: _plLabel(plKeys[i]),
          red: i.isEven ? 0.98 : 0.95,
          green: i.isEven ? 0.98 : 0.95,
          blue: i.isEven ? 0.98 : 0.95,
          bold: bold, valign: 'MIDDLE',
        ));
        reqs.add(_cell(
          sheetId: sheetId, row: r, col: 3, value: rupiah((pl[plKeys[i]] as int?) ?? 0),
          red: i.isEven ? 0.98 : 0.95,
          green: i.isEven ? 0.98 : 0.95,
          blue: i.isEven ? 0.98 : 0.95,
          bold: bold, halign: 'RIGHT', valign: 'MIDDLE',
        ));
      }

      // Header ranking (row 19) + zebra rank rows (row 20..24).
      reqs.add(_cell(
        sheetId: sheetId, row: 19, col: 0, value: '#',
        red: 0.85, green: 0.91, blue: 0.87, bold: true, halign: 'CENTER',
      ));
      reqs.add(_cell(
        sheetId: sheetId, row: 19, col: 1, value: 'Nama',
        red: 0.85, green: 0.91, blue: 0.87, bold: true,
      ));
      reqs.add(_cell(
        sheetId: sheetId, row: 19, col: 2, value: 'Kategori',
        red: 0.85, green: 0.91, blue: 0.87, bold: true,
      ));
      reqs.add(_cell(
        sheetId: sheetId, row: 19, col: 3, value: 'Terjual',
        red: 0.85, green: 0.91, blue: 0.87, bold: true, halign: 'CENTER',
      ));
      reqs.add(_cell(
        sheetId: sheetId, row: 19, col: 4, value: 'Omzet',
        red: 0.85, green: 0.91, blue: 0.87, bold: true, halign: 'RIGHT',
      ));
      for (final (i, p) in top.take(5).toList().indexed) {
        final r = 20 + i;
        final shade = i.isEven ? 0.98 : 0.94;
        reqs.add(_cell(
          sheetId: sheetId, row: r, col: 0, value: (i + 1).toString(),
          red: shade, green: shade, blue: shade, halign: 'CENTER', valign: 'MIDDLE',
        ));
        reqs.add(_cell(
          sheetId: sheetId, row: r, col: 1, value: p['name'],
          red: shade, green: shade, blue: shade, bold: i == 0, valign: 'MIDDLE',
        ));
        reqs.add(_cell(
          sheetId: sheetId, row: r, col: 2, value: p['category'],
          red: shade, green: shade, blue: shade, valign: 'MIDDLE',
        ));
        reqs.add(_cell(
          sheetId: sheetId, row: r, col: 3, value: '${p['qty']}',
          red: shade, green: shade, blue: shade, halign: 'CENTER', valign: 'MIDDLE',
        ));
        reqs.add(_cell(
          sheetId: sheetId, row: r, col: 4, value: rupiah((p['revenue'] as int?) ?? 0),
          red: shade, green: shade, blue: shade, halign: 'RIGHT', valign: 'MIDDLE',
        ));
      }

      await _sendTab(userId, spreadsheetId, tab, rows, reqs);
      return const SyncResult(ok: true, tab: tab);
    } catch (e) {
      debugPrint('[Spreadsheet] syncLaporan: $e');
      return SyncResult(ok: false, tab: tab, error: _friendlyError(e));
    }
  }

  static String _plLabel(String key) {
    const labels = {
      'pendapatan': 'Pendapatan',
      'hpp': 'HPP',
      'retur': 'Retur',
      'hppRetur': 'HPP Retur',
      'labaKotor': 'Laba Kotor',
      'expenses': 'Pengeluaran',
      'payroll': 'Payroll',
      'waste': 'Waste',
      'liquidityIn': 'Likuiditas Masuk',
      'liquidityOut': 'Likuiditas Keluar',
      'totalBeban': 'Total Beban',
      'labaBersih': 'Laba Bersih',
    };
    return labels[key] ?? key;
  }

  Future<SyncResult> syncKeuangan(
    String userId,
    String spreadsheetId, {
    List<Map<String, dynamic>>? formatRequests,
  }) async {
    const tab = 'Keuangan';
    try {
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
      await _sendTab(
        userId,
        spreadsheetId,
        tab,
        rows,
        formatRequests ?? headerRequests(tab, columnCount: 5),
      );
      return const SyncResult(ok: true, tab: tab);
    } catch (e) {
      debugPrint('[Spreadsheet] syncKeuangan: $e');
      return SyncResult(ok: false, tab: tab, error: _friendlyError(e));
    }
  }

  Future<SyncResult> syncKaryawan(
    String userId,
    String spreadsheetId, {
    List<Map<String, dynamic>>? formatRequests,
  }) async {
    const tab = 'Karyawan';
    try {
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
      await _sendTab(
        userId,
        spreadsheetId,
        tab,
        rows,
        formatRequests ?? headerRequests(tab, columnCount: 7),
      );
      return const SyncResult(ok: true, tab: tab);
    } catch (e) {
      debugPrint('[Spreadsheet] syncKaryawan: $e');
      return SyncResult(ok: false, tab: tab, error: _friendlyError(e));
    }
  }

  Future<SyncResult> syncPelanggan(
    String userId,
    String spreadsheetId, {
    List<Map<String, dynamic>>? formatRequests,
  }) async {
    const tab = 'Pelanggan';
    try {
      final custRepo = CustomerRepository(db);
      final customers = await custRepo.getCustomers();
      final rows = <List<dynamic>>[
        ['ID', 'Nama', 'No HP', 'Level', 'Total Belanja', 'Poin'],
        for (final c in customers)
          [c.id, c.name, c.phone ?? '', c.level, c.totalSpent, c.points],
      ];
      await _sendTab(
        userId,
        spreadsheetId,
        tab,
        rows,
        formatRequests ?? headerRequests(tab, columnCount: 6),
      );
      return const SyncResult(ok: true, tab: tab);
    } catch (e) {
      debugPrint('[Spreadsheet] syncPelanggan: $e');
      return SyncResult(ok: false, tab: tab, error: _friendlyError(e));
    }
  }

  Future<SyncResult> syncSupplier(
    String userId,
    String spreadsheetId, {
    List<Map<String, dynamic>>? formatRequests,
  }) async {
    const tab = 'Supplier';
    try {
      final suppRepo = SupplierRepository(db);
      final suppliers = await suppRepo.getSuppliers();
      final rows = <List<dynamic>>[
        ['ID', 'Nama', 'Kontak', 'No HP', 'Alamat', 'Catatan'],
        for (final s in suppliers)
          [s.id, s.name, s.contactPerson ?? '', s.phone ?? '', s.address ?? '', s.note ?? ''],
      ];
      await _sendTab(
        userId,
        spreadsheetId,
        tab,
        rows,
        formatRequests ?? headerRequests(tab, columnCount: 6),
      );
      return const SyncResult(ok: true, tab: tab);
    } catch (e) {
      debugPrint('[Spreadsheet] syncSupplier: $e');
      return SyncResult(ok: false, tab: tab, error: _friendlyError(e));
    }
  }

  Future<SyncResult> syncPromo(
    String userId,
    String spreadsheetId, {
    List<Map<String, dynamic>>? formatRequests,
  }) async {
    const tab = 'Promo';
    try {
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
      await _sendTab(
        userId,
        spreadsheetId,
        tab,
        rows,
        formatRequests ?? headerRequests(tab, columnCount: 10),
      );
      return const SyncResult(ok: true, tab: tab);
    } catch (e) {
      debugPrint('[Spreadsheet] syncPromo: $e');
      return SyncResult(ok: false, tab: tab, error: _friendlyError(e));
    }
  }

  Future<SyncResult> syncPresensi(
    String userId,
    String spreadsheetId, {
    List<Map<String, dynamic>>? formatRequests,
  }) async {
    const tab = 'Presensi';
    try {
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
      await _sendTab(
        userId,
        spreadsheetId,
        tab,
        rows,
        formatRequests ?? headerRequests(tab, columnCount: 8),
      );
      return const SyncResult(ok: true, tab: tab);
    } catch (e) {
      debugPrint('[Spreadsheet] syncPresensi: $e');
      return SyncResult(ok: false, tab: tab, error: _friendlyError(e));
    }
  }

  /// Convenience: sync all tabs sequentially. Returns list of per-tab results.
  /// [prepare] harus dipanggil dulu untuk mendapat [spreadsheetId].
  Future<List<SyncResult>> syncAll(
    String userId,
    String spreadsheetId,
    String storeName,
  ) async {
    final results = <SyncResult>[];
    // Laporan duluan (template utama), lalu data mentah.
    results.add(await syncLaporan(userId, spreadsheetId, storeName));
    results.add(await syncProducts(userId, spreadsheetId));
    results.add(await syncTransactions(userId, spreadsheetId));
    results.add(await syncStock(userId, spreadsheetId));
    results.add(await syncKeuangan(userId, spreadsheetId));
    results.add(await syncKaryawan(userId, spreadsheetId));
    results.add(await syncPelanggan(userId, spreadsheetId));
    results.add(await syncSupplier(userId, spreadsheetId));
    results.add(await syncPromo(userId, spreadsheetId));
    results.add(await syncPresensi(userId, spreadsheetId));
    return results;
  }
}
