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
  IntColumn get discountPercent => integer().withDefault(const Constant(0))();
  // 'persen' (default, legacy) | 'nominal' — diskon dalam bentuk uang (Rp) langsung
  TextColumn get discountType => text().withDefault(const Constant('persen'))();
  IntColumn get stock => integer().withDefault(const Constant(0))();
  IntColumn get minStock => integer().withDefault(const Constant(0))();
  TextColumn get imagePath => text().nullable()();
  // v2.2.44 (B1): foto produk sebagai BASE64 — ikut backup/restore cloud
  // (imagePath hanya path lokal yang tidak ikut cloud).
  TextColumn get imageBase64 => text().nullable()();
  // v2.2.44 (B10): true = produk bertipe jasa/layanan (tanpa stok wajib,
  // barcode tetap boleh). Menjadi dasar Tab Layanan di POS + menu Produk.
  BoolColumn get isService => boolean().withDefault(const Constant(false))();
  BoolColumn get isOnline => boolean().withDefault(const Constant(false))();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  TextColumn get productType => text().nullable()();
  TextColumn get variantsJson =>
      text().nullable()(); // JSON array: [{name,priceAdjustment,stock}]
  TextColumn get wholesaleJson =>
      text().nullable()(); // JSON array: [{minQty,price}]
  TextColumn get priceType =>
      text().withDefault(const Constant('pcs'))(); // 'pcs' or 'kg'
  // Supplier langganan produk (nullable): diisi saat produk dibuat dari
  // Catat Pembelian (toggle supplier). Dipakai untuk tahu produk ini
  // dipasok supplier mana — HPP tetap dari buyPrice.
  IntColumn get supplierId => integer().nullable()();
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
  // Sales attribution — which employee/cashier shift owns this transaction.
  // null employeeId = online order (shared across all cashiers).
  IntColumn get employeeId => integer().nullable()();
  IntColumn get sessionId => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('Normal'))();
  TextColumn get voidReason => text().nullable()();
  DateTimeColumn get voidedAt => dateTime().nullable()();
  // FnB: order type, table link, notes
  TextColumn get orderType => text().nullable()();
  IntColumn get tableId => integer().nullable()();
  TextColumn get notes => text().nullable()();
  // Piutang (v2.2.34): DP dibayar, cicilan, dan link ke debt row.
  IntColumn get dpAmount => integer().nullable()();
  IntColumn get installmentMonths => integer().nullable()();
  IntColumn get installmentPerMonth => integer().nullable()();
  IntColumn get debtId => integer().nullable()();
}

/// Retur/refund parsial per transaksi (barang dikembalikan pelanggan).
/// Stok item dikembalikan + uang dikembalikan dicatat agar laporan omzet,
/// HPP, top produk, dan kas shift selalu akurat.
class Refunds extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId => integer()();
  IntColumn get productId => integer().nullable()();
  TextColumn get productName => text()();
  IntColumn get qty => integer()();
  IntColumn get unitPrice => integer()();
  IntColumn get refundAmount => integer()();
  TextColumn get reason => text().nullable()();
  IntColumn get branchId => integer().nullable()();
  IntColumn get employeeId => integer().nullable()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
}

/// Role permissions — per-role menu access, stored in SQLite so role
/// permissions ride along with the cloud DB backup/restore (phone ↔ tablet).
class Roles extends Table {
  TextColumn get name => text()();
  TextColumn get color => text().nullable()();
  TextColumn get accessJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {name};
}

