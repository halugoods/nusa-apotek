import 'dart:convert';
import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';

/// Per-user Google Drive backup (v2.2.57+123).
///
/// Mirrors alur menu Spreadsheet lama — user klik tombol di app → Google
/// account picker → allow → selesai. Tidak ada client id/secret, tidak ada
/// dashboard setup. Setiap user menyalin backup ke Google Drive-nya sendiri.
///
/// Arsitektur:
///   App → GoogleSignIn (drive.file scope) → access token
///   → Drive REST API (files().create / files().update)
///   → user's Google Drive, file "NUSA_Backup_{variant}.sqlite.enc"
///
/// Tidak ada edge fn / Supabase yang dilibatkan untuk upload Drive.
/// SecureStore menyimpan drive_file_id agar operasi berikutnya tahu file mana
/// yang di-overwrite (1 file per user-varian = link stabil).
class CloudGoogleService {
  CloudGoogleService._();
  static final CloudGoogleService I = CloudGoogleService._();

  // ── Keys ───────────────────────────────────────────────────────────

  static const _keyDriveUserId = 'nusa_drive_user_id';
  static const _keyDriveUserEmail = 'nusa_drive_user_email';
  static const _keyDriveFileId = 'nusa_drive_file_id';
  static const _keyDriveLastUploaded = 'nusa_drive_last_uploaded';

  // ── GoogleSignIn ───────────────────────────────────────────────────

