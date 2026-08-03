/// Resolves menu icon key → PNG asset path based on active theme colour.
///
/// Icons are named `{UPPER_NAME} {HEX}.png` inside `assets/icons/`.
/// Example: `iconAssetPath('product')` → `assets/icons/PRODUCT F97316.png`
/// when the active primary colour is Orange (#F97316).
library;

import 'package:flutter/material.dart';
import '../config/nusa_config.dart';

/// Maps dashboard icon key → uppercase filename prefix.
Map<String, String> _iconNameMap = {
  'product':       'PRODUCT',
  'inventory':     'INVENTORY',
  'transaction':   'TRANSACTION',
  'customer':      'CUSTOMER',
  'debt':          'DEBT',
  'promotion':     'PROMOTION',
  'online':        'ONLINE',
  'report':        'REPORT',
  'notification':  'NOTIFICATION',
  'employee':      'EMPLOYEE',
  'finance':       'FINANCE',
  'table':         'TABLE',
  'supplier':      'SUPPLIER',
  'branch':        'BRANCH',
  'ai':            'AI CHAT',
  'ai_chat':       'AI CHAT',
  'settings':      'SETTINGS',
  'table_bar':     'MEJA',
  'laundry':       'LAUNDRY',
  'repair':        'REPAIR',
  'booking':       'BOOKING',
  'prescription':  'PRESCRIPTION',
  'print_order':   'PRINT ORDER',
};

/// Returns the PNG asset path for [iconKey] matching the active primary colour.
///
/// Falls back to `assets/icons/PRODUCT F97316.png` when no match is found so
/// the UI never shows a broken-image placeholder.
String iconAssetPath(String iconKey) {
  final iconName = _iconNameMap[iconKey] ?? iconKey.toUpperCase();
  final hex = themePrimaryToHex(NusaConfig.activePrimary);
  return 'assets/icons/$iconName $hex.png';
}

/// Returns the splash logo asset path corresponding to the active theme
/// preset colour.  Each variant has an `app_logo_{id}.png` in `assets/icons/`.
String splashLogoPath() {
  final id = _activeThemeId();
  return 'assets/icons/app_logo_$id.png';
}

// ── colour utilities ──────────────────────────────────────────────────────

/// Maps a [Color] value to its 6-digit HEX string (no `#` prefix).
String themePrimaryToHex(Color c) {
  return '${c.value.toRadixString(16).substring(2).toUpperCase()}';
}

/// Returns the variant id (`kelontong`, `fnb`, …) whose primary colour
/// matches [NusaConfig.activePrimary].  Falls back to `kelontong`.
String _activeThemeId() {
  final active = NusaConfig.activePrimary.value;
  for (final entry in NusaConfig.themePresets.entries) {
    if (entry.value['primary']!.value == active) return entry.key;
  }
  return 'kelontong';
}