class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  // v2.2.45 (B11): barcode member — scan HID/kamera untuk pilih pelanggan &
  // cetak kartu member. Bisa diisi manual atau di-generate.
  TextColumn get barcode => text().nullable()();
  IntColumn get points => integer().withDefault(const Constant(0))();
  IntColumn get totalSpent => integer().withDefault(const Constant(0))();
  TextColumn get level => text().withDefault(const Constant('Silver'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Riwayat poin per pelanggan (dapat / pakai poin) untuk tampilan
/// "Poin History" di detail pelanggan & info poin di struk.
class PointHistories extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer()();
  TextColumn get type => text()(); // 'earn' | 'redeem' | 'adjust'
  IntColumn get points => integer()(); // + dapat, - pakai
  IntColumn get transactionId => integer().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
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
  // 'otomatis' (auto-apply saat cart penuhi syarat) | 'kode' (hanya via kode) | 'bebas' (bisa dipilih di kasir)
  TextColumn get mode => text().withDefault(const Constant('otomatis'))();
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
  TextColumn get nfcTag => text().nullable()(); // NFC tag hash for tap-to-login
  // v2.2.44 (B8): barcode karyawan — jalur auth ke-4 (PIN/FP/NFC/barcode).
  // Owner bisa cetak id-card ber-barcode → scan HID untuk login/presensi.
  TextColumn get barcode => text().nullable()();
  // v2.2.45 (B1): foto profil karyawan ikut backup cloud — BASE64 di kolom DB.
  // photoPath cuma path file lokal yang TIDAK ikut backup; setelah restore di
  // device baru file-nya tidak ada. photoBase64 mengembalikan foto setelah
  // restore (di-hydrate ke disk lalu photoPath diperbarui).
  TextColumn get photoBase64 => text().nullable()();
  TextColumn get workStart => text().nullable()(); // "HH:mm" default "08:00"
  TextColumn get workEnd => text().nullable()(); // "HH:mm" default "17:00"
  BoolColumn get requiresAttendance =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get requiresCashOpen =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get requiresCashClose =>
      boolean().withDefault(const Constant(false))();
  // v2.2.54: staf layanan — boleh dipilih sebagai capster/stylist di booking
  // (varian jasa). Default true supaya karyawan existing langsung terpilih;
  // owner menyaring lewat form karyawan (role Gudang/Finance dicentang mati).
  BoolColumn get isServiceStaff =>
      boolean().withDefault(const Constant(true))();
  // v2.2.57: komisi capster/stylist (% omset yang jadi hak dia). Hanya
  // relevan saat isServiceStaff=true. Default 10% sesuai konvensi industri.
  RealColumn get commissionPercent =>
      real().withDefault(const Constant(10.0))();
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

// Pembelian/restok dari supplier: header per transaksi pembelian.
// Saat dicatat (receive), stok produk masuk + harga modal (buyPrice) ikut
// diperbarui ke harga beli terbaru — HPP/laba rugi jadi presisi.
class PurchaseOrders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invoice => text()();
  IntColumn get supplierId => integer()();
  TextColumn get supplierName =>
      text()(); // snapshot nama supplier (aman walau supplier dihapus)
  IntColumn get total => integer().withDefault(const Constant(0))();
  // Biaya tambahan (packing/ongkir/stiker dll): JSON array
  // [{name, amount}] — total dibagi rata ke qty item → masuk HPP (buyPrice).
  TextColumn get extraCostsJson => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
}

class PurchaseOrderItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get purchaseOrderId => integer()();
  // Untuk produk (isMaterial=0): productId = id produk (stok masuk + buyPrice
  // update). Untuk bahan (isMaterial=1): productId nullable (bahan non-produk,
  // mis. plastik — cukup dicatat riwayat, tanpa menyentuh stok produk).
  IntColumn get productId => integer().nullable()();
  TextColumn get productName => text()(); // snapshot nama produk/bahan
  IntColumn get qty => integer()();
  IntColumn get buyPrice => integer()(); // harga modal saat pembelian
  IntColumn get total => integer()();
  BoolColumn get isMaterial => boolean().withDefault(const Constant(false))();
}

/// Riwayat harga beli bahan per supplier — dipakai untuk melihat kenaikan /
/// penurunan harga pembelian (mis. plastik yang harganya fluktuatif).
class MaterialPrices extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get supplierId => integer()();
  IntColumn get orderId => integer()(); // PurchaseOrders.id (asal catatan)
  TextColumn get materialName => text()(); // nama bahan (snapshot)
  IntColumn get price => integer()(); // harga beli saat itu
  IntColumn get qty => integer().withDefault(const Constant(1))();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
}

// ── v2.2.43: Satuan dinamis (CRUD kamus) + konversi per produk ────────────

