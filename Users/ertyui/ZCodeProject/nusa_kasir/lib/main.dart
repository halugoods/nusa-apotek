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
import 'package:nusa_kasir/core/activation/activation_repository.dart';
import 'package:nusa_kasir/core/utils/receipt_renderer.dart';
import 'package:nusa_kasir/core/services/notification_service.dart';
import 'package:nusa_kasir/core/services/stok_alert_worker.dart';
import 'package:nusa_kasir/core/services/update_service.dart';
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
      await (db.update(db.employees)..where((t) => t.id.equals(e.id))).write(
        EmployeesCompanion(pin: Value(fixed)),
      );
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
      final errorString =
          'FlutterError: ${details.exception}\n${details.stack?.toString().substring(0, 500) ?? ''}';
      debugPrint(errorString);
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PlatformDispatcher error: $error\n$stack');
    return true; // handled
  };
}

Future<void> _writeRestoreFile(
  String rootPath,
  String relativePath,
  List<int> bytes,
) async {
  final rootCanonical = p.normalize(Directory(rootPath).absolute.path);
  final destinationCanonical = p.normalize(
    File(p.join(rootPath, relativePath)).absolute.path,
  );
  if (destinationCanonical != rootCanonical &&
      !p.isWithin(rootCanonical, destinationCanonical)) {
    throw FormatException(
      'Restore path escapes application directory: $relativePath',
    );
  }
  await File(destinationCanonical).writeAsBytes(bytes, flush: true);
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

    // ── CRITICAL: clear stale SQLite sidecar files (-wal/-shm) first ──
    // If a previous session left a WAL/journal behind, SQLite would replay
    // it on top of the swapped-in database → mixed/empty tables → menu dead
    // + every PIN fails again. This is the same class of corruption as the
    // original restore bug, so clean all sidecars of the target file BEFORE
    // the swap. The database has NOT been opened yet at this point (we run
    // before AppDatabase() is constructed in main), so it's safe.
    final dbPath = p.join(dir.path, 'nusa_kasir.sqlite');
    for (final sidecar in ['$dbPath-wal', '$dbPath-shm', '$dbPath-journal']) {
      final f = File(sidecar);
      if (await f.exists()) {
        try {
          await f.delete();
          debugPrint('[Restore] Cleaned stale sidecar: ${p.basename(sidecar)}');
        } catch (_) {
          // Non-fatal: a locked sidecar just stays; SQLite handles it.
        }
      }
    }

    var imageCount = 0;
    for (final entry in files.entries) {
      await _writeRestoreFile(dir.path, entry.key, entry.value);
      if (entry.key != 'nusa_kasir.sqlite') imageCount++;
    }
    if (imageCount > 0) {
      debugPrint('[Restore] Extracted $imageCount product images');
    }

    await pending.delete();
    await SecureStore.clearPendingRestore();
  } catch (e) {
    // Keep the marker and pending file so the restore can be retried next launch.
    debugPrint('[Restore] _applyPendingRestore error (will retry): $e');
  }
}

