import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

/// Stylist/stylist performance & commission reports (v2.2.57).
///
/// Salon variant only. Computes on-the-fly from `appointments` joined with
/// `transactions` and `employees` — no separate commission table, so the
/// numbers always match what really happened (cannot drift).
///
/// Money is stored in IDR integer (rupiah). Commission rate is stored as
/// `commission_percent` REAL on employees (default 10).
class StylistReportRepository {
  final AppDatabase db;
  StylistReportRepository(this.db);

  /// Kinerja Stylist dalam periode [start, end).
  ///
  /// Omset per stylist dihitung proporsional: kalau 1 transaksi punya 2
  /// appointment dengan stylist berbeda, masing-masing dapat setengah dari
  /// total transaksi. Tanpa data appointment.stylistId, transaksi tidak
  /// dihitung (owner bisa pakai laporan Penjualan reguler).
  Future<List<StylistSummary>> kinerja({
    required DateTime start,
    required DateTime end,
  }) async {
    final apts = await (db.select(db.appointments)
          ..where((t) => t.transactionId.isNotNull()))
        .get();
    final txIds = apts.map((a) => a.transactionId!).toSet();
    if (txIds.isEmpty) return const [];

    final txs = await (db.select(db.transactions)
          ..where(
            (t) =>
                t.id.isIn(txIds.toList()) &
                t.date.isBetweenValues(start, end) &
                t.status.equals('Normal'),
          ))
        .get();

    // Map transactionId -> total
    final txTotal = <int, int>{
      for (final t in txs) t.id: t.total,
    };

    // Map transactionId -> appointment count (for proportional split)
    final txAptCount = <int, int>{};
    for (final a in apts) {
      final tid = a.transactionId;
      if (tid == null || !txTotal.containsKey(tid)) continue;
      txAptCount[tid] = (txAptCount[tid] ?? 0) + 1;
    }

    // Load all service-staff once
    final staff = await (db.select(db.employees)
          ..where((e) => e.isServiceStaff.equals(true)))
        .get();

    final byEmp = <int, _Acc>{};
    for (final a in apts) {
      final sid = a.stylistId;
      if (sid == null) continue;
      final tid = a.transactionId;
      if (tid == null || !txTotal.containsKey(tid)) continue;
      final share = txTotal[tid]! / txAptCount[tid]!;
      final acc = byEmp.putIfAbsent(sid, () => _Acc());
      acc.omset += share;
      acc.appointments += 1;
      acc.transactions.add(tid);
    }

    final result = <StylistSummary>[];
    for (final emp in staff) {
      final acc = byEmp[emp.id];
      if (acc == null) continue;
      final pct = emp.commissionPercent;
      result.add(
        StylistSummary(
          employeeId: emp.id,
          name: emp.name,
          commissionPercent: pct,
          trxCount: acc.transactions.length,
          appointmentCount: acc.appointments,
          totalOmset: acc.omset.round(),
          totalKomisi: (acc.omset * pct / 100).round(),
        ),
      );
    }
    result.sort((a, b) => b.totalOmset.compareTo(a.totalOmset));
    return result;
  }

  /// Drilldown per stylist — list transaksi (dengan porsi omset & komisi)
  /// yang dia handle dalam periode.
  Future<List<StylistTransaction>> detail({
    required int employeeId,
    required DateTime start,
    required DateTime end,
  }) async {
    final apts = await (db.select(db.appointments)
          ..where((t) =>
              t.stylistId.equals(employeeId) & t.transactionId.isNotNull()))
        .get();
    if (apts.isEmpty) return const [];

    final txIds = apts.map((a) => a.transactionId!).toSet();
    final txs = await (db.select(db.transactions)
          ..where(
            (t) =>
                t.id.isIn(txIds.toList()) &
                t.date.isBetweenValues(start, end) &
                t.status.equals('Normal'),
          ))
        .get();
    final txById = {for (final t in txs) t.id: t};

    final txAptCount = <int, int>{};
    for (final a in apts) {
      final tid = a.transactionId;
      if (tid == null) continue;
      txAptCount[tid] = (txAptCount[tid] ?? 0) + 1;
    }

    final emp = await (db.select(db.employees)
          ..where((e) => e.id.equals(employeeId)))
        .getSingleOrNull();
    final pct = emp?.commissionPercent ?? 10.0;

    final result = <StylistTransaction>[];
    for (final a in apts) {
      final tid = a.transactionId;
      if (tid == null) continue;
      final t = txById[tid];
      if (t == null) continue;
      final share = t.total / (txAptCount[tid] ?? 1);
      result.add(
        StylistTransaction(
          appointmentId: a.id,
          transactionId: t.id,
          date: t.date,
          invoice: t.invoice,
          service: a.service,
          customerName: a.customerName,
          transactionTotal: t.total,
          omsetShare: share.round(),
          komisi: (share * pct / 100).round(),
        ),
      );
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  /// Total komisi kumulatif seorang stylist (untuk "Pendapatan Saya").
  Future<StylistEarnings> myEarnings({
    required int employeeId,
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await detail(
      employeeId: employeeId,
      start: start,
      end: end,
    );
    final omset = rows.fold<int>(0, (sum, e) => sum + e.omsetShare);
    final komisi = rows.fold<int>(0, (sum, e) => sum + e.komisi);
    return StylistEarnings(
      employeeId: employeeId,
      omset: omset,
      komisi: komisi,
      trxCount: rows.length,
    );
  }
}

class _Acc {
  double omset = 0;
  int appointments = 0;
  final Set<int> transactions = <int>{};
}

class StylistSummary {
  final int employeeId;
  final String name;
  final double commissionPercent;
  final int trxCount;
  final int appointmentCount;
  final int totalOmset;
  final int totalKomisi;

  StylistSummary({
    required this.employeeId,
    required this.name,
    required this.commissionPercent,
    required this.trxCount,
    required this.appointmentCount,
    required this.totalOmset,
    required this.totalKomisi,
  });
}

class StylistTransaction {
  final int appointmentId;
  final int transactionId;
  final DateTime date;
  final String invoice;
  final String service;
  final String customerName;
  final int transactionTotal;
  final int omsetShare;
  final int komisi;

  StylistTransaction({
    required this.appointmentId,
    required this.transactionId,
    required this.date,
    required this.invoice,
    required this.service,
    required this.customerName,
    required this.transactionTotal,
    required this.omsetShare,
    required this.komisi,
  });
}

class StylistEarnings {
  final int employeeId;
  final int omset;
  final int komisi;
  final int trxCount;
  StylistEarnings({
    required this.employeeId,
    required this.omset,
    required this.komisi,
    required this.trxCount,
  });
}
