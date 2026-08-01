import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:nusa_kasir/app.dart';
import 'package:nusa_kasir/core/auth/employee_session.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:nusa_kasir/core/services/notification_service.dart';
import 'package:nusa_kasir/core/services/stok_alert_worker.dart';
import 'package:nusa_kasir/core/services/image_storage_service.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/settings_repository.dart';
import 'package:nusa_kasir/core/services/backup_crypto.dart';
import 'package:nusa_kasir/data/repositories/attendance_repository.dart';
import 'package:drift/drift.dart';

/// Ensure PIN length in the database is always 6 digits.
/// If the setting was changed to 4 (or corrupted), fix it.
/// If any employee PIN is not 6 digits, pad/truncate it.
Future<void> _repairPinLength() async {
  try {
    final db = AppDatabase();
    final settingsRepo = SettingsRepository(db);
    final pinLen = await settingsRepo.getPinLength();

    // Force setting back to 6
    if (pinLen != 6) {
      await settingsRepo.setPinLength(6);
    }

    // Fix any employee PINs that don't match 6 digits
    final attRepo = AttendanceRepository(db);
    final emps = await attRepo.getEmployees();
    for (final e in emps) {
      if (e.pin.length == 6) continue;
      String fixed;
      if (e.pin.length > 6) {
        fixed = e.pin.substring(0, 6);
      } else {
        fixed = e.pin.padRight(6, '0');
      }
      await (db.update(db.employees)..where((t) => t.id.equals(e.id)))
          .write(EmployeesCompanion(pin: Value(fixed)));
    }
    await db.close();
  } catch (_) {
    // Non-fatal — app continues even if repair fails
  }
}

/// Catch all unhandled Flutter errors and display them instead of blank screen.
void _setupErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (!details.silent) {
      final errorString = 'FlutterError: ${details.exception}\n${details.stack?.toString().substring(0, 500) ?? ''}';
      debugPrint(errorString);
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PlatformDispatcher error: $error\n$stack');
    return true; // handled
  };
}

/// Swap a pending backup into place BEFORE the database opens.
///
/// Supports both legacy format (raw SQLite bytes) and new NUS1 archive format
/// (SQLite + product images packed together).
Future<void> _applyPendingRestore() async {
  if (!await SecureStore.hasPendingRestore()) return;
  try {
    final dir = await getApplicationDocumentsDirectory();
    final pending = File(p.join(dir.path, 'nusa_kasir.sqlite.pending'));
    if (!await pending.exists()) {
      await SecureStore.clearPendingRestore();
      return;
    }

    final bytes = await pending.readAsBytes();

    // Try NUS1 archive format first (new — includes images)
    final files = BackupCrypto.unpackFiles(bytes);

    var imageCount = 0;
    for (final entry in files.entries) {
      final dest = File(p.join(dir.path, entry.key));
      await dest.writeAsBytes(entry.value, flush: true);
      if (entry.key != 'nusa_kasir.sqlite') imageCount++;
    }
    if (imageCount > 0) {
      debugPrint('[Restore] Extracted $imageCount product images');
    }

    await pending.delete();
    await SecureStore.clearPendingRestore();
  } catch (e) {
    debugPrint('[Restore] _applyPendingRestore error: $e');
    await SecureStore.clearPendingRestore();
  }
}

/// Sync images between local cache and Supabase Storage.
/// Runs once on startup — first-time migration uploads local images,
/// then downloads any cloud images missing from local cache.
void _syncImagesFromCloud() {
  Future.microtask(() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      final svc = ImageStorageService(Supabase.instance.client, uid);

      // First-time: upload existing local images to cloud
      final migrated = await SecureStore.getImagesMigrated();
      if (!migrated) {
        final uploaded = await svc.uploadAllLocal();
        await SecureStore.setImagesMigrated(true);
        if (uploaded > 0) {
          debugPrint('[Sync] First-time migration: uploaded $uploaded images');
        }
      }

      // Download any cloud images we don't have locally
      final downloaded = await svc.syncAll();
      if (downloaded > 0) {
        debugPrint('[Sync] Downloaded $downloaded images from cloud');
      }
    } catch (e) {
      debugPrint('[Sync] Image sync error: $e');
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _setupErrorHandlers();

  // Default fallback values in case any init step throws.
  // runApp() MUST be called — a white screen is worse than missing features.
  String persistedTheme = 'system';
  String initialLocation = '/activation';

  // Auto-repair PIN length BEFORE anything opens — ensures 6-digit PINs always
  try { await _repairPinLength(); } catch (_) {}

  try {
    // Workmanager
    try { await Workmanager().initialize(stokCallbackDispatcher, isInDebugMode: false); } catch (_) {}

    // Local notifications
    try { await NotificationService.init(); } catch (_) {}

    if (NusaConfig.supabaseUrl.isNotEmpty && NusaConfig.supabaseAnon.isNotEmpty) {
      try { await Supabase.initialize(url: NusaConfig.supabaseUrl, publishableKey: NusaConfig.supabaseAnon); } catch (_) {}
    }

    // Apply pending device-migration backup BEFORE opening the database.
    try { await _applyPendingRestore(); } catch (_) {}

    // Manual sync only — user controls when to upload/download via Settings.
    // Auto-sync removed to prevent race-condition data loss between devices.

    // Register background tasks
    try { registerStokCheck(); } catch (_) {}
    try { registerOnlineCheck(); } catch (_) {}

    // Load persisted theme mode before app starts.
    final db = AppDatabase();
    try {
      persistedTheme = await SettingsRepository(db).getThemeMode() ?? 'system';
    } catch (_) {}

    // Determine initial route.
    try {
      final activated = (await SecureStore.getActivation()) != null;
      if (!activated) {
        initialLocation = '/activation';
      } else {
        final session = await EmployeeSession.restore();
        initialLocation = (session != null && !session.isExpired)
            ? '/home'
            : '/activation';
      }
    } catch (_) {
      initialLocation = '/activation';
    }

    // Background: sync images from cloud (first-time migration + download)
    _syncImagesFromCloud();

    try { await db.close(); } catch (_) {}
  } catch (e) {
    debugPrint('[Main] Startup error: $e');
    // Fall through — runApp() always executes
  }

  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith((ref) => persistedTheme),
      ],
      child: NusaApp(initialLocation: initialLocation),
    ),
  );
}
