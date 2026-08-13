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

  /// Selected printer address ("Name|MAC") — single source of truth for both
  /// the settings sheet and auto-print, so a printer picked on one device
  /// isn't lost when the receipt sheet runs on another screen/device.
  static const _printerAddressKey = 'nusa_printer_address';
  static Future<void> setPrinterAddress(String v) =>
      SecureStore.write(key: _printerAddressKey, value: v);
  static Future<String?> getPrinterAddress() =>
      SecureStore.read(key: _printerAddressKey);

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

  // -- Receipt font settings (universal ESC/POS: Standar=Font A, Kompak=Font B) --
  // Jenis font: 'standar' (Font A, universal — direkomendasikan) | 'kompak' (Font B).
  static Future<void> setReceiptFontType(String v) =>
      SecureStore.write(key: 'nusa_receipt_font_type', value: v);
  static Future<String> getReceiptFontType() async =>
      (await SecureStore.read(key: 'nusa_receipt_font_type')) ?? 'standar';

  // Ukuran per section (ESC/POS perbesaran 1x-8x):
  // header: 1/2/3 → Kecil/Normal/Besar. items: 1/2 → Kecil/Besar. footer: 1/2.
  static Future<void> setReceiptFontHeader(int v) =>
      SecureStore.write(key: 'nusa_receipt_font_header', value: v.toString());
  static Future<int> getReceiptFontHeader() async =>
      int.tryParse(await SecureStore.read(key: 'nusa_receipt_font_header') ?? '') ?? 2;
  static Future<void> setReceiptFontItems(int v) =>
      SecureStore.write(key: 'nusa_receipt_font_items', value: v.toString());
  static Future<int> getReceiptFontItems() async =>
      int.tryParse(await SecureStore.read(key: 'nusa_receipt_font_items') ?? '') ?? 1;
  static Future<void> setReceiptFontFooter(int v) =>
      SecureStore.write(key: 'nusa_receipt_font_footer', value: v.toString());
  static Future<int> getReceiptFontFooter() async =>
      int.tryParse(await SecureStore.read(key: 'nusa_receipt_font_footer') ?? '') ?? 1;

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
  static Future<bool> getLaundryStatsExpanded() async =>
      (await SecureStore.read(key: 'nusa_laundry_stats_expanded')) == 'true';
  static Future<void> setLaundryStatsExpanded(bool v) =>
      SecureStore.write(key: 'nusa_laundry_stats_expanded', value: v.toString());

  // ── Salon settings ──
  static Future<int> getSalonDefaultDuration() async {
    final v = await SecureStore.read(key: 'nusa_salon_default_duration');
    return v != null ? int.tryParse(v) ?? 60 : 60;
  }
  static Future<void> setSalonDefaultDuration(int v) =>
      SecureStore.write(key: 'nusa_salon_default_duration', value: v.toString());
  static Future<bool> getSalonNotifyBooking() async =>
      (await SecureStore.read(key: 'nusa_salon_notify_booking')) == 'true';
  static Future<void> setSalonNotifyBooking(bool v) =>
      SecureStore.write(key: 'nusa_salon_notify_booking', value: v.toString());
  static Future<bool> getSalonStatsExpanded() async =>
      (await SecureStore.read(key: 'nusa_salon_stats_expanded')) == 'true';
  static Future<void> setSalonStatsExpanded(bool v) =>
      SecureStore.write(key: 'nusa_salon_stats_expanded', value: v.toString());

  // ── Bengkel settings ──
  static Future<bool> getBengkelStatsExpanded() async =>
      (await SecureStore.read(key: 'nusa_bengkel_stats_expanded')) == 'true';
  static Future<void> setBengkelStatsExpanded(bool v) =>
      SecureStore.write(key: 'nusa_bengkel_stats_expanded', value: v.toString());

  // ── Image migration flag ──────────────────────────────────────────
  static Future<bool> getImagesMigrated() async =>
      (await SecureStore.read(key: 'nusa_images_migrated')) == 'true';
  static Future<void> setImagesMigrated(bool v) =>
      SecureStore.write(key: 'nusa_images_migrated', value: v.toString());

  // ── PIN pad kasir (default: aktif) ────────────────────────────────
  static Future<bool> getPinPadEnabled() async {
    final v = await SecureStore.read(key: 'nusa_pinpad_kasir_enabled');
    return v == null || v == 'true'; // default aktif
  }
  static Future<void> setPinPadEnabled(bool v) =>
      SecureStore.write(key: 'nusa_pinpad_kasir_enabled', value: v.toString());

  // ── Izin pertama kali (dialog sekali) ─────────────────────────────
  static Future<bool> getPermissionsAsked() async =>
      (await SecureStore.read(key: 'nusa_permissions_asked')) == 'true';
  static Future<void> setPermissionsAsked(bool v) =>
      SecureStore.write(key: 'nusa_permissions_asked', value: v.toString());

  // ── Auto cloud sync state (per device) ────────────────────────────
  static Future<DateTime?> getLastCloudSeen() async {
    final v = await SecureStore.read(key: 'nusa_last_cloud_seen');
    return v != null ? DateTime.tryParse(v) : null;
  }
  static Future<void> setLastCloudSeen(DateTime v) =>
      SecureStore.write(key: 'nusa_last_cloud_seen', value: v.toUtc().toIso8601String());

  static Future<DateTime?> getLastLocalChange() async {
    final v = await SecureStore.read(key: 'nusa_last_local_change');
    return v != null ? DateTime.tryParse(v) : null;
  }
  static Future<void> setLastLocalChange(DateTime v) =>
      SecureStore.write(key: 'nusa_last_local_change', value: v.toUtc().toIso8601String());

  static Future<int> getConflictCount() async {
    final v = await SecureStore.read(key: 'nusa_conflict_count');
    return v != null ? int.tryParse(v) ?? 0 : 0;
  }
  static Future<void> setConflictCount(int v) =>
      SecureStore.write(key: 'nusa_conflict_count', value: v.toString());
  static Future<void> bumpConflictCount() async {
    final c = await getConflictCount();
    await setConflictCount(c + 1);
  }
}
