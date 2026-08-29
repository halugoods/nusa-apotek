import 'dart:convert';
import 'package:workmanager/workmanager.dart';
import 'package:nusa_kasir/core/services/notification_service.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/report_repository.dart';

/// Task name untuk rangkuman harian AI (insight proaktif — Area H).
const aiInsightTaskName = 'nusa_kasir_ai_insight';

/// Key penyimpanan insight terakhir (SecureStore) — dipakai dashboard card.
const aiInsightStorageKey = 'nusa_ai_insight_last';

/// Rangkuman harian AI — dijalankan background (interval 6 jam, best effort
/// ~pagi) dan menghasilkan insight bisnis singkat (omzet, produk terlaris,
/// stok menipis) untuk notifikasi + kartu dashboard.
///
/// Area H (v2.2.57+115): insight TIDAK dikirim ke AI cloud (hemat biaya) —
/// dihitung lokal dari data transaksi, lalu dikirim sebagai notifikasi +
/// kartu dashboard ("AI Insight"). Chat tetap full AI cloud (ai-assistant).
class AiInsightWorker {
  /// Build insight text from today's data. Idempotent — panggil kapan saja.
  /// [db] opsional: kalau dikirim (mis. dari dashboard yang sudah punya
  /// koneksi drift), koneksi tsb dipakai; kalau null, buka koneksi sendiri.
  static Future<Map<String, dynamic>> buildInsight({AppDatabase? db}) async {
    final ownsDb = db == null;
    final dbase = db ?? AppDatabase();
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Omzet + jumlah transaksi hari ini
      final reportRepo = ReportRepository(dbase);
      final todaySummary = await reportRepo.summary(from: today, to: now);
      final omzet = todaySummary['omzet'] as int? ?? 0;
      final count = todaySummary['count'] as int? ?? 0;

      // Bandingkan dengan kemarin (untuk konteks naik/turun)
      final yesterday = today.subtract(const Duration(days: 1));
      final ySummary = await reportRepo.summary(
        from: yesterday,
        to: today,
      );
      final yOmzet = ySummary['omzet'] as int? ?? 0;

      // Produk terlaris hari ini (dari transaksi)
      String topProduct = '';
      final txList = todaySummary['items'] as List? ?? [];
      final qtyByProduct = <String, int>{};
      for (final tx in txList) {
        final items = _parseItems(tx);
        for (final it in items) {
          final name = it['name'] as String? ?? '';
          final qty = it['qty'] as int? ?? 0;
          if (name.isNotEmpty) {
            qtyByProduct[name] = (qtyByProduct[name] ?? 0) + qty;
          }
        }
      }
      if (qtyByProduct.isNotEmpty) {
        final top = qtyByProduct.entries.reduce((a, b) => a.value > b.value ? a : b);
        topProduct = top.key;
      }

      // Stok menipis
      final products = await dbase.select(dbase.products).get();
      final lowStock = products
          .where((p) => p.stock < p.minStock && p.minStock > 0)
          .take(3)
          .map((p) => p.name)
          .toList();

      // ── Susun insight (bahasa natural) ──
      final sb = StringBuffer();
      sb.write('Hari ini omzet Rp ${_fmt(omzet)}');
      if (count > 0) sb.write(' dari $count transaksi');
      sb.write('.');

      if (yOmzet > 0 && omzet > 0) {
        final delta = ((omzet - yOmzet) / yOmzet * 100).round();
        if (delta > 5) {
          sb.write(' Naik $delta% dibanding kemarin — bagus!');
        } else if (delta < -5) {
          sb.write(' Turun ${delta.abs()}% dari kemarin.');
        }
      }

      if (topProduct.isNotEmpty) {
        sb.write(' Produk terlaris: $topProduct.');
      }
      if (lowStock.isNotEmpty) {
        sb.write(' Stok menipis: ${lowStock.join(', ')}.');
      }

      if (omzet == 0 && count == 0) {
        sb.write(' Belum ada transaksi hari ini — kasir belum dibuka?');
      }

      final insight = sb.toString();
      return {
        'date': now.toIso8601String(),
        'omzet': omzet,
        'count': count,
        'top_product': topProduct,
        'low_stock': lowStock,
        'text': insight,
      };
    } catch (_) {
      return {
        'date': DateTime.now().toIso8601String(),
        'text': 'Belum ada data cukup untuk insight hari ini.',
      };
    } finally {
      if (ownsDb) await dbase.close();
    }
  }

  static List<Map<String, dynamic>> _parseItems(dynamic tx) {
    if (tx is! Map<String, dynamic>) return [];
    final raw = tx['items'];
    if (raw == null) return [];
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList();
    }
    try {
      final decoded = jsonDecode(raw as String);
      return (decoded as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }

  static String _fmt(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }
}

/// Background task handler — dipanggil dari stokCallbackDispatcher.
/// Public supaya bisa dipanggil lintas library (stok_alert_worker.dart).
Future<void> runAiInsight(AppDatabase db) async {
  // Pakai koneksi yang dikirim dispatcher (jangan buka baru) supaya tidak
  // ada drift connection bocor di background isolate.
  final data = await AiInsightWorker.buildInsight(db: db);
  final text = data['text'] as String? ?? '';
  if (text.isEmpty) return;

  await NotificationService.add(
    id: 'ai-insight-${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}',
    type: 'insight',
    title: '🤖 AI Insight — Rangkuman Hari Ini',
    body: text,
    showAlert: true,
    route: '/dashboard',
  );
}

/// Register periodic task (09:00 setiap hari + fallback interval 6 jam kalau
/// Android menunda). Dipanggil saat app start.
Future<void> registerAiInsightCheck() async {
  try {
    // Android: min periodic 15 menit; kita minta interval panjang supaya
    // baterai hemat, tapi tetap jalan meski app tertutup (best effort).
    await Workmanager().registerPeriodicTask(
      aiInsightTaskName,
      aiInsightTaskName,
      frequency: const Duration(hours: 6),
      initialDelay: const Duration(minutes: 5),
      constraints: Constraints(),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  } catch (_) {
    // ignore — non-fatal
  }
}

Future<void> cancelAiInsightCheck() async {
  await Workmanager().cancelByUniqueName(aiInsightTaskName);
}
