import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Manages local notification channel and display for NUSA Kasir.
class NotificationService {
  static const _channelId = 'nusa_kasir_stock';
  static const _channelName = 'Stok Menipis';
  static const _channelDesc = 'Notifikasi saat stok produk menipis';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Initialize the plugin. Call once in main().
  static Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
  }

  /// Show a local notification for low stock products.
  static Future<void> showLowStockAlert(List<String> productNames) async {
    if (productNames.isEmpty) return;

    final body = productNames.length == 1
        ? 'Stok "${productNames.first}" menipis. Segera restock.'
        : '${productNames.length} produk stoknya menipis: ${productNames.take(3).join(", ")}';

    await _plugin.show(
      DateTime.now().millisecond, // unique id
      '⚠️ Stok Menipis',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