/// Auto cloud sync — receive side. Runs at app launch (before the DB opens).
///
/// Rule: pull from cloud ONLY if the cloud backup is newer than what we last
/// saw AND we have no local changes that haven't been uploaded yet. This
/// never overwrites un-uploaded local work. Timeout 3s — offline starts fast.
Future<void> _receiveAtLaunch() async {
  try {
    if (await SecureStore.getActivation() == null) return;
    final uid = await SecureStore.read(key: 'nusa_google_user_id');
    if (uid == null) return;

    final client = Supabase.instance.client;
    final repo = ActivationRepository(client);
    final cloudTime = await repo.getBackupTimestamp().timeout(
      const Duration(seconds: 3),
      onTimeout: () => null,
    );
    if (cloudTime == null) return;

    final lastSeen = await SecureStore.getLastCloudSeen();
    final lastLocalChange = await SecureStore.getLastLocalChange();

    // Cloud not newer than last seen → nothing to pull.
    if (lastSeen != null && !cloudTime.isAfter(lastSeen)) return;

    // Local un-uploaded changes → don't overwrite local; leave for upload.
    if (lastLocalChange != null &&
        (lastSeen == null || lastLocalChange.isAfter(lastSeen))) {
      return;
    }

    // No local pending changes → adopt cloud backup.
    final ok = await repo.restoreFromCloud().timeout(
      const Duration(seconds: 15),
      onTimeout: () => false,
    );
    if (ok) {
      await SecureStore.setLastCloudSeen(cloudTime);
      debugPrint('[AutoSync] Received cloud backup ($cloudTime)');
    }
  } catch (e) {
    debugPrint('[AutoSync] receive-at-launch skip: $e');
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
  try {
    await _repairPinLength();
  } catch (_) {}

  try {
    // Workmanager
    try {
      await Workmanager().initialize(
        stokCallbackDispatcher,
        isInDebugMode: false,
      );
    } catch (_) {}

    // Local notifications
    try {
      await NotificationService.init();
    } catch (_) {}

    if (NusaConfig.supabaseUrl.isNotEmpty &&
        NusaConfig.supabaseAnon.isNotEmpty) {
      try {
        await Supabase.initialize(
          url: NusaConfig.supabaseUrl,
          publishableKey: NusaConfig.supabaseAnon,
        );
      } catch (_) {}
    }

    // Auto cloud sync — receive-at-launch: pull the newest cloud backup
    // BEFORE the database opens, but only when we have NO un-uploaded local
    // changes (otherwise the local work would be silently overwritten).
    try {
      await _receiveAtLaunch();
    } catch (_) {}

    // Reset pengaturan struk ke v2 (bit-image, ukuran pixel) SEKALI saat
    // upgrade ke v2.2.24+76 — nilai lama (perbesaran ESC/POS 1-5) tidak
    // kompatibel dengan kamus pixel 12-48 baru, jadi dibersihkan ke default
    // (Header 24, Rincian 12, Footer 12, Logo 60%, Font Standar).
    try {
      if (!await SecureStore.getReceiptV2ResetDone()) {
        await SecureStore.setReceiptFontType('standar');
        await SecureStore.setReceiptFontHeader(receiptHeaderDefaultPx);
        await SecureStore.setReceiptFontItems(receiptItemsDefaultPx);
        await SecureStore.setReceiptFontFooter(receiptFooterDefaultPx);
        await SecureStore.setReceiptLogoWidthPercent(receiptLogoDefaultPercent);
        await SecureStore.setReceiptV2ResetDone();
        debugPrint('[Receipt] pengaturan struk di-reset ke v2 (bit-image)');
      }
    } catch (_) {}

    // Apply pending device-migration backup BEFORE opening the database.
    try {
      await _applyPendingRestore();
    } catch (_) {}

    // Register background tasks
    try {
      registerStokCheck();
    } catch (_) {}
    try {
      registerOnlineCheck();
    } catch (_) {}

    // Load persisted theme mode and color preset before app starts.
    final db = AppDatabase();
    try {
      persistedTheme = await SettingsRepository(db).getThemeMode() ?? 'system';
    } catch (_) {}
    try {
      final preset = await SecureStore.getThemePreset();
      if (preset != null && NusaConfig.themePresets.containsKey(preset)) {
        NusaConfig.applyTheme(preset);
      }
    } catch (_) {}
    // Cash drawer flag dibaca langsung dari SecureStore saat print
    // (ReceiptPrinter.printReceipt → SecureStore.getCashDrawerEnabled()),
    // jadi tidak perlu di-restore ke static field lagi.

    // Hapus APK update sisa (auto-cleanup) — user gaptek lupa menghapus,
    // memori penyimpanan penuh. File tidak bisa dihapus saat installer masih
    // memakainya, jadi dibersihkan saat app start berikutnya.
    try {
      await UpdateService.cleanupApk();
    } catch (_) {}

    // Determine initial route.
    try {
      final activated = (await SecureStore.getActivation()) != null;
      if (!activated) {
        // Dev mode: show variant picker first, then activation
        // Production: go directly to activation with build-time config
        initialLocation = NusaConfig.isDevBuild
            ? '/variant-picker'
            : '/activation';
      } else {
        final session = await EmployeeSession.restore();
        if (session != null && !session.isExpired) {
          initialLocation = '/home';
        } else {
          // Already activated — skip activation screen, go straight to PIN login.
          initialLocation = '/login';
        }
      }
    } catch (_) {
      initialLocation = '/activation';
    }

    // Background: sync images from cloud (first-time migration + download)
    _syncImagesFromCloud();

    try {
      await db.close();
    } catch (_) {}
  } catch (e) {
    debugPrint('[Main] Startup error: $e');
    // Fall through — runApp() always executes
  }

  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith((ref) => persistedTheme),
        themePresetProvider.overrideWith((ref) {
          final preset = NusaConfig.themePresets.keys.firstWhere(
            (id) =>
                NusaConfig.activePrimary ==
                NusaConfig.themePresets[id]!['primary'],
            orElse: () => NusaConfig.productId.replaceFirst('nusa-', ''),
          );
          return preset;
        }),
      ],
      child: NusaApp(initialLocation: initialLocation),
    ),
  );
}
