import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/services/spreadsheet_service.dart';
// SyncResult is exported from spreadsheet_service.dart
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:nusa_kasir/shared/widgets/nusa_button.dart';
import 'package:nusa_kasir/shared/widgets/nusa_card.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';

/// Google Sheets Terpusat (v2.2.57+121) — Company API via edge fn
/// `sheets-admin` di nusa-online.
///
/// App TIDAK login Google lagi. Spreadsheet dibuat server (service account
/// NUSA) atas nama user; app cukup kirim `user_id` canonical + rows + request
/// format JSON. Link KONTINU: 1 spreadsheet per user, dibuat sekali, dipakai
/// terus untuk semua pembukuan.
class SpreadsheetScreen extends ConsumerStatefulWidget {
  SpreadsheetScreen({super.key});
  @override
  ConsumerState<SpreadsheetScreen> createState() => _SpreadsheetScreenState();
}

class _SpreadsheetScreenState extends ConsumerState<SpreadsheetScreen> {
  SpreadsheetService? _svc;
  String? _spreadsheetUrl;
  String _userEmail = '';
  String _storeName = '';
  String _error = '';
  bool _connecting = false;
  bool _syncing = false;
  bool _archiving = false;
  String _syncingTab = '';
  final Map<String, DateTime?> _lastSync = {};
  int _syncedCount = 0;
  int _totalCount = 0;

  // All tabs (10 total) — urutan sama dengan server (tab pertama = Laporan).
  static const _allTabs = [
    'Laporan', 'Produk', 'Transaksi', 'Stok', 'Keuangan',
    'Karyawan', 'Pelanggan', 'Supplier', 'Promo', 'Presensi',
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _svc = SpreadsheetService(ref.read(databaseProvider));
    final savedEmail = await SecureStore.getSheetsEmail();
    final savedUrl = await SecureStore.getSheetsId();
    final storeName = await _svc!.storeName();
    if (mounted) {
      setState(() {
        _userEmail = savedEmail ?? '';
        _storeName = storeName;
        _spreadsheetUrl = (savedUrl != null && savedUrl.isNotEmpty) ? savedUrl : null;
      });
    }
  }

  /// Siapkan spreadsheet user: buka link kontinu yang sudah ada, atau buat
  /// baru kalau belum pernah (create_spreadsheet via server).
  Future<void> _prepare() async {
    final svc = _svc;
    final uid = await SpreadsheetService.uid();
    if (svc == null || uid == null) {
      if (mounted) TopToast.error(context, 'Identitas akun belum tersedia — coba buka ulang app.');
      return;
    }

    setState(() {
      _connecting = true;
      _error = '';
    });

    final email = (await svc.email()).isNotEmpty
        ? await svc.email()
        : _userEmail;

    final result = await svc.prepare(
      userId: uid,
      email: email,
      storeName: _storeName,
    );

    if (!mounted) return;
    if (result.error != null) {
      setState(() {
        _connecting = false;
        _error = result.error!;
      });
      TopToast.error(context, result.error!);
      return;
    }

    await SecureStore.saveSheetsEmail(email);
    setState(() {
      _connecting = false;
      _spreadsheetUrl = result.url;
    });
    TopToast.success(
      context,
      result.createdNow
          ? 'Spreadsheet dibuat — mulai sinkron data...'
          : 'Spreadsheet ditemukan — melanjutkan pembukuan lama',
    );
    _syncAll();
  }

  void _openUrl(String url) {
    try {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[Spreadsheet] Gagal buka URL: $e');
    }
  }

  void _reset() async {
    await SecureStore.clearSheetsEmail();
    await SecureStore.clearSheetsId();
    if (mounted) {
      setState(() {
        _userEmail = '';
        _spreadsheetUrl = null;
        _lastSync.clear();
        _error = '';
      });
    }
    TopToast.success(context, 'Koneksi spreadsheet diputus');
  }

