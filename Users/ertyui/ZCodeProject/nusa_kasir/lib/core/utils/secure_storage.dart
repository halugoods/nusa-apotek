import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nusa_kasir/core/constants/app_constants.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';

/// DO NOT wipe the entire keystore on PlatformException.
/// A single key failure (e.g. after OS update) should NOT delete
/// unrelated keys like activation, Google ID, or employee session.
/// Instead, just return null for reads and retry writes on the specific key.
class SecureStore {
  const SecureStore._();
  static const _s = FlutterSecureStorage();

  // -- Generic key-value wrappers (catch PlatformException) --

  static Future<void> write({
    required String key,
    required String value,
  }) async {
    try {
      await _s.write(key: key, value: value);
    } on PlatformException {
      // Retry once after clearing just this key (corner case: key corruption)
      try {
        await _s.delete(key: key);
        await _s.write(key: key, value: value);
      } catch (_) {}
    }
  }

  static Future<String?> read({required String key}) async {
    try {
      return await _s.read(key: key);
    } on PlatformException {
      // Never wipe — just return null. Activation/auth state is sacred.
      return null;
    }
  }

  static Future<void> delete({required String key}) async {
    try {
      await _s.delete(key: key);
    } on PlatformException {
      // Already gone or inaccessible — don't cascade
    }
  }

  // -- Activation (namespaced per product to prevent cross-variant license leaks) --
  static String get _activationKey =>
      'nusa_activation_${NusaConfig.productId}';
  static const String _legacyActivationKey = 'nusa_activation';

  static Future<void> saveActivation(String key) =>
      SecureStore.write(key: _activationKey, value: key);
  static Future<String?> getActivation() async {
    // Check namespaced key first
    final v = await SecureStore.read(key: _activationKey);
    if (v != null) return v;
    // Fall back to legacy un-namespaced key, then migrate
    final legacy = await SecureStore.read(key: _legacyActivationKey);
    if (legacy != null) {
      await SecureStore.write(key: _activationKey, value: legacy);
      await SecureStore.delete(key: _legacyActivationKey);
      return legacy;
    }
    // Migration: nusa-servicehp → nusa-servis (variant rename v1.6.9)
    if (NusaConfig.productId == 'nusa-servis') {
      final oldKey = await SecureStore.read(key: 'nusa_activation_nusa-servicehp');
      if (oldKey != null) {
        await SecureStore.write(key: _activationKey, value: oldKey);
        await SecureStore.delete(key: 'nusa_activation_nusa-servicehp');
        return oldKey;
      }
    }
    return null;
  }
  static Future<void> clearActivation() async {
    await SecureStore.delete(key: _activationKey);
    await SecureStore.delete(key: _legacyActivationKey);
  }

  // -- Pending DB restore (device migration) --
  static Future<void> savePendingRestore() =>
      SecureStore.write(key: 'nusa_pending_restore', value: '1');
  static Future<bool> hasPendingRestore() async =>
      (await SecureStore.read(key: 'nusa_pending_restore')) == '1';
  static Future<void> clearPendingRestore() =>
      SecureStore.delete(key: 'nusa_pending_restore');

  /// How many times has the current pending restore been attempted?
  /// Reset to 0 when a new pending file is staged.
  static Future<int> pendingRestoreAttempts() async {
    final v = await SecureStore.read(key: 'nusa_pending_restore_attempts');
    return int.tryParse(v ?? '0') ?? 0;
  }

  static Future<void> incrementPendingRestoreAttempts() async {
    final current = await pendingRestoreAttempts();
    await SecureStore.write(
      key: 'nusa_pending_restore_attempts',
      value: '${current + 1}',
    );
  }

  static Future<void> clearPendingRestoreAttempts() =>
      SecureStore.delete(key: 'nusa_pending_restore_attempts');

  // -- Cloud backup timestamp (for conflict resolution, namespaced per product) --
  static String get _backupTimeKey =>
      'nusa_last_backup_at_${NusaConfig.productId}';
  static Future<void> saveLastBackupTime(DateTime t) =>
      SecureStore.write(key: _backupTimeKey, value: t.toIso8601String());
  static Future<DateTime?> getLastBackupTime() async {
    final v = await SecureStore.read(key: _backupTimeKey);
    return v != null ? DateTime.tryParse(v) : null;
  }

  static Future<void> clearLastBackupTime() =>
      SecureStore.delete(key: _backupTimeKey);

  // -- Sheets tokens --
  static Future<void> saveSheetsTokens(String json) =>
      SecureStore.write(key: AppConstants.sheetsTokenKey, value: json);
  static Future<String?> getSheetsTokens() =>
      SecureStore.read(key: AppConstants.sheetsTokenKey);
  static Future<void> clearSheetsTokens() =>
      SecureStore.delete(key: AppConstants.sheetsTokenKey);

  // -- Sheets email + spreadsheet ID per user --
  static Future<void> saveSheetsEmail(String email) =>
      SecureStore.write(key: 'nusa_sheets_email', value: email);
  static Future<String?> getSheetsEmail() =>
      SecureStore.read(key: 'nusa_sheets_email');
  static Future<void> clearSheetsEmail() =>
      SecureStore.delete(key: 'nusa_sheets_email');

  static Future<void> saveSheetsId(String id) =>
      SecureStore.write(key: 'nusa_sheets_id', value: id);
  static Future<String?> getSheetsId() =>
      SecureStore.read(key: 'nusa_sheets_id');
  static Future<void> clearSheetsId() =>
      SecureStore.delete(key: 'nusa_sheets_id');

