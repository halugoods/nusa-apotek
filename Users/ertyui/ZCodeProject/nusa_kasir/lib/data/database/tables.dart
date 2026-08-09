import 'package:drift/drift.dart';

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get sku => text().nullable()();
  TextColumn get barcode => text().nullable()();
  TextColumn get category => text().withDefault(const Constant('Lainnya'))();
  IntColumn get buyPrice => integer().withDefault(const Constant(0))();
  IntColumn get sellPrice => integer()();
  IntColumn get stock => integer().withDefault(const Constant(0))();
  IntColumn get minStock => integer().withDefault(const Constant(0))();
  TextColumn get imagePath => text().nullable()();
  BoolColumn get isOnline => boolean().withDefault(const Constant(false))();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  TextColumn get productType => text().nullable()();
  TextColumn get variantsJson => text().nullable()();   // JSON array: [{name,priceAdjustment,stock}]
  TextColumn get wholesaleJson => text().nullable()();  // JSON array: [{minQty,price}]
  TextColumn get priceType => text().withDefault(const Constant('pcs'))(); // 'pcs' or 'kg'
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer()();
  TextColumn get type => text()();
  IntColumn get qty => integer()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
}
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invoice => text()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get items => text()();
  IntColumn get total => integer().withDefault(const Constant(0))();
  IntColumn get discount => integer().withDefault(const Constant(0))();
  TextColumn get paymentMethod => text().withDefault(const Constant('tunai'))();
  IntColumn get customerId => integer().nullable()();
  IntColumn get cashGiven => integer().nullable()();
  IntColumn get cashReturn => integer().nullable()();
  TextColumn get cashierName => text().nullable()();
  IntColumn get branchId => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('Normal'))();
  TextColumn get voidReason => text().nullable()();
  DateTimeColumn get voidedAt => dateTime().nullable()();
  // FnB: order type, table link, notes
  TextColumn get orderType => text().nullable()();
  IntColumn get tableId => integer().nullable()();
  TextColumn get notes => text().nullable()();
}
class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  IntColumn get points => integer().withDefault(const Constant(0))();
  IntColumn get totalSpent => integer().withDefault(const Constant(0))();
  TextColumn get level => text().withDefault(const Constant('Silver'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
class Promos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get code => text()();
  TextColumn get type => text()();
  IntColumn get value => integer()();
  IntColumn get minBelanja => integer().withDefault(const Constant(0))();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
  IntColumn get maxUses => integer().nullable()();
  IntColumn get usedCount => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('Aktif'))();
}
class Employees extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get pin => text()();
  TextColumn get role => text()();
  IntColumn get branchId => integer().nullable()();
  TextColumn get status => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  IntColumn get baseSalary => integer().nullable()();
  DateTimeColumn get startDate => dateTime().nullable()();
  TextColumn get nfcTag => text().nullable()();   // NFC tag hash for tap-to-login
  TextColumn get workStart => text().nullable()(); // "HH:mm" default "08:00"
  TextColumn get workEnd => text().nullable()();   // "HH:mm" default "17:00"
  BoolColumn get requiresAttendance => boolean().withDefault(const Constant(false))();
  BoolColumn get requiresCashOpen => boolean().withDefault(const Constant(false))();
  BoolColumn get requiresCashClose => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
class Attendance extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get employeeId => integer()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get checkIn => text().nullable()();
  TextColumn get checkOut => text().nullable()();
  IntColumn get pettyCash => integer().nullable()();
  IntColumn get finalCash => integer().nullable()();
  TextColumn get status => text().nullable()();
  IntColumn get expectedCash => integer().nullable()();
  TextColumn get shiftNotes => text().nullable()();
}
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get category => text()();
  TextColumn get description => text()();
  IntColumn get amount => integer()();
  IntColumn get branchId => integer().nullable()();
}
class ExpenseCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
}
class RecurringExpenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get category => text()();
  IntColumn get amount => integer()();
  TextColumn get description => text()();
  TextColumn get frequency => text()(); // harian, mingguan, bulanan
  DateTimeColumn get nextDate => dateTime()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}
