import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Opens the native contact picker and returns the selected contact's name & phone.
/// Returns null if the user cancels or an error occurs.
///
/// Architecture: one-way MethodChannel ('com.nusa_kasir/contacts'):
/// 1. Dart → Native: call `pickContact`, native opens OS contact picker
/// 2. Native → Dart: native calls `result.success({name, phone})` directly
///    (not invokeMethod), so the Dart `await invokeMethod` returns the data.
///
/// Phone numbers are normalized to 08xxx format:
/// - Strips all non-digit characters (dashes, spaces, parentheses)
/// - Converts +628xx / 628xx → 08xx
/// - Leaves 08xx unchanged
///
/// No completer, no handler registration — just plain async platform call.
class ContactPicker {
  static const _channel = MethodChannel('com.nusa_kasir/contacts');

  /// Normalize a raw phone number to 08xxx format.
  /// - Strips all non-digit chars
  /// - Converts 62xxx → 0xxx (Indonesian mobile prefix)
  static String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';

    // +62 prefix → strip to 62xxx then convert
    if (digits.startsWith('62') && digits.length >= 10) {
      return '0${digits.substring(2)}';
    }
    // Already 0-prefix → keep as-is
    return digits;
  }

  /// Opens the native contact picker. Returns the selected contact or null.
  static Future<Map<String, String>?> pickContact() async {
    try {
      // Native will hold this call's result until the user picks or cancels,
      // then reply in onActivityResult via result.success(map/null).
      final data = await _channel.invokeMethod<Map<dynamic, dynamic>>('pickContact');

      debugPrint('[ContactPicker] raw result: $data');

      if (data == null || data.isEmpty) {
        debugPrint('[ContactPicker] null/empty — user cancelled');
        return null;
      }

      final rawPhone = (data['phone'] as String?) ?? '';
      final normalized = _normalizePhone(rawPhone);
      final result = {
        'name': (data['name'] as String?) ?? '',
        'phone': normalized,
      };
      debugPrint('[ContactPicker] success: name="${result["name"]}" raw="$rawPhone" → normalized="${result["phone"]}"');
      return result;
    } on MissingPluginException {
      debugPrint('[ContactPicker] MissingPluginException');
      return null;
    } on PlatformException catch (e) {
      debugPrint('[ContactPicker] PlatformException: ${e.code} — ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[ContactPicker] Unexpected error: $e');
      return null;
    }
  }
}

/// Convenience wrapper for backwards compatibility.
Future<Map<String, String>?> pickContact() => ContactPicker.pickContact();
