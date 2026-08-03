import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Encrypts/decrypts the local SQLite backup using AES-256-GCM.
///
/// Key is derived from the Google user ID (SHA-256), so any device logged into
/// the same Google account can decrypt the backup. No activation key needed.
///
/// Data is gzip-compressed before encryption to reduce storage (~5x-10x).
class BackupCrypto {
  static final _aes = AesGcm.with256bits();

  /// Derive a 32-byte key from the Google user ID.
  static Future<SecretKey> _deriveKey(String googleUserId) async {
    final alg = Sha256();
    final hash = await alg.hash(utf8.encode(googleUserId));
    return SecretKey(hash.bytes);
  }

  /// Gzip compress data.
  static List<int> _gzip(List<int> data) {
    final compressed = GZipCodec().encode(data);
    return compressed;
  }

  /// Gzip decompress data.
  static List<int> _gunzip(List<int> data) {
    final decompressed = GZipCodec().decode(data);
    return decompressed;
  }

  /// Pack multiple (filename, bytes) pairs into a single binary archive.
  ///
  /// Format:
  ///   "NUS1" (magic 4 bytes)
  ///   fileCount (uint32 LE)
  ///   For each file:
  ///     nameLen (uint16 LE)
  ///     name (UTF-8 bytes)
  ///     dataLen (uint32 LE)
  ///     data (raw bytes)
  static Uint8List packFiles(Map<String, Uint8List> files) {
    final entries = files.entries.toList();
    // Calculate total size
    var total = 4 + 4; // magic + count
    for (final e in entries) {
      total += 2 + e.key.length + 4 + e.value.length;
    }
    final buf = ByteData(total);
    var offset = 0;

    // Magic
    buf.setUint8(offset++, 0x4E); // N
    buf.setUint8(offset++, 0x55); // U
    buf.setUint8(offset++, 0x53); // S
    buf.setUint8(offset++, 0x31); // 1

    // File count
    buf.setUint32(offset, entries.length, Endian.little);
    offset += 4;

    // Files
    for (final e in entries) {
      final nameBytes = utf8.encode(e.key);
      buf.setUint16(offset, nameBytes.length, Endian.little);
      offset += 2;
      for (var i = 0; i < nameBytes.length; i++) {
        buf.setUint8(offset++, nameBytes[i]);
      }
      buf.setUint32(offset, e.value.length, Endian.little);
      offset += 4;
      for (var i = 0; i < e.value.length; i++) {
        buf.setUint8(offset++, e.value[i]);
      }
    }
    return buf.buffer.asUint8List();
  }

  /// Unpack a binary archive back to a map of filename → bytes.
  ///
  /// Archive entries are untrusted input. Keep limits deliberately conservative
  /// because this runs before the database is opened during startup.
  static Map<String, Uint8List> unpackFiles(Uint8List data) {
    const headerLen = 8;
    const maxFiles = 10000;
    const maxNameBytes = 4096;
    const maxTotalBytes = 512 * 1024 * 1024;
    final result = <String, Uint8List>{};

    if (data.length < 4) {
      // Not our archive format — treat as raw SQLite (legacy).
      return {'nusa_kasir.sqlite': data};
    }
    final hasMagic =
        data[0] == 0x4E &&
        data[1] == 0x55 &&
        data[2] == 0x53 &&
        data[3] == 0x31;
    if (!hasMagic) {
      return {'nusa_kasir.sqlite': data};
    }
    if (data.length < headerLen) {
      throw const FormatException('Archive header truncated');
    }

    final buf = ByteData.sublistView(data);
    var offset = 4;
    final count = buf.getUint32(offset, Endian.little);
    offset += 4;
    if (count == 0 || count > maxFiles) {
      throw FormatException('Invalid archive file count: $count');
    }

    var totalBytes = 0;
    for (var f = 0; f < count; f++) {
      if (data.length - offset < 2) {
        throw const FormatException('Archive entry header truncated');
      }
      final nameLen = buf.getUint16(offset, Endian.little);
      offset += 2;
      if (nameLen == 0 ||
          nameLen > maxNameBytes ||
          data.length - offset < nameLen) {
        throw const FormatException('Invalid archive filename length');
      }
      final nameBytes = data.sublist(offset, offset + nameLen);
      offset += nameLen;
      final name = utf8.decode(nameBytes, allowMalformed: false);
      final segments = name.replaceAll('\\', '/').split('/');
      if (name.startsWith('/') ||
          name.startsWith('\\') ||
          RegExp(r'^[A-Za-z]:([/\\]|$)').hasMatch(name) ||
          segments.any(
            (segment) => segment == '..' || segment.isEmpty || segment == '.',
          )) {
        throw FormatException('Unsafe archive filename: $name');
      }
      if (result.containsKey(name)) {
        throw FormatException('Duplicate archive filename: $name');
      }
      if (data.length - offset < 4) {
        throw const FormatException('Archive data length truncated');
      }
      final dataLen = buf.getUint32(offset, Endian.little);
      offset += 4;
      if (dataLen > data.length - offset ||
          dataLen > maxTotalBytes - totalBytes) {
        throw const FormatException('Invalid archive data length');
      }
      final bytes = Uint8List.fromList(data.sublist(offset, offset + dataLen));
      offset += dataLen;
      totalBytes += dataLen;
      result[name] = bytes;
    }
    if (offset != data.length) {
      throw const FormatException('Trailing archive data');
    }
    return result;
  }

  /// Encrypt [plaintext] → gzip → [nonce(12)] + [ciphertext] + [mac(16)].
  static Future<Uint8List> encrypt(
    List<int> plaintext,
    String googleUserId,
  ) async {
    final secretKey = await _deriveKey(googleUserId);
    final compressed = _gzip(plaintext);
    final nonce = _aes.newNonce();
    final box = await _aes.encrypt(
      compressed,
      secretKey: secretKey,
      nonce: nonce,
    );
    final out = Uint8List(
      nonce.length + box.cipherText.length + box.mac.bytes.length,
    );
    var i = 0;
    out.setAll(i, nonce);
    i += nonce.length;
    out.setAll(i, box.cipherText);
    i += box.cipherText.length;
    out.setAll(i, box.mac.bytes);
    return out;
  }

  /// Decrypt [data] (nonce + ciphertext + mac) → gunzip → plaintext bytes.
  static Future<List<int>> decrypt(Uint8List data, String googleUserId) async {
    final secretKey = await _deriveKey(googleUserId);
    const nonceLen = 12;
    const macLen = 16;
    if (data.length < nonceLen + macLen) throw Exception('Data terlalu pendek');
    final nonce = data.sublist(0, nonceLen);
    final cipherText = data.sublist(nonceLen, data.length - macLen);
    final macBytes = data.sublist(data.length - macLen);
    final box = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));
    final compressed = await _aes.decrypt(box, secretKey: secretKey);
    return _gunzip(compressed);
  }
}
