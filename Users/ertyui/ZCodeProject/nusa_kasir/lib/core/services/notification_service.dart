import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';

/// A single notification item shown in the in-app Notification Center.
class AppNotification {
  final String id;
  final String type; // 'update' | 'stock' | 'online' | 'attendance' | 'info'
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;
  // v2.2.35: route app yang dibuka saat notif diketuk (tool-calling).
  // 'update' → dialog update; 'online' → /pesanan_online; 'stock' → /stok;
  // 'attendance' → /presensi. null = tidak ada aksi.
  final String? route;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.route,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'read': read,
    'route': route,
  };

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    createdAt: createdAt,
    read: read ?? this.read,
    route: route,
  );

  factory AppNotification.fromJson(Map<String, dynamic> m) => AppNotification(
    id: '${m['id'] ?? ''}',
    type: '${m['type'] ?? 'info'}',
    title: '${m['title'] ?? ''}',
    body: '${m['body'] ?? ''}',
    createdAt: DateTime.tryParse('${m['createdAt']}') ?? DateTime.now(),
    read: m['read'] == true,
    route: m['route'] == null ? null : '${m['route']}',
  );
}

/// Manages local notification channel and the in-app Notification Center
/// (persisted locally, no backend).
class NotificationService {
  static const _channelId = 'nusa_kasir_stock';
  static const _channelName = 'Stok Menipis';
  static const _channelDesc = 'Notifikasi saat stok produk menipis';

  static const _centerKey = 'nusa_notif_center';
  static const int _maxStored = 50;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Initialize the plugin. Call once in main().
  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
  }

  // ── In-app Notification Center (persisted in SecureStore) ─────────

  /// All stored notifications, newest first.
  static Future<List<AppNotification>> getCenter() async {
    final raw = await SecureStore.read(key: _centerKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list =
          (jsonDecode(raw) as List<dynamic>)
              .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Number of unread notifications (drives the bell badge).
  static Future<int> unreadCount() async {
    final list = await getCenter();
    return list.where((n) => !n.read).length;
  }

  /// Add a notification (dedup by [id] — updating an existing one replaces it
  /// in place, keeping its position). Persists + shows an OS-level alert for
  /// important types.
  static Future<void> add({
    required String id,
    required String type,
    required String title,
    required String body,
    bool showAlert = false,
    String? route,
  }) async {
    final existing = await getCenter();
    final now = DateTime.now();
    final list = existing.where((n) => n.id != id).toList();
    list.insert(
      0,
      AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        createdAt: now,
        route: route,
      ),
    );
    if (list.length > _maxStored) list.removeRange(_maxStored, list.length);
    await SecureStore.write(
      key: _centerKey,
      value: jsonEncode(list.map((n) => n.toJson()).toList()),
    );

    if (showAlert) {
      await _plugin.show(
        now.millisecond,
        title,
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

  /// Mark a single notification (or all, when [id] is null) as read.
  static Future<void> markRead({String? id}) async {
    final list = await getCenter();
    final updated = id == null
        ? list.map((n) => n.copyWith(read: true)).toList()
        : list.map((n) => n.id == id ? n.copyWith(read: true) : n).toList();
    await SecureStore.write(
      key: _centerKey,
      value: jsonEncode(updated.map((n) => n.toJson()).toList()),
    );
  }

  /// Remove a single notification by id.
  static Future<void> remove(String id) async {
    final list = await getCenter();
    final updated = list.where((n) => n.id != id).toList();
    await SecureStore.write(
      key: _centerKey,
      value: jsonEncode(updated.map((n) => n.toJson()).toList()),
    );
  }
}