class Payroll extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get employeeId => integer()();
  TextColumn get period => text()();
  IntColumn get salary => integer()();
  IntColumn get bonus => integer().withDefault(const Constant(0))();
  IntColumn get deduction => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get status => text().withDefault(const Constant('Pending'))();
}
class Waste extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer()();
  IntColumn get qty => integer()();
  TextColumn get reason => text().nullable()();
  TextColumn get type => text().withDefault(const Constant('Expired'))();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
}
class Liquidity extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get type => text()();
  TextColumn get category => text()();
  TextColumn get description => text()();
  IntColumn get amount => integer()();
  TextColumn get method => text().nullable()();
  IntColumn get branchId => integer().nullable()();
}
class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get contactPerson => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
class Branches extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('Aktif'))();
}
class Settings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get storeName => text().withDefault(const Constant(''))();
  TextColumn get storeAddress => text().nullable()();
  TextColumn get storePhone => text().nullable()();
  TextColumn get posPrefix => text().nullable()();
  IntColumn get trxCounter => integer().withDefault(const Constant(0))();
  IntColumn get minStockAlert => integer().withDefault(const Constant(0))();
  TextColumn get qrisString => text().nullable()();
  TextColumn get themeMode => text().nullable()();
  IntColumn get posGridColumns => integer().withDefault(const Constant(2))();
  TextColumn get bankName => text().nullable()();
  TextColumn get bankAccount => text().nullable()();
  TextColumn get bankHolder => text().nullable()();
  TextColumn get receiptFooter => text().nullable()();
  TextColumn get storeLogoPath => text().nullable()();
  // ── WA Templates (JSON array of {name, body}) ──
  TextColumn get waTemplates => text().nullable()();
  // ── Point system config ──
  IntColumn get pointsPerRupiah => integer().withDefault(const Constant(100))();
  IntColumn get silverThreshold => integer().withDefault(const Constant(0))();
  IntColumn get goldThreshold => integer().withDefault(const Constant(1000))();
  IntColumn get platinumThreshold => integer().withDefault(const Constant(5000))();
  // ── QRIS image (replaces qrisString) ──
  TextColumn get qrisImagePath => text().nullable()();
  // ── Receipt advanced ──
  TextColumn get receiptHeader => text().nullable()();
  TextColumn get receiptPaperSize => text().withDefault(const Constant('58mm'))();
  IntColumn get pinLength => integer().withDefault(const Constant(6))();
  BoolColumn get receiptShowLogo => boolean().withDefault(const Constant(true))();
  BoolColumn get receiptShowCashier => boolean().withDefault(const Constant(true))();
  BoolColumn get receiptShowInvoice => boolean().withDefault(const Constant(true))();
  BoolColumn get receiptShowDate => boolean().withDefault(const Constant(true))();
  BoolColumn get receiptShowBarcode => boolean().withDefault(const Constant(false))();
  // ── Kitchen printer (FnB) ──
  TextColumn get kitchenPrinterAddress => text().nullable()();
  BoolColumn get kitchenPrinterEnabled => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
}
class ActivationsLocal extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get key => text()();
  TextColumn get deviceId => text()();
  DateTimeColumn get activatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get status => text().withDefault(const Constant('active'))();
}
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get taskType => text()();
  TextColumn get payload => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
class CashierSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get employeeId => integer()();
  DateTimeColumn get openedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get closedAt => dateTime().nullable()();
  IntColumn get startingCash => integer().withDefault(const Constant(0))();
  IntColumn get branchId => integer().nullable()();
}
class OnlineOrders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invoice => text()();
  TextColumn get customerName => text()();
  TextColumn get customerPhone => text()();
  TextColumn get items => text()();  // JSON string
  IntColumn get subtotal => integer().withDefault(const Constant(0))();
  IntColumn get discount => integer().withDefault(const Constant(0))();
  IntColumn get handlingFee => integer().withDefault(const Constant(0))();
  IntColumn get total => integer()();
  TextColumn get paymentMethod => text().withDefault(const Constant('Tunai'))();
  TextColumn get pickupTime => text().nullable()();
  TextColumn get branch => text().withDefault(const Constant('Pusat'))();
  TextColumn get notes => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('Online Baru'))();
  TextColumn get processedBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
