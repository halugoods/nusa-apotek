import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/attendance_repository.dart';
import 'package:nusa_kasir/data/repositories/branch_repository.dart';
import 'package:nusa_kasir/data/repositories/finance_repository.dart';
import 'package:nusa_kasir/data/repositories/product_repository.dart';
import 'package:nusa_kasir/shared/widgets/nusa_card.dart';
import 'package:nusa_kasir/shared/widgets/nusa_input.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/empty_state.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _expenseCategories = [
  'Operasional',
  'Listrik',
  'Air',
  'Internet',
  'Belanja',
  'Sewa',
  'Transport',
  'Lainnya',
];

IconData _iconForCategory(String cat) => switch (cat.toLowerCase()) {
  'operasional' => Icons.settings,
  'listrik' || 'air' || 'internet' => Icons.electrical_services,
  'belanja' || 'bahan' => Icons.shopping_cart,
  'sewa' => Icons.home,
  'transport' => Icons.local_shipping,
  _ => Icons.money_off,
};

class FinanceScreen extends ConsumerStatefulWidget {
  FinanceScreen({super.key});
  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  final _tabs = ['Pengeluaran', 'Payroll', 'Waste', 'Berulang', 'Likuiditas'];
  int _tab = 0;
  List<Expense> _expenses = [];
  List<PayrollData> _payroll = [];
  List<WasteData> _waste = [];
  List<LiquidityData> _liquidity = [];
  List<RecurringExpense> _recurring = [];
  List<ExpenseCategory> _categories = [];
  List<Employee> _employees = [];
  List<Product> _products = [];
  List<Branche> _branches = [];
  List<String> months = [];

  int _totalExpenseThisMonth = 0;
  int _totalPayroll = 0;
  int _totalWasteCost = 0;
  int _runningBalance = 0;
  String _timeFilter = 'Hari ini';
  DateTimeRange? _dateRange;
  int? _branchFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final f = FinanceRepository(ref.read(databaseProvider));
    final empRepo = AttendanceRepository(ref.read(databaseProvider));
    final prodRepo = ProductRepository(ref.read(databaseProvider));
    final branchRepo = BranchRepository(ref.read(databaseProvider));

    await f.processRecurring();

