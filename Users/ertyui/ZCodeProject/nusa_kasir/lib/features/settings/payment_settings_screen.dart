import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/services/image_storage_service.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:nusa_kasir/core/utils/image_utils.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';
import 'package:nusa_kasir/shared/widgets/nusa_card.dart';
import 'package:nusa_kasir/shared/widgets/nusa_input.dart';
import 'package:nusa_kasir/shared/widgets/nusa_button.dart';
import 'package:nusa_kasir/shared/widgets/nusa_search_bar.dart';

class PaymentSettingsScreen extends ConsumerStatefulWidget {
  PaymentSettingsScreen({super.key});
  @override
  ConsumerState<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends ConsumerState<PaymentSettingsScreen> {
  final _bankAccountCtrl = TextEditingController();
  final _bankHolderCtrl = TextEditingController();
  String? _qrisImagePath;
  String? _bankName;
  bool _loading = false;

  static const _bankList = [
    'Bank BCA', 'Bank Mandiri', 'Bank BNI', 'Bank BRI', 'Bank CIMB Niaga',
    'Bank Danamon', 'Bank Permata', 'Bank Panin', 'Bank OCBC NISP',
    'Bank Maybank Indonesia', 'Bank Mega', 'Bank BTN', 'Bank BTPN',
    'Bank BJB', 'Bank DKI', 'Bank Jatim', 'Bank Jateng', 'Bank DIY',
    'Bank Sumut', 'Bank Nagari', 'Bank Lampung', 'Bank Kalsel',
    'Bank Kaltimtara', 'Bank Sulselbar', 'Bank Sulteng', 'Bank Sultra',
    'Bank Maluku Malut', 'Bank NTB', 'Bank NTT', 'Bank Papua',
    'Bank Bengkulu', 'Bank Jambi', 'Bank Aceh', 'Bank Riau Kepri',
    'Bank Banten', 'Bank Kalbar', 'Bank Kalteng',
    'Bank Sinarmas', 'Bank Bukopin', 'Bank Muamalat', 'Bank Syariah Indonesia',
    'Bank Commonwealth', 'Bank UOB Indonesia', 'Bank DBS Indonesia',
    'Bank HSBC Indonesia', 'Bank Standard Chartered', 'Bank ANZ Indonesia',
    'Bank Jago', 'Bank Neo Commerce', 'Bank Seabank', 'Bank Aladin',
    'Bank Amar', 'Bank Raya', 'GoPay', 'OVO', 'DANA', 'ShopeePay',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final repo = ref.read(settingsRepoProvider);
    final qrisPath = await repo.getQrisImagePath();
    final bankName = await repo.getBankName();
    final bankAccount = await repo.getBankAccount();
    final bankHolder = await repo.getBankHolder();
    if (mounted) {
      setState(() {
        _qrisImagePath = qrisPath;
        _bankName = bankName;
      });
    }
    _bankAccountCtrl.text = bankAccount ?? '';
    _bankHolderCtrl.text = bankHolder ?? '';
  }

  @override
  void dispose() {
    _bankAccountCtrl.dispose();
    _bankHolderCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickQrisImage() async {
    try {
      final path = await pickAndSaveImage(maxSize: 1024, prefix: 'qris_');
      if (path == null) return; // cancelled or failed
      await ref.read(settingsRepoProvider).setQrisImagePath(path);
      if (mounted) {
        setState(() => _qrisImagePath = path);
        TopToast.success(context, 'QRIS disimpan ✅');
      }
      // Upload to cloud
      try {
        // Supabase auth tidak dipakai — uid canonical backup dari SecureStore
        // (v2.2.57+115 Area I: sama dengan path backup supaya foto tidak pecah).
        final uid = await SecureStore.resolveCanonicalUid();
        if (uid != null) {
          ImageStorageService(Supabase.instance.client, uid)
              .uploadImage('settings', path);
        }
      } catch (_) {}
    } catch (_) {
      if (mounted) TopToast.error(context, 'Gagal menyimpan gambar QRIS');
    }
  }

  Future<void> _removeQrisImage() async {
    await ref.read(settingsRepoProvider).setQrisImagePath(null);
    if (mounted) {
      setState(() => _qrisImagePath = null);
      TopToast.success(context, 'QRIS dihapus ✅');
    }
  }

  Future<void> _saveBank() async {
    setState(() => _loading = true);
    try {
      await ref.read(settingsRepoProvider).setBankInfo(
        name: _bankName,
        account: _bankAccountCtrl.text.trim(),
        holder: _bankHolderCtrl.text.trim(),
      );
      if (mounted) TopToast.success(context, 'Info rekening disimpan ✅');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showBankPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String filter = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final filtered = filter.isEmpty
              ? _bankList
              : _bankList.where((b) => b.toLowerCase().contains(filter.toLowerCase())).toList();
          return Container(
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                margin: EdgeInsets.symmetric(vertical: 8),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? NusaConfig.darkDivider : NusaConfig.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 8),
              Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.account_balance, color: Color(0xFF6366F1), size: 20),
                ),
                SizedBox(width: 12),
                Text('Pilih Bank', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ]),
              SizedBox(height: 12),
              NusaSearchBar(
                hint: 'Cari bank...',
                onChanged: (v) => setSt(() => filter = v),
              ),
              SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final bank = filtered[i];
                    final selected = _bankName == bank;
                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 4),
                      leading: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: selected
                              ? Color(0xFF6366F1).withValues(alpha: 0.12)
                              : (isDark ? NusaConfig.darkSurface2 : NusaConfig.backgroundColor),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.account_balance,
                            size: 18,
                            color: selected ? Color(0xFF6366F1) : (isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                      ),
                      title: Text(bank, style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14,
                          color: selected ? Color(0xFF6366F1) : null)),
                      trailing: selected
                          ? Icon(Icons.check_circle, color: Color(0xFF6366F1), size: 22)
                          : null,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onTap: () {
                        setState(() => _bankName = bank);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ScreenScaffold(
      'Pembayaran',
      SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── QRIS Section ──
            _sectionHeader('QRIS', Icons.qr_code_2, Color(0xFF6366F1), isDark),
            NusaCard(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('QRIS Statis',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  SizedBox(height: 4),
                  Text('Upload gambar QRIS dari penyedia pembayaran Anda (contoh: QRIS, Gopay, dll)',
                      style: TextStyle(fontSize: 12,
                          color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                  SizedBox(height: 14),
                  if (_qrisImagePath != null && _qrisImagePath!.isNotEmpty && File(_qrisImagePath!).existsSync()) ...[
                    // QRIS preview
                    Container(
                      height: 220,
                      margin: EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(File(_qrisImagePath!), fit: BoxFit.contain, cacheWidth: 400),
                      ),
                    ),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickQrisImage,
                          icon: Icon(Icons.image_outlined, size: 18),
                          label: Text('Ganti Gambar',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: NusaConfig.activePrimary,
                            side:  BorderSide(color: NusaConfig.activePrimary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _removeQrisImage,
                        icon: Icon(Icons.delete_outline, size: 18),
                        label: Text('Hapus'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: NusaConfig.activePrimary,
                          side:  BorderSide(color: NusaConfig.activePrimary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        ),
                      ),
                    ]),
                  ] else ...[
                    // Placeholder
                    GestureDetector(
                      onTap: _pickQrisImage,
                      child: Container(
                        height: 160,
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor,
                            style: BorderStyle.solid,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          color: isDark ? NusaConfig.darkSurface2 : NusaConfig.backgroundColor,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_2, size: 48,
                                color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                            SizedBox(height: 8),
                            Text('Belum ada gambar QRIS',
                                style: TextStyle(fontSize: 13,
                                    color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                            SizedBox(height: 12),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Color(0xFF6366F1).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('Pilih Gambar QRIS',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 24),

            // ── Bank Transfer Section ──
            _sectionHeader('TRANSFER BANK', Icons.account_balance, Color(0xFF6366F1), isDark),
            NusaCard(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Informasi Rekening',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  SizedBox(height: 4),
                  Text('Data rekening bank untuk pembayaran via transfer',
                      style: TextStyle(fontSize: 12,
                          color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                  SizedBox(height: 14),
                  // Bank dropdown
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Bank',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                      SizedBox(height: 6),
                      GestureDetector(
                        onTap: _showBankPicker,
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          decoration: BoxDecoration(
                            color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? NusaConfig.darkInputBorder : NusaConfig.inputBorder,
                            ),
                          ),
                          child: Row(children: [
                            Icon(Icons.account_balance, size: 20,
                                color: _bankName != null ? Color(0xFF6366F1) : (isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _bankName ?? 'Pilih bank...',
                                style: TextStyle(fontSize: 15,
                                    color: _bankName != null
                                        ? (isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)
                                        : (isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
                              ),
                            ),
                            Icon(Icons.expand_more, size: 22,
                                color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                          ]),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  NusaInput('Nomor Rekening', controller: _bankAccountCtrl,
                      hint: 'Cth: 1234567890', type: TextInputType.number),
                  SizedBox(height: 12),
                  NusaInput('Atas Nama', controller: _bankHolderCtrl,
                      hint: 'Cth: Budi Santoso'),
                  SizedBox(height: 16),
                  // Preview card
                  if (_bankName != null && _bankName!.isNotEmpty && _bankAccountCtrl.text.isNotEmpty)
                    Container(
                      padding: EdgeInsets.all(14),
                      margin: EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? NusaConfig.darkSurface2 : Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor),
                      ),
                      child: Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Color(0xFF6366F1).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.account_balance, size: 20, color: Color(0xFF6366F1)),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_bankName!,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                              SizedBox(height: 2),
                              Text(_bankAccountCtrl.text,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                                      fontFamily: 'monospace', letterSpacing: 1)),
                              if (_bankHolderCtrl.text.isNotEmpty) ...[
                                SizedBox(height: 2),
                                Text('a.n. ${_bankHolderCtrl.text}',
                                    style: TextStyle(fontSize: 12,
                                        color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                              ],
                            ],
                          ),
                        ),
                      ]),
                    ),
                  NusaButton('Simpan Rekening', onPressed: _loading ? null : _saveBank),
                ],
              ),
            ),

            // ── EDC / Kartu Debit-Kredit — Segera Hadir ──
            SizedBox(height: 24),
            _sectionHeader('EDC / KARTU', Icons.credit_card, Color(0xFF0D9488), isDark),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF0D9488).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Color(0xFF0D9488).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: Color(0xFF0D9488).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.credit_card, size: 24, color: Color(0xFF0D9488)),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('EDC / Kartu Debit-Kredit',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                                    color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary)),
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('Segera Hadir',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text('Pembayaran via mesin EDC (debit/kredit) sedang dalam pengembangan.',
                            style: TextStyle(fontSize: 12,
                                color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color, bool isDark) {
    return Padding(
      padding: EdgeInsets.only(top: 4, bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
