import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/shared/widgets/nusa_button.dart';
import 'package:nusa_kasir/shared/widgets/nusa_card.dart';
import 'package:nusa_kasir/shared/widgets/nusa_input.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

/// Data Toko (v2.2.57+112) — form informasi toko lengkap, bukan cuma nama.
///
/// Mengisi kolom yang SUDAH ADA di tabel Settings (storeName, storePhone,
/// storeAddress) — tidak ada perubahan schema, jadi restore cloud lama tetap
/// aman. Jarak antar-field dilonggarkan (24px) sesuai brief redesign.
class StoreDataScreen extends ConsumerStatefulWidget {
  const StoreDataScreen({super.key});

  @override
  ConsumerState<StoreDataScreen> createState() => _StoreDataScreenState();
}

class _StoreDataScreenState extends ConsumerState<StoreDataScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _ownerName = '';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(settingsRepoProvider);
    final name = await repo.getStoreName();
    final phone = await repo.getStorePhone();
    final address = await repo.getStoreAddress();
    final owner = await repo.getOwnerName();
    if (!mounted) return;
    setState(() {
      _nameCtrl.text = name;
      _phoneCtrl.text = phone;
      _addressCtrl.text = address;
      _ownerName = owner;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    if (name.isEmpty) {
      TopToast.error(context, 'Nama toko tidak boleh kosong');
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(settingsRepoProvider);
      await repo.setStoreName(name);
      await repo.setStorePhone(phone);
      await repo.setStoreAddress(address);
      if (mounted) {
        TopToast.success(context, 'Data toko tersimpan');
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      if (mounted) TopToast.error(context, 'Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ScreenScaffold(
      'Data Toko',
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Card: info toko ──
                      NusaCard(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.storefront_outlined,
                                    size: 20,
                                    color: NusaConfig.activePrimary),
                                const SizedBox(width: 8),
                                const Text(
                                  'Informasi Toko',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16),
                                ),
                              ],
                            ),
                            // Jarak antar-field sengaja dilonggarkan (24px).
                            const SizedBox(height: 24),
                            NusaInput('Nama Toko',
                                controller: _nameCtrl,
                                hint: 'contoh: Toko Berkah Jaya'),
                            const SizedBox(height: 24),
                            NusaInput('No. HP / WhatsApp',
                                controller: _phoneCtrl,
                                type: TextInputType.phone,
                                hint: 'contoh: 0812xxxxxxx'),
                            const SizedBox(height: 24),
                            NusaInput('Alamat Toko',
                                controller: _addressCtrl,
                                maxLines: 3,
                                hint: 'Alamat lengkap toko'),
                            const SizedBox(height: 24),
                            NusaButton(
                              _saving ? 'Menyimpan...' : 'Simpan',
                              onPressed: _saving ? null : _save,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Card: pemilik ──
                      NusaCard(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person_outline,
                                    size: 20,
                                    color: NusaConfig.activePrimary),
                                const SizedBox(width: 8),
                                const Text(
                                  'Pemilik',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _ownerName.isEmpty ? '—' : _ownerName,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? NusaConfig.darkTextPrimary
                                    : NusaConfig.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Nama pemilik diambil dari akun Owner.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? NusaConfig.darkTextTertiary
                                    : NusaConfig.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
