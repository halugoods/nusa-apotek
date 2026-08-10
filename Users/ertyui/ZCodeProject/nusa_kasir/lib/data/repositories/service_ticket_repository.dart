import 'package:drift/drift.dart';
import 'package:nusa_kasir/data/database/app_database.dart';

class ServiceTicketRepository {
  final AppDatabase db;
  ServiceTicketRepository(this.db);

  Future<int> add({
    required String customerName,
    String? customerPhone,
    required String deviceName,
    required String issue,
    int estimatedCost = 0,
    String? notes,
    // ── Bengkel (vehicle workshop) fields ──
    String? plateNumber,
    String? vehicleBrand,
    int? vehicleYear,
    String? technician,
    int sparepartCost = 0,
    int serviceCost = 0,
    int? queueNumber,
  }) =>
      db.into(db.serviceTickets).insert(ServiceTicketsCompanion.insert(
            customerName: customerName,
            customerPhone: Value(customerPhone),
            deviceName: deviceName,
            issue: issue,
            estimatedCost: Value(estimatedCost),
            notes: Value(notes),
            plateNumber: Value(plateNumber),
            vehicleBrand: Value(vehicleBrand),
            vehicleYear: Value(vehicleYear),
            technician: Value(technician),
            sparepartCost: Value(sparepartCost),
            serviceCost: Value(serviceCost),
            queueNumber: Value(queueNumber),
          ));

  Future<List<ServiceTicket>> getAll() =>
      (db.select(db.serviceTickets)
            ..orderBy([(t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc)]))
          .get();

  Future<ServiceTicket?> byId(int id) =>
      (db.select(db.serviceTickets)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> updateStatus(int id, String status) =>
      (db.update(db.serviceTickets)..where((t) => t.id.equals(id)))
          .write(ServiceTicketsCompanion(status: Value(status)));

  Future<void> updateCost(
    int id, {
    int? finalCost,
    String? notes,
    // ── Bengkel fields ──
    String? customerName,
    String? customerPhone,
    String? deviceName,
    String? issue,
    int? estimatedCost,
    String? plateNumber,
    String? vehicleBrand,
    int? vehicleYear,
    String? technician,
    int? sparepartCost,
    int? serviceCost,
  }) async {
    var c = const ServiceTicketsCompanion();
    if (finalCost != null) c = c.copyWith(finalCost: Value(finalCost));
    if (notes != null) c = c.copyWith(notes: Value(notes));
    // ── Bengkel fields ──
    if (customerName != null) c = c.copyWith(customerName: Value(customerName));
    if (customerPhone != null) c = c.copyWith(customerPhone: Value(customerPhone));
    if (deviceName != null) c = c.copyWith(deviceName: Value(deviceName));
    if (issue != null) c = c.copyWith(issue: Value(issue));
    if (estimatedCost != null) c = c.copyWith(estimatedCost: Value(estimatedCost));
    if (plateNumber != null) c = c.copyWith(plateNumber: Value(plateNumber));
    if (vehicleBrand != null) c = c.copyWith(vehicleBrand: Value(vehicleBrand));
    if (vehicleYear != null) c = c.copyWith(vehicleYear: Value(vehicleYear));
    if (technician != null) c = c.copyWith(technician: Value(technician));
    if (sparepartCost != null) c = c.copyWith(sparepartCost: Value(sparepartCost));
    if (serviceCost != null) c = c.copyWith(serviceCost: Value(serviceCost));
    await (db.update(db.serviceTickets)..where((t) => t.id.equals(id))).write(c);
  }

  Future<int> countByStatus(String status) async {
    final rows = await (db.select(db.serviceTickets)
          ..where((t) => t.status.equals(status)))
        .get();
    return rows.length;
  }

  /// Count of service tickets created today.
  Future<int> countToday() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final rows = await (db.select(db.serviceTickets)
          ..where((t) => t.createdAt.isBiggerOrEqualValue(start) & t.createdAt.isSmallerThanValue(end)))
        .get();
    return rows.length;
  }

  /// Sum of a cost column filtered by status (for dashboard stats).
  Future<int> sumByStatus(String status, {required int Function(ServiceTicket) costOf}) async {
    final rows = await (db.select(db.serviceTickets)
          ..where((t) => t.status.equals(status)))
        .get();
    var sum = 0;
    for (final t in rows) {
      sum += costOf(t);
    }
    return sum;
  }

  /// Next queue number for today (like salon counter).
  Future<int> getNextQueue() async {
    final today = await _todayTickets();
    return today.length + 1;
  }

  /// All technicians currently assigned to tickets (for filter dropdown).
  Future<List<String>> getTechnicians() async {
    final rows = await db.select(db.serviceTickets).get();
    final names = <String>{};
    for (final t in rows) {
      final n = t.technician?.trim();
      if (n != null && n.isNotEmpty) names.add(n);
    }
    return names.toList()..sort();
  }

  Future<int> countPending() async {
    final rows = await (db.select(db.serviceTickets)
          ..where((t) => t.status.equals('Diambil').not()))
        .get();
    return rows.length;
  }

  Future<void> delete(int id) =>
      (db.delete(db.serviceTickets)..where((t) => t.id.equals(id))).go();

  Future<List<ServiceTicket>> _todayTickets() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return (db.select(db.serviceTickets)
          ..where((t) => t.createdAt.isBiggerOrEqualValue(start) & t.createdAt.isSmallerThanValue(end)))
        .get();
  }
}