  Future<void> _syncTab(String tab) async {
    final svc = _svc;
    final uid = await SpreadsheetService.uid();
    final url = _spreadsheetUrl;
    if (svc == null || uid == null || url == null) return;

    final id = _idFromUrl(url);
    if (id == null) return;

    setState(() {
      _syncing = true;
      _syncingTab = tab;
    });
    SyncResult result;
    switch (tab) {
      case 'Produk':    result = await svc.syncProducts(uid, id); break;
      case 'Transaksi': result = await svc.syncTransactions(uid, id); break;
      case 'Stok':      result = await svc.syncStock(uid, id); break;
      case 'Laporan':   result = await svc.syncLaporan(uid, id, _storeName); break;
      case 'Keuangan':  result = await svc.syncKeuangan(uid, id); break;
      case 'Karyawan':  result = await svc.syncKaryawan(uid, id); break;
      case 'Pelanggan': result = await svc.syncPelanggan(uid, id); break;
      case 'Supplier':  result = await svc.syncSupplier(uid, id); break;
      case 'Promo':     result = await svc.syncPromo(uid, id); break;
      case 'Presensi':  result = await svc.syncPresensi(uid, id); break;
      default: return;
    }
    if (mounted) {
      setState(() {
        _syncing = false;
        _syncingTab = '';
        if (result.ok) _lastSync[tab] = DateTime.now();
      });
      if (result.ok) {
        TopToast.success(context, '$tab tersinkronisasi');
      } else {
        TopToast.error(context, result.error ?? 'Gagal sinkron $tab');
      }
    }
  }

  Future<void> _syncAll() async {
    final svc = _svc;
    final uid = await SpreadsheetService.uid();
    final url = _spreadsheetUrl;
    if (svc == null || uid == null || url == null) return;

    final id = _idFromUrl(url);
    if (id == null) return;

    setState(() {
      _syncing = true;
      _syncingTab = 'Semua';
      _syncedCount = 0;
      _totalCount = _allTabs.length;
    });
    final results = await svc.syncAll(uid, id, _storeName);
    final errors = <String>[];
    for (final r in results) {
      if (r.ok) {
        if (mounted) _lastSync[r.tab] = DateTime.now();
      } else if (r.error != null) {
        errors.add('${r.tab}: ${r.error}');
      }
      if (mounted) setState(() => _syncedCount++);
    }
    if (mounted) {
      setState(() {
        _syncing = false;
        _syncingTab = '';
      });
      if (results.every((r) => r.ok)) {
        TopToast.success(context, 'Semua data tersinkronisasi!');
      } else {
        final msg = errors.isNotEmpty
            ? errors.take(2).join('\n')
            : 'Sebagian gagal sinkronisasi';
        TopToast.error(context, msg);
      }
    }
  }

