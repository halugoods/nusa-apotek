import 'dart:io';
import 'dart:typed_data';
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
    try {
      await _channel.invokeMethod('connectDevice', {'address': address});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Send raw bytes over the active Bluetooth SPP connection.
  ///
  /// Strategy: try single-write first (works for most printers).
  /// If that fails, fall back to chunked mode with delay between chunks
  /// to accommodate printers with small internal buffers.
  static Future<bool> sendBytes(Uint8List data) async {
    try {
      // 1) Single-write fast path (works for 95% of thermal printers).
      final result = await _channel.invokeMethod<bool>('sendBytes', {'data': data});
      if (result == true) return true;

      // 2) Chunked fallback — some cheap printers overflow on large payloads.
      const chunkSize = 256;
      for (var i = 0; i < data.length; i += chunkSize) {
        final end = (i + chunkSize > data.length) ? data.length : i + chunkSize;
        final chunk = data.sublist(i, end);
        final ok = await _channel.invokeMethod<bool>('sendBytes', {'data': chunk});
        if (ok != true) return false;
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return true;
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

  /// Check if all required Bluetooth permissions are granted.
  static Future<bool> hasBluetoothPermissions() async {
    if (!Platform.isAndroid) return true;

    final scan = await Permission.bluetoothScan.status;
    final connect = await Permission.bluetoothConnect.status;

    return scan.isGranted && connect.isGranted;
  }

  /// Request all required Bluetooth permissions from the user.
  /// Returns true if all permissions are granted after the request.
  static Future<bool> requestBluetoothPermissions() async {
    if (!Platform.isAndroid) return true;

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
  }

  /// Check if device runs Android 12+ (API 31+) where runtime BT permissions apply.
  static bool get needsRuntimePermission {
    if (!Platform.isAndroid) return false;
    // Android 12 = API 31
    return true; // we always check; the API gracefully degrades on older versions
  }
}
