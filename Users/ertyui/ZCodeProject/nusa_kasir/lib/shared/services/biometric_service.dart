import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';

/// Biometric (fingerprint/face) service for Owner quick unlock.
///
/// Fingerprint does NOT select which user logs in — it only unlocks
/// an existing valid Owner session. If no Owner session exists or the
/// session is expired, biometric is never prompted.
///
/// Holistic device support strategy:
/// - biometricOnly: false on ALL devices (allows PIN/pattern fallback)
/// - No hardware pre-checks (canCheckBiometrics returns false on many
///   Xiaomi/Redmi MIUI and Samsung OneUI devices even when HW works)
/// - Samsung-specific: OneUI biometric prompt can be cancelled by
///   system — we add retry and better error extraction
/// - Generic fallback: if local_auth throws PlatformException with
///   error codes like "NotAvailable", "PasscodeNotSet", etc., we
///   surface the exact native error
class BiometricService {
  const BiometricService._();

  static final _auth = LocalAuthentication();

  // New canonical key; legacy `nusa_fingerprint_enabled` read for migration.
  static const _keyEnabled = 'nusa_biometric_enabled';
  static const _legacyKeyEnabled = 'nusa_fingerprint_enabled';

  // ── Settings ────────────────────────────────────────────────────

  /// Check if biometric is enabled in NUSA settings (Owner toggle).
  static Future<bool> isEnabled() async {
    try {
      final v = await SecureStore.read(key: _keyEnabled);
      if (v != null) return v == 'true';
      // Migration: read the legacy fingerprint flag so enabling Face ID
      // on an upgraded install doesn't silently turn the toggle off.
      final legacy = await SecureStore.read(key: _legacyKeyEnabled);
      return legacy == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Enable biometric login for Owner.
  static Future<void> enable() async {
    await SecureStore.write(key: _keyEnabled, value: 'true');
    // Clear legacy key so the new key becomes authoritative
    await SecureStore.delete(key: _legacyKeyEnabled);
  }

  /// Disable biometric login for Owner.
  static Future<void> disable() async {
    await SecureStore.write(key: _keyEnabled, value: 'false');
  }

  /// Pick the unlock icon that matches what the device actually has:
  /// face → face icon, otherwise the generic fingerprint symbol.
  static Future<IconData> getUnlockIcon() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face) ||
          types.contains(BiometricType.iris)) {
        return Icons.face_retouching_natural;
      }
    } catch (_) {}
    return Icons.fingerprint;
  }

  // ── Authentication ──────────────────────────────────────────────

  /// Result of an authentication attempt.
  /// [ok] — true if biometric/pin accepted.
  /// [message] — user-facing message (only set when [ok] is false).
  static ({bool ok, String? message}) lastResult = (ok: false, message: null);

  /// Check if the device can authenticate at all.
  /// Returns (ok, message). Does NOT show any dialog.
  static Future<({bool ok, String message})> checkCapabilities() async {
    try {
      final supported = await _auth.isDeviceSupported();
      debugPrint('[BiometricService] isDeviceSupported: $supported');
      if (!supported) {
        return (ok: false, message: 'Perangkat tidak mendukung biometric');
      }

      final canCheck = await _auth.canCheckBiometrics;
      debugPrint('[BiometricService] canCheckBiometrics: $canCheck');

      final types = await _auth.getAvailableBiometrics();
      debugPrint('[BiometricService] available biometrics: $types');

      if (types.isEmpty && !canCheck) {
        return (ok: false, message: 'Tidak ada sidik jari terdaftar di perangkat');
      }

      return (ok: true, message: 'OK — ${types.map((t) => t.name).join(', ')}');
    } catch (e) {
      debugPrint('[BiometricService] checkCapabilities error: $e');
      // On error, let the authenticate() call decide — don't block
      return (ok: true, message: 'Unknown (will try anyway)');
    }
  }

  /// Translate native error codes to human-readable Indonesian messages.
  static String _translateError(String code, String message) {
    switch (code) {
      case 'NotAvailable':
        return 'Biometric tidak tersedia di perangkat ini. '
            'Pastikan kamu sudah mendaftarkan sidik jari di Pengaturan HP.';
      case 'PasscodeNotSet':
        return 'Kunci layar (PIN/pola) belum diatur. '
            'Buka Pengaturan HP → Keamanan → atur kunci layar terlebih dahulu.';
      case 'LockedOut':
      case 'TooManyAttempts':
        return 'Terlalu banyak percobaan gagal. '
            'Buka kunci HP dengan PIN/pola, lalu coba lagi.';
      case 'SystemCancel':
        return 'Sistem membatalkan pemindaian. '
            'Coba lagi — pastikan tidak ada aplikasi lain yang mengganggu.';
      case 'UserCancel':
        return 'Pemindaian dibatalkan oleh pengguna.';
      case 'biometricNotEnrolled':
      case 'NotEnrolled':
        return 'Sidik jari belum terdaftar. '
            'Buka Pengaturan HP → Biometric → daftarkan sidik jari kamu.';
      default:
        // Samsung OneUI often returns generic errors; give actionable advice
        return 'Gagal memindai: ${message.isNotEmpty ? message : code}. '
            'Coba: (1) Pastikan sidik jari terdaftar di Pengaturan HP, '
            '(2) Restart HP jika baru update, '
            '(3) Coba unlock HP dulu dengan sidik jari dari layar kunci.';
    }
  }

  /// After calling this, read [lastResult] for a user-facing error message.
  static Future<bool> authenticate({
    String reason = 'Verifikasi biometrik untuk melanjutkan',
  }) async {
    try {
      // Diagnostic: log device capabilities (does NOT block auth)
      try {
        final types = await _auth.getAvailableBiometrics();
        debugPrint('[BiometricService] device biometric types: $types');
        if (types.isEmpty) {
          debugPrint('[BiometricService] ⚠ getAvailableBiometrics() returned EMPTY list');
          debugPrint('[BiometricService] Proceeding anyway — OS dialog will handle it');
        }
      } catch (e) {
        debugPrint('[BiometricService] could not get biometric types: $e');
      }

      // Attempt 1: Standard local_auth with PIN fallback
      bool? ok;
      String? errorMsg;

      try {
        ok = await _auth.authenticate(
          localizedReason: reason,
          biometricOnly: false,
          persistAcrossBackgrounding: true,
        ).timeout(const Duration(seconds: 30));
        debugPrint('[BiometricService] authenticate → $ok');
      } on TimeoutException {
        debugPrint('[BiometricService] authenticate TIMEOUT — cancelling');
        try { await _auth.stopAuthentication(); } catch (_) {}
        errorMsg = 'Waktu pemindaian habis. Coba lagi.';
      } on PlatformException catch (e) {
        debugPrint('[BiometricService] PlatformException: code=${e.code} message=${e.message}');
        errorMsg = _translateError(e.code, e.message ?? '');
      }

      if (ok == true) {
        lastResult = (ok: true, message: null);
        return true;
      }

      // If first attempt failed with a non-timeout error, try once more
      if (errorMsg == null && ok != true) {
        debugPrint('[BiometricService] Retry attempt 2...');
        try {
          ok = await _auth.authenticate(
            localizedReason: 'Coba lagi — $reason',
            biometricOnly: false,
            persistAcrossBackgrounding: true,
          ).timeout(const Duration(seconds: 30));
          debugPrint('[BiometricService] retry authenticate → $ok');
        } on TimeoutException {
          try { await _auth.stopAuthentication(); } catch (_) {}
        } on PlatformException catch (e) {
          debugPrint('[BiometricService] Retry PlatformException: code=${e.code}');
          errorMsg = _translateError(e.code, e.message ?? '');
        }
      }

      if (ok == true) {
        lastResult = (ok: true, message: null);
        return true;
      }

      // Both attempts failed
      lastResult = (
        ok: false,
        message: errorMsg ?? 'Pemindaian dibatalkan atau gagal — coba lagi',
      );
      return false;
    } on Exception catch (e) {
      String msg;
      try {
        msg = (e as dynamic).message as String? ?? '$e';
      } catch (_) {
        msg = '$e';
      }
      debugPrint('[BiometricService] authenticate ERROR (${e.runtimeType}): $msg');
      lastResult = (ok: false, message: _translateError('', msg));
      return false;
    } catch (e) {
      debugPrint('[BiometricService] authenticate UNKNOWN ERROR: $e');
      lastResult = (ok: false, message: 'Gagal — $e');
      return false;
    }
  }
}
