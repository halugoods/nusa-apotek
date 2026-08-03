import 'package:flutter/foundation.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// ---------------------------------------------------------------
  /// Store Settings
  /// ---------------------------------------------------------------

  Future<bool> upsertStore({
    required String storeName,
    String? description,
    String? whatsapp,
    String? address,
    String? openHours,
    bool isActive = false,
    String? slug,
  }) async {
    final sid = await storeId;
    if (sid == null) {
      debugPrint('[OnlineOrderService] upsertStore: no store_id (activation key missing)');
      return false;
    }
    try {
      debugPrint('[OnlineOrderService] upsertStore: invoking online-store edge function...');
      final res = await supabase.functions.invoke('online-store', body: {
        'action': 'upsert_store',
        'store_id': sid,
        'store_name': storeName,
        'slug': slug ?? '',
        'description': description ?? '',
        'whatsapp': whatsapp ?? '',
        'address': address ?? '',
        'open_hours': openHours ?? '08:00 - 21:00',
        'is_active': isActive,
      });
      debugPrint('[OnlineOrderService] upsertStore: status=${res.status}');
      return res.status < 400;
    } catch (e) {
      debugPrint('[OnlineOrderService] upsertStore ERROR: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getStoreSettings() async {
    final sid = await storeId;
    if (sid == null) return null;
    try {
      final res = await supabase.functions.invoke('online-store', body: {
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
      final res = await supabase.functions.invoke('online-store', body: {
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

  Future<List<Map<String, dynamic>>> getOrders({String? status, int limit = 50}) async {
    final sid = await storeId;
    if (sid == null) return [];
    try {
      final res = await supabase.functions.invoke('online-store', body: {
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
      final res = await supabase.functions.invoke('online-store', body: {
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
