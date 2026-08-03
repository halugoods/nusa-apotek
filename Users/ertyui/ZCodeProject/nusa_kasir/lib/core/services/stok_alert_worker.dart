import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Unique task names registered with workmanager.
const _stokTaskName = 'nusa_kasir_stok_check';
const _onlineCheckTask = 'nusa_kasir_online_check';

/// Combined top-level callback dispatcher for all background tasks.
/// Workmanager only supports ONE callback — we fan out from here.
@pragma('vm:entry-point')
void stokCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      if (taskName == _stokTaskName) {
        final db = AppDatabase();
        await _checkAndNotify(db);
        await db.close();
        return true;
      }
      if (taskName == _onlineCheckTask) {
        final db = AppDatabase();
        await _checkOnlineOrders(db);
        await db.close();
        return true;
      }
      return false;
    } catch (e) {
      // ignore: avoid_print
      print('[stok_alert_worker] Background task "$taskName" gagal: $e');
      return false;
    }
  });
}

// ─── Stock Alert ────────────────────────────────────────────────────

Future<void> _checkAndNotify(AppDatabase db) async {
  final plugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  await plugin.initialize(
    const InitializationSettings(android: androidSettings, iOS: iosSettings),
  );

  final products = await db.select(db.products).get();
  final lowStock = products.where((p) => p.stock <= p.minStock).toList();
  if (lowStock.isEmpty) return;

  final names = lowStock.map((p) => p.name).toList();
  final body = names.length == 1
      ? 'Stok "${names.first}" menipis. Segera restock.'
      : '${names.length} produk stoknya menipis: ${names.take(3).join(", ")}';

  await plugin.show(
    DateTime.now().millisecond,
    '⚠️ Stok Menipis',
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'nusa_kasir_stock',
        'Stok Menipis',
        channelDescription: 'Notifikasi saat stok produk menipis',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true, presentBadge: true, presentSound: true,
      ),
    ),
  );
}

Future<void> registerStokCheck() async {
  await Workmanager().registerPeriodicTask(
    _stokTaskName, _stokTaskName,
    frequency: const Duration(minutes: 30),
    constraints: Constraints(),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
  );
}

Future<void> cancelStokCheck() async {
  await Workmanager().cancelByUniqueName(_stokTaskName);
}

// ─── Online Order Check ─────────────────────────────────────────────

Future<void> _checkOnlineOrders(AppDatabase db) async {
  final plugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  await plugin.initialize(
    const InitializationSettings(android: androidSettings, iOS: iosSettings),
  );

  try {
    final key = await SecureStore.getActivation();
    if (key == null) return;

    if (NusaConfig.supabaseUrl.isNotEmpty && NusaConfig.supabaseAnon.isNotEmpty) {
      try {
        // Check if already initialized
        Supabase.instance.client;
      } catch (_) {
        await Supabase.initialize(
          url: NusaConfig.supabaseUrl, publishableKey: NusaConfig.supabaseAnon,
        );
      }
    }

    final supabase = Supabase.instance.client;
    final res = await supabase.functions.invoke('online-store', body: {
      'action': 'get_orders',
      'store_id': key,
      'status': 'Online Baru',
      'limit': 10,
    });

    if (res.status >= 400) return;
    final data = res.data as Map<String, dynamic>;
    final orders = (data['orders'] as List).cast<Map<String, dynamic>>();
    if (orders.isEmpty) return;

    // Check local duplicates
    final localOrders = await (db.select(db.onlineOrders)
      ..where((t) => t.status.equals('Online Baru'))).get();
    final localInvoices = localOrders.map((o) => o.invoice).toSet();
    final newOrders = orders.where((o) => !localInvoices.contains(o['invoice'] as String)).toList();
    if (newOrders.isEmpty) return;

    // Save new orders
    for (final order in newOrders) {
      try {
        await db.into(db.onlineOrders).insert(OnlineOrdersCompanion.insert(
          invoice: order['invoice'] as String? ?? '',
          customerName: order['customer_name'] as String? ?? '',
          customerPhone: order['customer_phone'] as String? ?? '',
          items: jsonEncode(order['items']),
          total: order['total'] as int? ?? 0,
          subtotal: Value(order['subtotal'] as int? ?? 0),
          discount: Value(order['discount'] as int? ?? 0),
          handlingFee: Value(order['handling_fee'] as int? ?? 0),
          paymentMethod: Value(order['payment_method'] as String? ?? 'Tunai'),
          pickupTime: Value(order['pickup_time'] as String?),
          branch: Value(order['branch'] as String? ?? 'Pusat'),
          notes: Value(order['notes'] as String?),
          status: Value(order['status'] as String? ?? 'Online Baru'),
        ));
      } catch (e) {
        // Log but continue — don't lose the rest of the batch
        // ignore: avoid_print
        print('[stok_alert_worker] Gagal menyimpan pesanan ${order['invoice']}: $e');
      }
    }

    final count = newOrders.length;
    final body = count == 1
        ? 'Pesanan baru dari ${newOrders.first['customer_name']}!'
        : '$count pesanan online baru masuk!';

    await plugin.show(
      DateTime.now().millisecond,
      '🛒 Pesanan Online Baru',
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'nusa_kasir_online', 'Pesanan Online',
          channelDescription: 'Notifikasi pesanan online baru',
          importance: Importance.high, priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true,
        ),
      ),
    );
  } catch (_) {}
}

Future<void> registerOnlineCheck() async {
  await Workmanager().registerPeriodicTask(
    _onlineCheckTask, _onlineCheckTask,
    frequency: const Duration(minutes: 2),
    constraints: Constraints(),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
  );
}

Future<void> cancelOnlineCheck() async {
  await Workmanager().cancelByUniqueName(_onlineCheckTask);
}
