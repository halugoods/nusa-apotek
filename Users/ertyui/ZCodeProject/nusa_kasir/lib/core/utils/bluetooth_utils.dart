import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
/// Checks/enables Bluetooth state + requests runtime permissions.
///
/// Android 12+ (API 31+): BLUETOOTH_SCAN + BLUETOOTH_CONNECT are "dangerous"
/// permissions that MUST be requested at runtime. Without them, classic
/// Bluetooth device discovery silently returns zero results.
///
/// Device discovery, connection and data sending are handled by native
/// Android SPP (RFCOMM) via MethodChannel — no third-party Bluetooth
/// library dependency.
class BluetoothUtils {
  static const _channel = MethodChannel('com.nusa_kasir/bluetooth');

  /// Returns true if Bluetooth is currently enabled on the device.
  static Future<bool> isBluetoothEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isBluetoothEnabled');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests the user to turn on Bluetooth via system dialog.
  static Future<bool> requestBluetoothEnable() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestBluetoothEnable');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system Bluetooth settings screen.
  static Future<bool> openBluetoothSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openBluetoothSettings');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system App Info settings screen.
  static Future<bool> openAppSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openAppSettings');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────
  // Native SPP: discover bonded Bluetooth devices
  // ──────────────────────────────────────────────────────────

  /// Scan bonded (paired) Bluetooth devices via native Android API.
  /// Returns list of {name, address} maps.
  static Future<List<Map<String, String>>> scanDevices() async {
    if (!Platform.isAndroid) return [];
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('scanDevices');
      if (result == null) return [];
      return result.cast<Map<dynamic, dynamic>>().map((m) {
        return {
          'name': m['name']?.toString() ?? 'Printer',
          'address': m['address']?.toString() ?? '',
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────
  // Native SPP: connect / send / disconnect
  // ──────────────────────────────────────────────────────────

  /// Connect to a Bluetooth device by MAC address via RFCOMM SPP.
  static Future<bool> connectDevice(String address) async {
    _lastAddress = address;
    try {
      await _channel.invokeMethod('connectDevice', {'address': address});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Most recently connected device address — used by [sendBytes] to
  /// transparently reconnect when the socket drops mid-receipt.
  static String? _lastAddress;

  /// Send raw bytes over the active Bluetooth SPP connection.
  ///
  /// Strategy: small payloads (≤256 bytes) use single-write for speed.
  /// Large payloads (receipt with logo raster) skip single-write entirely
  /// and use chunked mode — avoids printer buffer overflow + retry corruption
  /// where a partially-sent single-write causes duplicate/overlapping data
  /// when the chunked retry starts from the beginning.
  ///
  /// Robustness: thermal printers drop the socket mid-job (buffer overflow,
  /// BT radio hiccup). Each chunk is retried once after a short backoff and
  /// the connection is transparently re-established against the last known
  /// address before retrying, so a receipt never silently truncates at the
  /// header — the sender re-syncs and the full payload goes out.
  static Future<bool> sendBytes(Uint8List data) async {
    try {
      // Small payloads (test print, simple commands) — single-write is safe.
      if (data.length <= 256) {
        final result = await _channel.invokeMethod<bool>('sendBytes', {'data': data});
        if (result == true) return true;
        // Fall through to chunked if single-write failed even on small data.
      }

      // Chunked mode — 128 bytes per chunk with 80ms delay.
      // Cheap thermal printers have <4KB buffers; this prevents overflow and
      // ensures each chunk is fully processed before the next arrives.
      const chunkSize = 128;
      var reconnectAttempted = false;
      for (var i = 0; i < data.length; i += chunkSize) {
        final end = (i + chunkSize > data.length) ? data.length : i + chunkSize;
        final chunk = data.sublist(i, end);
        var ok = await _sendChunk(chunk);
        if (ok != true && !reconnectAttempted && _lastAddress != null) {
          // Socket likely died — back off, re-establish SPP, retry the chunk.
          debugPrint('[BluetoothUtils] chunk failed at $i — reconnecting to $_lastAddress');
          await Future.delayed(const Duration(milliseconds: 300));
          await connectDevice(_lastAddress!);
          reconnectAttempted = true;
          ok = await _sendChunk(chunk);
        }
        if (ok != true) return false;
        await Future.delayed(const Duration(milliseconds: 80));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _sendChunk(Uint8List chunk) async {
    try {
      return (await _channel.invokeMethod<bool>('sendBytes', {'data': chunk})) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Disconnect the active Bluetooth SPP connection.
  static Future<void> disconnectDevice() async {
    try {
      await _channel.invokeMethod('disconnectDevice');
    } catch (_) {}
  }

  /// Check if a Bluetooth SPP connection is currently active.
  static Future<bool> isConnected() async {
    try {
      final result = await _channel.invokeMethod<bool>('isConnected');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────
  // Runtime Permission Helpers
  // ──────────────────────────────────────────────────────────

  /// Android SDK level where BLUETOOTH_SCAN/CONNECT became dangerous
  /// runtime permissions (Android 12 = API 31).
  static const int _sdk12 = 31;

  /// True when this device needs the Android 12+ Bluetooth runtime
  /// permissions. On Android 7–11 the classic BLUETOOTH/BLUETOOTH_ADMIN
  /// manifest permissions are enough (install-time, not runtime).
  static bool get needsRuntimePermission {
    if (!Platform.isAndroid) return false;
    try {
      return _androidSdkInt >= _sdk12;
    } catch (_) {
      // Can't read SDK level — assume modern so we still request.
      return true;
    }
  }

  /// Android SDK integer (e.g. 24 for Android 7, 33 for Android 13).
  /// Falls back to 0 (unknown) if parsing fails.
  static int get _androidSdkInt {
    try {
      // Platform.operatingSystemVersion looks like "Android 13" or "13".
      final raw = Platform.operatingSystemVersion;
      final match = RegExp(r'(\d+)').firstMatch(raw);
      if (match == null) return 0;
      return int.tryParse(match.group(1)!) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Check if all required Bluetooth permissions are granted.
  ///
  /// On Android <12 these are install-time permissions so always granted.
  /// On Android 12+ we check BLUETOOTH_SCAN + BLUETOOTH_CONNECT. Never
  /// throws — permission_handler can throw on platforms where a
  /// permission doesn't exist.
  static Future<bool> hasBluetoothPermissions() async {
    if (!Platform.isAndroid) return true;
    if (!needsRuntimePermission) return true;

    try {
      final scan = await Permission.bluetoothScan.status;
      final connect = await Permission.bluetoothConnect.status;
      return scan.isGranted && connect.isGranted;
    } catch (e) {
      debugPrint('[BluetoothUtils] hasBluetoothPermissions error: $e');
      // Can't determine — assume not granted so caller asks the user.
      return false;
    }
  }

  /// Request all required Bluetooth permissions from the user.
  /// Returns true if all permissions are granted after the request.
  /// On Android <12 there is nothing to request — returns true.
  static Future<bool> requestBluetoothPermissions() async {
    if (!Platform.isAndroid) return true;
    if (!needsRuntimePermission) return true;

    try {
      final perms = <Permission>[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ];

      // If permanently denied, open app settings
      for (final p in perms) {
        if (await p.status.isPermanentlyDenied) {
          await openAppSettings();
          await Future.delayed(Duration(seconds: 1));
          return hasBluetoothPermissions();
        }
      }

      final statuses = await perms.request();
      return statuses.values.every((s) => s.isGranted);
    } catch (e) {
      debugPrint('[BluetoothUtils] requestBluetoothPermissions error: $e');
      return false;
    }
  }
}
