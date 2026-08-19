import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:functions_client/functions_client.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/services/google_auth_service.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Klasifikasi kegagalan edge function — dipakai UI untuk menampilkan
/// pesan yang akurat (jangan bilang "Cek koneksi" saat sebenarnya 404).
enum OnlineStoreError {
  /// Edge function belum ter-deploy / route tidak ditemukan (HTTP 404).
  notDeployed,

  /// Server merespons 5xx / timeout — coba lagi nanti.
  serverError,

  /// Perangkat tidak punya koneksi (SocketException/TimeoutException).
  noInternet,

  /// Slug sudah dipakai toko lain — user harus ganti slug (HTTP 409).
  slugTaken,

  /// Lain-lain.
  unknown,
}

/// Handles all Supabase communication for the online store feature.
/// Uses Supabase Edge Function `online-store` for admin operations
/// (which runs with service_role to bypass RLS) and direct calls for
/// public data reads.
class OnlineOrderService {
  final SupabaseClient supabase;

  OnlineOrderService(this.supabase);

  /// Normalisasi nomor WA ke format 08xx (GAS pattern):
  /// strip karakter non-digit, lalu 62→0, lalu 8→08.
  static String normalizePhoneTo08(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('62')) digits = '0${digits.substring(2)}';
    if (digits.startsWith('8')) digits = '0$digits';
    return digits;
  }

  /// 08xx → 628xx untuk link wa.me.
  static String formatWA(String phone08) {
    final d = phone08.replaceAll(RegExp(r'[^0-9]'), '');
    return d.startsWith('0') ? '62${d.substring(1)}' : d;
  }

  /// Parse JSON string yang optional → fallback bila kosong/rusak.
  static List<Map<String, dynamic>> parseList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final v = jsonDecode(raw);
      if (v is List) return v.cast<Map<String, dynamic>>();
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Store id yang sudah ter-resolve ke row asli di server (setelah
  /// fallback (user_id, variant)). Dipakai semua operasi supaya produk/
  /// order/promo selalu menunjuk ke row toko yang sama.
  String? _resolvedStoreId;

  /// Get the store_id (derived from activation key for uniqueness).
  /// Setelah [getStoreSettings] berhasil, memakai store_id row asli —
  /// supaya clear-data/re-login (key mungkin beda) tidak membuat toko
  /// baru atau sync ke store yang salah.
  Future<String?> get storeId async {
    if (_resolvedStoreId != null) return _resolvedStoreId;
    final key = await SecureStore.getActivation();
    return key; // activation key as store_id
  }

  /// Klasifikasi error → OnlineStoreError yang bisa ditampilkan ke user.
  OnlineStoreError _classify(Object? e) {
    if (e is FunctionException) {
      if (e.status == 404) return OnlineStoreError.notDeployed;
      if (e.status >= 500) return OnlineStoreError.serverError;
      return OnlineStoreError.unknown;
    }
    if (e is SocketException || e is TimeoutException) {
      return OnlineStoreError.noInternet;
    }
    return OnlineStoreError.unknown;
  }

  /// Invoke edge function + retry 1x saat error server transient (5xx).
  /// Error lain (404, no internet, dll) langsung dilempar ulang.
  Future<FunctionResponse> _invoke(String function, Map body) async {
    try {
      return await supabase.functions.invoke(function, body: body);
    } catch (e) {
      final cls = _classify(e);
      if (cls == OnlineStoreError.serverError) {
        debugPrint('[OnlineOrderService] retry 1x setelah error server: $e');
        await Future.delayed(const Duration(milliseconds: 600));
        return await supabase.functions.invoke(function, body: body);
      }
      rethrow;
    }
  }

  /// ---------------------------------------------------------------
  /// Store Settings
  /// ---------------------------------------------------------------

  /// Returns (ok, error). `error` hanya relevan saat `ok == false`.
  /// Slug divalidasi unik oleh edge function: jika sudah dipakai toko lain,
  /// edge function mengembalikan error 'slug_taken' → (ok: false,
  /// error: OnlineStoreError.slugTaken).
  Future<({bool ok, OnlineStoreError error})> upsertStore({
    required String storeName,
    String? description,
    String? whatsapp,
    String? address,
    String? openHours,
    bool isActive = false,
    String? slug,
    String? variant,
    String? themeId,
    String? primaryColor,
    String? darkColor,
    String? softColor,
    String? orderTypes,
    int? deliveryFee,
    String? pickupOptions,
    String? paymentMethods,
    String? memberSettings,
    String? logoUrl,
  }) async {
    final sid = await storeId;
    if (sid == null) {
      debugPrint(
        '[OnlineOrderService] upsertStore: no store_id (activation key missing)',
      );
      return (ok: false, error: OnlineStoreError.unknown);
    }
    try {
      // Google UID = pemilik toko (persistensi lintas clear-data &
      // anti rebutan slug antar varian). Sama dengan backup identity.
      final userId = await GoogleAuthService.getStoredUserId();
      debugPrint(
        '[OnlineOrderService] upsertStore: invoking online-store edge function...',
      );
      final res = await _invoke('online-store', {
        'action': 'upsert_store',
        'store_id': sid,
        if (userId != null) 'user_id': userId,
        'store_name': storeName,
        'slug': slug ?? '',
        'variant': variant ?? '',
        'theme_id': themeId ?? '',
        'primary_color': primaryColor ?? '',
        'dark_color': darkColor ?? '',
        'soft_color': softColor ?? '',
        'description': description ?? '',
        'whatsapp': whatsapp ?? '',
        'address': address ?? '',
        'open_hours': openHours ?? '08:00 - 21:00',
        'is_active': isActive,
        if (orderTypes != null) 'order_types': orderTypes,
        if (deliveryFee != null) 'delivery_fee': deliveryFee,
        if (pickupOptions != null) 'pickup_options': pickupOptions,
        if (paymentMethods != null) 'payment_methods': paymentMethods,
        if (memberSettings != null) 'member_settings': memberSettings,
        if (logoUrl != null) 'logo_url': logoUrl,
      });
      debugPrint('[OnlineOrderService] upsertStore: status=${res.status}');
      return (ok: res.status < 400, error: OnlineStoreError.unknown);
    } catch (e) {
      debugPrint('[OnlineOrderService] upsertStore ERROR: $e');
      if (e is FunctionException && e.status == 409) {
        return (ok: false, error: OnlineStoreError.slugTaken);
      }
      return (ok: false, error: _classify(e));
    }
  }

  /// Cek ketersediaan slug (debounce di UI). Sistem memastikan slug unik
  /// per varian — mencegah dua toko (varian sama) memakai alamat yang sama.
  /// Slug milik user ini sendiri (user_id sama) tidak dianggap taken.
  Future<bool> isSlugAvailable(String slug, {String? variant}) async {
    if (slug.trim().isEmpty) return false;
    try {
      final userId = await GoogleAuthService.getStoredUserId();
      final res = await _invoke('online-store', {
        'action': 'check_slug',
        'slug': slug.trim().toLowerCase(),
        'variant': variant ?? NusaConfig.productId,
        if (userId != null) 'user_id': userId,
      });
      if (res.status >= 400) return false;
      final data = res.data as Map<String, dynamic>;
      return (data['available'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getStoreSettings() async {
    final sid = await storeId;
    if (sid == null) return null;
    try {
      // Kirim user_id + variant: edge fn fallback ke (user_id, variant)
      // bila row by store_id tidak ada (clear-data / key beda).
      final userId = await GoogleAuthService.getStoredUserId();
      final res = await _invoke('online-store', {
        'action': 'get_store',
        'store_id': sid,
        if (userId != null) 'user_id': userId,
        'variant': NusaConfig.productId,
      });
      if (res.status >= 400) return null;
      final data = res.data as Map<String, dynamic>;
      final store = data['store'] as Map<String, dynamic>?;
      if (store != null) {
        final rowStoreId = store['store_id'] as String?;
        if (rowStoreId != null && rowStoreId.isNotEmpty) {
          // Pakai store_id row asli untuk operasi berikutnya (sync
          // produk/order/promo selalu menunjuk row yang sama).
          _resolvedStoreId = rowStoreId;
        }
      }
      return store;
    } catch (_) {
      return null;
    }
  }

  /// ---------------------------------------------------------------
  /// Product Sync
  /// ---------------------------------------------------------------

  Future<bool> syncProducts(List<Map<String, dynamic>> products) async {
    final sid = await storeId;
    if (sid == null) return false;
    try {
      final res = await _invoke('online-store', {
        'action': 'sync_products',
        'store_id': sid,
        'products': products,
      });
      return res.status < 400;
    } catch (_) {
      return false;
    }
  }

  /// ---------------------------------------------------------------
  /// Orders (live via Supabase Realtime)
  /// ---------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getOrders({
    String? status,
    int limit = 50,
  }) async {
    final sid = await storeId;
    if (sid == null) return [];
    try {
      final res = await _invoke('online-store', {
        'action': 'get_orders',
        'store_id': sid,
        'status': status,
        'limit': limit,
      });
      if (res.status >= 400) return [];
      final data = res.data as Map<String, dynamic>;
      return (data['orders'] as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<bool> updateOrderStatus({
    required int orderId,
    required String status,
    String? processedBy,
  }) async {
    final sid = await storeId;
    if (sid == null) return false;
    try {
      final res = await _invoke('online-store', {
        'action': 'update_order',
        'store_id': sid,
        'order_id': orderId,
        'status': status,
        'processed_by': processedBy ?? '',
      });
      return res.status < 400;
    } catch (_) {
      return false;
    }
  }

  /// Upload cabang Aktif (status == 'Aktif') + WA per cabang ke tabel
  /// `branches` (replace-all per store). Web memakai ini untuk dropdown
  /// cabang + WA tujuan order.
  Future<bool> syncBranches(List<Map<String, dynamic>> branches) async {
    final sid = await storeId;
    if (sid == null) return false;
    try {
      final res = await _invoke('online-store', {
        'action': 'sync_branches',
        'store_id': sid,
        'branches': branches,
      });
      return res.status < 400;
    } catch (_) {
      return false;
    }
  }

  /// Upload kupon/promo (quota/periode/minSpend/limitPerUser) ke tabel
  /// `promos` (replace-all per store). Web memvalidasi saat checkout.
  Future<bool> syncPromos(List<Map<String, dynamic>> promos) async {
    final sid = await storeId;
    if (sid == null) return false;
    try {
      final res = await _invoke('online-store', {
        'action': 'sync_promos',
        'store_id': sid,
        'promos': promos,
      });
      return res.status < 400;
    } catch (_) {
      return false;
    }
  }

  /// Read-back kupon untuk CRUD di app (hanya milik store ini).
  Future<List<Map<String, dynamic>>> getPromos() async {
    final sid = await storeId;
    if (sid == null) return [];
    try {
      final res = await _invoke('online-store', {
        'action': 'get_promos',
        'store_id': sid,
      });
      if (res.status >= 400) return [];
      final data = res.data as Map<String, dynamic>;
      return (data['promos'] as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Submit order dari storefront → edge function. Kembalikan
  /// (ok, errorMessage). errorMessage berisi pesan spesifik (mis. promo
  /// tidak valid) saat ok == false.
  Future<({bool ok, String errorMessage})> submitOrder(
    Map<String, dynamic> payload,
  ) async {
    try {
      final res = await _invoke('online-store', {
        'action': 'submit_order',
        ...payload,
      });
      if (res.status < 400) return (ok: true, errorMessage: '');
      final data = res.data is Map ? res.data as Map : {};
      final msg = data['error'] as String? ?? 'Gagal mengirim pesanan';
      return (ok: false, errorMessage: msg);
    } catch (e) {
      return (ok: false, errorMessage: 'Gagal mengirim pesanan: $e');
    }
  }

  /// Tukar poin member (validasi saldo di edge). Kembalikan
  /// (ok, errorMessage, pointsLeft).
  Future<({bool ok, String errorMessage, int pointsLeft})> redeemPoints({
    required String phone,
    required int points,
  }) async {
    final sid = await storeId;
    if (sid == null) return (ok: false, errorMessage: 'Toko belum aktif', pointsLeft: 0);
    try {
      final res = await _invoke('online-store', {
        'action': 'redeem_points',
        'store_id': sid,
        'phone': phone,
        'points': points,
      });
      if (res.status < 400) {
        final data = res.data is Map ? res.data as Map : {};
        return (
          ok: true,
          errorMessage: '',
          pointsLeft: (data['points_left'] as num?)?.toInt() ?? 0,
        );
      }
      final data = res.data is Map ? res.data as Map : {};
      return (
        ok: false,
        errorMessage: data['error'] as String? ?? 'Tukar poin gagal',
        pointsLeft: 0,
      );
    } catch (e) {
      return (ok: false, errorMessage: 'Tukar poin gagal: $e', pointsLeft: 0);
    }
  }

  /// Check if online store is configured and active
  Future<bool> get isStoreActive async {
    final settings = await getStoreSettings();
    return settings?['is_active'] == true;
  }

  /// ---------------------------------------------------------------
  /// Print form configs (Order Cetak — field per layanan)
  /// ---------------------------------------------------------------

  /// Upload config field form Order Cetak per layanan ke tabel
  /// `print_form_configs` (replace-all per store). Web tidak memakai —
  /// murni cadangan cloud supaya config tidak hilang saat clear-data.
  Future<bool> syncPrintFormConfigs(List<Map<String, dynamic>> configs) async {
    final sid = await storeId;
    if (sid == null) return false;
    try {
      final res = await _invoke('online-store', {
        'action': 'sync_print_form_configs',
        'store_id': sid,
        'configs': configs,
      });
      return res.status < 400;
    } catch (_) {
      return false;
    }
  }

  /// Read-back config field form Order Cetak milik store ini
  /// (daftar {service_name, fields_json}).
  Future<List<Map<String, dynamic>>> getPrintFormConfigs() async {
    final sid = await storeId;
    if (sid == null) return [];
    try {
      final res = await _invoke('online-store', {
        'action': 'get_print_form_configs',
        'store_id': sid,
      });
      if (res.status >= 400) return [];
      final data = res.data as Map<String, dynamic>;
      return (data['configs'] as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}