  // -- Feature toggles (JSON, namespaced per product) --
  static String get _featureToggleKey =>
      'nusa_feature_toggles_${NusaConfig.productId}';
  static Future<void> saveFeatureToggles(String json) =>
      SecureStore.write(key: _featureToggleKey, value: json);
  static Future<String?> getFeatureToggles() =>
      SecureStore.read(key: _featureToggleKey);
  static Future<void> clearFeatureToggles() =>
      SecureStore.delete(key: _featureToggleKey);

  // -- Menu order (JSON array, namespaced per product) --
  static String get _menuOrderKey => 'nusa_menu_order_${NusaConfig.productId}';
  static Future<void> saveMenuOrder(String json) =>
      SecureStore.write(key: _menuOrderKey, value: json);
  static Future<String?> getMenuOrder() => SecureStore.read(key: _menuOrderKey);
  static Future<void> clearMenuOrder() =>
      SecureStore.delete(key: _menuOrderKey);

  // -- Theme preset (theme ID string, namespaced per product) --
  static String get _themePresetKey =>
      'nusa_theme_preset_${NusaConfig.productId}';
  static Future<void> saveThemePreset(String themeId) =>
      SecureStore.write(key: _themePresetKey, value: themeId);
  static Future<String?> getThemePreset() =>
      SecureStore.read(key: _themePresetKey);
  static Future<void> clearThemePreset() =>
      SecureStore.delete(key: _themePresetKey);

  // -- Printer settings --
  static Future<void> setAutoPrint(bool v) =>
      SecureStore.write(key: 'nusa_printer_auto_print', value: v.toString());
  static Future<bool> getAutoPrint() async =>
      (await SecureStore.read(key: 'nusa_printer_auto_print')) == 'true';
  static Future<void> setPaperSize(String v) =>
      SecureStore.write(key: 'nusa_printer_paper_size', value: v);
  static Future<String> getPaperSize() async =>
      (await SecureStore.read(key: 'nusa_printer_paper_size')) ?? '58';

  // -- Cash drawer --
  static Future<void> setCashDrawerEnabled(bool v) =>
      SecureStore.write(key: 'nusa_cash_drawer_enabled', value: v.toString());
  static Future<bool> getCashDrawerEnabled() async =>
      (await SecureStore.read(key: 'nusa_cash_drawer_enabled')) == 'true';

  // -- Printer footer --
  static Future<void> setPrinterFooter(String v) =>
      SecureStore.write(key: 'nusa_printer_footer', value: v);
  static Future<String> getPrinterFooter() async =>
      (await SecureStore.read(key: 'nusa_printer_footer')) ?? '';

  // -- Printer logo path --
  static Future<void> setPrinterLogoPath(String? v) async {
    if (v == null) {
      await SecureStore.delete(key: 'nusa_printer_logo_path');
    } else {
      await SecureStore.write(key: 'nusa_printer_logo_path', value: v);
    }
  }

  static Future<String?> getPrinterLogoPath() async =>
      SecureStore.read(key: 'nusa_printer_logo_path');

  // -- Kitchen printer (FnB) --
  static const _kitchenPrinterKey = 'nusa_kitchen_printer_address';

  static Future<String?> getKitchenPrinterAddress() =>
      SecureStore.read(key: _kitchenPrinterKey);

  static Future<void> setKitchenPrinterAddress(String? v) async {
    if (v == null) {
      await SecureStore.delete(key: _kitchenPrinterKey);
    } else {
      await SecureStore.write(key: _kitchenPrinterKey, value: v);
    }
  }

  static const _kitchenPrinterEnabledKey = 'nusa_kitchen_printer_enabled';

  static Future<bool> getKitchenPrinterEnabled() async =>
      (await SecureStore.read(key: _kitchenPrinterEnabledKey)) == 'true';

  static Future<void> setKitchenPrinterEnabled(bool v) =>
      SecureStore.write(key: _kitchenPrinterEnabledKey, value: v.toString());

  // ── FnB payment flow: true = bayar dulu (pay first, then table), false = pesan dulu (default) ──
  static Future<bool> getFnbPaymentFirst() async =>
      (await SecureStore.read(key: 'nusa_fnb_payment_first')) == 'true';
  static Future<void> setFnbPaymentFirst(bool v) =>
      SecureStore.write(key: 'nusa_fnb_payment_first', value: v.toString());

  // ── Laundry settings ──
  static Future<String> getLaundryDefaultPriceType() async =>
      (await SecureStore.read(key: 'nusa_laundry_default_price_type')) ?? 'pcs';
  static Future<void> setLaundryDefaultPriceType(String v) =>
      SecureStore.write(key: 'nusa_laundry_default_price_type', value: v);
  static Future<bool> getLaundryNotifyReady() async =>
      (await SecureStore.read(key: 'nusa_laundry_notify_ready')) == 'true';
  static Future<void> setLaundryNotifyReady(bool v) =>
      SecureStore.write(key: 'nusa_laundry_notify_ready', value: v.toString());

  // ── Image migration flag ──────────────────────────────────────────
  static Future<bool> getImagesMigrated() async =>
      (await SecureStore.read(key: 'nusa_images_migrated')) == 'true';
  static Future<void> setImagesMigrated(bool v) =>
      SecureStore.write(key: 'nusa_images_migrated', value: v.toString());
}
