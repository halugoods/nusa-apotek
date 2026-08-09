import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
import 'package:cryptography/cryptography.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/attendance_repository.dart';

/// NFC tag read/write service for employee tap-to-login.
///
/// Tag format (NDEF text record payload, NTAG215):
///   NUSA|{employeeId}|{hmacHash}
///
/// Tag format (Mifare Classic block 4, sector 1):
///   NUSA|{employeeId} (padded to 16 bytes)
///
/// The hash binds the tag to a specific employee on a specific device,
/// preventing cloning or tag swapping between employees.
/// Mifare Classic uses a simpler UID-based lookup without HMAC.
///
/// NFC reliability strategy:
///   The actual tag capture is handled by native Android foreground dispatch
///   (MainActivity.kt: enableForegroundDispatch). This guarantees the tag comes
///   to us even on MIUI/Samsung where enableReaderMode() silently fails.
///   Flutter side uses nfc_manager's standard onDiscovered callback — no extra
///   stream subscription needed because the native side handles the hard part.
class NfcTagService {
  const NfcTagService._();

  static const _prefix = 'NUSA';
  static const _sep = '|';

  /// Check if NFC hardware is available on this device.
  static Future<bool> isAvailable() => NfcManager.instance.isAvailable();

  /// Write an employee tag to an NFC tag.
  ///
  /// Supports NTAG215 (NDEF) and Mifare Classic 1K/4K (sector-based).
  ///
  /// Returns true on success, false if the tag is not writable or
  /// the user cancels.
  static Future<bool> writeEmployeeTag(int employeeId) async {
    final hash = await _computeHash(employeeId);
    final payload = '$_prefix$_sep$employeeId$_sep$hash';

    final completer = Completer<bool>();

    // Start session with onDiscovered. The native MainActivity foreground
    // dispatch ensures the tag comes to us (not DANA) on all devices.
    NfcManager.instance.startSession(
      alertMessage: 'Tempelkan kartu NFC ke belakang HP',
      onDiscovered: (tag) async {
        // ── Try NDEF first ──
        final ndef = Ndef.from(tag);
        if (ndef != null && ndef.isWritable) {
          try {
            await ndef.write(
              NdefMessage([
                NdefRecord.createText(payload, languageCode: 'id'),
              ]),
            );
            await NfcManager.instance.stopSession(
              alertMessage: '✅ NFC Tag berhasil didaftarkan!',
            );
            if (!completer.isCompleted) completer.complete(true);
            return;
          } catch (_) {
            // NDEF write failed, fall through to Mifare
          }
        }

        // ── Mifare Classic fallback ──
        final mf = MifareClassic.from(tag);
        if (mf != null) {
          try {
            final defaultKey = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
            await mf.authenticateSectorWithKeyA(sectorIndex: 1, key: defaultKey);
            final data = Uint8List.fromList(
              '$_prefix$_sep$employeeId'.padRight(16, '\x00').codeUnits,
            );
            await mf.writeBlock(blockIndex: 4, data: data);
            await NfcManager.instance.stopSession(
              alertMessage: '✅ Kartu RFID berhasil didaftarkan!',
            );
            if (!completer.isCompleted) completer.complete(true);
            return;
          } catch (_) {
            await NfcManager.instance.stopSession(
              errorMessage: 'Gagal menulis kartu. Gunakan NTAG215 atau Mifare Classic.',
            );
            if (!completer.isCompleted) completer.complete(false);
            return;
          }
        }

        await NfcManager.instance.stopSession(
          errorMessage: 'Kartu tidak didukung. Gunakan NTAG215 atau Mifare Classic.',
        );
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    // 30-second timeout
    Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        NfcManager.instance.stopSession();
        completer.complete(false);
      }
    });

    return completer.future;
  }

  /// Read an employee NFC tag and validate it.
  ///
  /// Supports NDEF (NTAG215), Mifare Classic (RFID), and UID fallback.
  ///
  /// Returns the employeeId if the tag is valid, null otherwise.
  static Future<int?> readEmployeeTag() async {
    final completer = Completer<int?>();

    NfcManager.instance.startSession(
      alertMessage: 'Tempelkan kartu NFC',
      onDiscovered: (tag) async {
        int? employeeId;

        // ── NDEF ──
        final ndef = Ndef.from(tag);
        if (ndef != null) {
          NdefMessage? msg;
          try {
            msg = ndef.cachedMessage ?? (await ndef.read());
          } catch (_) {}

          if (msg != null && msg.records.isNotEmpty) {
            for (final record in msg.records) {
              final text = _parseTextRecord(record);
              if (text == null || !text.startsWith('$_prefix$_sep')) continue;

              final parts = text.split(_sep);
              if (parts.length != 3) continue;

              final id = int.tryParse(parts[1]);
              final tagHash = parts[2];

              if (id == null) continue;

              final expectedHash = await _computeHash(id);
              if (tagHash == expectedHash) {
                employeeId = id;
                break;
              }
            }
          }
        }

        // ── Mifare Classic ──
        if (employeeId == null) {
          final mf = MifareClassic.from(tag);
          if (mf != null) {
            try {
              final defaultKey = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
              await mf.authenticateSectorWithKeyA(sectorIndex: 1, key: defaultKey);
              final block = await mf.readBlock(blockIndex: 4);
              if (block != null && block.isNotEmpty) {
                final text = String.fromCharCodes(block).replaceAll('\x00', '').trim();
                if (text.startsWith('$_prefix$_sep')) {
                  final parts = text.split(_sep);
                  if (parts.length >= 2) {
                    employeeId = int.tryParse(parts[1]);
                  }
                }
              }
            } catch (_) {}
          }
        }

        // ── UID fallback ──
        if (employeeId == null) {
          final nfcA = NfcA.from(tag);
          if (nfcA != null && nfcA.identifier.isNotEmpty) {
            final uidHex = nfcA.identifier
                .map((b) => b.toRadixString(16).padLeft(2, '0'))
                .join('');
            employeeId = await _lookupByUid(uidHex);
          }
        }

        if (employeeId != null) {
          await NfcManager.instance.stopSession();
          if (!completer.isCompleted) completer.complete(employeeId);
        } else {
          await NfcManager.instance.stopSession(errorMessage: 'Tag tidak dikenal');
          if (!completer.isCompleted) completer.complete(null);
        }
      },
    );

    // 30-second timeout
    Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        NfcManager.instance.stopSession();
        completer.complete(null);
      }
    });

    return completer.future;
  }

  /// Stop any active NFC session (cleanup).
  static Future<void> stopSession() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }

  // ── Internal ──

  static Future<int?> _lookupByUid(String uidHex) async {
    try {
      final db = AppDatabase();
      final repo = AttendanceRepository(db);
      final emp = await repo.getByNfcTag(uidHex);
      await db.close();
      return emp?.id;
    } catch (_) {
      return null;
    }
  }

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

  static String? _parseTextRecord(NdefRecord record) {
    if (record.payload.isEmpty) return null;

    if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
        record.type.isNotEmpty &&
        record.type.first == 0x54) {
      final payload = record.payload;
      if (payload.length < 2) return null;
      final langLen = payload.first & 0x3F;
      if (1 + langLen >= payload.length) return null;
      return utf8.decode(payload.sublist(1 + langLen));
    }

    try {
      return utf8.decode(record.payload);
    } catch (_) {
      return null;
    }
  }
}
