import 'dart:convert';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:cryptography/cryptography.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';

/// NFC tag read/write service for employee tap-to-login.
///
/// Tag format (NDEF text record payload):
///   NUSA|{employeeId}|{hmacHash}
///
/// The hash binds the tag to a specific employee on a specific device,
/// preventing cloning or tag swapping between employees.
class NfcTagService {
  const NfcTagService._();

  static const _prefix = 'NUSA';
  static const _sep = '|';

  /// Check if NFC hardware is available on this device.
  static Future<bool> isAvailable() => NfcManager.instance.isAvailable();

  /// Write an employee tag to an NFC tag (NDEF formatted).
  ///
  /// Returns true on success, false if the tag is not writable or
  /// the user cancels.
  static Future<bool> writeEmployeeTag(int employeeId) async {
    final hash = await _computeHash(employeeId);
    final payload = '$_prefix$_sep$employeeId$_sep$hash';

    bool written = false;

    await NfcManager.instance.startSession(
      alertMessage: 'Tempelkan kartu NFC ke belakang HP',
      onDiscovered: (tag) async {
        final ndef = Ndef.from(tag);
        if (ndef == null || !ndef.isWritable) {
          await NfcManager.instance.stopSession(errorMessage: 'Kartu tidak bisa ditulis. Gunakan NTAG215.');
          return;
        }

        try {
          await ndef.write(
            NdefMessage([
              NdefRecord.createText(payload, languageCode: 'id'),
            ]),
          );
          written = true;
          await NfcManager.instance.stopSession(
            alertMessage: '✅ NFC Tag berhasil didaftarkan!',
          );
        } catch (_) {
          await NfcManager.instance.stopSession(
            errorMessage: 'Gagal menulis NFC tag — coba lagi',
          );
        }
      },
    );

    return written;
  }

  /// Read an employee NFC tag and validate it.
  ///
  /// Returns the employeeId if the tag is valid, null otherwise.
  /// Starts an NFC session that auto-closes on tag discovery.
  static Future<int?> readEmployeeTag() async {
    int? employeeId;

    await NfcManager.instance.startSession(
      alertMessage: 'Tempelkan kartu NFC',
      onDiscovered: (tag) async {
        final ndef = Ndef.from(tag);
        final msg = ndef?.cachedMessage ?? (await ndef?.read());

        if (msg == null || msg.records.isEmpty) {
          await NfcManager.instance.stopSession(errorMessage: 'Tag tidak terbaca');
          return;
        }

        // Parse text records
        for (final record in msg.records) {
          final text = _parseTextRecord(record);
          if (text == null || !text.startsWith('$_prefix$_sep')) continue;

          final parts = text.split(_sep);
          if (parts.length != 3) continue;

          final id = int.tryParse(parts[1]);
          final tagHash = parts[2];

          if (id == null) continue;

          // Validate hash
          final expectedHash = await _computeHash(id);
          if (tagHash == expectedHash) {
            employeeId = id;
            await NfcManager.instance.stopSession();
            return;
          }
        }

        await NfcManager.instance.stopSession(errorMessage: 'Tag tidak dikenal');
      },
    );

    return employeeId;
  }

  /// Stop any active NFC session (cleanup).
  static Future<void> stopSession() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }

  // ── Internal ──

  /// HMAC-SHA256 hash binding employee + activation key → anti-cloning.
  ///
  /// Uses cryptographic HMAC so that attackers cannot forge valid tags
  /// even if they know the employee ID.
  static Future<String> _computeHash(int employeeId) async {
    final activationKey = await SecureStore.getActivation();
    final hmac = Hmac.sha256();
    final key = SecretKey(utf8.encode(activationKey ?? 'nusa_default'));
    final message = utf8.encode('$employeeId|nusa_tag_secret');
    final mac = await hmac.calculateMac(message, secretKey: key);
    return mac.bytes
        .take(8)
        .fold<String>('', (s, b) => s + b.toRadixString(16).padLeft(2, '0'));
  }

  /// Parse a text record from an NDEF message.
  static String? _parseTextRecord(NdefRecord record) {
    // Standard NDEF text record format:
    // byte 0: status (bit 7=MB, bit 6=ME, bit 5=CF, bit 4=SR, bit 3=IL, bit 2-0=TNF=0x01)
    // byte 1: language code length
    // bytes 2..2+langLen: language code
    // rest: UTF-8 payload
    if (record.payload.isEmpty) return null;

    // Try well-known text record parsing
    if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
        record.type.isNotEmpty &&
        record.type.first == 0x54) {
      // 'T' = text record
      final payload = record.payload;
      if (payload.length < 2) return null;
      final langLen = payload.first & 0x3F;
      if (1 + langLen >= payload.length) return null;
      return utf8.decode(payload.sublist(1 + langLen));
    }

    // Fallback: just try UTF-8 decode the whole payload
    try {
      return utf8.decode(record.payload);
    } catch (_) {
      return null;
    }
  }
}
