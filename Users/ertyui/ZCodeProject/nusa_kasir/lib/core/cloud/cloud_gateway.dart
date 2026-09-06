import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// v2.2.57+130 (Milestone C): CloudGateway — satu pintu ke backend Cloudflare
/// (pengganti supabase_flutter). Payload 1:1 dengan edge fn lama supaya
/// refactor app minimal:
///
///   functions.invoke('license-manager', body: {...})
///     → CloudGateway.shared.invoke('license-manager', body: {...})
///       (POST {base}/api/license-manager/{action} — action dibaca dari body)
///
/// Storage:
///   uploadBinary/downloadBinary/list/remove/getPublicUrl
///     → CloudGateway.shared.storage... (R2 via worker)
///
/// Realtime (pengganti channel().onBroadcast/onPostgresChanges):
///   CloudGateway.shared.wsChannel('orders:STORE') → WebSocketChannel
///   Pesan JSON: {"event": "...", "payload": {...}}
///
/// Identitas: Bearer JWT dari /api/auth (login email / google_link / anon).
/// Sebelum login, gateway anon-autoload dengan legacy uid (resolveCanonicalUid)
/// supaya path backup R2 tetap sama seperti Supabase Storage.
class CloudGateway {
  CloudGateway._();
  static final CloudGateway shared = CloudGateway._();

  /// Base URL worker — overridable via --dart-define (NUSA_CLOUD_BASE).
  static const String baseUrl = NusaConfig.cloudBaseUrl;

  String? _jwt;
  String? get jwt => _jwt;
  bool get hasSession => _jwt != null && _jwt!.isNotEmpty;

  /// Admin key untuk dashboard-ish call dari app (license-manager admin).
  String? get adminKey => NusaConfig.nusaAdminKey.isEmpty ? null : NusaConfig.nusaAdminKey;

  /// Inisialisasi: muat JWT tersimpan, atau bikin sesi anon dengan legacy uid
  /// (agar path R2 = uid lama). Tidak throw — gateway tetap bisa dipakai
  /// guest (app offline-first).
  Future<void> init() async {
    final saved = await SecureStore.read(key: 'nusa_cloud_jwt');
    if (saved != null && saved.isNotEmpty) {
      _jwt = saved;
      return;
    }
    try {
      // Sesi anon dengan legacy uid (uuid per-install) — sama pola Supabase
      // anon session dulu. resolveCanonicalUid sudah menggabungkan Google/
      // email; di sini cukup identifier device untuk anon.
      final legacy = await SecureStore.read(key: 'nusa_device_uuid') ??
          _newDeviceUuid();
      final res = await invokeRaw('auth', 'anon', body: {'legacyId': legacy});
      if (res.ok && res.data is Map) {
        final jwt = (res.data as Map)['jwt'] as String?;
        if (jwt != null) {
          _jwt = jwt;
          await SecureStore.write(key: 'nusa_cloud_jwt', value: jwt);
        }
      }
    } catch (_) {
      // offline / worker belum deploy — biarkan; invoke gagal nanti.
    }
  }

  String _newDeviceUuid() {
    final u = const Uuid().v4();
    SecureStore.write(key: 'nusa_device_uuid', value: u);
    return u;
  }

  Future<void> setSession(String jwt) async {
    _jwt = jwt;
    await SecureStore.write(key: 'nusa_cloud_jwt', value: jwt);
  }

  Future<void> signOut() async {
    _jwt = null;
    await SecureStore.write(key: 'nusa_cloud_jwt', value: '');
  }

  Map<String, String> _headers() {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (_jwt != null) h['Authorization'] = 'Bearer $_jwt';
    if (adminKey != null) h['x-admin-key'] = adminKey!;
    return h;
  }

  // ── Functions (pengganti functions.invoke) ─────────────────────────

  /// Ambil action dari body dan pindah ke path — app lama mengirim
  /// {'action': 'x', ...}; fn edge lama membaca body['action'].
  Future<CloudResult> invoke(String fn, {required Map<String, dynamic> body}) async {
    final action = body.remove('action') as String? ?? '';
    return invokeRaw(fn, action, body: body);
  }

  Future<CloudResult> invokeRaw(String fn, String action, {Map<String, dynamic>? body}) async {
    final url = '$baseUrl/api/$fn/$action';
    try {
      final res = await _post(url, body ?? {});
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      return CloudResult(status: res.statusCode, data: map);
    } catch (e) {
      return CloudResult(status: 599, error: e.toString());
    }
  }

  Future<http.Response> _post(String url, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse(url),
      headers: _headers(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));
    return res;
  }

  // ── Storage (R2 via worker) ─────────────────────────────────────────

  /// Upload bytes ke bucket. path = '{uid}/{productId}/{category}/{file}'.
  Future<bool> storageUpload(String bucket, String path, Uint8List bytes, {String contentType = 'application/octet-stream', bool upsert = false}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/storage/$bucket/$path'),
      headers: {..._headers(), 'Content-Type': contentType, 'X-Upsert': upsert ? '1' : '0'},
      body: bytes,
    ).timeout(const Duration(seconds: 30));
    return res.statusCode < 400;
  }

  Future<Uint8List?> storageDownload(String bucket, String path) async {
    final res = await http.get(
      Uri.parse('$baseUrl/storage/$bucket/$path'),
      headers: _headers(),
    ).timeout(const Duration(seconds: 30));
    if (res.statusCode >= 400) return null;
    return res.bodyBytes;
  }

  Future<List<Map<String, dynamic>>> storageList(String bucket, String prefix) async {
    final res = await http.get(
      Uri.parse('$baseUrl/storage/$bucket?prefix=${Uri.encodeComponent(prefix)}'),
      headers: _headers(),
    ).timeout(const Duration(seconds: 30));
    if (res.statusCode >= 400) return [];
    final data = jsonDecode(res.body);
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  Future<void> storageRemove(String bucket, List<String> paths) async {
    await http.post(
      Uri.parse('$baseUrl/storage/$bucket/remove'),
      headers: _headers(),
      body: jsonEncode({'paths': paths}),
    );
  }

  String storagePublicUrl(String bucket, String path) =>
      bucket == 'nusa-images' ? '$baseUrl/img/$path' : '$baseUrl/storage/$bucket/$path';

  /// v2.2.57+130 (A1): convenience — public URL untuk bucket nusa-images.
  /// Equivalent: storagePublicUrl('nusa-images', path).
  String getPublicUrl(String path) => '$baseUrl/img/$path';

  // ── Realtime (WebSocket via Durable Object) ────────────────────────

  /// channel name: 'backup_updated:{uid}', 'ring:{uid}', 'orders:{storeId}'.
  WebSocketChannel? wsChannel(String channel) {
    final wsBase = baseUrl.replaceFirst('http', 'ws');
    try {
      return WebSocketChannel.connect(
        Uri.parse('$wsBase/ws?channel=${Uri.encodeComponent(channel)}'),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Hasil invoke — meniru FunctionResponse supabase (status + data).
class CloudResult {
  final int status;
  final dynamic data;
  final String? error;
  CloudResult({required this.status, this.data, this.error});
  bool get ok => status >= 200 && status < 400;
}
