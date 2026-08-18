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

class SpreadsheetScreen extends ConsumerStatefulWidget {
  SpreadsheetScreen({super.key});
  @override
  ConsumerState<SpreadsheetScreen> createState() => _SpreadsheetScreenState();
}

class _SpreadsheetScreenState extends ConsumerState<SpreadsheetScreen> {
  SpreadsheetService? _svc;
  String? _spreadsheetId;
  String _userEmail = '';
  bool _connecting = false;
  bool _syncing = false;
  String _syncingTab = '';
  final Map<String, DateTime?> _lastSync = {};
  int _syncedCount = 0;
  int _totalCount = 0;
  String projectId = '';
  String sheetsApiEnableUrl = '';

  // All tabs (10 total)
  static const _allTabs = [
    'Produk', 'Transaksi', 'Stok', 'Laporan', 'Keuangan',
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
    final savedSheetId = await SecureStore.getSheetsId();

    // Try silent restore (no popup). Only works if user previously signed in
    // AND granted Sheets scope. If the restored token lacks Sheets scope,
    // we clear and ask for re-login — never keep a bad session.
    if (savedEmail != null) {
      try {
        final account = await _svc!.signInSilently();
        if (account != null) {
          final accessErr = await _svc!.verifyAccess();
          if (accessErr.isEmpty) {
            // Good session — restore
            if (mounted) {
              setState(() {
                _userEmail = account.email;
                _spreadsheetId = savedSheetId;
              });
            }
            return;
          }
          // Session restored but no Sheets scope — clear it
          debugPrint('[Spreadsheet] silent session lacks Sheets scope, clearing');
        }
      } catch (e) {
        debugPrint('[Spreadsheet] signInSilently threw: $e');
      }
    }

    // Fallback: show saved email but no active session
    if (savedEmail != null && mounted) {
      setState(() {
        _userEmail = savedEmail;
        _spreadsheetId = savedSheetId;
      });
    }
  }

  Future<void> _signIn() async {
    setState(() => _connecting = true);

    try {
      // If a previous session exists, disconnect it first to force a clean
      // sign-in that explicitly asks for Sheets permission.
      // Only call disconnect if there's an actual signed-in user, otherwise
      // disconnect() throws and we eat the real error in the outer catch.
      if (_svc!.isSignedIn) {
        try {
          await _svc!.signOut();
        } catch (_) {
          // Fine — nothing to disconnect
        }
      }

      // Fresh sign-in — this will show the Google consent screen
      // that explicitly asks for Spreadsheet permission.
      final account = await _svc!.signIn();
      if (account == null || !mounted) {
        setState(() => _connecting = false);
        return;
      }

      // Verify the token actually has Sheets access
      final err = await _svc!.verifyAccess();
      if (err.isNotEmpty && mounted) {
        setState(() => _connecting = false);
        TopToast.error(context, err);
        return;
      }

      // Save & restore
      final email = account.email;
      await SecureStore.saveSheetsEmail(email);
      final savedId = await SecureStore.getSheetsId();
      if (mounted) {
        setState(() {
          _userEmail = email;
          _spreadsheetId = (savedId != null && savedId.isNotEmpty) ? savedId : null;
          _connecting = false;
        });
        TopToast.success(context, 'Login berhasil — siap membuat spreadsheet');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _connecting = false);
        TopToast.error(context, 'Gagal login — periksa koneksi internet');
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await _svc!.signOut();
    } catch (_) {}
    await SecureStore.clearSheetsTokens();
    await SecureStore.clearSheetsEmail();
    await SecureStore.clearSheetsId();
    if (mounted) {
      setState(() {
        _userEmail = '';
        _spreadsheetId = null;
        _lastSync.clear();
      });
    }
  }