/// Kamus satuan global (CRUD user): pcs, dus, karton, botol, strip, bebas.
/// gram/kg/ml/liter sebagai NAMA satuan boleh — mode timbang tetap lewat
/// `Products.priceType` ('pcs'/'kg'), TERPISAH dari kamus hitung ini.
class Units extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Konversi satuan per produk (v2.2.43): tiap produk punya tepat 1 satuan
/// dasar (isBase=1, qtyPerBase=1) + N satuan jual (mis. dus=12, karton=6).
/// Produk tanpa baris di tabel ini = fallback 'pcs' (kompatibel data lama).
class ProductUnits extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer()();
  IntColumn get unitId => integer()();
  RealColumn get qtyPerBase => real().withDefault(const Constant(1))();
  BoolColumn get isBase => boolean().withDefault(const Constant(false))();
}

// ── v2.2.43: F&B Bahan Baku + Resep + HPP (hanya dipakai F&B) ─────────────

/// Bahan baku (raw material) — punya stok sendiri + harga modal (HPP).
/// Stok berkurang saat checkout produk yang punya resep (PERINGATAN saja
/// bila kurang — transaksi tetap jalan). 1 bahan = 1 satuan (keputusan user).
class RawMaterials extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get unitId => integer().nullable()();
  IntColumn get stock => integer().withDefault(const Constant(0))();
  IntColumn get minStock => integer().withDefault(const Constant(0))();
  IntColumn get costPrice => integer().withDefault(const Constant(0))();
  IntColumn get supplierId => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Resep produk: 1 produk → N bahan, tiap bahan dengan qty REAL (mis. 1.5).
/// `getRecipeCost(productId)` = Σ qty × costPrice → HPP resep di laporan.
class Recipes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer()();
  IntColumn get materialId => integer()();
  RealColumn get qty => real().withDefault(const Constant(1))();
}

/// Riwayat mutasi stok bahan ('in' | 'out') — untuk stok masuk cepat,
/// pembelian bahan, dan pengurangan otomatis saat checkout.
class IngredientStocks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get materialId => integer()();
  TextColumn get type => text()(); // 'in' | 'out'
  RealColumn get qty => real()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
}

/// Opsi cicilan piutang (v2.2.34): paket jumlah bulan yang bisa dipilih
/// kasir saat checkout dengan DP. CRUD hanya Owner (di layar Piutang).
/// months = berapa bulan sisa dibagi rata; label contoh "3× bulanan".
class InstallmentOptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get months => integer()();
  TextColumn get label => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
}

/// Preset estimasi selesai Order Cetak (v2.2.34): dropdown CRUD di form
/// Order Cetak supaya estimasi konsisten (bukan free-text semrawut).
class EstimateOptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get label => text().unique()();
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
  IntColumn get platinumThreshold =>
      integer().withDefault(const Constant(5000))();
  // ── QRIS image (replaces qrisString) ──
  TextColumn get qrisImagePath => text().nullable()();
  // ── Receipt advanced ──
  TextColumn get receiptHeader => text().nullable()();
  TextColumn get receiptSubHeader => text().nullable()();
  TextColumn get receiptPaperSize =>
      text().withDefault(const Constant('58mm'))();
  IntColumn get pinLength => integer().withDefault(const Constant(6))();
  BoolColumn get receiptShowLogo =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get receiptShowCashier =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get receiptShowInvoice =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get receiptShowDate =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get receiptShowBarcode =>
      boolean().withDefault(const Constant(false))();
  // ── Kitchen printer (FnB) ──
  TextColumn get kitchenPrinterAddress => text().nullable()();
  BoolColumn get kitchenPrinterEnabled =>
      boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
}

class ActivationsLocal extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get key => text()();
  TextColumn get deviceId => text()();
  DateTimeColumn get activatedAt =>
      dateTime().withDefault(currentDateAndTime)();
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
  TextColumn get items => text()(); // JSON string
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
  TextColumn get status => text().withDefault(
    const Constant('Belum Lunas'),
  )(); // Belum Lunas | Lunas
  // Cicilan (v2.2.34): berapa bulan sisa dibagi rata (null = tidak dicicil).
  IntColumn get installmentMonths => integer().nullable()();
}

class DebtPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get debtId => integer()();
  IntColumn get amount => integer()();
  TextColumn get method => text().withDefault(const Constant('Tunai'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get paidAt => dateTime().withDefault(currentDateAndTime)();
  // v2.2.35: cabang tempat setoran piutang dicatat (untuk laporan uang masuk).
  IntColumn get branchId => integer().nullable()();
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
  TextColumn get title => text()(); // auto-generated from first message
  TextColumn get messagesJson => text()(); // JSON array of {role, content}
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// ── Domain feature tables ────────────────────────────────────────────────

/// F&B: Dining table management.
class DiningTables extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get capacity => integer().withDefault(const Constant(4))();
  TextColumn get status => text().withDefault(
    const Constant('Kosong'),
  )(); // Kosong | Dipesan | Tutup
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Laundry: Order tracking through wash-iron-deliver stages.
class LaundryOrders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get customerName => text()();
  TextColumn get customerPhone => text().nullable()();
  TextColumn get itemsJson => text()(); // JSON [{name,qty,price}]
  IntColumn get total => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('Baru'))();
  // Baru | Cuci | Kering | Setrika | Siap | Diantar | Diambil
  TextColumn get notes => text().nullable()();
  DateTimeColumn get estimatedReady =>
      dateTime().nullable()(); // estimasi selesai
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Bengkel & Servis: Service ticket management (vehicle workshop context).
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
  // ── Bengkel (vehicle workshop) columns ──
  TextColumn get plateNumber =>
      text().nullable()(); // plat nomor kendaraan (e.g. B 1234 XYZ)
  TextColumn get vehicleBrand => text()
      .nullable()(); // merk/model kendaraan (e.g. Honda Beat, Toyota Avanza)
  IntColumn get vehicleYear => integer().nullable()(); // tahun kendaraan
  TextColumn get technician => text().nullable()(); // nama teknisi
  IntColumn get sparepartCost =>
      integer().withDefault(const Constant(0))(); // biaya suku cadang
  IntColumn get serviceCost =>
      integer().withDefault(const Constant(0))(); // biaya jasa
  IntColumn get queueNumber => integer().nullable()(); // nomor antrian harian
}

/// Salon: Appointment booking with stylist + time slot.
class Appointments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get customerName => text()();
  TextColumn get customerPhone => text().nullable()();
  TextColumn get service => text()(); // e.g. Haircut, Coloring
  TextColumn get stylist => text().nullable()();
  // v2.2.54: ID karyawan stylist (FK logis ke Employees) — nama tetap di
  // kolom `stylist` (denormalisasi untuk struk/tampilan tanpa join).
  IntColumn get stylistId => integer().nullable()();
  // v2.2.57: link appointment → transaksi (omset & komisi per capster
  // dihitung dari transaksi yang terkait booking).
  IntColumn get transactionId => integer().nullable()();
  DateTimeColumn get date => dateTime()();
  TextColumn get timeSlot => text()(); // "HH:mm"
  TextColumn get status => text().withDefault(const Constant('Dikonfirmasi'))();
  // Dikonfirmasi | Datang | Menunggu | Selesai | Batal
  TextColumn get notes => text().nullable()();
  IntColumn get estimatedDuration =>
      integer().nullable()(); // estimasi durasi dalam menit
  IntColumn get counterId =>
      integer().nullable()(); // nomor urut booking per hari
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
  // Dimensi cetak (opsional): P (cm) × L (cm) — banner/spanduk/undangan.
  IntColumn get widthCm => integer().nullable()();
  IntColumn get lengthCm => integer().nullable()();
  // Estimasi selesai (opsional): teks bebas, mis. "2 jam" / "Besok 14:00".
  TextColumn get estimateReady => text().nullable()();
  IntColumn get total => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('Baru'))();
  // Baru | Diproses | Selesai | Diambil
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  // v2.2.35: nilai field form kustom (JSON map label→value) per order cetak.
  TextColumn get customFieldsJson => text().nullable()();
}

/// Fotocopy/Percetakan: jenis layanan (custom, tanpa icon bulat).
/// isDefault=1 untuk seed bawaan (Fotocopy, Print Warna, dst).
class PrintServiceTypes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  // v2.2.35: field form yang TAMPIL untuk layanan ini (JSON list string).
  // null = semua field default tampil. Sinkron ke Supabase print_form_configs.
  TextColumn get fieldsJson => text().nullable()();
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
