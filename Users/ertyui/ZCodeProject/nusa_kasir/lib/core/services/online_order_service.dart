import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:functions_client/functions_client.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
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

  /// Get the store_id (derived from activation key for uniqueness)
  Future<String?> get storeId async {
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
  }) async {
    final sid = await storeId;
    if (sid == null) {
      debugPrint(
        '[OnlineOrderService] upsertStore: no store_id (activation key missing)',
      );
      return (ok: false, error: OnlineStoreError.unknown);
    }
    try {
      debugPrint(
        '[OnlineOrderService] upsertStore: invoking online-store edge function...',
      );
      final res = await _invoke('online-store', {
        'action': 'upsert_store',
        'store_id': sid,
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
  Future<bool> isSlugAvailable(String slug, {String? variant}) async {
    if (slug.trim().isEmpty) return false;
    try {
      final res = await _invoke('online-store', {
        'action': 'check_slug',
        'slug': slug.trim().toLowerCase(),
        'variant': variant ?? NusaConfig.productId,
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
      final res = await _invoke('online-store', {
        'action': 'get_store',
        'store_id': sid,
      });
      if (res.status >= 400) return null;
      final data = res.data as Map<String, dynamic>;
      return data['store'] as Map<String, dynamic>?;
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

  /// Check if online store is configured and active
  Future<bool> get isStoreActive async {
    final settings = await getStoreSettings();
    return settings?['is_active'] == true;
  }
}
