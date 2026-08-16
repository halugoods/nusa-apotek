import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/services/image_storage_service.dart';
import 'package:nusa_kasir/core/services/online_order_service.dart';
import 'package:nusa_kasir/core/utils/image_utils.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';
import 'package:nusa_kasir/shared/widgets/nusa_button.dart';
import 'package:nusa_kasir/shared/widgets/nusa_card.dart';
import 'package:nusa_kasir/shared/widgets/nusa_input.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

class OnlineStoreSetupScreen extends ConsumerStatefulWidget {
  OnlineStoreSetupScreen({super.key});
  @override
  ConsumerState<OnlineStoreSetupScreen> createState() =>
      _OnlineStoreSetupScreenState();
}

class _OnlineStoreSetupScreenState
    extends ConsumerState<OnlineStoreSetupScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _storeUrl;
  bool _isActive = false;
  String? _logoPath;
  int _onlineProductCount = 0;
  // Produk yang gagal upload gambarnya (nama) — ditampilkan sebagai banner
  // peringatan, bukan cuma toast yang gampang terlewat.
  List<String> _imgFailedNames = [];
  // Alasan kegagalan per produk (nama → alasan) — tampil detail di banner.
  final Map<String, String> _imgFailReasons = {};
  WebViewController? _webViewCtrl;
  // Wizard 2 langkah: 1 = setup alamat toko, 2 = detail & simpan.
  int _step = 1;
  // Pernah tersimpan → baru preview ditampilkan di bawah.
  bool _everSaved = false;

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _waCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController(text: '08:00 - 21:00');
  // Slug custom (alamat website) + status validasi ketersediaan.
  final _slugCtrl = TextEditingController();
  String? _slugStatus; // 'checking' | 'available' | 'taken' | 'invalid'
  Timer? _slugDebounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _waCtrl.dispose();
    _addressCtrl.dispose();
    _hoursCtrl.dispose();
    _slugCtrl.dispose();
    _slugDebounce?.cancel();
    super.dispose();
  }

  String _slugify(String name) {
    return name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  /// Color → hex string '#RRGGBB' untuk dikirim ke server (warna website).
  String _colorToHex(Color c) {
    final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  Future<void> _load() async {
    final key = await SecureStore.getActivation();
    if (key == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final repo = ref.read(settingsRepoProvider);
    final name = await repo.getStoreName();
    if (name.isNotEmpty) _nameCtrl.text = name;

    // Load store logo from local settings
    _logoPath = await repo.getStoreLogoPath();

    final fallbackSlug = _slugify(name);
    _storeUrl =
        'https://nusa-online.vercel.app/toko/${NusaConfig.productId}/$fallbackSlug';

    // Count online products
    try {
      final db = ref.read(databaseProvider);
      final products = await ProductRepository(db).getProducts();
      _onlineProductCount = products.where((p) => p.isOnline).length;
    } catch (_) {}

    try {
      final svc = OnlineOrderService(Supabase.instance.client);
      final store = await svc.getStoreSettings();
      if (store != null) {
        _isActive = store['is_active'] == true;
        _nameCtrl.text = store['store_name'] as String? ?? _nameCtrl.text;
        _descCtrl.text = store['description'] as String? ?? '';
        _waCtrl.text = store['whatsapp'] as String? ?? '';
        _addressCtrl.text = store['address'] as String? ?? '';
        _hoursCtrl.text = store['open_hours'] as String? ?? '08:00 - 21:00';
        final cloudSlug = store['slug'] as String?;
        if (cloudSlug != null && cloudSlug.isNotEmpty) {
          _slugCtrl.text = cloudSlug;
          _slugStatus = 'available';
        }
        _everSaved = true;
        // Store tersimpan → langsung ke langkah 2 (detail).
        if (cloudSlug != null && cloudSlug.isNotEmpty) _step = 2;
        _storeUrl =
            'https://nusa-online.vercel.app/toko/${NusaConfig.productId}/'
            '${(cloudSlug != null && cloudSlug.isNotEmpty) ? cloudSlug : _slugify(_nameCtrl.text)}';
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save({bool? activate}) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      TopToast.error(context, 'Nama toko wajib diisi');
      return;
    }
    final slug = _slugCtrl.text.trim().toLowerCase();
    if (slug.isEmpty) {
      TopToast.error(context, 'Slug (alamat toko) wajib diisi');
      return;
    }
    if (_slugStatus != 'available' && _slugStatus != 'checking') {
      if (_slugStatus == 'taken') {
        TopToast.error(
          context,
          'Slug sudah dipakai toko lain. Ganti slug lain.',
        );
      } else {
        TopToast.error(
          context,
          'Slug tidak valid. Gunakan huruf kecil, angka, dan tanda hubung (-).',
        );
      }
      return;
    }

    setState(() => _saving = true);
    final isActive = activate ?? _isActive;

    try {
      final svc = OnlineOrderService(Supabase.instance.client);
      // Kirim tema app (warna) ke server — website memakai warna yang sama.
      final themeId = ref.read(themePresetProvider);
      final theme = NusaConfig.themePresets[themeId];
      final result = await svc.upsertStore(
        storeName: name,
        slug: slug,
        variant: NusaConfig.productId,
        themeId: themeId,
        primaryColor: theme?['primary'] != null
            ? _colorToHex(theme!['primary']!)
            : '',
        darkColor: theme?['dark'] != null ? _colorToHex(theme!['dark']!) : '',
        softColor: theme?['soft'] != null ? _colorToHex(theme!['soft']!) : '',
        description: _descCtrl.text.trim(),
        whatsapp: _waCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        openHours: _hoursCtrl.text.trim(),
        isActive: isActive,
      );
      final ok = result.ok;

      if (ok) {
        await ref.read(settingsRepoProvider).setStoreName(name);
        _storeUrl =
            'https://nusa-online.vercel.app/toko/${NusaConfig.productId}/$slug';

        if (isActive) await _syncProducts();

        if (mounted) {
          setState(() {
            _isActive = isActive;
            _everSaved = true;
            _step = 2;
            _storeUrl =
                'https://nusa-online.vercel.app/toko/${NusaConfig.productId}/$slug';
          });
          TopToast.success(
            context,
            isActive ? 'Toko online diaktifkan' : 'Pengaturan disimpan',
          );
        }
      } else {
        // Gagal → kembalikan toggle ke nilai server (UI tidak bohong).
        if (activate != null && mounted) {
          setState(() => _isActive = !activate);
        }
        if (mounted) {
          TopToast.error(context, _errorMessage(result.error));
        }
      }
    } catch (e) {
      if (activate != null && mounted) {
        setState(() => _isActive = !activate);
      }
      if (mounted) TopToast.error(context, 'Error: $e');
    }

    if (mounted) setState(() => _saving = false);
  }

  /// Lanjut dari langkah 1 → 2. Simpan nama+slug dulu agar URL terbentuk
  /// dan toko terdaftar, baru user melengkapi detail.
  Future<void> _goStepTwo() async {
    final name = _nameCtrl.text.trim();
    final slug = _slugCtrl.text.trim().toLowerCase();
    if (name.isEmpty ||
        slug.isEmpty ||
        _slugStatus == 'taken' ||
        _slugStatus == 'invalid') {
      TopToast.error(context, 'Lengkapi nama toko dan alamat yang tersedia');
      return;
    }
    setState(() => _saving = true);
    try {
      final svc = OnlineOrderService(Supabase.instance.client);
      final themeId = ref.read(themePresetProvider);
      final theme = NusaConfig.themePresets[themeId];
      final result = await svc.upsertStore(
        storeName: name,
        slug: slug,
        variant: NusaConfig.productId,
        themeId: themeId,
        primaryColor: theme?['primary'] != null
            ? _colorToHex(theme!['primary']!)
            : '',
        darkColor: theme?['dark'] != null ? _colorToHex(theme!['dark']!) : '',
        softColor: theme?['soft'] != null ? _colorToHex(theme!['soft']!) : '',
        description: _descCtrl.text.trim(),
        whatsapp: _waCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        openHours: _hoursCtrl.text.trim(),
        isActive: _isActive,
      );
      if (result.ok) {
        await ref.read(settingsRepoProvider).setStoreName(name);
        if (mounted) {
          setState(() {
            _step = 2;
            _everSaved = true;
            _storeUrl =
                'https://nusa-online.vercel.app/toko/${NusaConfig.productId}/$slug';
          });
        }
      } else {
        if (mounted) TopToast.error(context, _errorMessage(result.error));
      }
    } catch (e) {
      if (mounted) TopToast.error(context, 'Error: $e');
    }
    if (mounted) setState(() => _saving = false);
  }

  /// Validasi + cek ketersediaan slug (debounce 400ms). Slug unik global —
  /// dua toko tidak boleh memakai alamat yang sama.
  void _onSlugChanged(String value) {
    _slugDebounce?.cancel();
    final s = value.trim().toLowerCase();
    final valid = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(s);
    if (s.isEmpty || !valid || s.length > 40) {
      setState(() => _slugStatus = s.isEmpty ? null : 'invalid');
      return;
    }
    setState(() => _slugStatus = 'checking');
    _slugDebounce = Timer(const Duration(milliseconds: 400), () async {
      final svc = OnlineOrderService(Supabase.instance.client);
      final available = await svc.isSlugAvailable(s);
      if (!mounted) return;
      setState(() {
        _slugStatus = available ? 'available' : 'taken';
      });
    });
  }

  /// Pesan error yang akurat — jangan asal "Cek koneksi internet".
  String _errorMessage(OnlineStoreError err) {
    switch (err) {
      case OnlineStoreError.notDeployed:
        return 'Fitur online belum aktif di server. Hubungi admin NUSA.';
      case OnlineStoreError.serverError:
        return 'Server sedang sibuk. Coba beberapa saat lagi.';
      case OnlineStoreError.noInternet:
        return 'Gagal menyimpan. Cek koneksi internet.';
      case OnlineStoreError.slugTaken:
        return 'Slug sudah digunakan toko lain. Ganti slug lain.';
      case OnlineStoreError.unknown:
        return 'Gagal menyimpan. Coba lagi.';
    }
  }

  Future<void> _syncProducts() async {
    setState(() {
      _saving = true;
      _imgFailedNames = [];
    });
    int imgSuccess = 0;
    int imgFailed = 0;
    try {
      final db = ref.read(databaseProvider);
      final products = await ProductRepository(db).getProducts();
      final online = products.where((p) => p.isOnline).toList();
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      final storeId = await OnlineOrderService(client).storeId;
      if (storeId == null) {
        if (mounted) setState(() => _saving = false);
        debugPrint('[OnlineStoreSetup] ⚠ No storeId (activation key)');
        return;
      }

      debugPrint(
        '[OnlineStoreSetup] Syncing ${online.length} products for store $storeId, uid=$uid',
      );

      // Phase 1: Upload all images + collect product data
      final rows = <Map<String, dynamic>>[];
      for (final prod in online) {
        String? imageUrl;

        if (prod.imagePath != null &&
            prod.imagePath!.isNotEmpty &&
            uid != null) {
          try {
            final file = File(prod.imagePath!);
            if (await file.exists()) {
              final filename = p.basename(prod.imagePath!);
              // Try upload with retry — pakai detail supaya ALASAN kegagalan
              // terlihat (MIME 415 / RLS 403 / jaringan), bukan senyap.
              bool uploaded = false;
              String failReason = 'upload gagal';
              for (int attempt = 0; attempt < 3; attempt++) {
                try {
                  if (attempt > 0) {
                    debugPrint(
                      '[OnlineStoreSetup] Retry upload ${prod.name} attempt $attempt',
                    );
                    await Future.delayed(Duration(seconds: attempt));
                  }
                  final svc = ImageStorageService(client, uid);
                  final r = await svc.uploadImageDetailed(
                    'products',
                    prod.imagePath!,
                  );
                  uploaded = r.ok;
                  failReason = r.message;
                  if (uploaded) break;
                } catch (e) {
                  failReason = '$e';
                  debugPrint(
                    '[OnlineStoreSetup] Upload attempt $attempt failed: $e',
                  );
                }
              }

              if (uploaded) {
                imageUrl = client.storage
                    .from('nusa-images')
                    .getPublicUrl(
                      '$uid/${NusaConfig.productId}/products/$filename',
                    );
                imgSuccess++;
                debugPrint(
                  '[OnlineStoreSetup] 📸 Uploaded: ${prod.name} → $imageUrl',
                );
              } else {
                imgFailed++;
                _imgFailedNames.add(prod.name);
                _imgFailReasons[prod.name] = failReason;
                debugPrint(
                  '[OnlineStoreSetup] ⚠ Upload gagal ${prod.name}: $failReason',
                );
              }
            } else {
              debugPrint(
                '[OnlineStoreSetup] ⚠ File not found: ${prod.imagePath}',
              );
              imgFailed++;
              _imgFailedNames.add(prod.name);
              _imgFailReasons[prod.name] = 'file gambar tidak ada di HP';
            }
          } catch (e) {
            imgFailed++;
            _imgFailedNames.add(prod.name);
            _imgFailReasons[prod.name] = '$e';
            debugPrint(
              '[OnlineStoreSetup] ⚠ Image skipped for ${prod.name}: $e',
            );
          }
        } else if (prod.imagePath != null && uid == null) {
          imgFailed++;
          _imgFailedNames.add(prod.name);
          _imgFailReasons[prod.name] = 'belum login Google (tidak bisa upload)';
          debugPrint('[OnlineStoreSetup] ⚠ No user ID — cannot upload images');
        }

        rows.add({
          'product_id': prod.id,
          'name': prod.name,
          'category': prod.category,
          'price': prod.sellPrice,
          'stock': prod.stock,
          'image': imageUrl ?? '',
          'description': '',
          'is_published': true,
        });
      }

      // Phase 2: Send ALL products in ONE batch to edge function
      String? syncError;
      if (rows.isNotEmpty) {
        debugPrint(
          '[OnlineStoreSetup] Sending ${rows.length} products to edge function',
        );
        final res = await client.functions.invoke(
          'online-store',
          body: {
            'action': 'sync_products',
            'store_id': storeId,
            'products': rows,
          },
        );
        debugPrint(
          '[OnlineStoreSetup] Edge function response: status=${res.status}',
        );
        if (res.status >= 400) {
          syncError = 'Server: ${res.data ?? 'status ${res.status}'}'.trim();
          debugPrint('[OnlineStoreSetup] Edge function error: ${res.data}');
        }
      } else {
        syncError =
            'Belum ada produk yang ditandai tampil online. '
            'Centang "Online" saat edit produk.';
      }

      if (mounted) {
        setState(() => _onlineProductCount = online.length);
        if (syncError != null) {
          TopToast.error(context, 'Sinkron gagal — $syncError');
          return;
        }
        final msg =
            '${online.length} produk disinkronkan'
            '${imgSuccess > 0 ? " ($imgSuccess gambar)" : ""}'
            '${imgFailed > 0 ? " — $imgFailed gambar gagal" : ""}';
        if (imgFailed > 0 && _imgFailedNames.isNotEmpty) {
          // Nama produk yang gagal + ALASAN — dipakai banner peringatan.
          final reason = _imgFailReasons[_imgFailedNames.first] ?? '';
          setState(() {});
          TopToast.info(
            context,
            '${_imgFailedNames.length} produk gagal upload gambar: '
            '${_imgFailedNames.take(3).join(', ')}'
            '${_imgFailedNames.length > 3 ? ', dll.' : ''}'
            '${reason.isNotEmpty ? ' — $reason' : ''}',
          );
        }
        TopToast.success(context, msg);
      }
    } catch (e) {
      debugPrint('[OnlineStoreSetup] Gagal sinkronisasi produk: $e');
      if (mounted) TopToast.error(context, 'Gagal sinkron: $e');
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _pickLogo() async {
    try {
      final path = await pickAndSaveImage(maxSize: 1024, prefix: 'store_logo_');
      if (path == null) return; // cancelled or failed
      await ref.read(settingsRepoProvider).setStoreLogoPath(path);
      setState(() => _logoPath = path);

      // Cloud upload
      try {
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid != null) {
          ImageStorageService(
            Supabase.instance.client,
            uid,
          ).uploadImage('settings', path);
        }
      } catch (_) {}
    } catch (_) {
      if (mounted) TopToast.error(context, 'Gagal menyimpan logo');
    }
  }

  Future<void> _openPreview() async {
    if (_storeUrl == null || _storeUrl!.isEmpty) {
      if (mounted) TopToast.error(context, 'URL toko belum diatur.');
      return;
    }
    var uri = Uri.parse(_storeUrl!);
    if (!uri.hasScheme) uri = Uri.parse('https://$_storeUrl');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        TopToast.error(context, 'Tidak dapat membuka browser.');
      }
    } catch (_) {
      if (mounted) TopToast.error(context, 'Gagal membuka website');
    }
  }

  void _initWebView() {
    if (_storeUrl == null || _storeUrl!.isEmpty) return;
    if (_webViewCtrl != null) return; // already initialized

    _webViewCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() {}); // trigger rebuild for spinner
          },
          onPageFinished: (_) {
            if (mounted) setState(() {}); // hide spinner
          },
        ),
      )
      ..loadRequest(Uri.parse(_storeUrl!));
  }

  void _copyLink() {
    if (_storeUrl != null) {
      Clipboard.setData(ClipboardData(text: _storeUrl!));
      TopToast.success(context, 'Link toko disalin');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? NusaConfig.darkTextPrimary
        : NusaConfig.textPrimary;
    final subColor = isDark
        ? NusaConfig.darkTextSecondary
        : NusaConfig.textSecondary;
    final cardBg = isDark ? NusaConfig.darkSurface : Colors.white;
    final borderC = isDark ? NusaConfig.darkBorder : NusaConfig.borderColor;

    if (_loading) {
      return ScreenScaffold(
        'Toko Online',
        Center(child: CircularProgressIndicator()),
      );
    }

    return ScreenScaffold(
      'Toko Online',
      SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ═══════════════════════════════════════════════
            // STEP INDICATOR — 1 Setup Alamat · 2 Detail
            // ═══════════════════════════════════════════════
            _buildStepIndicator(isDark),

            SizedBox(height: 16),

            // ═══════════════════════════════════════════════
            // STEP 1 — Setup Alamat Toko (wajib)
            // ═══════════════════════════════════════════════
            if (_step == 1) _buildStepOne(isDark, textColor, subColor, borderC),

            // ═══════════════════════════════════════════════
            // STEP 2 — Detail & Simpan
            // ═══════════════════════════════════════════════
            if (_step == 2)
              _buildStepTwo(isDark, textColor, subColor, cardBg, borderC),

            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Step indicator — 2 chip sederhana mengikuti design system.
  // ─────────────────────────────────────────────────────────
  Widget _buildStepIndicator(bool isDark) {
    return Row(
      children: [
        Expanded(child: _stepChip(isDark, 1, 'Setup Alamat')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: isDark
                ? NusaConfig.darkTextTertiary
                : NusaConfig.textTertiary,
          ),
        ),
        Expanded(child: _stepChip(isDark, 2, 'Detail & Simpan')),
      ],
    );
  }

  Widget _stepChip(bool isDark, int step, String label) {
    final active = _step >= step;
    final done = _step > step;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: active
            ? (done
                  ? Color(0xFF059669).withValues(alpha: 0.1)
                  : NusaConfig.activeSoft)
            : (isDark ? NusaConfig.darkSurface2 : Color(0xFFF3F4F6)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? (done
                    ? Color(0xFF059669).withValues(alpha: 0.3)
                    : NusaConfig.activePrimary.withValues(alpha: 0.3))
              : (isDark ? NusaConfig.darkBorder : NusaConfig.borderColor),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? Color(0xFF059669)
                  : (active
                        ? NusaConfig.activePrimary
                        : (isDark
                              ? NusaConfig.darkTextTertiary
                              : NusaConfig.textTertiary)),
            ),
            child: Center(
              child: done
                  ? Icon(Icons.check, size: 13, color: Colors.white)
                  : Text(
                      '$step',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: active
                            ? Colors.white
                            : (isDark
                                  ? NusaConfig.darkTextTertiary
                                  : NusaConfig.textTertiary),
                      ),
                    ),
            ),
          ),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active
                    ? (done ? Color(0xFF059669) : NusaConfig.activePrimary)
                    : (isDark
                          ? NusaConfig.darkTextTertiary
                          : NusaConfig.textTertiary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // STEP 1 — Setup Alamat Toko (Nama + Slug, paling atas/wajib)
  // ─────────────────────────────────────────────────────────
  Widget _buildStepOne(
    bool isDark,
    Color textColor,
    Color subColor,
    Color borderC,
  ) {
    return NusaCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront_rounded, size: 18, color: textColor),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Setup Alamat Toko',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            'Langkah pertama: beri nama dan alamat website toko kamu. '
            'Alamat ini yang akan dibagikan ke pelanggan.',
            style: TextStyle(fontSize: 12, color: subColor, height: 1.4),
          ),
          SizedBox(height: 16),

          NusaInput(
            'Nama Toko *',
            controller: _nameCtrl,
            hint: 'Cth: Toko Berkah Jaya',
            prefixIcon: Icon(Icons.store),
          ),
          SizedBox(height: 14),

          // ── Slug custom (alamat website) + validasi unik ──
          _buildSlugField(isDark, textColor, subColor, borderC),

          SizedBox(height: 20),

          // Tombol Lanjut — aktif saat nama + slug tersedia.
          NusaButton(
            _saving ? 'Memeriksa...' : 'Lanjut',
            onPressed:
                (_saving ||
                    _nameCtrl.text.trim().isEmpty ||
                    _slugCtrl.text.trim().isEmpty ||
                    _slugStatus == 'taken' ||
                    _slugStatus == 'invalid')
                ? null
                : _goStepTwo,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Slug field — dipakai di Step 1.
  // ─────────────────────────────────────────────────────────
  Widget _buildSlugField(
    bool isDark,
    Color textColor,
    Color subColor,
    Color borderC,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alamat Toko (Slug) *',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark
                ? NusaConfig.darkTextSecondary
                : NusaConfig.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _slugStatus == 'taken'
                  ? const Color(0xFFE63946)
                  : _slugStatus == 'available'
                  ? const Color(0xFF059669)
                  : borderC,
            ),
          ),
          child: TextField(
            controller: _slugCtrl,
            onChanged: _onSlugChanged,
            style: TextStyle(
              fontSize: 15,
              color: textColor,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: 'cth: berkah-jaya',
              hintStyle: TextStyle(
                color: isDark
                    ? NusaConfig.darkTextTertiary
                    : NusaConfig.textTertiary,
                fontSize: 15,
              ),
              prefixIcon: Icon(
                Icons.alternate_email,
                size: 20,
                color: subColor,
              ),
              suffixIcon: _slugStatus == null || _slugStatus == 'checking'
                  ? (_slugStatus == 'checking'
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: subColor,
                              ),
                            ),
                          )
                        : null)
                  : Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        _slugStatus == 'available'
                            ? Icons.check_circle
                            : Icons.cancel,
                        size: 20,
                        color: _slugStatus == 'available'
                            ? const Color(0xFF059669)
                            : const Color(0xFFE63946),
                      ),
                    ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Status / penjelasan slug untuk user awam.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _slugStatus == 'taken'
                  ? Icons.error_outline
                  : _slugStatus == 'available'
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              size: 14,
              color: _slugStatus == 'taken'
                  ? const Color(0xFFE63946)
                  : _slugStatus == 'available'
                  ? const Color(0xFF059669)
                  : subColor,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _slugStatus == 'taken'
                    ? 'Slug ini sudah dipakai toko lain. Ganti slug lain.'
                    : _slugStatus == 'available'
                    ? 'Slug tersedia — alamat toko kamu: '
                          'nusa-online.vercel.app/toko/'
                          '${NusaConfig.productId}/${_slugCtrl.text.trim().toLowerCase()}'
                    : _slugStatus == 'invalid'
                    ? 'Slug tidak valid. Gunakan huruf kecil, angka, dan tanda hubung (-). '
                          'Contoh: berkah-jaya'
                    : 'Apa itu slug? Slug adalah alamat website toko kamu, '
                          'contoh: "berkah-jaya". Gunakan huruf kecil, angka, '
                          'dan tanda hubung (-). Sistem otomatis memeriksa apakah '
                          'slug sudah dipakai toko lain.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: _slugStatus == 'taken'
                      ? const Color(0xFFE63946)
                      : _slugStatus == 'available'
                      ? const Color(0xFF059669)
                      : subColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // STEP 2 — Detail toko + produk + toggle + Simpan.
  // ─────────────────────────────────────────────────────────
  Widget _buildStepTwo(
    bool isDark,
    Color textColor,
    Color subColor,
    Color cardBg,
    Color borderC,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Info toko: logo + deskripsi + WA/jam + alamat.
        _buildStoreInfoForm(isDark, textColor, subColor, cardBg, borderC),

        SizedBox(height: 16),

        // Produk online + tombol sinkron.
        _buildProductsCard(isDark, textColor, subColor, cardBg, borderC),

        SizedBox(height: 16),

        // Toggle aktivasi (tanpa status card lebay).
        _buildActivationToggle(isDark, textColor, subColor, cardBg, borderC),

        SizedBox(height: 20),

        NusaButton(
          _saving ? 'Menyimpan...' : 'Simpan',
          onPressed: _saving ? null : () => _save(),
        ),
        SizedBox(height: 8),

        // Tombol kembali ke langkah 1 (ubah alamat toko).
        if (_everSaved)
          TextButton(
            onPressed: _saving ? null : () => setState(() => _step = 1),
            style: TextButton.styleFrom(
              foregroundColor: isDark
                  ? NusaConfig.darkTextSecondary
                  : NusaConfig.textSecondary,
            ),
            child: Text(
              'Ubah Nama / Alamat Toko',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        SizedBox(height: 8),

        Text(
          'Produk yang dicentang "Tampil di Toko Online" saat edit produk '
          'akan otomatis muncul di website toko kamu.',
          style: TextStyle(
            fontSize: 11,
            color: isDark
                ? NusaConfig.darkTextTertiary
                : NusaConfig.textTertiary,
          ),
          textAlign: TextAlign.center,
        ),

        // ── Preview: paling bawah, sendiri, hanya setelah tersimpan ──
        if (_everSaved) ...[
          SizedBox(height: 20),
          _buildStorePreview(isDark, textColor, subColor, cardBg, borderC),
        ],
      ],
    );
  }

  Widget _buildStorePreview(
    bool isDark,
    Color textColor,
    Color subColor,
    Color cardBg,
    Color borderC,
  ) {
    final name = _nameCtrl.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.preview, size: 18, color: textColor),
            SizedBox(width: 8),
            Text(
              'Tampilan Toko',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
        SizedBox(height: 10),

        // ── Link toko + aksi (Salin / Buka Website) ──
        if (_storeUrl != null) ...[
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkSurface2 : Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderC),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.link, size: 16, color: subColor),
                    SizedBox(width: 8),
                    Text(
                      'Link Toko',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: subColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderC),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _storeUrl!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: NusaConfig.activePrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      GestureDetector(
                        onTap: _copyLink,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: NusaConfig.activePrimary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.copy,
                                size: 14,
                                color: NusaConfig.activePrimary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Salin',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: NusaConfig.activePrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openPreview,
                    icon: Icon(Icons.open_in_browser, size: 16),
                    label: Text(
                      'Buka Website',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Color(0xFF059669),
                      side: BorderSide(color: Color(0xFF059669)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
        ],

        if (_isActive && _storeUrl != null) ...[
          // ── Live WebView preview (9:16 phone ratio) ──
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: borderC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Builder(
                  builder: (context) {
                    // Init WebView on first build
                    _initWebView();
                    if (_webViewCtrl == null) {
                      return Center(child: CircularProgressIndicator());
                    }
                    return WebViewWidget(controller: _webViewCtrl!);
                  },
                ),
              ),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Ini adalah tampilan live toko online kamu.',
            style: TextStyle(fontSize: 11, color: subColor),
          ),
        ] else ...[
          // ── Fallback: static store info card ──
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkSurface2 : Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderC),
            ),
            child: Column(
              children: [
                if (_logoPath != null && _logoPath!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(_logoPath!),
                        height: 56,
                        fit: BoxFit.contain,
                        cacheWidth: 200,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isDark
                            ? NusaConfig.darkSurface
                            : Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.store,
                        size: 28,
                        color: isDark
                            ? NusaConfig.darkTextSecondary
                            : Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                Text(
                  name.isNotEmpty ? name : 'Nama Toko Kamu',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_descCtrl.text.trim().isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    _descCtrl.text.trim(),
                    style: TextStyle(fontSize: 12, color: subColor),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _isActive ? Color(0xFFD1FAE5) : Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _isActive ? 'Buka' : 'Tutup',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _isActive ? Color(0xFF059669) : Color(0xFFE63946),
                    ),
                  ),
                ),
                if (_hoursCtrl.text.trim().isNotEmpty) ...[
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.access_time, size: 13, color: subColor),
                      SizedBox(width: 4),
                      Text(
                        _hoursCtrl.text.trim(),
                        style: TextStyle(fontSize: 12, color: subColor),
                      ),
                    ],
                  ),
                ],
                if (_addressCtrl.text.trim().isNotEmpty) ...[
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on, size: 13, color: subColor),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _addressCtrl.text.trim(),
                          style: TextStyle(fontSize: 12, color: subColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
        SizedBox(height: 16),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // Store Info Form
  // ─────────────────────────────────────────────────────────
  Widget _buildStoreInfoForm(
    bool isDark,
    Color textColor,
    Color subColor,
    Color cardBg,
    Color borderC,
  ) {
    return NusaCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note, size: 18, color: textColor),
              SizedBox(width: 8),
              Text(
                'Info Toko',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // ── Logo ──
          Row(
            children: [
              GestureDetector(
                onTap: _pickLogo,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark
                        ? NusaConfig.darkSurface2
                        : NusaConfig.surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderC, width: 1.5),
                  ),
                  child: _logoPath != null && _logoPath!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(_logoPath!),
                            fit: BoxFit.cover,
                            cacheWidth: 400,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: 24,
                              color: subColor,
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Logo',
                              style: TextStyle(fontSize: 8, color: subColor),
                            ),
                          ],
                        ),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Logo Toko',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tampil di halaman toko & preview',
                      style: TextStyle(fontSize: 11, color: subColor),
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _pickLogo,
                          icon: Icon(Icons.upload, size: 16),
                          label: Text(
                            _logoPath != null ? 'Ganti' : 'Upload',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        if (_logoPath != null)
                          TextButton.icon(
                            onPressed: () {
                              ref
                                  .read(settingsRepoProvider)
                                  .setStoreLogoPath('');
                              setState(() => _logoPath = null);
                            },
                            icon: Icon(
                              Icons.delete,
                              size: 16,
                              color: Colors.redAccent,
                            ),
                            label: Text(
                              'Hapus',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Deskripsi
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deskripsi Singkat',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? NusaConfig.darkSurface2
                      : NusaConfig.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderC),
                ),
                child: TextField(
                  controller: _descCtrl,
                  maxLines: 2,
                  style: TextStyle(fontSize: 14, color: textColor),
                  decoration: InputDecoration(
                    hintText: 'Jelaskan toko kamu dalam 1-2 kalimat...',
                    hintStyle: TextStyle(fontSize: 13, color: subColor),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(14),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: NusaInput(
                  'WhatsApp',
                  controller: _waCtrl,
                  hint: '08xxxxxxxxxx',
                  prefixIcon: Icon(Icons.phone_android),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: NusaInput(
                  'Jam Buka',
                  controller: _hoursCtrl,
                  hint: '08:00 - 21:00',
                  prefixIcon: Icon(Icons.access_time),
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          NusaInput(
            'Alamat',
            controller: _addressCtrl,
            hint: 'Jl. ... (opsional)',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Products Card
  // ─────────────────────────────────────────────────────────
  Widget _buildProductsCard(
    bool isDark,
    Color textColor,
    Color subColor,
    Color cardBg,
    Color borderC,
  ) {
    return NusaCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.inventory_2,
                  size: 22,
                  color: Color(0xFFF59E0B),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Produk Online',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      _onlineProductCount > 0
                          ? '$_onlineProductCount produk siap tampil di website'
                          : 'Belum ada produk online. Tandai produk saat edit.',
                      style: TextStyle(fontSize: 12, color: subColor),
                    ),
                  ],
                ),
              ),
              // Sync button
              if (_isActive)
                TextButton(
                  onPressed: _saving ? null : _syncProducts,
                  style: TextButton.styleFrom(
                    foregroundColor: Color(0xFFF59E0B),
                    padding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Text(
                    'Sinkronkan',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
            ],
          ),
          // Peringatan upload gambar gagal — jangan senyap (K6).
          if (_imgFailedNames.isNotEmpty)
            Container(
              margin: EdgeInsets.only(top: 12),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(
                  0xFFEF4444,
                ).withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.image_not_supported_outlined,
                    size: 18,
                    color: const Color(0xFFEF4444),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_imgFailedNames.length} produk gagal upload gambar',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFEF4444),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '${_imgFailedNames.take(3).join(', ')}'
                          '${_imgFailedNames.length > 3 ? ', dll.' : ''} — '
                          '${_imgFailReasons[_imgFailedNames.first] ?? 'periksa koneksi & coba Sinkronkan lagi'}. '
                          'Produk tetap tampil tanpa foto.',
                          style: TextStyle(fontSize: 11.5, color: subColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Activation Toggle
  // ─────────────────────────────────────────────────────────
  Widget _buildActivationToggle(
    bool isDark,
    Color textColor,
    Color subColor,
    Color cardBg,
    Color borderC,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isActive ? Color(0xFF059669).withValues(alpha: 0.06) : cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isActive
              ? Color(0xFF059669).withValues(alpha: 0.25)
              : borderC,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _isActive
                  ? Color(0xFF059669).withValues(alpha: 0.15)
                  : NusaConfig.activeSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isActive ? Icons.toggle_on : Icons.toggle_off,
              size: 24,
              color: _isActive ? Color(0xFF059669) : NusaConfig.activePrimary,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isActive ? 'Toko Online Aktif' : 'Aktifkan Toko Online',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  _isActive
                      ? 'Pelanggan bisa melihat & order di website'
                      : 'Produk dengan centang "Online" akan tampil',
                  style: TextStyle(fontSize: 12, color: subColor),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Switch(
            value: _isActive,
            activeColor: Color(0xFF059669),
            activeTrackColor: Color(0xFF059669).withValues(alpha: 0.3),
            onChanged: (v) {
              setState(() => _isActive = v);
              _save(activate: v);
            },
          ),
        ],
      ),
    );
  }
}