  /// scope drive.file = app hanya bisa akses file yang dia buat sendiri.
  /// Tidak perlu full drive access, tidak ada akses ke seluruh Drive user.
  final GoogleSignIn _signIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/drive.file'],
  );

  /// Connect akun Google → minta izin Drive. Sekali klik, user pilih
  /// akun, kasih izin, selesai. Pattern sama persis dengan menu Spreadsheet.
  ///
  /// Returns true on success, false on cancel/error.
  Future<bool> connect() async {
    try {
      final account = await _signIn.signIn();
      if (account == null) return false;

      await SecureStore.write(key: _keyDriveUserId, value: account.id);
      if (account.email.isNotEmpty) {
        await SecureStore.write(key: _keyDriveUserEmail, value: account.email);
      }
      // Clear stale file ID — akan dicari / dibuat baru saat upload pertama
      await SecureStore.delete(key: _keyDriveFileId);
      debugPrint('[CloudGoogle] Connected: ${account.email}');
      return true;
    } catch (e) {
      debugPrint('[CloudGoogle] connect error: $e');
      return false;
    }
  }

  /// Putuskan koneksi Drive — hapus kredensial lokal.
  Future<void> disconnect() async {
    try {
      await _signIn.disconnect();
    } catch (_) {}
    await SecureStore.delete(key: _keyDriveUserId);
    await SecureStore.delete(key: _keyDriveUserEmail);
    await SecureStore.delete(key: _keyDriveFileId);
    await SecureStore.delete(key: _keyDriveLastUploaded);
    debugPrint('[CloudGoogle] Disconnected');
  }

  /// True jika akun Drive sudah terhubung.
  static Future<bool> isConnected() async {
    final id = await SecureStore.read(key: _keyDriveUserId);
    return id != null && id.isNotEmpty;
  }

  /// Email akun Drive yang terhubung (null kalau belum).
  static Future<String?> connectedEmail() =>
      SecureStore.read(key: _keyDriveUserEmail);

  /// Waktu upload terakhir ke Drive (null kalau belum pernah).
  static Future<DateTime?> lastUploadedAt() async {
    final str = await SecureStore.read(key: _keyDriveLastUploaded);
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  // ── Drive REST API ─────────────────────────────────────────────────

  static const _driveApiBase = 'https://www.googleapis.com/drive/v3';
  static const _driveUploadBase =
      'https://www.googleapis.com/upload/drive/v3/files';

  /// Upload encrypted backup (bytes sudah di-encrypt oleh caller) ke
  /// Google Drive user. Find-or-create "NUSA_Backup_{variant}.sqlite.enc".
  ///
  /// - Kalau belum ada file → create baru (simpan file ID di SecureStore).
  /// - Kalau sudah ada → overwrite (PATCH /files/{id}?uploadType=multipart).
  /// - Gagal upload = debugPrint + return false (tidak lempar exception).
  ///
  /// Caller: [activation_repository.dart uploadBackupNow] setelah Supabase
  /// upload berhasil (fire-and-forget, gagal tidak menggagalkan backup).
  Future<bool> uploadBackup(Uint8List encryptedBytes) async {
    final accessToken = await _signIn.currentUser?.authHeaders['Authorization'];
    if (accessToken == null || !accessToken.startsWith('Bearer ')) {
      debugPrint('[CloudGoogle] No access token — not connected');
      return false;
    }

    final token = accessToken.substring('Bearer '.length);
    final fileName = 'NUSA_Backup_${NusaConfig.productId}.sqlite.enc';

    try {
      // Cek apakah sudah ada file ID tersimpan
      String? fileId = await SecureStore.read(key: _keyDriveFileId);

      // Kalau belum ada di SecureStore, cari di Drive
      if (fileId == null || fileId.isEmpty) {
        fileId = await _findFileId(token, fileName);
      }

      if (fileId != null && fileId.isNotEmpty) {
        // Overwrite file yang sudah ada
        await _updateFile(token, fileId, fileName, encryptedBytes);
        await SecureStore.write(
          key: _keyDriveLastUploaded,
          value: DateTime.now().toUtc().toIso8601String(),
        );
        debugPrint(
          '[CloudGoogle] Updated backup: $fileName (id: $fileId, ${encryptedBytes.length} bytes)',
        );
      } else {
        // Buat file baru
        final newId = await _createFile(token, fileName, encryptedBytes);
        await SecureStore.write(key: _keyDriveFileId, value: newId);
        await SecureStore.write(
          key: _keyDriveLastUploaded,
          value: DateTime.now().toUtc().toIso8601String(),
        );
        debugPrint(
          '[CloudGoogle] Created backup: $fileName (id: $newId, ${encryptedBytes.length} bytes)',
        );
      }
      return true;
    } catch (e) {
      debugPrint('[CloudGoogle] upload error: $e');
      return false;
    }
  }

  /// Cari file ID berdasarkan nama + MIME type.
  Future<String?> _findFileId(String token, String fileName) async {
    final uri = Uri.parse('$_driveApiBase/files').replace(queryParameters: {
      'q': "name='$fileName' and mimeType='application/octet-stream' and trashed=false",
      'fields': 'files(id,name)',
      'spaces': 'drive',
    });

    final resp = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (resp.statusCode != 200) {
      debugPrint('[CloudGoogle] findFileId status: ${resp.statusCode}');
      return null;
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final files = body['files'] as List<dynamic>?;
    if (files != null && files.isNotEmpty) {
      return (files.first as Map<String, dynamic>)['id'] as String?;
    }
    return null;
  }

  /// Buat file baru di Drive via multipart/related upload.
  Future<String> _createFile(
    String token,
    String fileName,
    Uint8List bytes,
  ) async {
    final metadata = jsonEncode({
      'name': fileName,
      'mimeType': 'application/octet-stream',
      'description': 'NUSA Backup — ${NusaConfig.productId} — ${DateTime.now().toUtc().toIso8601String()}',
    });

    final body = _buildMultipartBody(metadata, bytes);

    final uri = Uri.parse('$_driveUploadBase?uploadType=multipart');
    final resp = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'multipart/related; boundary=boundary_nusa',
      },
      body: body,
    );

    if (resp.statusCode != 200) {
      debugPrint('[CloudGoogle] createFile status: ${resp.statusCode} body: ${resp.body}');
      throw Exception('Gagal membuat file di Google Drive: ${resp.statusCode}');
    }

    final created = jsonDecode(resp.body) as Map<String, dynamic>;
    return created['id'] as String;
  }

  /// Overwrite file yang sudah ada.
  Future<void> _updateFile(
    String token,
    String fileId,
    String fileName,
    Uint8List bytes,
  ) async {
    final metadata = jsonEncode({
      'name': fileName,
      'description': 'NUSA Backup — ${NusaConfig.productId} — ${DateTime.now().toUtc().toIso8601String()}',
    });

    final body = _buildMultipartBody(metadata, bytes);

    final uri = Uri.parse('$_driveUploadBase/$fileId?uploadType=multipart');
    final resp = await http.patch(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'multipart/related; boundary=boundary_nusa',
      },
      body: body,
    );

    if (resp.statusCode != 200) {
      debugPrint('[CloudGoogle] updateFile status: ${resp.statusCode} body: ${resp.body}');
      throw Exception('Gagal memperbarui file di Google Drive: ${resp.statusCode}');
    }
  }

  /// Build multipart/related body:
  /// --boundary_nusa\r\n
  /// Content-Type: application/json\r\n\r\n
  /// {metadata}\r\n
  /// --boundary_nusa\r\n
  /// Content-Type: application/octet-stream\r\n\r\n
  /// {bytes}\r\n
  /// --boundary_nusa--\r\n
  Uint8List _buildMultipartBody(String metadata, Uint8List bytes) {
    final boundary = 'boundary_nusa';
    final parts = <Uint8List>[];

    // Part 1: metadata JSON
    final metaBytes = utf8.encode(metadata);
    parts.add(utf8.encode('--$boundary\r\n'));
    parts.add(utf8.encode('Content-Type: application/json; charset=UTF-8\r\n\r\n'));
    parts.add(Uint8List.fromList(metaBytes));
    parts.add(utf8.encode('\r\n'));

    // Part 2: file bytes
    parts.add(utf8.encode('--$boundary\r\n'));
    parts.add(utf8.encode('Content-Type: application/octet-stream\r\n\r\n'));
    parts.add(bytes);
    parts.add(utf8.encode('\r\n'));

    // End boundary
    parts.add(utf8.encode('--$boundary--\r\n'));

    // Combine all parts
    final totalLength = parts.fold<int>(0, (sum, p) => sum + p.length);
    final result = Uint8List(totalLength);
    var offset = 0;
    for (final part in parts) {
      result.setRange(offset, offset + part.length, part);
      offset += part.length;
    }
    return result;
  }

  // ── Helpers ───────────────────────────────────────────────────────

  /// Format byte count ke string readable.
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Format DateTime → string Indonesia.
  static String formatDate(DateTime dt) {
    final bulan = [
      'Jan','Feb','Mar','Apr','Mei','Jun',
      'Jul','Agu','Sep','Okt','Nov','Des',
    ];
    return '${dt.day} ${bulan[dt.month - 1]} ${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