  /// Ekstrak spreadsheet id dari URL Google Sheets.
  static String? _idFromUrl(String url) {
    final m = RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)').firstMatch(url);
    return m?.group(1);
  }

  String _lastSyncText(String tab) {
    final dt = _lastSync[tab];
    if (dt == null) return 'Belum';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}j lalu';
    return '${diff.inDays}h lalu';
  }

  // Icons per tab
  static const _tabIcons = {
    'Laporan': Icons.paid_outlined,
    'Produk': Icons.inventory_2_outlined,
    'Transaksi': Icons.receipt_long_outlined,
    'Stok': Icons.view_module_outlined,
    'Keuangan': Icons.account_balance_wallet_outlined,
    'Karyawan': Icons.people_outline,
    'Pelanggan': Icons.person_outline,
    'Supplier': Icons.local_shipping_outlined,
    'Promo': Icons.discount_outlined,
    'Presensi': Icons.fingerprint_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary;
    final textTer = isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary;
    final connected = _spreadsheetUrl != null;

    return ScreenScaffold(
      'Spreadsheet',
      SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(children: [
          SizedBox(height: 16),

          // ── Status koneksi ──
          NusaCard(Padding(
            padding: EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: connected
                      ? NusaConfig.accentGreen.withValues(alpha: 0.12)
                      : NusaConfig.textTertiary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  connected ? Icons.check_circle_rounded : Icons.cloud_off_rounded,
                  color: connected ? NusaConfig.accentGreen : NusaConfig.textTertiary,
                  size: 22,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(connected ? 'Spreadsheet Aktif' : 'Belum Ada Spreadsheet',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPri)),
                  SizedBox(height: 2),
                  Text(
                    connected
                        ? (_userEmail.isNotEmpty ? _userEmail : 'Data pembukuan Anda')
                        : 'Spreadsheet dibuat & diisi otomatis oleh server NUSA',
                    style: TextStyle(fontSize: 12, color: textTer),
                  ),
                ]),
              ),
            ]),
          )),
          SizedBox(height: 16),

          if (!connected) ...[
            SizedBox(
              width: double.infinity,
              child: NusaButton(
                _connecting ? 'Menyiapkan...' : 'Buat / Buka Spreadsheet',
                onPressed: _connecting ? null : _prepare,
              ),
            ),
            SizedBox(height: 12),
            Text('Tanpa login Google — server NUSA yang membuat & mengisi spreadsheet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: textTer)),
            SizedBox(height: 4),
            Text('Sekali buat, link dipakai terus untuk semua pembukuan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: textTer)),
          ] else ...[
            // Spreadsheet aktif — tampilkan link + tombol buka
            NusaCard(Padding(
              padding: EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: NusaConfig.accentGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.description_outlined,
                        color: NusaConfig.accentGreen, size: 22),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Spreadsheet Aktif',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPri)),
                      SizedBox(height: 2),
                      Text(
                        'Semua data siap disinkronkan',
                        style: TextStyle(fontSize: 12, color: textTer),
                      ),
                    ]),
                  ),
                ]),
                SizedBox(height: 12),
                InkWell(
                  onTap: () => _openUrl(_spreadsheetUrl!),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: NusaConfig.accentGreen.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NusaConfig.accentGreen.withValues(alpha: 0.2)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.open_in_new, size: 15, color: NusaConfig.accentGreen),
                        SizedBox(width: 6),
                        Text('Buka Spreadsheet',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: NusaConfig.accentGreen)),
                      ]),
                      SizedBox(height: 4),
                      Text(
                        _spreadsheetUrl!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: textTer),
                      ),
                    ]),
                  ),
                ),
              ]),
            )),
            SizedBox(height: 20),

            // ── Sync section ──
            Row(children: [
              Expanded(
                child: Text('Sinkronisasi Data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPri)),
              ),
              if (_syncing && _syncingTab == 'Semua')
                Text('$_syncedCount / $_totalCount', style: TextStyle(fontSize: 13, color: textTer)),
            ]),
            SizedBox(height: 8),

            // Progress bar for sync all
            if (_syncing && _syncingTab == 'Semua') ...[
              Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _totalCount > 0 ? _syncedCount / _totalCount : 0,
                    backgroundColor: isDark ? NusaConfig.darkDivider : NusaConfig.dividerColor,
                    valueColor: AlwaysStoppedAnimation(NusaConfig.accentGreen),
                    minHeight: 6,
                  ),
                ),
              ),
            ],

            // Tab list
            ..._allTabs.map((tab) => Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: _syncTile(tab, _tabIcons[tab] ?? Icons.sync, isDark: isDark),
            )),

            SizedBox(height: 16),
            // Sync All button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _syncing ? null : _syncAll,
                icon: _syncing && _syncingTab == 'Semua'
                    ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(Icons.sync_rounded, size: 18),
                label: Text(_syncing && _syncingTab == 'Semua' ? 'Menyinkronkan...' : 'Sync Semua Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NusaConfig.activePrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            SizedBox(height: 12),
            // Arsip bulan lama (cold tier — data dibaca dari Supabase)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _archiving ? null : _showArchives,
                icon: _archiving
                    ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.inventory_2_outlined, size: 18),
                label: Text('Lihat Arsip Bulan Lama'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: NusaConfig.activePrimary,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            SizedBox(height: 16),
            // Reset / putus koneksi
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _reset,
                icon: Icon(Icons.link_off, size: 18),
                label: Text('Putus Koneksi Spreadsheet'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: NusaConfig.activePrimary,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],

          if (_error.isNotEmpty) ...[
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFEF4444).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFFEF4444).withValues(alpha: 0.2)),
              ),
              child: Text(
                _error,
                style: TextStyle(fontSize: 12, color: Color(0xFFEF4444), height: 1.4),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  // ── Arsip bulan lama (cold tier Supabase) ────────────────────────────

  Future<void> _showArchives() async {
    setState(() => _archiving = true);
    List<Map<String, dynamic>> archives = [];
    String? err;
    try {
      archives = await (_svc ?? SpreadsheetService(ref.read(databaseProvider))).fetchArchives();
    } catch (e) {
      err = e.toString();
    }
    if (mounted) setState(() => _archiving = false);
    if (!mounted) return;
    if (err != null) {
      TopToast.error(context, 'Gagal memuat arsip: $err');
      return;
    }

    // Kelompokkan per bulan → {bulan: {tab: rowCount}}
    final byMonth = <String, Map<String, int>>{};
    for (final a in archives) {
      final bulan = a['bulan'] as String? ?? '';
      final tab = a['tab'] as String? ?? '';
      final rc = (a['row_count'] as num?)?.toInt() ?? 0;
      byMonth.putIfAbsent(bulan, () => {})[tab] = rc;
    }
    final bulans = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));

    if (bulans.isEmpty) {
      TopToast.info(context, 'Belum ada arsip bulanan. Arsip otomatis dibuat tanggal 2 tiap bulan.');
      return;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textPri = isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary;
        final textSec = isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary;
        final textTer = isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary;
        final surf = isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor;
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.inventory_2_outlined, color: NusaConfig.activePrimary, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Arsip Bulan Lama',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPri)),
                  ),
                ]),
                SizedBox(height: 4),
                Text(
                  'Data bulan selesai tersimpan aman di cloud NUSA (Supabase) — '
                  'spreadsheet tetap ramping untuk bulan berjalan.',
                  style: TextStyle(fontSize: 12, color: textTer),
                ),
                SizedBox(height: 14),
                for (final bulan in bulans) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: surf,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_bulanLabel(bulan),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPri)),
                        SizedBox(height: 6),
                        for (final e in (byMonth[bulan] ?? {})
                            .entries
                            .toList()
                          ..sort((a, b) => b.value.compareTo(a.value)))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(children: [
                              Expanded(child: Text(e.key,
                                  style: TextStyle(fontSize: 12, color: textSec))),
                              Text('${e.value} baris',
                                  style: TextStyle(fontSize: 12, color: textTer)),
                            ]),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _bulanLabel(String yyyyMm) {
    const names = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    final parts = yyyyMm.split('-');
    if (parts.length != 2) return yyyyMm;
    final m = int.tryParse(parts[1]) ?? 0;
    if (m < 1 || m > 12) return yyyyMm;
    return '${names[m]} ${parts[0]}';
  }

  Widget _syncTile(String label, IconData icon, {required bool isDark}) {
    final isActive = _syncing && _syncingTab == label;
    final textPri = isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary;
    final textTer = isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary;
    final surf = isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor;
    final border = isDark ? NusaConfig.darkBorder : NusaConfig.borderColor;

    return Container(
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: (_syncing) ? null : () => _syncTab(label),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: NusaConfig.activePrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: NusaConfig.activePrimary, size: 19),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPri)),
                  SizedBox(height: 1),
                  Text('Terakhir: ${_lastSyncText(label)}',
                      style: TextStyle(fontSize: 11, color: textTer)),
                ]),
              ),
              if (isActive)
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: NusaConfig.activePrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.sync_rounded, size: 15, color: NusaConfig.activePrimary),
                    SizedBox(width: 4),
                    Text('Sync', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: NusaConfig.activePrimary)),
                  ]),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