  Future<void> _createSheet() async {
    final email = _userEmail;
    if (email.isEmpty) return;

    if (_svc == null) {
      TopToast.error(context, 'Gagal terhubung ke Google — silakan login ulang');
      return;
    }

    setState(() => _connecting = true);

    try {
      // Verify access before attempting create
      final verifyErr = await _svc!.verifyAccess();
      if (verifyErr.isNotEmpty) {
        if (mounted) {
          setState(() => _connecting = false);
          TopToast.error(context, 'Sesi login kadaluarsa — silakan login ulang');
          _signIn();
        }
        return;
      }

      final id = await _svc!.findOrCreate(email);
      if (id != null && id.isNotEmpty && mounted) {
        await SecureStore.saveSheetsId(id);
        setState(() {
          _spreadsheetId = id;
          _connecting = false;
        });
        TopToast.success(context, 'Spreadsheet dibuat — sinkron data otomatis...');
        _syncAll();
      } else if (mounted) {
        setState(() => _connecting = false);
        TopToast.error(context, 'Gagal membuat spreadsheet di Google Drive.\n'
            'Pastikan Google Drive Anda aktif dan coba lagi.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _connecting = false);
        final msg = e.toString();
        if (msg.contains('apiNotEnabled') || msg.contains('403') || msg.contains('disabled')) {
          _showApiSetupDialog();
        } else if (msg.contains('quota') || msg.contains('429')) {
          TopToast.error(context, 'Kuota Google Sheets tercapai. Coba beberapa saat lagi.');
        } else {
          TopToast.error(context, 'Gagal membuat spreadsheet.\n$msg');
        }
      }
    }
  }

  void _showApiSetupDialog() {
    // Direct link to enable Sheets API in Google Cloud Console
    // Uses the Firebase project ID from google-services.json
    projectId = 'nusa-kasir-hgds-36c2f';
    sheetsApiEnableUrl =
        'https://console.cloud.google.com/apis/library/sheets.googleapis.com'
        '?project=$projectId';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.info_outline, color: NusaConfig.accentGold, size: 24),
          SizedBox(width: 10),
          Expanded(child: Text('Google Sheets API', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Google Sheets API belum diaktifkan untuk project Firebase Anda.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.4),
            ),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: NusaConfig.accentGold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NusaConfig.accentGold.withValues(alpha: 0.25)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.lightbulb_outline, size: 18, color: NusaConfig.accentGold),
                  SizedBox(width: 6),
                  Text('1-Klik Setup', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: NusaConfig.accentGold)),
                ]),
                SizedBox(height: 4),
                Text(
                  'Tombol di bawah akan membuka halaman Google Cloud Console\n'
                  'langsung ke Google Sheets API. Klik ENABLE, lalu tunggu 1-2 menit.',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ]),
            ),
            SizedBox(height: 14),
            Text(
              'Manual:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 6),
            Text(
              '1. console.cloud.google.com\n'
              '2. Pilih project "nusa-kasir-hgds-36c2f"\n'
              '3. APIs & Services → Library\n'
              '4. Cari "Google Sheets API" → Enable\n'
              '5. Tunggu 1-2 menit, lalu coba lagi',
              style: TextStyle(fontSize: 12, height: 1.7),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Tutup')),
          SizedBox(width: 4),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _openUrl(sheetsApiEnableUrl);
            },
            icon: Icon(Icons.open_in_browser, size: 18),
            label: Text('Buka Google Cloud Console'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF1A73E8),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _openUrl(String url) {
    try {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[Spreadsheet] Gagal buka URL: $e');
    }
  }

  Future<void> _syncTab(String tab) async {
    if (_spreadsheetId == null || _svc == null) return;

    // Quick access check before syncing
    final verifyErr = await _svc!.verifyAccess();
    if (verifyErr.isNotEmpty) {
      if (mounted) TopToast.error(context, verifyErr);
      return;
    }

    setState(() {
      _syncing = true;
      _syncingTab = tab;
    });
    SyncResult result;
    switch (tab) {
      case 'Produk':    result = await _svc!.syncProducts(_spreadsheetId!); break;
      case 'Transaksi': result = await _svc!.syncTransactions(_spreadsheetId!); break;
      case 'Stok':      result = await _svc!.syncStock(_spreadsheetId!); break;
      case 'Laporan':   result = await _svc!.syncLaporan(_spreadsheetId!); break;
      case 'Keuangan':  result = await _svc!.syncKeuangan(_spreadsheetId!); break;
      case 'Karyawan':  result = await _svc!.syncKaryawan(_spreadsheetId!); break;
      case 'Pelanggan': result = await _svc!.syncPelanggan(_spreadsheetId!); break;
      case 'Supplier':  result = await _svc!.syncSupplier(_spreadsheetId!); break;
      case 'Promo':     result = await _svc!.syncPromo(_spreadsheetId!); break;
      case 'Presensi':  result = await _svc!.syncPresensi(_spreadsheetId!); break;
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
    if (_spreadsheetId == null || _svc == null) return;

    // Quick access check before syncing
    final verifyErr = await _svc!.verifyAccess();
    if (verifyErr.isNotEmpty) {
      if (mounted) TopToast.error(context, verifyErr);
      return;
    }

    setState(() {
      _syncing = true;
      _syncingTab = 'Semua';
      _syncedCount = 0;
      _totalCount = _allTabs.length;
    });
    final results = await _svc!.syncAll(_spreadsheetId!);
    int okCount = 0;
    final errors = <String>[];
    for (final r in results) {
      if (r.ok) {
        okCount++;
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
    'Produk': Icons.inventory_2_outlined,
    'Transaksi': Icons.receipt_long_outlined,
    'Stok': Icons.view_module_outlined,
    'Laporan': Icons.paid_outlined,
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

    return ScreenScaffold(
      'Spreadsheet',
      SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(children: [
          // ── Badge "Dalam Pengembangan" ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: NusaConfig.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: NusaConfig.warning.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.construction, size: 18, color: NusaConfig.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Fitur ini masih dalam pengembangan — gunakan seperlunya.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: NusaConfig.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),

          // ── Status koneksi ──
          NusaCard(Padding(
            padding: EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: _userEmail.isNotEmpty
                      ? NusaConfig.accentGreen.withValues(alpha: 0.12)
                      : NusaConfig.textTertiary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _userEmail.isNotEmpty ? Icons.check_circle_rounded : Icons.cloud_off_rounded,
                  color: _userEmail.isNotEmpty ? NusaConfig.accentGreen : NusaConfig.textTertiary,
                  size: 22,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_userEmail.isNotEmpty ? 'Terhubung' : 'Belum Terhubung',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPri)),
                  SizedBox(height: 2),
                  Text(
                    _userEmail.isNotEmpty ? _userEmail : 'Login Google untuk sinkronisasi',
                    style: TextStyle(fontSize: 12, color: textTer),
                  ),
                ]),
              ),
            ]),
          )),
          SizedBox(height: 16),

          // ── Not connected → Login button ──
          if (_userEmail.isEmpty) ...[
            SizedBox(
              width: double.infinity,
              child: NusaButton(
                _connecting ? 'Menghubungkan...' : 'Login dengan Google',
                onPressed: _connecting ? null : _signIn,
              ),
            ),
            SizedBox(height: 12),
            Text('Data akan otomatis tersimpan di Google Sheets akun Anda',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: textTer)),
          ]

          // ── Connected ──
          else ...[
            // Spreadsheet status card
            NusaCard(Padding(
              padding: EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: _spreadsheetId != null
                          ? NusaConfig.accentGreen.withValues(alpha: 0.12)
                          : NusaConfig.accentPurple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _spreadsheetId != null ? Icons.description_outlined : Icons.add_to_drive,
                      color: _spreadsheetId != null ? NusaConfig.accentGreen : NusaConfig.accentPurple,
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_spreadsheetId != null ? 'Spreadsheet Aktif' : 'Belum Ada Spreadsheet',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPri)),
                      SizedBox(height: 2),
                      Text(
                        _spreadsheetId != null ? 'Semua data siap disinkronkan' : 'Satu klik untuk membuat',
                        style: TextStyle(fontSize: 12, color: textTer),
                      ),
                    ]),
                  ),
                ]),
                if (_spreadsheetId == null && !_connecting) ...[
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: NusaButton('Buat Spreadsheet Baru', onPressed: _createSheet),
                  ),
                ],
              ]),
            )),
            SizedBox(height: 20),

            // ── Sync section ──
            if (_spreadsheetId != null) ...[
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
            ],

            SizedBox(height: 16),
            // Sign out
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _signOut,
                icon: Icon(Icons.logout, size: 18),
                label: Text('Putuskan Koneksi'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: NusaConfig.activePrimary,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
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
