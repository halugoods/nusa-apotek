import 'dart:async';
import 'dart:convert';
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
import 'package:nusa_kasir/core/services/google_auth_service.dart';
import 'package:nusa_kasir/core/services/image_storage_service.dart';
import 'package:nusa_kasir/core/services/online_order_service.dart';
import 'package:nusa_kasir/core/services/online_product_sync_service.dart';
import 'package:nusa_kasir/core/utils/image_utils.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/branch_repository.dart';
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
  // Google UID — namespace path upload storage (dipakai bangun URL publik).
  String _logoUid = '';
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

  // ── Pengaturan Toko Online (tab di langkah 2) ──
  // Metode bayar: [{name,type,details,qr,handling_fee,is_active}]
  List<Map<String, dynamic>> _payMethods = [];
  // Tipe pesanan: [{name,is_active}] (default Ambil Sendiri / Delivery)
  List<Map<String, dynamic>> _orderTypes = [];
  // Jam ambil: [{time,is_active}]
  List<Map<String, dynamic>> _pickupOptions = [];
  // Ongkir (Rp) untuk tipe Delivery.
  int _deliveryFee = 0;
  // Pengaturan member: {pointEarnPercent, pointExchangeRate, minRedeem,
  // referralRewardType, referralRewardValue}
  Map<String, dynamic> _memberSettings = {};
  // Cabang lokal (sync ke tabel branches — hanya yang status 'Aktif').
  List<Branche> _branches = [];
  // Kupon ter-sync (read-back via get_promos untuk CRUD).
  List<Map<String, dynamic>> _promos = [];
  bool _storeCfgDirty = false;
  // Sub-tab dalam pengaturan toko online.
  int _cfgTab = 0;

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

  /// URL publik logo toko di bucket nusa-images (path sama dengan upload).
  /// Dipakai upsertStore supaya web bisa render <img>.
  String _buildLogoPublicUrl(String localPath) {
    try {
      return Supabase.instance.client.storage
          .from('nusa-images')
          .getPublicUrl(
              '$_logoUid/${NusaConfig.productId}/settings/${p.basename(localPath)}');
    } catch (_) {
      return '';
    }
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
    // v2.2.57+120: auto-fill info toko dari "Data Toko" lokal (No. HP/WA +
    // alamat) — user yang sudah mengisi Data Toko di Pengaturan tidak perlu
    // mengetik ulang di sini. Nilai cloud tetap menang bila sudah ada.
    final localPhone = await repo.getStorePhone();
    final localAddress = await repo.getStoreAddress();
    if (localPhone.isNotEmpty) _waCtrl.text = localPhone;
    if (localAddress.isNotEmpty) _addressCtrl.text = localAddress;

    // Load store logo from local settings
    _logoPath = await repo.getStoreLogoPath();
    // Simpan UID untuk bangun URL publik logo (v2.2.35).
    try {
      _logoUid = await GoogleAuthService.getStoredUserId() ?? '';
    } catch (_) {}

    final fallbackSlug = _slugify(name);
    _storeUrl =
        'https://nusa-online.vercel.app/toko/${NusaConfig.productId}/$fallbackSlug';

    // Count online products
    try {
      final db = ref.read(databaseProvider);
      final products = await ProductRepository(db).getProducts();
      _onlineProductCount = products.where((p) => p.isOnline).length;
    } catch (_) {}

    // Cabang lokal (dipakai tab Pengaturan → sync cabang).
    try {
      _branches = await BranchRepository(
        ref.read(databaseProvider),
      ).getAll();
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

        // ── Pengaturan toko online (kolom baru) ──
        _payMethods = OnlineOrderService.parseList(
          store['payment_methods'] as String?,
        );
        _orderTypes = OnlineOrderService.parseList(
          store['order_types'] as String?,
        );
        _pickupOptions = OnlineOrderService.parseList(
          store['pickup_options'] as String?,
        );
        _deliveryFee =
            (store['delivery_fee'] as num?)?.toInt() ?? 0;
        try {
          final ms = store['member_settings'] as String?;
          if (ms != null && ms.isNotEmpty) {
            _memberSettings =
                (jsonDecode(ms) as Map).cast<String, dynamic>();
          }
        } catch (_) {}
        if (_payMethods.isEmpty) {
          _payMethods = [
            {'name': 'Tunai', 'type': 'tunai', 'handling_fee': 0, 'is_active': true},
            {'name': 'QRIS', 'type': 'qris', 'handling_fee': 0, 'is_active': true},
            {'name': 'Transfer', 'type': 'bank', 'handling_fee': 0, 'is_active': true},
          ];
        }
        if (_orderTypes.isEmpty) {
          _orderTypes = [
            {'name': 'Ambil Sendiri', 'is_active': true},
            {'name': 'Delivery', 'is_active': true},
          ];
        }
        if (_pickupOptions.isEmpty) {
          _pickupOptions = [
            {'time': 'Segera', 'is_active': true},
            {'time': '15 Menit', 'is_active': true},
            {'time': '30 Menit', 'is_active': true},
            {'time': '1 Jam', 'is_active': true},
          ];
        }
        // Kupon read-back untuk CRUD.
        _promos = await svc.getPromos();
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
        // Logo toko (v2.2.35) — URL publik dari upload storage settings.
        logoUrl: _logoPath != null && _logoPath!.isNotEmpty
            ? _buildLogoPublicUrl(_logoPath!)
            : null,
      );
      final ok = result.ok;

      if (ok) {
        await ref.read(settingsRepoProvider).setStoreName(name);
        // v2.2.57+120: info toko di sini ikut disimpan ke Data Toko lokal
        // (No. HP/WA + alamat) — dua arah, jadi edit di toko online juga
        // memperbarui Data Toko di Pengaturan.
        await ref.read(settingsRepoProvider).setStorePhone(_waCtrl.text.trim());
        await ref
            .read(settingsRepoProvider)
            .setStoreAddress(_addressCtrl.text.trim());
        _storeUrl =
            'https://nusa-online.vercel.app/toko/${NusaConfig.productId}/$slug';

        // Kirim pengaturan toko online (metode bayar, tipe pesanan, dll).
        final cfgOk = await _pushStoreConfig(svc);
        if (_storeCfgDirty && !cfgOk) {
          if (mounted) {
            TopToast.error(
              context,
              'Pengaturan tambahan gagal terkirim — coba lagi.',
            );
          }
        } else {
          _storeCfgDirty = false;
        }

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

  /// Kirim pengaturan tambahan toko online (payment methods, order types,
  /// pickup options, delivery fee, member settings, cabang, kupon) ke
  /// Supabase. Dipanggil setelah upsert_store sukses.
  Future<bool> _pushStoreConfig(OnlineOrderService svc) async {
    try {
      final r1 = await svc.upsertStore(
        storeName: _nameCtrl.text.trim(),
        slug: _slugCtrl.text.trim().toLowerCase(),
        variant: NusaConfig.productId,
        isActive: _isActive,
        orderTypes: _jsonStr(_orderTypes),
        deliveryFee: _deliveryFee,
        pickupOptions: _jsonStr(_pickupOptions),
        paymentMethods: _jsonStr(_payMethods),
        memberSettings: _jsonStr(_memberSettings),
      );
      if (!r1.ok) return false;

      // Sync cabang (hanya yang status 'Aktif') — web butuh dropdown cabang.
      final activeBranches = _branches
          .where((b) => b.status == 'Aktif')
          .map(
            (b) => {
              'name': b.name,
              'phone': b.phone ?? '',
              'is_active': true,
            },
          )
          .toList();
      await svc.syncBranches(activeBranches);
      await svc.syncPromos(_promos);
      return true;
    } catch (e) {
      debugPrint('[OnlineStoreSetup] _pushStoreConfig error: $e');
      return false;
    }
  }

  String _jsonStr(Object? o) => jsonEncode(o);

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
    // Status global sinkron produk online — chip header ikut bergerak.
    OnlineProductSyncService.status.value = OnlineSyncStatus(
      OnlineSyncPhase.uploading,
      lastOkAt: OnlineProductSyncService.status.value.lastOkAt,
      lastCount: OnlineProductSyncService.status.value.lastCount,
    );
    try {
      final db = ref.read(databaseProvider);
      final online = OnlineOrderService(Supabase.instance.client);
      final result = await online.syncOnlineProducts(db);
      _imgFailedNames
        ..clear()
        ..addAll(result.failedNames);
      _imgFailReasons
        ..clear()
        ..addAll(result.imgFailReasons);
      if (mounted) {
        setState(() => _onlineProductCount = result.count);
        if (result.error != null) {
          OnlineProductSyncService.status.value = OnlineSyncStatus(
            OnlineSyncPhase.failed,
            lastOkAt: OnlineProductSyncService.status.value.lastOkAt,
            lastCount: OnlineProductSyncService.status.value.lastCount,
          );
          TopToast.error(context, 'Sinkron gagal — ${result.error}');
          return;
        }
        OnlineProductSyncService.status.value = OnlineSyncStatus(
          OnlineSyncPhase.ok,
          lastOkAt: DateTime.now(),
          lastCount: result.count,
        );
        try {
          await SecureStore.write(
            key: 'nusa_online_sync_status_${NusaConfig.productId}',
            value: DateTime.now().toUtc().millisecondsSinceEpoch.toString(),
          );
        } catch (_) {}
        final msg =
            '${result.count} produk disinkronkan'
            '${result.imgSuccess > 0 ? " (${result.imgSuccess} gambar)" : ""}'
            '${result.imgFailed > 0 ? " — ${result.imgFailed} gambar gagal" : ""}';
        if (result.imgFailed > 0 && result.failedNames.isNotEmpty) {
          final reason = result.imgFailReasons[result.failedNames.first] ?? '';
          TopToast.info(
            context,
            '${result.failedNames.length} produk gagal upload gambar: '
            '${result.failedNames.take(3).join(', ')}'
            '${result.failedNames.length > 3 ? ', dll.' : ''}'
            '${reason.isNotEmpty ? ' — $reason' : ''}',
          );
        }
        TopToast.success(context, msg);
      }
    } catch (e) {
      debugPrint('[OnlineStoreSetup] Gagal sinkronisasi produk: $e');
      OnlineProductSyncService.status.value = OnlineSyncStatus(
        OnlineSyncPhase.failed,
        lastOkAt: OnlineProductSyncService.status.value.lastOkAt,
        lastCount: OnlineProductSyncService.status.value.lastCount,
      );
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

      // Cloud upload → logo_url ke website (v2.2.35).
      try {
        // Logo toko — ID Google dari SecureStore (bukan Supabase currentUser).
        final uid = await GoogleAuthService.getStoredUserId();
        if (uid != null) {
          _logoUid = uid;
          final svc = ImageStorageService(Supabase.instance.client, uid);
          final ok = await svc.uploadImage('settings', path);
          if (ok) {
            // URL publik (policy SELECT bucket nusa-images) — dikirim ke
            // store_settings supaya web bisa render <img>.
            final publicUrl = Supabase.instance.client.storage
                .from('nusa-images')
                .getPublicUrl('$uid/${NusaConfig.productId}/settings/'
                    '${p.basename(path)}');
            final online = OnlineOrderService(Supabase.instance.client);
            await online.upsertStore(
              storeName: _nameCtrl.text.trim().isEmpty
                  ? 'Toko Saya'
                  : _nameCtrl.text.trim(),
              slug: _slugCtrl.text.trim().isEmpty
                  ? 'toko-saya'
                  : _slugCtrl.text.trim().toLowerCase(),
              variant: NusaConfig.productId,
              logoUrl: publicUrl,
            );
          }
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
      // Chip status sinkron produk online (v2.2.57+120) — hijau = sudah
      // sinkron, amber = sedang unggah, merah = gagal, abu = belum pernah.
      actions: [_OnlineStoreSyncChip()],
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

        // Pengaturan toko online (metode bayar, tipe pesanan, cabang,
        // kupon, poin member) — tab baru.
        _buildStoreConfigCard(isDark, textColor, subColor, cardBg, borderC),

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
              // Sync button — v2.2.57+120: wrap-card; hijau saat sinkron
              // sukses (tombol terkunci abu-abu, status "Tersinkron"),
              // amber saat sedang unggah, hijau siap dipakai manual.
              if (_isActive)
                ValueListenableBuilder<OnlineSyncStatus>(
                  valueListenable: OnlineProductSyncService.status,
                  builder: (context, st, _) {
                    final synced = st.phase == OnlineSyncPhase.ok;
                    final uploading = st.phase == OnlineSyncPhase.uploading;
                    final failed = st.phase == OnlineSyncPhase.failed;
                    final Color bg;
                    final Color fg;
                    final String label;
                    if (uploading) {
                      bg = Color(0xFFF59E0B).withValues(alpha: 0.12);
                      fg = Color(0xFFB45309);
                      label = 'Menyinkron…';
                    } else if (synced) {
                      bg = NusaConfig.success.withValues(alpha: 0.12);
                      fg = NusaConfig.success;
                      label = 'Tersinkron ✓';
                    } else if (failed) {
                      bg = NusaConfig.error.withValues(alpha: 0.12);
                      fg = NusaConfig.error;
                      label = 'Coba Sinkron';
                    } else {
                      bg = Color(0xFFF59E0B).withValues(alpha: 0.12);
                      fg = Color(0xFFF59E0B);
                      label = 'Sinkronkan';
                    }
                    return GestureDetector(
                      onTap: (uploading || synced) || _saving
                          ? null
                          : _syncProducts,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(10),
                          // Disabled (sudah tersinkron) = tanpa border tegas.
                          border: synced || uploading
                              ? Border.all(
                                  color: fg.withValues(alpha: 0.3),
                                  width: 1,
                                )
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (uploading)
                              SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: fg,
                                ),
                              )
                            else
                              Icon(
                                synced
                                    ? Icons.cloud_done_outlined
                                    : Icons.sync_rounded,
                                size: 16,
                                color: fg,
                              ),
                            SizedBox(width: 6),
                            Text(
                              label,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                color: fg,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
  // Pengaturan Toko Online — kartu + sub-tab (Metode Bayar,
  // Tipe Pesanan, Cabang, Kupon, Member). Semua tersimpan saat
  // tombol "Simpan" utama ditekan (di-push via _pushStoreConfig).
  // ─────────────────────────────────────────────────────────
  Widget _buildStoreConfigCard(
    bool isDark,
    Color textColor,
    Color subColor,
    Color cardBg,
    Color borderC,
  ) {
    const tabs = ['Bayar', 'Pesanan', 'Cabang', 'Kupon', 'Member'];
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
                  color: Color(0xFF8B5CF6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  size: 22,
                  color: Color(0xFF8B5CF6),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pengaturan Toko Online',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Metode bayar, tipe pesanan, cabang, kupon & poin',
                      style: TextStyle(fontSize: 12, color: subColor),
                    ),
                  ],
                ),
              ),
              if (_storeCfgDirty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Color(0xFF8B5CF6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Belum disimpan',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12),

          // ── Sub-tab chips ──
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _cfgTab = i),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _cfgTab == i
                              ? Color(0xFF8B5CF6)
                              : (isDark
                                    ? NusaConfig.darkSurface2
                                    : Color(0xFFF3F4F6)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          tabs[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _cfgTab == i
                                ? Colors.white
                                : (isDark
                                      ? NusaConfig.darkTextSecondary
                                      : NusaConfig.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 12),

          // ── Panel sesuai sub-tab aktif ──
          if (_cfgTab == 0)
            _buildPayMethodsPanel(isDark, textColor, subColor, borderC)
          else if (_cfgTab == 1)
            _buildOrderTypesPanel(isDark, textColor, subColor, borderC)
          else if (_cfgTab == 2)
            _buildBranchesPanel(isDark, textColor, subColor, borderC)
          else if (_cfgTab == 3)
            _buildPromosPanel(isDark, textColor, subColor, borderC)
          else
            _buildMemberPanel(isDark, textColor, subColor, borderC),
        ],
      ),
    );
  }

  // ── Metode Bayar ──
  Widget _buildPayMethodsPanel(
    bool isDark,
    Color textColor,
    Color subColor,
    Color borderC,
  ) {
    if (_payMethods.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Belum ada metode bayar. Tambah Tunai / QRIS / Transfer.',
          style: TextStyle(fontSize: 12, color: subColor),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _payMethods.length; i++)
          Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkSurface2 : Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderC),
            ),
            child: Row(
              children: [
                Icon(
                  _payMethods[i]['type'] == 'qris'
                      ? Icons.qr_code_2
                      : _payMethods[i]['type'] == 'bank'
                      ? Icons.account_balance
                      : Icons.payments,
                  size: 20,
                  color: Color(0xFF8B5CF6),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_payMethods[i]['name']}',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        _payMethods[i]['details'] != null &&
                                (_payMethods[i]['details'] as String).isNotEmpty
                            ? '${_payMethods[i]['details']}'
                            : 'Fee: Rp ${_payMethods[i]['handling_fee'] ?? 0}',
                        style: TextStyle(fontSize: 11, color: subColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Toggle aktif / nonaktif
                Switch(
                  value: _payMethods[i]['is_active'] != false,
                  activeColor: Color(0xFF8B5CF6),
                  activeTrackColor: Color(0xFF8B5CF6).withValues(alpha: 0.3),
                  onChanged: (v) {
                    setState(() {
                      _payMethods[i]['is_active'] = v;
                      _storeCfgDirty = true;
                    });
                  },
                ),
              ],
            ),
          ),
        Text(
          'Aktif/nonaktif langsung tampil di website. Detail QRIS/bank '
          'mengikuti menu Pembayaran (hanya Tampilkan yang diaktifkan).',
          style: TextStyle(fontSize: 11, color: subColor, height: 1.4),
        ),
      ],
    );
  }

  // ── Tipe Pesanan + Jam Ambil + Ongkir ──
  Widget _buildOrderTypesPanel(
    bool isDark,
    Color textColor,
    Color subColor,
    Color borderC,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tipe Pesanan',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        SizedBox(height: 6),
        for (var i = 0; i < _orderTypes.length; i++)
          Container(
            margin: EdgeInsets.only(bottom: 6),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkSurface2 : Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderC),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_orderTypes[i]['name']}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),
                Switch(
                  value: _orderTypes[i]['is_active'] != false,
                  activeColor: Color(0xFF8B5CF6),
                  activeTrackColor: Color(0xFF8B5CF6).withValues(alpha: 0.3),
                  onChanged: (v) {
                    setState(() {
                      _orderTypes[i]['is_active'] = v;
                      _storeCfgDirty = true;
                    });
                  },
                ),
              ],
            ),
          ),
        if (_orderTypes.any((t) => t['name'] == 'Delivery' &&
            t['is_active'] != false)) ...[
          SizedBox(height: 10),
          Text(
            'Ongkir (Rp) — untuk tipe Delivery',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkSurface2 : NusaConfig.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderC),
            ),
            child: TextField(
              controller: TextEditingController(
                text: _deliveryFee == 0 ? '' : '$_deliveryFee',
              ),
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: 14, color: textColor),
              decoration: InputDecoration(
                hintText: 'Cth: 5000',
                hintStyle: TextStyle(fontSize: 13, color: subColor),
                prefixIcon: Icon(Icons.local_shipping, size: 20, color: subColor),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: (v) {
                final n = int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), ''));
                setState(() {
                  _deliveryFee = n ?? 0;
                  _storeCfgDirty = true;
                });
              },
            ),
          ),
        ],
        SizedBox(height: 12),
        Text(
          'Jam Ambil (dropdown di website)',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        SizedBox(height: 6),
        for (var i = 0; i < _pickupOptions.length; i++)
          Container(
            margin: EdgeInsets.only(bottom: 6),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkSurface2 : Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderC),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_pickupOptions[i]['time']}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),
                // Edit teks jam ambil
                GestureDetector(
                  onTap: () => _editPickupOption(i, isDark),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark
                          ? NusaConfig.darkSurface
                          : NusaConfig.inputFill,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: subColor,
                    ),
                  ),
                ),
                SizedBox(width: 6),
                // Hapus jam ambil
                GestureDetector(
                  onTap: () => _deletePickupOption(i),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
                Switch(
                  value: _pickupOptions[i]['is_active'] != false,
                  activeColor: Color(0xFF8B5CF6),
                  activeTrackColor: Color(0xFF8B5CF6).withValues(alpha: 0.3),
                  onChanged: (v) {
                    setState(() {
                      _pickupOptions[i]['is_active'] = v;
                      _storeCfgDirty = true;
                    });
                  },
                ),
              ],
            ),
          ),
        // ── + Tambah Jam Ambil (teks bebas) ──
        GestureDetector(
          onTap: () => _addPickupOption(isDark),
          child: Container(
            margin: EdgeInsets.only(top: 4),
            padding: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Color(0xFF8B5CF6).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Color(0xFF8B5CF6).withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 18, color: Color(0xFF8B5CF6)),
                SizedBox(width: 6),
                Text(
                  'Tambah Jam',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Teks bebas — mis. "Segera", "30 Menit", "14:00"',
          style: TextStyle(fontSize: 11, color: subColor),
        ),
      ],
    );
  }

  // ── CRUD Jam Ambil (teks bebas) ─────────────────────────────────

  Future<void> _addPickupOption(bool isDark) async {
    final value = await _pickupOptionDialog(isDark, '', 'Tambah Jam Ambil');
    if (value == null || value.trim().isEmpty) return;
    setState(() {
      _pickupOptions.add({'time': value.trim(), 'is_active': true});
      _storeCfgDirty = true;
    });
  }

  Future<void> _editPickupOption(int index, bool isDark) async {
    final current = '${_pickupOptions[index]['time']}';
    final value = await _pickupOptionDialog(isDark, current, 'Edit Jam Ambil');
    if (value == null || value.trim().isEmpty) return;
    setState(() {
      _pickupOptions[index]['time'] = value.trim();
      _storeCfgDirty = true;
    });
  }

  Future<void> _deletePickupOption(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Jam Ambil?'),
        content: Text('"${_pickupOptions[index]['time']}" akan dihapus dari website.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _pickupOptions.removeAt(index);
      _storeCfgDirty = true;
    });
  }

  Future<String?> _pickupOptionDialog(
    bool isDark,
    String initial,
    String title,
  ) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(
            color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Mis. Segera / 30 Menit / 14:00',
            hintStyle: TextStyle(
              fontSize: 13,
              color: isDark
                  ? NusaConfig.darkTextTertiary
                  : NusaConfig.textTertiary,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // ── Cabang (dari menu Cabang — hanya yang Aktif di-sync) ──
  Widget _buildBranchesPanel(
    bool isDark,
    Color textColor,
    Color subColor,
    Color borderC,
  ) {
    if (_branches.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Belum ada cabang. Tambahkan cabang di menu Cabang, lalu '
          'simpan — cabang Aktif akan tampil di website.',
          style: TextStyle(fontSize: 12, color: subColor, height: 1.4),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in _branches)
          Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkSurface2 : Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderC),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: (b.status == 'Aktif'
                            ? NusaConfig.accentGreen
                            : Color(0xFF9CA3AF))
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.storefront,
                    size: 20,
                    color: b.status == 'Aktif'
                        ? NusaConfig.accentGreen
                        : Color(0xFF9CA3AF),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.name,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      if (b.phone != null && b.phone!.isNotEmpty)
                        Text(
                          b.phone!,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: subColor,
                            fontFamily: 'monospace',
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (b.status == 'Aktif'
                            ? NusaConfig.accentGreen
                            : Color(0xFF9CA3AF))
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    b.status == 'Aktif' ? 'Tampil' : 'Sembunyi',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: b.status == 'Aktif'
                          ? NusaConfig.accentGreen
                          : Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Text(
          'Kelola cabang di menu Cabang. Hanya status "Aktif" yang '
          'dikirim ke website (pembeli wajib pilih cabang).',
          style: TextStyle(fontSize: 11, color: subColor, height: 1.4),
        ),
      ],
    );
  }

  // ── Kupon / Promo ──
  Widget _buildPromosPanel(
    bool isDark,
    Color textColor,
    Color subColor,
    Color borderC,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Kupon diskon tampil di checkout website',
                style: TextStyle(fontSize: 11.5, color: subColor),
              ),
            ),
            TextButton.icon(
              onPressed: _showPromoForm,
              icon: Icon(Icons.add, size: 16),
              label: Text('Tambah'),
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFF8B5CF6),
              ),
            ),
          ],
        ),
        if (_promos.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Belum ada kupon. Contoh: "HEMAT10" diskon 10% atau '
              '"LEBARAN5K" potong Rp5.000.',
              style: TextStyle(fontSize: 12, color: subColor, height: 1.4),
            ),
          )
        else
          for (var i = 0; i < _promos.length; i++)
            Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? NusaConfig.darkSurface2 : Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderC),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_promos[i]['code']}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_promos[i]['title'] ?? ''}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Switch(
                        value: _promos[i]['is_active'] != false,
                        activeColor: Color(0xFF8B5CF6),
                        activeTrackColor:
                            Color(0xFF8B5CF6).withValues(alpha: 0.3),
                        onChanged: (v) {
                          setState(() {
                            _promos[i]['is_active'] = v;
                            _storeCfgDirty = true;
                          });
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    _promoSummary(_promos[i]),
                    style: TextStyle(fontSize: 11, color: subColor),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  String _promoSummary(Map<String, dynamic> p) {
    final type = p['type'] == 'nominal' ? 'Rp' : '%';
    final value = p['value'] ?? 0;
    final minSpend = (p['min_spend'] as num?)?.toInt() ?? 0;
    final quota = p['quota'];
    final buf = StringBuffer('Diskon $value$type');
    if (minSpend > 0) buf.write(' · min Rp${formatRupiah(minSpend)}');
    if (quota != null) buf.write(' · kuota $quota');
    return buf.toString();
  }

  /// Form tambah/edit kupon — bottom sheet.
  void _showPromoForm({int? index}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final editing = index != null && index < _promos.length;
    final existing = editing ? _promos[index] : null;
    final codeCtrl = TextEditingController(
      text: (existing?['code'] as String?) ?? '',
    );
    final titleCtrl = TextEditingController(
      text: (existing?['title'] as String?) ?? '',
    );
    final minCtrl = TextEditingController(
      text: ((existing?['min_spend'] as num?)?.toInt() ?? 0) == 0
          ? ''
          : '${(existing?['min_spend'] as num?)?.toInt()}',
    );
    final valueCtrl = TextEditingController(
      text: '${(existing?['value'] as num?)?.toInt() ?? 0}',
    );
    final quotaCtrl = TextEditingController(
      text: existing?['quota'] == null
          ? ''
          : '${existing?['quota']}',
    );
    var type = existing?['type'] == 'nominal' ? 'nominal' : 'persen';
    var minSpend = (existing?['min_spend'] as num?)?.toInt() ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final isDarkL = Theme.of(ctx).brightness == Brightness.dark;
          return Container(
            decoration: BoxDecoration(
              color: isDarkL ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              10,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDarkL
                            ? NusaConfig.darkDivider
                            : NusaConfig.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.confirmation_number_outlined,
                          color: Color(0xFFF59E0B),
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        editing ? 'Edit Kupon' : 'Kupon Baru',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDarkL
                              ? NusaConfig.darkTextPrimary
                              : NusaConfig.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  NusaInput(
                    'Kode Kupon *',
                    controller: codeCtrl,
                    hint: 'Cth: HEMAT10',
                    prefixIcon: Icon(Icons.tag),
                  ),
                  SizedBox(height: 12),
                  NusaInput(
                    'Nama Kupon',
                    controller: titleCtrl,
                    hint: 'Cth: Diskon Hemat',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSt(() => type = 'persen'),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: type == 'persen'
                                  ? Color(0xFF8B5CF6).withValues(alpha: 0.12)
                                  : (isDarkL
                                        ? NusaConfig.darkSurface2
                                        : Color(0xFFF3F4F6)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: type == 'persen'
                                    ? Color(0xFF8B5CF6)
                                    : (isDarkL
                                          ? NusaConfig.darkBorder
                                          : NusaConfig.borderColor),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Persen (%)',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: type == 'persen'
                                      ? Color(0xFF8B5CF6)
                                      : (isDarkL
                                            ? NusaConfig.darkTextSecondary
                                            : NusaConfig.textSecondary),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSt(() => type = 'nominal'),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: type == 'nominal'
                                  ? Color(0xFF8B5CF6).withValues(alpha: 0.12)
                                  : (isDarkL
                                        ? NusaConfig.darkSurface2
                                        : Color(0xFFF3F4F6)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: type == 'nominal'
                                    ? Color(0xFF8B5CF6)
                                    : (isDarkL
                                          ? NusaConfig.darkBorder
                                          : NusaConfig.borderColor),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Nominal (Rp)',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: type == 'nominal'
                                      ? Color(0xFF8B5CF6)
                                      : (isDarkL
                                            ? NusaConfig.darkTextSecondary
                                            : NusaConfig.textSecondary),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  NusaInput(
                    type == 'persen'
                        ? 'Diskon (%) *'
                        : 'Diskon (Rp) *',
                    controller: valueCtrl,
                    hint: type == 'persen' ? 'Cth: 10' : 'Cth: 5000',
                    type: TextInputType.number,
                  ),
                  SizedBox(height: 12),
                  NusaInput(
                    'Min. Belanja (Rp)',
                    controller: minCtrl,
                    hint: '0 = tanpa minimal',
                    type: TextInputType.number,
                  ),
                  SizedBox(height: 12),
                  NusaInput(
                    'Kuota (jumlah pemakaian)',
                    controller: quotaCtrl,
                    hint: 'Kosong = tanpa batas',
                    type: TextInputType.number,
                  ),
                  SizedBox(height: 20),
                  NusaButton(
                    'Simpan Kupon',
                    onPressed: () {
                      final code = codeCtrl.text.trim().toUpperCase();
                      final value =
                          int.tryParse(valueCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                      if (code.isEmpty || value <= 0) {
                        TopToast.error(ctx, 'Kode & nilai diskon wajib diisi');
                        return;
                      }
                      final promo = {
                        'code': code,
                        'title': titleCtrl.text.trim(),
                        'type': type,
                        'value': value,
                        'min_spend': int.tryParse(
                              minCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
                            ) ??
                            0,
                        'quota': quotaCtrl.text.trim().isEmpty
                            ? null
                            : int.tryParse(
                                quotaCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
                              ),
                        'limit_per_user': 1,
                        'is_active': true,
                      };
                      setState(() {
                        if (editing) {
                          _promos[index] = promo;
                        } else {
                          _promos.add(promo);
                        }
                        _storeCfgDirty = true;
                      });
                      Navigator.pop(ctx);
                      TopToast.success(
                        context,
                        editing ? 'Kupon diperbarui' : 'Kupon ditambahkan',
                      );
                    },
                  ),
                  if (editing) ...[
                    SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _promos.removeAt(index);
                          _storeCfgDirty = true;
                        });
                        Navigator.pop(ctx);
                        TopToast.success(context, 'Kupon dihapus');
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                      child: Text(
                        'Hapus Kupon',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Member & Poin ──
  Widget _buildMemberPanel(
    bool isDark,
    Color textColor,
    Color subColor,
    Color borderC,
  ) {
    final earnPercent =
        (_memberSettings['pointEarnPercent'] as num?)?.toInt() ?? 1;
    final exchangeRate =
        (_memberSettings['pointExchangeRate'] as num?)?.toInt() ?? 1000;
    final minRedeem = (_memberSettings['minRedeem'] as num?)?.toInt() ?? 500;
    final refType = _memberSettings['referralRewardType'] as String? ?? 'persen';
    final refValue =
        (_memberSettings['referralRewardValue'] as num?)?.toInt() ?? 5;
    final goldMin = (_memberSettings['goldMin'] as num?)?.toInt() ?? 1000;
    final platinumMin =
        (_memberSettings['platinumMin'] as num?)?.toInt() ?? 5000;
    final goldPercent = (_memberSettings['goldPercent'] as num?)?.toInt() ?? 2;
    final platinumPercent =
        (_memberSettings['platinumPercent'] as num?)?.toInt() ?? 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cfgNumberField(
          isDark,
          textColor,
          subColor,
          borderC,
          label: 'Poin per belanja (%)',
          hint: 'Cth: 1 = 1% dari total belanja',
          initial: earnPercent,
          onChanged: (v) {
            setState(() {
              _memberSettings['pointEarnPercent'] = v;
              _storeCfgDirty = true;
            });
          },
        ),
        SizedBox(height: 12),
        _cfgNumberField(
          isDark,
          textColor,
          subColor,
          borderC,
          label: 'Nilai tukar (Rp per poin)',
          hint: 'Cth: 1000 = 1 poin setara Rp1.000',
          initial: exchangeRate,
          onChanged: (v) {
            setState(() {
              _memberSettings['pointExchangeRate'] = v;
              _storeCfgDirty = true;
            });
          },
        ),
        SizedBox(height: 12),
        _cfgNumberField(
          isDark,
          textColor,
          subColor,
          borderC,
          label: 'Poin minimal tukar',
          hint: 'Cth: 500',
          initial: minRedeem,
          onChanged: (v) {
            setState(() {
              _memberSettings['minRedeem'] = v;
              _storeCfgDirty = true;
            });
          },
        ),
        SizedBox(height: 16),
        Text(
          'Tier Member (diskon otomatis)',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        SizedBox(height: 8),
        _cfgNumberField(
          isDark,
          textColor,
          subColor,
          borderC,
          label: 'Gold — min poin',
          hint: 'Cth: 1000',
          initial: goldMin,
          onChanged: (v) {
            setState(() {
              _memberSettings['goldMin'] = v;
              _storeCfgDirty = true;
            });
          },
        ),
        SizedBox(height: 12),
        _cfgNumberField(
          isDark,
          textColor,
          subColor,
          borderC,
          label: 'Gold — diskon (%)',
          hint: 'Cth: 2',
          initial: goldPercent,
          onChanged: (v) {
            setState(() {
              _memberSettings['goldPercent'] = v;
              _storeCfgDirty = true;
            });
          },
        ),
        SizedBox(height: 12),
        _cfgNumberField(
          isDark,
          textColor,
          subColor,
          borderC,
          label: 'Platinum — min poin',
          hint: 'Cth: 5000',
          initial: platinumMin,
          onChanged: (v) {
            setState(() {
              _memberSettings['platinumMin'] = v;
              _storeCfgDirty = true;
            });
          },
        ),
        SizedBox(height: 12),
        _cfgNumberField(
          isDark,
          textColor,
          subColor,
          borderC,
          label: 'Platinum — diskon (%)',
          hint: 'Cth: 5',
          initial: platinumPercent,
          onChanged: (v) {
            setState(() {
              _memberSettings['platinumPercent'] = v;
              _storeCfgDirty = true;
            });
          },
        ),
        SizedBox(height: 16),
        Text(
          'Program Ajak Teman',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _memberSettings['referralRewardType'] = 'persen';
                    _storeCfgDirty = true;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: refType == 'persen'
                        ? Color(0xFF8B5CF6).withValues(alpha: 0.12)
                        : (isDark ? NusaConfig.darkSurface2 : Color(0xFFF3F4F6)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: refType == 'persen'
                          ? Color(0xFF8B5CF6)
                          : borderC,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Persen (%)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: refType == 'persen'
                            ? Color(0xFF8B5CF6)
                            : subColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _memberSettings['referralRewardType'] = 'nominal';
                    _storeCfgDirty = true;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: refType == 'nominal'
                        ? Color(0xFF8B5CF6).withValues(alpha: 0.12)
                        : (isDark ? NusaConfig.darkSurface2 : Color(0xFFF3F4F6)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: refType == 'nominal'
                          ? Color(0xFF8B5CF6)
                          : borderC,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Nominal (Rp)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: refType == 'nominal'
                            ? Color(0xFF8B5CF6)
                            : subColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        _cfgNumberField(
          isDark,
          textColor,
          subColor,
          borderC,
          label: refType == 'persen' ? 'Reward referrer (%)' : 'Reward referrer (Rp)',
          hint: 'Cth: 5',
          initial: refValue,
          onChanged: (v) {
            setState(() {
              _memberSettings['referralRewardValue'] = v;
              _storeCfgDirty = true;
            });
          },
        ),
        SizedBox(height: 12),
        Text(
          'Pembeli yang membagikan link ?ref=<nomor> mendapat poin reward '
          'saat temannya (pembeli baru) checkout pertama kali.',
          style: TextStyle(fontSize: 11, color: subColor, height: 1.4),
        ),
      ],
    );
  }

  /// Field angka untuk pengaturan member (label DI ATAS field — style baru).
  Widget _cfgNumberField(
    bool isDark,
    Color textColor,
    Color subColor,
    Color borderC, {
    required String label,
    required String hint,
    required int initial,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark
                ? NusaConfig.darkTextSecondary
                : NusaConfig.textSecondary,
          ),
        ),
        SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface2 : NusaConfig.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderC),
          ),
          child: TextField(
            controller: TextEditingController(
              text: initial == 0 ? '' : '$initial',
            ),
            keyboardType: TextInputType.number,
            style: TextStyle(fontSize: 14, color: textColor),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: 13, color: subColor),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            onChanged: (v) {
              final n = int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), ''));
              onChanged(n ?? 0);
            },
          ),
        ),
      ],
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

/// Chip status sinkron produk ke toko online (v2.2.57+120) — di header
/// Toko Online, mirror ikon cloud dashboard:
///   hijau cloud_done   = produk terakhir tersinkron (HH:MM)
///   amber cloud_upload = sedang mengunggah produk
///   merah cloud_off    = sinkron terakhir gagal
///   abu  cloud         = belum ada sinkron (produk belum pernah disinkron)
/// Tap → penjelasan singkat.
class _OnlineStoreSyncChip extends StatelessWidget {
  const _OnlineStoreSyncChip();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<OnlineSyncStatus>(
      valueListenable: OnlineProductSyncService.status,
      builder: (context, st, _) {
        final IconData icon;
        final Color color;
        switch (st.phase) {
          case OnlineSyncPhase.uploading:
            icon = Icons.cloud_upload_outlined;
            color = NusaConfig.warning;
          case OnlineSyncPhase.ok:
            icon = Icons.cloud_done_outlined;
            color = NusaConfig.success;
          case OnlineSyncPhase.failed:
            icon = Icons.cloud_off_outlined;
            color = NusaConfig.error;
          case OnlineSyncPhase.idle:
            icon = Icons.cloud_outlined;
            color = isDark
                ? NusaConfig.darkTextTertiary
                : NusaConfig.textTertiary;
        }
        return GestureDetector(
          onTap: () => _explain(context, st),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
        );
      },
    );
  }

  void _explain(BuildContext context, OnlineSyncStatus st) {
    final String msg;
    switch (st.phase) {
      case OnlineSyncPhase.uploading:
        msg = 'Menyinkronkan produk ke toko online…';
      case OnlineSyncPhase.ok:
        final n = st.lastCount;
        msg = 'Produk tersinkron'
            '${n != null ? ' ($n produk)' : ''}'
            '${st.lastOkAt != null ? ' ${_hhmm(st.lastOkAt!)}' : ''}.';
      case OnlineSyncPhase.failed:
        msg = 'Sinkron produk GAGAL. Periksa koneksi — produk '
            'akan dicoba ulang otomatis saat ada perubahan.';
      case OnlineSyncPhase.idle:
        msg = 'Belum ada produk tersinkron. Produk yang ditandai '
            '"Online" akan otomatis tersinkron ke website.';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _hhmm(DateTime t) {
    final local = t.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