class CustomerDebts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer()();
  TextColumn get customerName => text()(); // denormalized
  IntColumn get amount => integer()(); // total utang
  IntColumn get remainingAmount => integer()(); // sisa yg belum dibayar
  TextColumn get description => text().nullable()();
  DateTimeColumn get debtDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('Belum Lunas'))(); // Belum Lunas | Lunas
}
class DebtPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get debtId => integer()();
  IntColumn get amount => integer()();
  TextColumn get method => text().withDefault(const Constant('Tunai'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get paidAt => dateTime().withDefault(currentDateAndTime)();
}
class StockCounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('Draft'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get totalProducts => integer().withDefault(const Constant(0))();
  IntColumn get matchCount => integer().withDefault(const Constant(0))();
  IntColumn get diffCount => integer().withDefault(const Constant(0))();
}
class StockCountItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get countSessionId => integer()();
  IntColumn get productId => integer()();
  TextColumn get productName => text()();
  IntColumn get systemStock => integer()();
  IntColumn get physicalStock => integer().nullable()();
  IntColumn get difference => integer().withDefault(const Constant(0))();
  IntColumn get buyPrice => integer().withDefault(const Constant(0))();
  IntColumn get sellPrice => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
}

/// AI chat session history — stored locally with message JSON + metadata.
class ChatSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();           // auto-generated from first message
  TextColumn get messagesJson => text()();    // JSON array of {role, content}
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// ── Domain feature tables ────────────────────────────────────────────────

/// F&B: Dining table management.
class DiningTables extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get capacity => integer().withDefault(const Constant(4))();
  TextColumn get status => text().withDefault(const Constant('Kosong'))(); // Kosong | Dipesan | Tutup
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Laundry: Order tracking through wash-iron-deliver stages.
class LaundryOrders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get customerName => text()();
  TextColumn get customerPhone => text().nullable()();
  TextColumn get itemsJson => text()();       // JSON [{name,qty,price}]
  IntColumn get total => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('Baru'))();
    // Baru | Cuci | Kering | Setrika | Siap | Diantar | Diambil
  TextColumn get notes => text().nullable()();
  DateTimeColumn get estimatedReady => dateTime().nullable()(); // estimasi selesai
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Bengkel & Servis: Service ticket management.
class ServiceTickets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get customerName => text()();
  TextColumn get customerPhone => text().nullable()();
  TextColumn get deviceName => text()();
  TextColumn get issue => text()();
  IntColumn get estimatedCost => integer().withDefault(const Constant(0))();
  IntColumn get finalCost => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('Diagnosa'))();
    // Diagnosa | Estimasi | Perbaikan | Selesai | Diambil
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Salon: Appointment booking with stylist + time slot.
class Appointments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get customerName => text()();
  TextColumn get customerPhone => text().nullable()();
  TextColumn get service => text()();         // e.g. Haircut, Coloring
  TextColumn get stylist => text().nullable()();
  DateTimeColumn get date => dateTime()();
  TextColumn get timeSlot => text()();        // "HH:mm"
  TextColumn get status => text().withDefault(const Constant('Dikonfirmasi'))();
    // Dikonfirmasi | Menunggu | Selesai | Batal
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Apotek: Prescription management.
class Prescriptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get patientName => text()();
  TextColumn get doctorName => text().nullable()();
  TextColumn get itemsJson => text()();
  TextColumn get dosage => text().nullable()();
  IntColumn get total => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('Baru'))();
    // Baru | Diproses | Siap | Diambil
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Fotocopy: Print/copy order management.
class PrintOrders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get customerName => text()();
  TextColumn get customerPhone => text().nullable()();
  TextColumn get serviceType => text()();
    // Fotocopy | Print Warna | Print B/W | Jilid | Laminating | Scan
  IntColumn get pages => integer().withDefault(const Constant(0))();
  IntColumn get copies => integer().withDefault(const Constant(1))();
  TextColumn get paperSize => text().withDefault(const Constant('A4'))();
  IntColumn get total => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('Baru'))();
    // Baru | Diproses | Selesai | Diambil
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// FnB: Open tabs — saved orders that can be resumed later.
class OpenTabs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tableId => integer().nullable()();
  TextColumn get orderType => text().withDefault(const Constant('Dine In'))();
  TextColumn get itemsJson => text()();
  IntColumn get total => integer().withDefault(const Constant(0))();
  IntColumn get discount => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('Open'))();
    // Open | Completed | Void
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
