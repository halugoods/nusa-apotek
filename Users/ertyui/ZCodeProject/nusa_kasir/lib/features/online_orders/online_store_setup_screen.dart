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

class _OnlineStoreSetupScreenState extends ConsumerState<OnlineStoreSetupScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _saving = false;
  String? _storeUrl;
  bool _isActive = false;
  String? _logoPath;
  int _onlineProductCount = 0;
  WebViewController? _webViewCtrl;

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _waCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController(text: '08:00 - 21:00');

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween(
      begin: 0.35,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _waCtrl.dispose();
    _addressCtrl.dispose();
    _hoursCtrl.dispose();
    _pulseCtrl.dispose();
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
    _storeUrl = 'https://nusa-online.vercel.app/toko/$fallbackSlug';

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
        _storeUrl =
            'https://nusa-online.vercel.app/toko/${cloudSlug ?? _slugify(_nameCtrl.text)}';
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

    setState(() => _saving = true);
    final isActive = activate ?? _isActive;

    try {
      final svc = OnlineOrderService(Supabase.instance.client);
      final slug = _slugify(name);
      final result = await svc.upsertStore(
        storeName: name,
        slug: slug,
        description: _descCtrl.text.trim(),
        whatsapp: _waCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        openHours: _hoursCtrl.text.trim(),
        isActive: isActive,
      );
      final ok = result.ok;

      if (ok) {
        await ref.read(settingsRepoProvider).setStoreName(name);
        _storeUrl = 'https://nusa-online.vercel.app/toko/$slug';

        if (isActive) await _syncProducts();

        if (mounted) {
          setState(() {
            _isActive = isActive;
            _storeUrl = 'https://nusa-online.vercel.app/toko/$slug';
          });
          TopToast.success(
            context,
            isActive ? 'Toko online diaktifkan! 🎉' : 'Pengaturan disimpan',
          );
        }
      } else {
        if (mounted) {
          TopToast.error(context, _errorMessage(result.error));
        }
      }
    } catch (e) {
      if (mounted) TopToast.error(context, 'Error: $e');
    }

    if (mounted) setState(() => _saving = false);
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
      case OnlineStoreError.unknown:
        return 'Gagal menyimpan. Coba lagi.';
    }
  }

  Future<void> _syncProducts() async {
    setState(() => _saving = true);
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
              // Try upload with retry
              bool uploaded = false;
              for (int attempt = 0; attempt < 3; attempt++) {
                try {
                  if (attempt > 0) {
                    debugPrint(
                      '[OnlineStoreSetup] Retry upload ${prod.name} attempt $attempt',
                    );
                    await Future.delayed(Duration(seconds: attempt));
                  }
                  final svc = ImageStorageService(client, uid);
                  uploaded = await svc.uploadImage('products', prod.imagePath!);
                  if (uploaded) break;
                } catch (e) {
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
                debugPrint(
                  '[OnlineStoreSetup] ⚠ All upload attempts failed for ${prod.name}',
                );
              }
            } else {
              debugPrint(
                '[OnlineStoreSetup] ⚠ File not found: ${prod.imagePath}',
              );
              imgFailed++;
            }
          } catch (e) {
            imgFailed++;
            debugPrint(
              '[OnlineStoreSetup] ⚠ Image skipped for ${prod.name}: $e',
            );
          }
        } else if (prod.imagePath != null && uid == null) {
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
          debugPrint('[OnlineStoreSetup] Edge function error: ${res.data}');
        }
      }

      if (mounted) {
        setState(() => _onlineProductCount = online.length);
        final msg =
            '${online.length} produk disinkronkan'
            '${imgSuccess > 0 ? " ($imgSuccess gambar)" : ""}'
            '${imgFailed > 0 ? " — $imgFailed gambar gagal" : ""}';
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
      TopToast.success(context, 'Link disalin! 📋');
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
            // STATUS CARD — Active/Inactive
            // ═══════════════════════════════════════════════
            _buildStatusCard(isDark),

            // ═══════════════════════════════════════════════
            // LINK CARD — copy link + Buka Website
            // ═══════════════════════════════════════════════
            if (_isActive && _storeUrl != null) ...[
              SizedBox(height: 12),
              _buildLinkCard(isDark, cardBg, borderC),
            ],

            SizedBox(height: 16),

            // ═══════════════════════════════════════════════
            // STORE PREVIEW MOCKUP
            // ═══════════════════════════════════════════════
            _buildStorePreview(isDark, textColor, subColor, cardBg, borderC),

            SizedBox(height: 16),

            // ═══════════════════════════════════════════════
            // STORE INFO FORM
            // ═══════════════════════════════════════════════
            _buildStoreInfoForm(isDark, textColor, subColor, cardBg, borderC),

            SizedBox(height: 16),

            // ═══════════════════════════════════════════════
            // PRODUCTS CARD
            // ═══════════════════════════════════════════════
            _buildProductsCard(isDark, textColor, subColor, cardBg, borderC),

            SizedBox(height: 20),

            // ═══════════════════════════════════════════════
            // ACTIVATION TOGGLE
            // ═══════════════════════════════════════════════
            _buildActivationToggle(
              isDark,
              textColor,
              subColor,
              cardBg,
              borderC,
            ),

            SizedBox(height: 24),

            // ═══════════════════════════════════════════════
            // SAVE BUTTON
            // ═══════════════════════════════════════════════
            NusaButton(
              _saving ? 'Menyimpan...' : '💾 Simpan Semua',
              onPressed: _saving ? null : () => _save(),
            ),
            SizedBox(height: 12),

            // Help text
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
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Status Card — Slim / pipih
  // ─────────────────────────────────────────────────────────
  Widget _buildStatusCard(bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: _isActive
            ? LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF047857)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: isDark
                    ? [Color(0xFF374151), Color(0xFF1F2937)]
                    : [Color(0xFF9CA3AF), Color(0xFF6B7280)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        boxShadow: _isActive
            ? [
                BoxShadow(
                  color: Color(0xFF059669).withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Dot glow (pulsing when active)
          if (_isActive)
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, child) => Opacity(
                opacity: _pulseAnim.value,
                child: Container(
                  width: 10,
                  height: 10,
                  margin: EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF4ADE80),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF4ADE80).withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Container(
              width: 10,
              height: 10,
              margin: EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white38,
              ),
            ),
          // Text
          Expanded(
            child: Text(
              _isActive ? 'Toko Online Kamu Aktif 🎉' : 'Toko Online Nonaktif',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Status badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _isActive ? 'ON' : 'OFF',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Link Card — copy link + Buka Website
  // ─────────────────────────────────────────────────────────
  Widget _buildLinkCard(bool isDark, Color cardBg, Color borderC) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.link,
                size: 16,
                color: isDark
                    ? NusaConfig.darkTextSecondary
                    : NusaConfig.textSecondary,
              ),
              SizedBox(width: 8),
              Text(
                'Link Toko',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? NusaConfig.darkTextSecondary
                      : NusaConfig.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkSurface2 : Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
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
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: NusaConfig.activePrimary.withValues(alpha: 0.1),
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
    );
  }

  // ─────────────────────────────────────────────────────────
  // Store Preview (WebView or fallback)
  // ─────────────────────────────────────────────────────────
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
                    _isActive ? '🟢 Buka' : '🔴 Tutup',
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

          NusaInput(
            'Nama Toko *',
            controller: _nameCtrl,
            hint: 'Cth: Toko Berkah Jaya',
            prefixIcon: Icon(Icons.store),
          ),
          SizedBox(height: 12),

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
      Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Color(0xFFF59E0B).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.inventory_2, size: 22, color: Color(0xFFF59E0B)),
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
