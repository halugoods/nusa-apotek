import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

class ReportRepository {
  final AppDatabase db;
  ReportRepository(this.db);

  Future<List<Transaction>> getTransactions({
    DateTime? from,
    DateTime? to,
    int? branchId,
    int? employeeId,
  }) async {
    final q = db.select(db.transactions)
      ..where((t) => t.status.equals('Normal'));
    if (branchId != null) {
      q.where((t) => t.branchId.equals(branchId));
    }
    if (employeeId != null) {
      // Cashier scoping: own sales + shared online orders (employeeId null).
      q.where((t) =>
          t.employeeId.equals(employeeId) |
          t.employeeId.isNull());
    }
    if (from != null || to != null) {
      q.where((t) {
        final conds = <Expression<bool>>[];
        // Inclusive day-boundary filter: `from` (00:00:00) .. `to` end-of-day
        // (23:59:59.999). Previously the bounds were widened by ±1 day, which
        // made "Hari ini" bleed into yesterday's transactions.
        if (from != null) {
          conds.add(
            t.date.isBiggerOrEqual(Constant(DateTime(from.year, from.month, from.day))),
          );
        }
        if (to != null) {
          conds.add(
            t.date.isSmallerOrEqual(Constant(DateTime(to.year, to.month, to.day, 23, 59, 59))),
          );
        }
        return conds.reduce((a, b) => a & b);
      });
    }
    q.orderBy([
      (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
    ]);
    return q.get();
  }

  /// Returns summary stats for a period.
  /// Keys: omzet (int, sudah dikurangi retur), count (int), avg (int),
  ///       items (List<Transaction>).
  /// When [employeeId] is set, only transactions attributed to that employee
  /// (plus shared online orders with null employeeId) are counted.
  Future<Map<String, dynamic>> summary({
    DateTime? from,
    DateTime? to,
    int? branchId,
    int? employeeId,
  }) async {
    final list = await getTransactions(
        from: from, to: to, branchId: branchId, employeeId: employeeId);
    // Retur parsial mengurangi omzet: uang yang sudah dikembalikan ke
    // pelanggan bukan lagi pendapatan. Refund dicatat per employee yang
    // memproses — jadi untuk scoping kasir dipakai employeeId refund-nya.
    final refunds = await _refundsFor(
        from: from, to: to, branchId: branchId, employeeId: employeeId);
    final refundTotal = refunds.fold(0, (int s, r) => s + r.refundAmount);
    final omzet =
        list.fold(0, (int sum, t) => sum + t.total) - refundTotal;
    final count = list.length;
    final avg = count == 0 ? 0 : (omzet / count).round();
    return {'omzet': omzet, 'count': count, 'avg': avg, 'items': list};
  }

  /// Full Profit & Loss (Laba Rugi) for a date range.
  /// Returns a map with all line items.
  Future<Map<String, dynamic>> profitLoss({
    DateTime? from,
    DateTime? to,
    int? branchId,
  }) async {
    // ── Revenue (pendapatan) ──────────────────────────────────────
    final txList = await getTransactions(
      from: from,
      to: to,
      branchId: branchId,
    );
    final normalTx = txList.where((t) => t.status == 'Normal');
    final pendapatan = normalTx.fold(0, (int s, t) => s + t.total);

    // ── HPP (Harga Pokok Penjualan) ───────────────────────────────
    int hpp = 0;
    // Collect all product IDs to batch-lookup buy prices
    final productIds = <int>{};
    for (final tx in normalTx) {
      final items = _parseItems(tx.items);
      for (final it in items) {
        final pid = it['productId'] as int?;
        if (pid != null && pid >= 0) productIds.add(pid);
      }
    }
    // Batch lookup
    final products = await (db.select(
      db.products,
    )..where((p) => p.id.isIn(productIds))).get();
    final priceMap = {for (final p in products) p.id: p.buyPrice};

    for (final tx in normalTx) {
      final items = _parseItems(tx.items);
      for (final it in items) {
        final pid = it['productId'] as int?;
        final qty = it['qty'] as int? ?? 0;
        if (pid == null || qty <= 0) continue;
        if (pid < 0) {
          // Item manual (id negatif): HPP dari harga modal per item (costPrice),
          // bukan dari tabel produk. Tanpa costPrice → tidak menambah HPP.
          final cost = (it['costPrice'] as num?)?.toInt() ?? 0;
          hpp += cost * qty;
        } else {
          hpp += (priceMap[pid] ?? 0) * qty;
        }
      }
    }

    // ── Retur / Refund ─────────────────────────────────────────────
    // Uang yang dikembalikan ke pelanggan keluar dari pendapatan; barang
    // yang kembali ke toko juga keluar dari HPP (sudah tidak terjual).
    final refunds = await _refundsFor(from: from, to: to, branchId: branchId);
    final totalRetur = refunds.fold(0, (int s, r) => s + r.refundAmount);
    // HPP barang yang di-retur: pakai buyPrice produk saat ini — barang
    // kembali ke stok, jadi cost-nya kembali ke persediaan.
    int hppRetur = 0;
    for (final r in refunds) {
      if (r.productId == null) continue; // item manual: tidak ada HPP
      hppRetur += (priceMap[r.productId] ?? 0) * r.qty;
    }

    final pendapatanSetelahRetur = pendapatan - totalRetur;
    final hppSetelahRetur = hpp - hppRetur;
    final labaKotor = pendapatanSetelahRetur - hppSetelahRetur;

    // ── Expenses (pengeluaran) ────────────────────────────────────
    final expenses = await _filtered(
      db.select(db.expenses),
      from: from,
      to: to,
      branchId: branchId,
      branchIdOf: (e) => e.branchId,
    );
    final totalExpenses = expenses.fold(0, (int s, e) => s + e.amount);

    // ── Payroll ───────────────────────────────────────────────────
    final payroll = await _filtered(db.select(db.payroll), from: from, to: to);
    final totalPayroll = payroll.fold(
      0,
      (int s, p) => s + p.salary + p.bonus - p.deduction,
    );

    // ── Waste (loss from spoiled goods) ───────────────────────────
    final waste = await _filtered(db.select(db.waste), from: from, to: to);
    int totalWaste = 0;
    for (final w in waste) {
      final prod =
          priceMap[w.productId] ??
          (await (db.select(
                db.products,
              )..where((p) => p.id.equals(w.productId))).getSingleOrNull())
              ?.buyPrice ??
          0;
      totalWaste += prod * w.qty;
    }

    // ── Liquidity ─────────────────────────────────────────────────
    final liquidity = await _filtered(
      db.select(db.liquidity),
      from: from,
      to: to,
      branchId: branchId,
      branchIdOf: (l) => l.branchId,
    );
    final liquidityIn = liquidity
        .where((l) => l.type == 'in')
        .fold(0, (int s, l) => s + l.amount);
    final liquidityOut = liquidity
        .where((l) => l.type == 'out')
        .fold(0, (int s, l) => s + l.amount);

    // ── Totals ────────────────────────────────────────────────────
    final totalBeban = totalExpenses + totalPayroll + totalWaste + liquidityOut;
    final labaBersih = labaKotor - totalBeban + liquidityIn;

    return {
      'pendapatan': pendapatan,
      'hpp': hpp,
      'retur': totalRetur,
      'hppRetur': hppRetur,
      'labaKotor': labaKotor,
      'expenses': totalExpenses,
      'payroll': totalPayroll,
      'waste': totalWaste,
      'liquidityIn': liquidityIn,
      'liquidityOut': liquidityOut,
      'totalBeban': totalBeban,
      'labaBersih': labaBersih,
      'txCount': normalTx.length,
    };
  }

  /// Top-selling products (by quantity) for a period.
  /// Returns list of {id, name, category, qty, revenue}.
  Future<List<Map<String, dynamic>>> topProducts({
    DateTime? from,
    DateTime? to,
    int limit = 5,
    int? branchId,
  }) async {
    final agg = await _aggregateByProduct(
      from: from,
      to: to,
      branchId: branchId,
    );
    final list = agg.entries.map((e) {
      final p = e.value;
      return {
        'id': e.key,
        'name': p['name'] as String,
        'category': p['category'] as String,
        'qty': p['qty'] as int,
        'revenue': p['revenue'] as int,
      };
    }).toList();
    list.sort((a, b) => (b['qty'] as int).compareTo(a['qty'] as int));
    return list.take(limit).toList();
  }

  /// Daily revenue for bar chart.
  /// Returns Map where key is "YYYY-MM-DD" and value is total revenue.
  Future<Map<String, int>> dailyRevenue({
    DateTime? from,
    DateTime? to,
    int? branchId,
  }) async {
    final txs = await getTransactions(from: from, to: to, branchId: branchId);
    final byDay = <String, int>{};
    for (final t in txs) {
      final key =
          '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}';
      byDay[key] = (byDay[key] ?? 0) + t.total;
    }
    return byDay;
  }

  /// Sales grouped by category for a period.
  /// Returns list of {category, qty, revenue} sorted by revenue desc.
  Future<List<Map<String, dynamic>>> salesByCategory({
    DateTime? from,
    DateTime? to,
    int? branchId,
  }) async {
    final agg = await _aggregateByProduct(
      from: from,
      to: to,
      branchId: branchId,
    );
    final qtyByCat = <String, int>{};
    final revByCat = <String, int>{};
    for (final p in agg.values) {
      final cat = p['category'] as String;
      qtyByCat[cat] = (qtyByCat[cat] ?? 0) + (p['qty'] as int);
      revByCat[cat] = (revByCat[cat] ?? 0) + (p['revenue'] as int);
    }
    final cats = qtyByCat.keys.toList()
      ..sort((a, b) => (revByCat[b] ?? 0).compareTo(revByCat[a] ?? 0));
    return cats
        .map(
          (c) => {
            'category': c,
            'qty': qtyByCat[c] ?? 0,
            'revenue': revByCat[c] ?? 0,
          },
        )
        .toList();
  }

  /// Totals per payment method (Tunai / QRIS / Transfer / Lainnya).
  Future<Map<String, int>> salesByPaymentMethod({
    DateTime? from,
    DateTime? to,
    int? branchId,
  }) async {
    final txs = await getTransactions(from: from, to: to, branchId: branchId);
    final totals = <String, int>{};
    for (final t in txs) {
      final m = _normalizeMethod(t.paymentMethod);
      totals[m] = (totals[m] ?? 0) + t.total;
    }
    return totals;
  }

  /// Current summary vs the immediately-preceding equal-length period.
  /// Keys: omzet, count, avg, hasPrevious, prevOmzet, prevCount,
  ///       omzetGrowth (%), countGrowth (%).
  Future<Map<String, dynamic>> summaryWithPrevious(
    DateTime? from,
    DateTime? to, {
    int? branchId,
  }) async {
    final cur = await summary(from: from, to: to, branchId: branchId);
    Map<String, dynamic>? prev;
    var hasPrev = false;
    if (from != null && to != null) {
      final dur = to.difference(from);
      final prevTo = from.subtract(const Duration(days: 1));
      final prevFrom = prevTo.subtract(dur);
      prev = await summary(
        from: prevFrom,
        to: prevTo,
        branchId: branchId,
      );
      hasPrev = true;
    }
    final omzet = cur['omzet'] as int? ?? 0;
    final count = cur['count'] as int? ?? 0;
    final prevOmzet = prev?['omzet'] as int? ?? 0;
    final prevCount = prev?['count'] as int? ?? 0;
    final omzetGrowth = hasPrev && prevOmzet > 0
        ? (omzet - prevOmzet) / prevOmzet * 100
        : 0.0;
    final countGrowth = hasPrev && prevCount > 0
        ? (count - prevCount) / prevCount * 100
        : 0.0;
    return {
      'omzet': omzet,
      'count': count,
      'avg': cur['avg'],
      'hasPrevious': hasPrev,
      'prevOmzet': prevOmzet,
      'prevCount': prevCount,
      'omzetGrowth': omzetGrowth,
      'countGrowth': countGrowth,
    };
  }

  /// Aggregate quantity & revenue per product id, resolving name/category
  /// from the products table.
  Future<Map<int, Map<String, dynamic>>> _aggregateByProduct({
    DateTime? from,
    DateTime? to,
    int? branchId,
  }) async {
    final txs = await getTransactions(
      from: from,
      to: to,
      branchId: branchId,
    );
    final qtyById = <int, int>{};
    final revById = <int, int>{};
    final ids = <int>{};
    for (final t in txs) {
      for (final it in _parseItems(t.items)) {
        final pid = it['productId'] as int?;
        final qty = (it['qty'] as int?) ?? 0;
        final price = (it['price'] as num?)?.toInt() ?? 0;
        // Item manual (id negatif) tidak masuk agregat produk
        if (pid == null || pid < 0) continue;
        ids.add(pid);
        qtyById[pid] = (qtyById[pid] ?? 0) + qty;
        revById[pid] = (revById[pid] ?? 0) + qty * price;
      }
    }
    // Retur parsial mengurangi qty & revenue produk yang di-retur.
    final refunds = await _refundsFor(from: from, to: to, branchId: branchId);
    for (final r in refunds) {
      final pid = r.productId;
      if (pid == null || pid < 0) continue;
      ids.add(pid);
      qtyById[pid] = (qtyById[pid] ?? 0) - r.qty;
      revById[pid] = (revById[pid] ?? 0) - r.refundAmount;
    }
    final products = ids.isEmpty
        ? <Product>[]
        : await (db.select(db.products)..where((p) => p.id.isIn(ids))).get();
    final pmap = {for (final p in products) p.id: p};
    final out = <int, Map<String, dynamic>>{};
    for (final id in ids) {
      final p = pmap[id];
      out[id] = {
        'name': p?.name ?? 'Produk #$id',
        'category': p?.category ?? 'Lainnya',
        'qty': qtyById[id] ?? 0,
        'revenue': revById[id] ?? 0,
      };
    }
    return out;
  }

  /// Refunds scoped by period / branch / employee, for report subtraction.
  /// Mirrors `getTransactions` scoping: employeeId null = all, non-null =
  /// refunds processed by that employee + shared (branch-wide, null employee)
  /// refunds.
  Future<List<Refund>> _refundsFor({
    DateTime? from,
    DateTime? to,
    int? branchId,
    int? employeeId,
  }) async {
    var q = db.select(db.refunds);
    if (from != null || to != null) {
      q.where((r) {
        final conds = <Expression<bool>>[];
        if (from != null) {
          conds.add(r.date.isBiggerOrEqual(
              Constant(DateTime(from.year, from.month, from.day))));
        }
        if (to != null) {
          conds.add(r.date.isSmallerOrEqual(
              Constant(DateTime(to.year, to.month, to.day, 23, 59, 59))));
        }
        return conds.reduce((a, b) => a & b);
      });
    }
    if (branchId != null) {
      q.where((r) => r.branchId.equals(branchId));
    }
    if (employeeId != null) {
      // Refund diproses employee ini, plus retur bersama (employeeId null).
      q.where((r) => r.employeeId.equals(employeeId) | r.employeeId.isNull());
    }
    return q.get();
  }

  String _normalizeMethod(String? m) {
    final s = (m ?? '').toLowerCase();
    if (s.contains('qris')) return 'QRIS';
    if (s.contains('transfer')) return 'Transfer';
    if (s.contains('edc') || s.contains('kartu') || s.contains('debit') || s.contains('kredit')) {
      return 'Kartu';
    }
    if (s.contains('cash') || s.contains('tunai')) return 'Tunai';
    return m?.isNotEmpty == true ? m! : 'Lainnya';
  }

  List<Map<String, dynamic>> _parseItems(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Helper: apply date filter to a query.
  Future<List<T>> _filtered<T>(
    Selectable<T> query, {
    DateTime? from,
    DateTime? to,
    int? branchId,
    int? Function(T item)? branchIdOf,
  }) async {
    // We rely on the generated query being filtered by the caller
    // This is a simpler approach — fetch all then filter in Dart
    final list = await query.get();
    return list
        .where((item) {
          if (branchId != null &&
              branchIdOf != null &&
              branchIdOf(item) != branchId) {
            return false;
          }
          // Drift data classes have a `date` field convention — use dynamic
          final d = (item as dynamic).date as DateTime?;
          if (d == null) return true;
          if (from != null && d.isBefore(DateTime(from.year, from.month, from.day)))
            return false;
          if (to != null &&
              d.isAfter(DateTime(to.year, to.month, to.day, 23, 59, 59)))
            return false;
          return true;
        })
        .toList()
        .cast<T>();
  }
}
