import 'package:flutter/services.dart';

/// Checks/enables Bluetooth state via native platform channel.
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
  /// Returns true if the dialog was shown (user may or may not accept).
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

  /// Opens the system App Info settings screen for this app.
  static Future<bool> openAppSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openAppSettings');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