    final results = await Future.wait([
      f.getExpenses(branchId: _branchFilter),
      f.getPayroll(),
      f.getWaste(),
      f.getLiquidity(branchId: _branchFilter),
      f.getRecurring(),
      f.getCategories(),
      empRepo.getEmployees(),
      prodRepo.getProducts(),
      branchRepo.getAll(),
    ]);
    if (mounted) {
      final now = DateTime.now();
      final allExpenses = results[0] as List<Expense>;
      final expThisMonth = allExpenses
          .where((e) => e.date.year == now.year && e.date.month == now.month)
          .fold<int>(0, (sum, e) => sum + e.amount);
      final allPayroll = results[1] is List<PayrollData>
          ? (results[1] as List<PayrollData>).fold<int>(
              0,
              (sum, p) => sum + p.salary + p.bonus - p.deduction,
            )
          : 0;
      final allWaste = results[2] as List<WasteData>;
      int balance = 0;
      if (results[3] is List<LiquidityData>) {
        for (final l in results[3] as List<LiquidityData>) {
          balance += l.type == 'in' ? l.amount : -l.amount;
        }
      }
      setState(() {
        _expenses = allExpenses;
        _payroll = results[1] as List<PayrollData>;
        _waste = allWaste;
        _liquidity = results[3] as List<LiquidityData>;
        _recurring = results[4] as List<RecurringExpense>;
        _categories = results[5] as List<ExpenseCategory>;
        _employees = results[6] as List<Employee>;
        _products = results[7] as List<Product>;
        _branches = results[8] as List<Branche>;
        _totalExpenseThisMonth = expThisMonth;
        _totalPayroll = allPayroll;
        _totalWasteCost = allWaste.length;
        _runningBalance = balance;
      });
    }
  }

  String _empName(int id) {
    for (final e in _employees) {
      if (e.id == id) return e.name;
    }
    return 'ID $id';
  }

  String _prodName(int id) {
    for (final p in _products) {
      if (p.id == id) return p.name;
    }
    return 'ID $id';
  }

  List<String> get _allCategories {
    final built = <String>[..._expenseCategories];
    for (final c in _categories) {
      if (!built.contains(c.name)) built.add(c.name);
    }
    return built;
  }

  List<Expense> get _filteredExpenses {
    if (_timeFilter == 'custom' && _dateRange != null) {
      final to = _dateRange!.end.add(Duration(days: 1));
      return _expenses
          .where(
            (e) => !e.date.isBefore(_dateRange!.start) && e.date.isBefore(to),
          )
          .toList();
    }
    final now = DateTime.now();
    switch (_timeFilter) {
      case 'Hari ini':
        final today = DateTime(now.year, now.month, now.day);
        return _expenses.where((e) => !e.date.isBefore(today)).toList();
      case 'Kemarin':
        final yesterday = DateTime(now.year, now.month, now.day - 1);
        final today = DateTime(now.year, now.month, now.day);
        return _expenses
            .where((e) => !e.date.isBefore(yesterday) && e.date.isBefore(today))
            .toList();
      case 'Minggu ini':
        return _expenses
            .where((e) => e.date.isAfter(now.subtract(Duration(days: 7))))
            .toList();
      case 'Bulan ini':
        return _expenses
            .where((e) => e.date.isAfter(now.subtract(Duration(days: 30))))
            .toList();
      case 'Tahun ini':
        return _expenses
            .where((e) => !e.date.isBefore(DateTime(now.year, 1, 1)))
            .toList();
      default:
        return _expenses;
    }
  }

  String _timeLabel() => _timeFilter == 'custom' && _dateRange != null
      ? '${_dateRange!.start.day}/${_dateRange!.start.month}–${_dateRange!.end.day}/${_dateRange!.end.month}'
      : _timeFilter;

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      helpText: 'Pilih Rentang',
      cancelText: 'BATAL',
      confirmText: 'PILIH',
    );
    if (range != null) {
      setState(() {
        _dateRange = range;
        _timeFilter = 'custom';
      });
    }
  }

  String _date(DateTime d) {
    months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ScreenScaffold(
      'Keuangan',
      Column(
        children: [
          // Summary cards — konteks sesuai tab aktif (G: audit logika switch)
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                if (_tab == 0)
                  _SummaryCard(
                    label: 'Pengeluaran Bln Ini',
                    value: formatRupiah(_totalExpenseThisMonth),
                    icon: Icons.money_off,
                    color: NusaConfig.activePrimary,
                  )
                else if (_tab == 1)
                  _SummaryCard(
                    label: 'Total Payroll',
                    value: formatRupiah(_totalPayroll),
                    icon: Icons.people,
                    color: Color(0xFF8B5CF6),
                  )
                else if (_tab == 2)
                  _SummaryCard(
                    label: 'Item Waste',
                    value: '$_totalWasteCost item',
                    icon: Icons.delete_outline,
                    color: Color(0xFFEF4444),
                  )
                else if (_tab == 3)
                  _SummaryCard(
                    label: 'Langganan Aktif',
                    value: _recurring.where((r) => r.active).length.toString(),
                    icon: Icons.loop_rounded,
                    color: Color(0xFF8B5CF6),
                  )
                else
                  _SummaryCard(
                    label: 'Saldo Kas',
                    value: formatRupiah(_runningBalance),
                    icon: Icons.account_balance_wallet_outlined,
                    color: _runningBalance >= 0
                        ? NusaConfig.accentGreen
                        : NusaConfig.activePrimary,
                  ),
                SizedBox(width: 10),
                if (_tab == 0 || _tab == 4)
                  _SummaryCard(
                    label: _tab == 0 ? 'Periode Terfilter' : 'Arus Masuk',
                    value: _tab == 0
                        ? formatRupiah(
                            _filteredExpenses.fold<int>(
                              0,
                              (s, e) => s + e.amount,
                            ),
                          )
                        : formatRupiah(
                            _liquidity
                                .where((l) => l.type == 'in')
                                .fold<int>(0, (s, l) => s + l.amount),
                          ),
                    icon: _tab == 0
                        ? Icons.filter_alt_outlined
                        : Icons.south_west,
                    color: NusaConfig.info,
                  )
                else if (_tab == 1)
                  _SummaryCard(
                    label: 'Belum Dibayar',
                    value: _payroll
                        .where((p) => p.status != 'Paid')
                        .length
                        .toString(),
                    icon: Icons.schedule_rounded,
                    color: NusaConfig.warning,
                  )
                else if (_tab == 2)
                  _SummaryCard(
                    label: 'Estimasi Rugi',
                    value: formatRupiah(
                      _waste.fold<int>(0, (s, w) {
                        final p = _products
                            .where((e) => e.id == w.productId)
                            .firstOrNull;
                        return s + w.qty * (p?.buyPrice ?? 0);
                      }),
                    ),
                    icon: Icons.money_off_csred_outlined,
                    color: NusaConfig.warning,
                  )
                else
                  _SummaryCard(
                    label: 'Arus Keluar',
                    value: formatRupiah(
                      _liquidity
                          .where((l) => l.type == 'out')
                          .fold<int>(0, (s, l) => s + l.amount),
                    ),
                    icon: Icons.north_east,
                    color: NusaConfig.activePrimary,
                  ),
                SizedBox(width: 10),
                _SummaryCard(
                  label: _tab == 0
                      ? 'Jumlah Transaksi'
                      : _tab == 1
                      ? 'Karyawan'
                      : _tab == 2
                      ? 'Produk Rusak'
                      : _tab == 3
                      ? 'Total Bulanan'
                      : 'Total Aset',
                  value: _tab == 0
                      ? _filteredExpenses.length.toString()
                      : _tab == 1
                      ? _payroll.length.toString()
                      : _tab == 2
                      ? _waste.length.toString()
                      : _tab == 3
                      ? formatRupiah(
                          _recurring
                              .where((r) => r.active)
                              .fold<int>(0, (s, r) => s + r.amount),
                        )
                      : '${_liquidity.length} catatan',
                  icon: _tab == 0
                      ? Icons.receipt_long_outlined
                      : _tab == 1
                      ? Icons.badge_outlined
                      : _tab == 2
                      ? Icons.error_outline_rounded
                      : _tab == 3
                      ? Icons.calendar_month_outlined
                      : Icons.account_balance_outlined,
                  color: NusaConfig.activePrimary,
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
          // Segmented tabs
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark
                    ? NusaConfig.darkSurface
                    : NusaConfig.backgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? NusaConfig.darkBorder
                      : NusaConfig.dividerColor,
                ),
              ),
              child: Row(
                children: List.generate(
                  _tabs.length,
                  (i) => _segBtn(_tabs[i], i, isDark: isDark),
                ),
              ),
            ),
          ),
          SizedBox(height: 6),
          // Filters row
          if (_tab == 0 || _tab == 4)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Spacer(),
                  if (_branches.length > 1) ...[
                    _branchDropdown(isDark),
                    SizedBox(width: 6),
                  ],
                  if (_tab == 0) ...[_timeDropdown(isDark), SizedBox(width: 6)],
                  GestureDetector(
                    onTap: () => _showExportOptions(isDark),
                    child: Container(
                      height: 36,
                      width: 36,
                      decoration: BoxDecoration(
                        color: isDark
                            ? NusaConfig.darkSurface
                            : NusaConfig.surfaceColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? NusaConfig.darkBorder
                              : NusaConfig.borderColor,
                        ),
                      ),
                      child: Icon(
                        Icons.file_download_outlined,
                        size: 18,
                        color: isDark
                            ? NusaConfig.darkTextSecondary
                            : NusaConfig.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 4),
          Expanded(child: _body(isDark)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: NusaConfig.activePrimary,
        child: Icon(Icons.add, color: Colors.white),
        onPressed: _showAdd,
      ),
    );
  }

  Widget _segBtn(String label, int idx, {bool isDark = false}) {
    final sel = idx == _tab;
    final hint = _tabHints[label];
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = idx),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? NusaConfig.activePrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: sel
                      ? Colors.white
                      : (isDark
                            ? NusaConfig.darkTextSecondary
                            : NusaConfig.textSecondary),
                ),
              ),
              if (hint != null)
                Text(
                  hint,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                    color: sel
                        ? Colors.white.withValues(alpha: 0.85)
                        : (isDark
                              ? NusaConfig.darkTextTertiary
                              : NusaConfig.textTertiary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// G: teks hint abu2 kecil di bawah label tab — konteks tiap menu.
  static const _tabHints = {
    'Pengeluaran': 'bulan ini',
    'Payroll': 'gaji',
    'Waste': 'buang',
    'Berulang': 'langganan',
    'Likuiditas': 'kas',
  };

  Widget _timeDropdown(bool isDark) {
    return Container(
      height: 36,
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : NusaConfig.backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _timeFilter == 'custom' ? 'custom' : _timeFilter,
          isDense: true,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark
                ? NusaConfig.darkTextSecondary
                : NusaConfig.textSecondary,
          ),
          borderRadius: BorderRadius.circular(12),
          underline: SizedBox.shrink(),
          icon: Icon(
            Icons.expand_more_rounded,
            size: 18,
            color: isDark
                ? NusaConfig.darkTextTertiary
                : NusaConfig.textTertiary,
          ),
          items: [
            _ddItem('Hari ini'),
            _ddItem('Kemarin'),
            _ddItem('Minggu ini'),
            _ddItem('Bulan ini'),
            _ddItem('Tahun ini'),
            _ddItem('Semua'),
            if (_timeFilter == 'custom' && _dateRange != null)
              DropdownMenuItem(
                value: 'custom',
                enabled: false,
                child: Text(
                  _timeLabel(),
                  style: TextStyle(
                    fontSize: 11,
                    color: NusaConfig.activePrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            _ddItem('Pilih Periode'),
          ],
          onChanged: (v) {
            if (v == 'Pilih Periode') {
              _pickDateRange();
            } else {
              setState(() {
                _timeFilter = v!;
                _dateRange = null;
              });
            }
          },
        ),
      ),
    );
  }

  DropdownMenuItem<String> _ddItem(String label) =>
      DropdownMenuItem(value: label, child: Text(label));

  Widget _branchDropdown(bool isDark) {
    return Container(
      height: 32,
      padding: EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _branchFilter,
          isDense: true,
          icon: Icon(
            Icons.expand_more_rounded,
            size: 16,
            color: isDark
                ? NusaConfig.darkTextTertiary
                : NusaConfig.textTertiary,
          ),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark
                ? NusaConfig.darkTextSecondary
                : NusaConfig.textSecondary,
          ),
          dropdownColor: isDark ? NusaConfig.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(10),
          underline: SizedBox.shrink(),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text('Semua', style: TextStyle(fontSize: 11)),
            ),
            ..._branches.map(
              (b) => DropdownMenuItem<int?>(
                value: b.id,
                child: Text(b.name, style: TextStyle(fontSize: 11)),
              ),
            ),
          ],
          onChanged: (v) {
            setState(() => _branchFilter = v);
            _load();
          },
        ),
      ),
    );
  }

  Widget _body(bool isDark) {
    switch (_tab) {
      case 0:
        return _expensesTab(isDark);
      case 1:
        return _payrollTab(isDark);
      case 2:
        return _wasteTab(isDark);
      case 3:
        return _recurringTab(isDark);
      default:
        return _liquidityTab(isDark);
    }
  }

  // ── Tab: Pengeluaran ──────────────────────────────────────────

  Widget _expensesTab(bool isDark) {
    final filtered = _filteredExpenses;
    return _listView(
      filtered.isEmpty,
      filtered.map((e) => _expenseCard(e, isDark)).toList(),
      onDelete: (i) async {
        await FinanceRepository(
          ref.read(databaseProvider),
        ).deleteExpense(filtered[i].id);
        _load();
      },
    );
  }

  Widget _expenseCard(Expense e, bool isDark) {
    return NusaCard(
      Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: NusaConfig.activePrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _iconForCategory(e.category),
                size: 20,
                color: NusaConfig.activePrimary,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.category,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 2),
                  if (e.description.isNotEmpty)
                    Text(
                      e.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? NusaConfig.darkTextSecondary
                            : NusaConfig.textSecondary,
                      ),
                    ),
                  SizedBox(height: 1),
                  Text(
                    _date(e.date),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? NusaConfig.darkTextSecondary
                          : NusaConfig.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatRupiah(e.amount),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab: Payroll ──────────────────────────────────────────────

  Widget _payrollTab(bool isDark) {
    return _listView(
      _payroll.isEmpty,
      _payroll.map((p) => _payrollCard(p, isDark)).toList(),
      onDelete: (i) async {
        await FinanceRepository(
          ref.read(databaseProvider),
        ).deletePayroll(_payroll[i].id);
        _load();
      },
    );
  }

  Widget _payrollCard(PayrollData p, bool isDark) {
    return NusaCard(
      Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _empName(p.employeeId),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    final f = FinanceRepository(ref.read(databaseProvider));
                    await f.updatePayrollStatus(
                      p.id,
                      p.status == 'Paid' ? 'Pending' : 'Paid',
                    );
                    _load();
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: p.status == 'Paid'
                          ? Colors.green.withValues(alpha: 0.15)
                          : NusaConfig.activePrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      p.status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: p.status == 'Paid'
                            ? Colors.green
                            : NusaConfig.activePrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              'Periode: ${p.period}',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? NusaConfig.darkTextSecondary
                    : NusaConfig.textSecondary,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Gaji: ${formatRupiah(p.salary)} \u2022 Bonus: ${formatRupiah(p.bonus)} \u2022 Potong: ${formatRupiah(p.deduction)}',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? NusaConfig.darkTextSecondary
                    : NusaConfig.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab: Waste ────────────────────────────────────────────────

  Widget _wasteTab(bool isDark) {
    return _listView(
      _waste.isEmpty,
      _waste.map((w) => _wasteCard(w, isDark)).toList(),
      onDelete: (i) async {
        await FinanceRepository(
          ref.read(databaseProvider),
        ).deleteWaste(_waste[i].id);
        _load();
      },
    );
  }

  Widget _wasteCard(WasteData w, bool isDark) {
    return NusaCard(
      Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _prodName(w.productId),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${w.qty} pcs \u2022 ${w.type}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? NusaConfig.darkTextSecondary
                          : NusaConfig.textSecondary,
                    ),
                  ),
                  if (w.reason != null && w.reason!.isNotEmpty)
                    Text(
                      w.reason!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? NusaConfig.darkTextSecondary
                            : NusaConfig.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              _date(w.date),
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? NusaConfig.darkTextSecondary
                    : NusaConfig.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab: Berulang ─────────────────────────────────────────────

  Widget _recurringTab(bool isDark) {
    return _listView(
      _recurring.isEmpty,
      _recurring
          .map(
            (r) => NusaCard(
              Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(0xFF8B5CF6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.loop_rounded,
                        size: 20,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.category,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            r.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? NusaConfig.darkTextSecondary
                                  : NusaConfig.textSecondary,
                            ),
                          ),
                          Text(
                            '${r.frequency} \u2022 Next: ${_date(r.nextDate)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? NusaConfig.darkTextSecondary
                                  : NusaConfig.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          formatRupiah(r.amount),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.red,
                          ),
                        ),
                        SizedBox(height: 4),
                        GestureDetector(
                          onTap: () async {
                            final f = FinanceRepository(
                              ref.read(databaseProvider),
                            );
                            await f.toggleRecurring(r.id, !r.active);
                            await _load();
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: r.active
                                  ? NusaConfig.accentGreen.withValues(
                                      alpha: 0.12,
                                    )
                                  : Colors.grey.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              r.active ? 'Aktif' : 'Nonaktif',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: r.active
                                    ? NusaConfig.accentGreen
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
      onDelete: (i) async {
        await FinanceRepository(
          ref.read(databaseProvider),
        ).deleteRecurring(_recurring[i].id);
        _load();
      },
    );
  }

  // ── Tab: Likuiditas ───────────────────────────────────────────

  Widget _liquidityTab(bool isDark) {
    return Column(
      children: [
        _buildCashflowChart(isDark),
        SizedBox(height: 8),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'Saldo: ',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? NusaConfig.darkTextSecondary
                      : NusaConfig.textSecondary,
                ),
              ),
              Text(
                formatRupiah(_runningBalance),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _runningBalance >= 0
                      ? NusaConfig.accentGreen
                      : NusaConfig.activePrimary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 4),
        Expanded(
          child: _listView(
            _liquidity.isEmpty,
            _liquidity
                .map(
                  (l) => NusaCard(
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color:
                                  (l.type == 'in'
                                          ? NusaConfig.accentGreen
                                          : NusaConfig.activePrimary)
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              l.type == 'in'
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              size: 20,
                              color: l.type == 'in'
                                  ? NusaConfig.accentGreen
                                  : NusaConfig.activePrimary,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.category,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  l.description,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? NusaConfig.darkTextSecondary
                                        : NusaConfig.textSecondary,
                                  ),
                                ),
                                if (l.method != null)
                                  Text(
                                    'Metode: ${l.method}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? NusaConfig.darkTextSecondary
                                          : NusaConfig.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${l.type == 'in' ? '+ ' : '- '}${formatRupiah(l.amount)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: l.type == 'in'
                                  ? NusaConfig.accentGreen
                                  : NusaConfig.activePrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
            onDelete: (i) async {
              await FinanceRepository(
                ref.read(databaseProvider),
              ).deleteLiquidity(_liquidity[i].id);
              _load();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCashflowChart(bool isDark) {
    if (_liquidity.isEmpty) return SizedBox.shrink();

    final now = DateTime.now();
    months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final bars = <BarChartGroupData>[];

    for (var i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      int inAmt = 0, outAmt = 0;
      for (final l in _liquidity) {
        if (l.date.year == d.year && l.date.month == d.month) {
          if (l.type == 'in') {
            inAmt += l.amount;
          } else {
            outAmt += l.amount;
          }
        }
      }
      bars.add(
        BarChartGroupData(
          x: 5 - i,
          barRods: [
            BarChartRodData(
              toY: inAmt.toDouble(),
              color: NusaConfig.accentGreen,
              width: 10,
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            ),
            BarChartRodData(
              toY: outAmt.toDouble(),
              color: NusaConfig.activePrimary,
              width: 10,
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    final maxY = bars.isEmpty
        ? 100000.0
        : bars
              .expand((g) => g.barRods.map((r) => r.toY))
              .reduce((a, b) => a > b ? a : b)
              .toDouble();

    // Build labels for bottom axis
    final labels = <String>[];
    for (var i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      labels.add(months[d.month - 1]);
    }

    return SizedBox(
      height: 180,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cashflow 6 Bulan',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? NusaConfig.darkTextPrimary
                    : NusaConfig.textPrimary,
              ),
            ),
            SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _legendDot(NusaConfig.accentGreen, 'Masuk'),
                SizedBox(width: 12),
                _legendDot(NusaConfig.activePrimary, 'Keluar'),
              ],
            ),
            SizedBox(height: 6),
            Expanded(
              child: BarChart(
                BarChartData(
                  maxY: maxY > 0 ? maxY * 1.2 : 100000,
                  barGroups: bars,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY > 0
                        ? (maxY / 4).clamp(1, double.infinity)
                        : 25000,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: isDark
                          ? NusaConfig.darkDivider
                          : NusaConfig.dividerColor,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          return Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              idx < labels.length ? labels[idx] : '',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? NusaConfig.darkTextSecondary
                                    : NusaConfig.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 55,
                        getTitlesWidget: (v, _) => Text(
                          v >= 1000000
                              ? '${(v / 1000000).toStringAsFixed(1)}M'
                              : v >= 1000
                              ? '${(v / 1000).toInt()}k'
                              : '0',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? NusaConfig.darkTextSecondary
                                : NusaConfig.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIdx, rod, rodIdx) {
                        final amt = formatRupiah(rod.toY.toInt());
                        return BarTooltipItem(
                          '${rodIdx == 0 ? 'Masuk' : 'Keluar'}: $amt',
                          TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ── Shared list builder ───────────────────────────────────────

  Widget _listView(
    bool empty,
    List<Widget> children, {
    Future<void> Function(int)? onDelete,
  }) {
    if (empty) {
      return EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        message: 'Belum ada data',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16, 6, 16, 24),
        itemCount: children.length,
        itemBuilder: (_, i) {
          final child = children[i];
          if (onDelete == null)
            return Padding(padding: EdgeInsets.only(bottom: 10), child: child);
          return Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Dismissible(
              key: ValueKey(i),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) async {
                return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Hapus'),
                        content: Text('Yakin hapus data ini?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('Batal'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(
                              'Hapus',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ) ??
                    false;
              },
              onDismissed: (_) => onDelete(i),
              background: Container(
                alignment: Alignment.centerRight,
                padding: EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: NusaConfig.activePrimary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.delete, color: Colors.white),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  // ── Export ─────────────────────────────────────────────────────

  void _showExportOptions(bool isDark) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(NusaConfig.spaceLG),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ekspor Data Keuangan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: NusaConfig.spaceMD),
              ListTile(
                leading: Icon(
                  Icons.table_chart_outlined,
                  color: NusaConfig.accentGreen,
                ),
                title: Text(
                  'Ekspor CSV (Excel)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'File spreadsheet, bisa dibuka di Excel',
                  style: TextStyle(fontSize: 12),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
                ),
                tileColor: NusaConfig.accentGreen.withValues(alpha: 0.06),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportCsv();
                },
              ),
              SizedBox(height: NusaConfig.spaceXS),
              ListTile(
                leading: Icon(
                  Icons.picture_as_pdf_outlined,
                  color: NusaConfig.activePrimary,
                ),
                title: Text(
                  'Ekspor PDF',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Dokumen PDF siap cetak',
                  style: TextStyle(fontSize: 12),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
                ),
                tileColor: NusaConfig.activePrimary.withValues(alpha: 0.06),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportPdf();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportCsv() async {
    List<List<dynamic>> rows;
    String name;
    switch (_tab) {
      case 0:
        name = 'pengeluaran';
        rows = [
          ['Tanggal', 'Kategori', 'Keterangan', 'Jumlah'],
        ];
        for (final e in _filteredExpenses) {
          rows.add([_date(e.date), e.category, e.description, e.amount]);
        }
        break;
      case 1:
        name = 'payroll';
        rows = [
          ['Karyawan', 'Periode', 'Gaji', 'Bonus', 'Potongan', 'Status'],
        ];
        for (final p in _payroll) {
          rows.add([
            _empName(p.employeeId),
            p.period,
            p.salary,
            p.bonus,
            p.deduction,
            p.status,
          ]);
        }
        break;
      case 2:
        name = 'waste';
        rows = [
          ['Produk', 'Qty', 'Tipe', 'Alasan', 'Tanggal'],
        ];
        for (final w in _waste) {
          rows.add([
            _prodName(w.productId),
            w.qty,
            w.type,
            w.reason ?? '',
            _date(w.date),
          ]);
        }
        break;
      case 3:
        name = 'pengeluaran_berulang';
        rows = [
          ['Kategori', 'Jumlah', 'Keterangan', 'Frekuensi', 'Aktif'],
        ];
        for (final r in _recurring) {
          rows.add([
            r.category,
            r.amount,
            r.description,
            r.frequency,
            r.active ? 'Ya' : 'Tidak',
          ]);
        }
        break;
      default:
        name = 'likuiditas';
        rows = [
          ['Tanggal', 'Tipe', 'Kategori', 'Keterangan', 'Jumlah', 'Metode'],
        ];
        for (final l in _liquidity) {
          rows.add([
            _date(l.date),
            l.type == 'in' ? 'Masuk' : 'Keluar',
            l.category,
            l.description,
            l.amount,
            l.method ?? '',
          ]);
        }
    }

    try {
      final csv = ListToCsvConverter().convert(rows);
      final dir = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final file = File('${dir.path}/${name}_$stamp.csv');
      await file.writeAsString(csv);
      if (mounted) TopToast.success(context, 'CSV diexport ke ${file.path}');
    } catch (e) {
      if (mounted) TopToast.error(context, 'Gagal export: $e');
    }
  }

  Future<void> _exportPdf() async {
    try {
      final file = await _buildFinancePdf();
      if (mounted && file != null) {
        TopToast.success(context, 'PDF diexport ke ${file.path}');
      }
    } catch (e) {
      if (mounted) TopToast.error(context, 'Gagal export PDF: $e');
    }
  }

  Future<File?> _buildFinancePdf() async {
    final pdf = pw.Document(title: 'Laporan Keuangan', author: 'NUSA Kasir');
    final now = DateTime.now();
    final tabTitle = _tabs[_tab];
    final periodLabel = _timeLabel();

    pw.Widget headerCell(String text) => pw.Text(
      text,
      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
    );
    pw.Widget cell(String text) =>
        pw.Text(text, style: pw.TextStyle(fontSize: 10));

    List<pw.TableRow> tableRows;

    switch (_tab) {
      case 0:
        tableRows = [
          pw.TableRow(
            children: [
              'Tanggal',
              'Kategori',
              'Keterangan',
              'Jumlah',
            ].map(headerCell).toList(),
          ),
        ];
        for (final e in _filteredExpenses) {
          tableRows.add(
            pw.TableRow(
              children: [
                _date(e.date),
                e.category,
                e.description,
                formatRupiah(e.amount),
              ].map(cell).toList(),
            ),
          );
        }
        break;
      case 1:
        tableRows = [
          pw.TableRow(
            children: [
              'Karyawan',
              'Periode',
              'Gaji',
              'Bonus',
              'Potongan',
              'Status',
            ].map(headerCell).toList(),
          ),
        ];
        for (final p in _payroll) {
          tableRows.add(
            pw.TableRow(
              children: [
                _empName(p.employeeId),
                p.period,
                formatRupiah(p.salary),
                formatRupiah(p.bonus),
                formatRupiah(p.deduction),
                p.status,
              ].map(cell).toList(),
            ),
          );
        }
        break;
      case 2:
        tableRows = [
          pw.TableRow(
            children: [
              'Produk',
              'Qty',
              'Tipe',
              'Alasan',
              'Tanggal',
            ].map(headerCell).toList(),
          ),
        ];
        for (final w in _waste) {
          tableRows.add(
            pw.TableRow(
              children: [
                _prodName(w.productId),
                '${w.qty}',
                w.type,
                w.reason ?? '',
                _date(w.date),
              ].map(cell).toList(),
            ),
          );
        }
        break;
      case 3:
        tableRows = [
          pw.TableRow(
            children: [
              'Kategori',
              'Jumlah',
              'Keterangan',
              'Frekuensi',
              'Aktif',
            ].map(headerCell).toList(),
          ),
        ];
        for (final r in _recurring) {
          tableRows.add(
            pw.TableRow(
              children: [
                r.category,
                formatRupiah(r.amount),
                r.description,
                r.frequency,
                r.active ? 'Ya' : 'Tidak',
              ].map(cell).toList(),
            ),
          );
        }
        break;
      default:
        tableRows = [
          pw.TableRow(
            children: [
              'Tanggal',
              'Tipe',
              'Kategori',
              'Keterangan',
              'Jumlah',
              'Metode',
            ].map(headerCell).toList(),
          ),
        ];
        for (final l in _liquidity) {
          tableRows.add(
            pw.TableRow(
              children: [
                _date(l.date),
                l.type == 'in' ? 'Masuk' : 'Keluar',
                l.category,
                l.description,
                formatRupiah(l.amount),
                l.method ?? '',
              ].map(cell).toList(),
            ),
          );
        }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Text(
            'Laporan $tabTitle',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Periode: $periodLabel',
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: [],
            data: [],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellStyle: pw.TextStyle(fontSize: 10),
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignments: {
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
          ),
          pw.Table(
            children: tableRows,
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              for (
                var i = 0;
                i <
                    (tableRows.isNotEmpty
                        ? tableRows.first.children.length
                        : 4);
                i++
              )
                i: pw.FlexColumnWidth(),
            },
          ),
          pw.SizedBox(height: 24),
          pw.Divider(),
          pw.Text(
            'Dicetak otomatis oleh NUSA Kasir • ${now.day}/${now.month}/${now.year}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final fileName = _tabs[_tab].toLowerCase().replaceAll(' ', '_');
    final file = File('${dir.path}/${fileName}_$stamp.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // ── Add forms ─────────────────────────────────────────────────

  void _showAdd() {
    switch (_tab) {
      case 0:
        _addExpense();
        break;
      case 1:
        _addPayroll();
        break;
      case 2:
        _addWaste();
        break;
      case 3:
        _addRecurring();
        break;
      default:
        _addLiquidity();
    }
  }

  void _addExpense() {
    final descCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    String category = _allCategories.isNotEmpty
        ? _allCategories.first
        : 'Operasional';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Container(
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            10,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetHandle(isDark),
                _sheetHeader(
                  Icons.money_off,
                  NusaConfig.activePrimary,
                  'Tambah Pengeluaran',
                  isDark,
                ),
                SizedBox(height: 16),
                _sheetDropdown(
                  label: 'Kategori',
                  value: category,
                  items: _allCategories,
                  isDark: isDark,
                  trailing: GestureDetector(
                    onTap: () => _manageCategories(
                      isDark,
                      setSt,
                      (cats) => setState(() => _categories = cats),
                    ),
                    child: Container(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.edit,
                        size: 18,
                        color: isDark
                            ? NusaConfig.darkTextSecondary
                            : NusaConfig.textSecondary,
                      ),
                    ),
                  ),
                  onChanged: (v) => setSt(() => category = v!),
                ),
                SizedBox(height: 12),
                NusaInput('Keterangan', controller: descCtrl),
                SizedBox(height: 12),
                NusaInput(
                  'Jumlah (Rp)',
                  controller: amtCtrl,
                  type: TextInputType.number,
                ),
                SizedBox(height: 20),
                _sheetActions(
                  ctx,
                  onSave: () async {
                    final cat = category.trim();
                    final desc = descCtrl.text.trim();
                    final amt = int.tryParse(amtCtrl.text.trim()) ?? 0;
                    if (cat.isEmpty || amt <= 0) {
                      TopToast.error(
                        context,
                        'Kategori dan jumlah wajib diisi',
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    final f = FinanceRepository(ref.read(databaseProvider));
                    await f.addExpense(
                      category: cat,
                      description: desc,
                      amount: amt,
                      branchId: _branchFilter,
                    );
                    final monthly = await f.getExpensesThisMonth(
                      branchId: _branchFilter,
                    );
                    final total = monthly
                        .where((e) => e.category == cat)
                        .fold<int>(0, (s, e) => s + e.amount);
                    if (total > 5000000 && mounted)
                      TopToast.info(
                        context,
                        '\u26a0 Pengeluaran "$cat" bulan ini sudah Rp${formatRupiah(total)}',
                      );
                    _load();
                  },
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      descCtrl.dispose();
      amtCtrl.dispose();
    });
  }

  void _manageCategories(
    bool isDark,
    StateSetter setSt,
    Function(List<ExpenseCategory>) onDone,
  ) {
    final nameCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(isDark),
            Text(
              'Kelola Kategori',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? NusaConfig.darkTextPrimary
                    : NusaConfig.textPrimary,
              ),
            ),
            SizedBox(height: 12),
            if (_categories.isNotEmpty) ...[
              ..._categories.map(
                (c) => ListTile(
                  dense: true,
                  title: Text(
                    c.name,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark
                          ? NusaConfig.darkTextPrimary
                          : NusaConfig.textPrimary,
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.close, size: 18, color: Colors.red),
                    onPressed: () async {
                      final f = FinanceRepository(ref.read(databaseProvider));
                      await f.deleteCategory(c.id);
                      final cats = await f.getCategories();
                      onDone(cats);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ),
              SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: NusaInput('Kategori Baru', controller: nameCtrl),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final f = FinanceRepository(ref.read(databaseProvider));
                    await f.addCategory(name);
                    final cats = await f.getCategories();
                    onDone(cats);
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NusaConfig.activePrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Tambah'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addPayroll() {
    final periodCtrl = TextEditingController();
    final salaryCtrl = TextEditingController();
    final bonusCtrl = TextEditingController();
    final dedCtrl = TextEditingController();
    int empId = _employees.isNotEmpty ? _employees.first.id : 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Container(
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            10,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetHandle(isDark),
                _sheetHeader(
                  Icons.people,
                  Color(0xFF8B5CF6),
                  'Tambah Payroll',
                  isDark,
                ),
                SizedBox(height: 16),
                if (_employees.isEmpty)
                  Text(
                    'Belum ada karyawan.',
                    style: TextStyle(
                      color: isDark
                          ? NusaConfig.darkTextSecondary
                          : NusaConfig.textSecondary,
                    ),
                  )
                else ...[
                  _sheetDropdown<int>(
                    label: 'Karyawan',
                    value: _employees.any((e) => e.id == empId)
                        ? empId
                        : _employees.first.id,
                    items: _employees.map((e) => e.id).toList(),
                    itemLabel: (id) {
                      final emp = _employees.firstWhere((e) => e.id == id);
                      var label = emp.name;
                      if (emp.baseSalary != null)
                        label += '  (${formatRupiah(emp.baseSalary!)})';
                      return label;
                    },
                    isDark: isDark,
                    onChanged: (v) {
                      setSt(() => empId = v!);
                      final emp = _employees.firstWhere((e) => e.id == v);
                      if (emp.baseSalary != null)
                        salaryCtrl.text = '${emp.baseSalary}';
                    },
                  ),
                  SizedBox(height: 12),
                  NusaInput('Periode (cth: Jul 26)', controller: periodCtrl),
                  SizedBox(height: 12),
                  NusaInput(
                    'Gaji (Rp)',
                    controller: salaryCtrl,
                    type: TextInputType.number,
                  ),
                  SizedBox(height: 12),
                  NusaInput(
                    'Bonus (Rp)',
                    controller: bonusCtrl,
                    type: TextInputType.number,
                  ),
                  SizedBox(height: 12),
                  NusaInput(
                    'Potongan (Rp)',
                    controller: dedCtrl,
                    type: TextInputType.number,
                  ),
                ],
                SizedBox(height: 20),
                _sheetActions(
                  ctx,
                  onSave: () async {
                    if (_employees.isEmpty) return;
                    Navigator.pop(ctx);
                    final f = FinanceRepository(ref.read(databaseProvider));
                    await f.addPayroll(
                      employeeId: empId,
                      period: periodCtrl.text.trim(),
                      salary: int.tryParse(salaryCtrl.text.trim()) ?? 0,
                      bonus: int.tryParse(bonusCtrl.text.trim()) ?? 0,
                      deduction: int.tryParse(dedCtrl.text.trim()) ?? 0,
                    );
                    _load();
                  },
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      periodCtrl.dispose();
      salaryCtrl.dispose();
      bonusCtrl.dispose();
      dedCtrl.dispose();
    });
  }

  void _addWaste() {
    final qtyCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String type = 'Expired';
    int prodId = _products.isNotEmpty ? _products.first.id : 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Container(
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            10,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetHandle(isDark),
                _sheetHeader(
                  Icons.delete_outline,
                  Color(0xFFEF4444),
                  'Tambah Waste',
                  isDark,
                ),
                SizedBox(height: 16),
                if (_products.isEmpty)
                  Text(
                    'Belum ada produk.',
                    style: TextStyle(
                      color: isDark
                          ? NusaConfig.darkTextSecondary
                          : NusaConfig.textSecondary,
                    ),
                  )
                else ...[
                  _sheetDropdown<int>(
                    label: 'Produk',
                    value: _products.any((p) => p.id == prodId)
                        ? prodId
                        : _products.first.id,
                    items: _products.map((p) => p.id).toList(),
                    itemLabel: (id) =>
                        _products.firstWhere((p) => p.id == id).name,
                    isDark: isDark,
                    onChanged: (v) => setSt(() => prodId = v!),
                  ),
                  SizedBox(height: 12),
                  NusaInput(
                    'Jumlah (pcs)',
                    controller: qtyCtrl,
                    type: TextInputType.number,
                  ),
                  SizedBox(height: 12),
                  _sheetDropdown(
                    label: 'Tipe',
                    value: type,
                    items: ['Expired', 'Rusak', 'Lainnya'],
                    isDark: isDark,
                    onChanged: (v) => setSt(() => type = v!),
                  ),
                  SizedBox(height: 12),
                  NusaInput('Alasan', controller: reasonCtrl),
                ],
                SizedBox(height: 20),
                _sheetActions(
                  ctx,
                  onSave: () async {
                    if (_products.isEmpty) return;
                    Navigator.pop(ctx);
                    final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                    final f = FinanceRepository(ref.read(databaseProvider));
                    await f.addWaste(
                      productId: prodId,
                      qty: qty,
                      reason: reasonCtrl.text.trim(),
                      type: type,
                    );
                    if (qty > 0)
                      await ProductRepository(
                        ref.read(databaseProvider),
                      ).adjustStock(prodId, -qty);
                    _load();
                  },
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      qtyCtrl.dispose();
      reasonCtrl.dispose();
    });
  }

  void _addRecurring() {
    final catCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    String frequency = 'bulanan';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Container(
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            10,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetHandle(isDark),
                _sheetHeader(
                  Icons.loop_rounded,
                  Color(0xFF8B5CF6),
                  'Tambah Pengeluaran Berulang',
                  isDark,
                ),
                SizedBox(height: 16),
                NusaInput(
                  'Kategori',
                  controller: catCtrl,
                  hint: 'Cth: Sewa, Internet',
                ),
                SizedBox(height: 12),
                NusaInput(
                  'Jumlah (Rp)',
                  controller: amtCtrl,
                  type: TextInputType.number,
                ),
                SizedBox(height: 12),
                NusaInput('Keterangan', controller: descCtrl),
                SizedBox(height: 12),
                _sheetDropdown(
                  label: 'Frekuensi',
                  value: frequency,
                  items: ['harian', 'mingguan', 'bulanan'],
                  isDark: isDark,
                  onChanged: (v) => setSt(() => frequency = v!),
                ),
                SizedBox(height: 20),
                _sheetActions(
                  ctx,
                  onSave: () async {
                    final cat = catCtrl.text.trim();
                    final amt = int.tryParse(amtCtrl.text.trim()) ?? 0;
                    if (cat.isEmpty || amt <= 0) {
                      TopToast.error(
                        context,
                        'Kategori dan jumlah wajib diisi',
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    final now = DateTime.now();
                    DateTime next;
                    switch (frequency) {
                      case 'harian':
                        next = now.add(Duration(days: 1));
                        break;
                      case 'mingguan':
                        next = now.add(Duration(days: 7));
                        break;
                      default:
                        next = DateTime(now.year, now.month + 1, now.day);
                    }
                    final f = FinanceRepository(ref.read(databaseProvider));
                    await f.addRecurring(
                      category: cat,
                      amount: amt,
                      description: descCtrl.text.trim(),
                      frequency: frequency,
                      nextDate: next,
                    );
                    _load();
                  },
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      catCtrl.dispose();
      descCtrl.dispose();
      amtCtrl.dispose();
    });
  }

  void _addLiquidity() {
    final catCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    final methodCtrl = TextEditingController();
    String type = 'in';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Container(
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            10,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetHandle(isDark),
                _sheetHeader(
                  Icons.account_balance_wallet,
                  NusaConfig.accentGreen,
                  'Tambah Likuiditas',
                  isDark,
                ),
                SizedBox(height: 16),
                _sheetDropdown(
                  label: 'Tipe',
                  value: type,
                  items: ['in', 'out'],
                  itemLabel: (s) => s == 'in' ? 'Pemasukan' : 'Pengeluaran',
                  isDark: isDark,
                  onChanged: (v) => setSt(() => type = v!),
                ),
                SizedBox(height: 12),
                NusaInput('Kategori', controller: catCtrl),
                SizedBox(height: 12),
                NusaInput('Keterangan', controller: descCtrl),
                SizedBox(height: 12),
                NusaInput(
                  'Jumlah (Rp)',
                  controller: amtCtrl,
                  type: TextInputType.number,
                ),
                SizedBox(height: 12),
                NusaInput('Metode (opsional)', controller: methodCtrl),
                SizedBox(height: 20),
                _sheetActions(
                  ctx,
                  onSave: () async {
                    Navigator.pop(ctx);
                    final f = FinanceRepository(ref.read(databaseProvider));
                    await f.addLiquidity(
                      type: type,
                      category: catCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      amount: int.tryParse(amtCtrl.text.trim()) ?? 0,
                      method: methodCtrl.text.trim().isEmpty
                          ? null
                          : methodCtrl.text.trim(),
                      branchId: _branchFilter,
                    );
                    _load();
                  },
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      catCtrl.dispose();
      descCtrl.dispose();
      amtCtrl.dispose();
      methodCtrl.dispose();
    });
  }

  // ── Sheet helpers ─────────────────────────────────────────────

  Widget _sheetHandle(bool isDark) => Container(
    margin: EdgeInsets.symmetric(vertical: 8),
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: isDark ? NusaConfig.darkDivider : NusaConfig.dividerColor,
      borderRadius: BorderRadius.circular(2),
    ),
  );

  Widget _sheetHeader(IconData icon, Color color, String title, bool isDark) =>
      Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? NusaConfig.darkTextPrimary
                    : NusaConfig.textPrimary,
              ),
            ),
          ),
        ],
      );

  Widget _sheetDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    String Function(T)? itemLabel,
    required bool isDark,
    Widget? trailing,
    required ValueChanged<T?> onChanged,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark
              ? NusaConfig.darkTextSecondary
              : NusaConfig.textSecondary,
        ),
      ),
      SizedBox(height: 6),
      Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? NusaConfig.darkInputBorder : NusaConfig.inputBorder,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  value: items.contains(value) ? value : items.first,
                  isExpanded: true,
                  isDense: true,
                  icon: Icon(
                    Icons.expand_more,
                    size: 20,
                    color: isDark
                        ? NusaConfig.darkTextSecondary
                        : NusaConfig.textSecondary,
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? NusaConfig.darkTextPrimary
                        : NusaConfig.textPrimary,
                  ),
                  dropdownColor: isDark ? NusaConfig.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  underline: SizedBox.shrink(),
                  items: items
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(
                            itemLabel != null ? itemLabel(t) : t.toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: onChanged,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    ],
  );

  Widget _sheetActions(
    BuildContext ctx, {
    required VoidCallback onSave,
    required bool isDark,
  }) => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: () => Navigator.pop(ctx),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: BorderSide(
              color: isDark
                  ? NusaConfig.darkInputBorder
                  : NusaConfig.inputBorder,
            ),
          ),
          child: Text(
            'Batal',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? NusaConfig.darkTextSecondary
                  : NusaConfig.textSecondary,
            ),
          ),
        ),
      ),
      SizedBox(width: 12),
      Expanded(
        child: ElevatedButton(
          onPressed: onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: NusaConfig.activePrimary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Simpan',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ],
  );
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? NusaConfig.darkBorder : Color(0xFFF3F4F6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? NusaConfig.darkTextPrimary
                    : NusaConfig.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? NusaConfig.darkTextSecondary
                    : NusaConfig.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
