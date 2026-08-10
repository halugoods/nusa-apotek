import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables.dart';
part 'app_database.g.dart';

@DriftDatabase(tables: [Categories, Products, StockMovements, Transactions, Customers, Promos,
  Employees, Attendance, Expenses, ExpenseCategories, RecurringExpenses, Payroll, Waste,
  Liquidity, Suppliers, Branches, Settings, ActivationsLocal, SyncQueue, CashierSessions,
  OnlineOrders, CustomerDebts, DebtPayments, StockCounts, StockCountItems, ChatSessions,
  DiningTables, LaundryOrders, ServiceTickets, Appointments, Prescriptions, PrintOrders, OpenTabs])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.test() : super(NativeDatabase.memory());
  @override
  int get schemaVersion => 31;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(cashierSessions);
      }
      if (from < 3) {
        await m.addColumn(attendance, attendance.finalCash);
      }
      if (from < 4) {
        await m.addColumn(products, products.isOnline);
        await m.createTable(onlineOrders);
      }
      if (from < 5) {
        await m.addColumn(transactions, transactions.status);
        await m.addColumn(transactions, transactions.voidReason);
        await m.addColumn(transactions, transactions.voidedAt);
      }
      if (from < 6) {
        await m.addColumn(settings, settings.posGridColumns);
        await m.addColumn(settings, settings.bankName);
        await m.addColumn(settings, settings.bankAccount);
        await m.addColumn(settings, settings.bankHolder);
      }
      if (from < 7) {
        await m.addColumn(products, products.expiryDate);
        await m.addColumn(products, products.productType);
      }
      if (from < 8) {
        await m.addColumn(products, products.variantsJson);
        await m.addColumn(products, products.wholesaleJson);
      }
      if (from < 9) {
        await m.createTable(categories);
      }
      if (from < 10) {
        await m.addColumn(settings, settings.receiptFooter);
        await m.addColumn(settings, settings.storeLogoPath);
      }
      if (from < 11) {
        await m.addColumn(settings, settings.waTemplates);
        await m.addColumn(settings, settings.pointsPerRupiah);
        await m.addColumn(settings, settings.silverThreshold);
        await m.addColumn(settings, settings.goldThreshold);
        await m.addColumn(settings, settings.platinumThreshold);
      }
      if (from < 12) {
        await m.addColumn(employees, employees.phone);
        await m.addColumn(attendance, attendance.status);
      }
      if (from < 13) {
        await m.addColumn(employees, employees.photoPath);
        await m.addColumn(employees, employees.baseSalary);
        await m.addColumn(employees, employees.startDate);
      }
      if (from < 14) {
        await m.addColumn(expenses, expenses.branchId);
        await m.addColumn(liquidity, liquidity.branchId);
        await m.createTable(expenseCategories);
        await m.createTable(recurringExpenses);
      }
      if (from < 15) {
        await m.createTable(customerDebts);
        await m.createTable(debtPayments);
      }
      if (from < 16) {
        // ShiftSessions was added in v16 but has been removed & merged into Presensi
        // (columns now in attendance table via v18 migration below)
      }
      if (from < 17) {
        await m.createTable(stockCounts);
        await m.createTable(stockCountItems);
      }
      if (from < 18) {
        await m.addColumn(attendance, attendance.expectedCash);
        await m.addColumn(attendance, attendance.shiftNotes);
      }
      if (from < 19) {
        await m.addColumn(branches, branches.address);
        await m.addColumn(branches, branches.phone);
        await m.addColumn(branches, branches.status);
        await m.addColumn(settings, settings.qrisImagePath);
        await m.addColumn(settings, settings.receiptHeader);
        await m.addColumn(settings, settings.receiptPaperSize);
        await m.addColumn(settings, settings.receiptShowLogo);
        await m.addColumn(settings, settings.receiptShowCashier);
        await m.addColumn(settings, settings.receiptShowInvoice);
        await m.addColumn(settings, settings.receiptShowDate);
        await m.addColumn(settings, settings.receiptShowBarcode);
      }
      if (from < 20) {
        await m.addColumn(employees, employees.nfcTag);
      }
      if (from < 21) {
        await m.addColumn(settings, settings.pinLength);
      }
      if (from < 22) {
        await m.addColumn(employees, employees.workStart);
        await m.addColumn(employees, employees.workEnd);
      }
      if (from < 23) {
        await m.createTable(chatSessions);
      }
      if (from < 24) {
        await m.createTable(diningTables);
        await m.createTable(laundryOrders);
        await m.createTable(serviceTickets);
        await m.createTable(appointments);
        await m.createTable(prescriptions);
        await m.createTable(printOrders);
      }
      if (from < 25) {
        await m.addColumn(employees, employees.requiresAttendance);
      }
      if (from < 26) {
        await m.addColumn(employees, employees.requiresCashOpen);
        await m.addColumn(employees, employees.requiresCashClose);
      }
      if (from < 27) {
        await m.addColumn(transactions, transactions.orderType);
        await m.addColumn(transactions, transactions.tableId);
        await m.addColumn(transactions, transactions.notes);
        await m.addColumn(settings, settings.kitchenPrinterAddress);
        await m.addColumn(settings, settings.kitchenPrinterEnabled);
        await m.createTable(openTabs);
      }
      if (from < 28) {
        await m.addColumn(laundryOrders, laundryOrders.estimatedReady);
      }
      if (from < 29) {
        await m.addColumn(products, products.priceType);
      }
      if (from < 30) {
        await m.addColumn(appointments, appointments.estimatedDuration);
        await m.addColumn(appointments, appointments.counterId);
      }
      if (from < 31) {
        await m.addColumn(serviceTickets, serviceTickets.plateNumber);
        await m.addColumn(serviceTickets, serviceTickets.vehicleBrand);
        await m.addColumn(serviceTickets, serviceTickets.vehicleYear);
        await m.addColumn(serviceTickets, serviceTickets.technician);
        await m.addColumn(serviceTickets, serviceTickets.sparepartCost);
        await m.addColumn(serviceTickets, serviceTickets.serviceCost);
        await m.addColumn(serviceTickets, serviceTickets.queueNumber);
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = p.join(dir.path, 'nusa_kasir.sqlite');
    return NativeDatabase.createInBackground(File(file));
  });
}
