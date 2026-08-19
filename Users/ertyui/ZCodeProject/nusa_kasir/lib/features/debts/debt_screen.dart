import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/customer_repository.dart';
import 'package:nusa_kasir/data/repositories/debt_repository.dart';
import 'package:nusa_kasir/data/repositories/installment_option_repository.dart';
import 'package:nusa_kasir/features/auth/employee_session_provider.dart';
import 'package:nusa_kasir/shared/widgets/empty_state.dart';
import 'package:nusa_kasir/shared/widgets/nusa_button.dart';
import 'package:nusa_kasir/shared/widgets/nusa_input.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

class DebtScreen extends ConsumerStatefulWidget {
  DebtScreen({super.key});
  @override
  ConsumerState<DebtScreen> createState() => _DebtScreenState();
}

class _DebtScreenState extends ConsumerState<DebtScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;
  List<CustomerDebt> _activeDebts = [];
  List<CustomerDebt> _lunasDebts = [];
  List<CustomerDebt> _overdueDebts = [];
  int _totalReceivables = 0;
  int _overdueCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = DebtRepository(ref.read(databaseProvider));
    final results = await Future.wait([
      repo.getActiveDebts(),
      repo.getAllDebts(),
      repo.getOverdueDebts(),
      repo.getTotalReceivables(),
    ]);
    final active = results[0] as List<CustomerDebt>;
    final all = results[1] as List<CustomerDebt>;
    final overdue = results[2] as List<CustomerDebt>;
    final total = results[3] as int;
    final lunas = all.where((d) => d.status == 'Lunas').toList();
    if (mounted) {
      setState(() {
        _activeDebts = active.where((d) => !_isOverdue(d)).toList();
        _lunasDebts = lunas;
        _overdueDebts = overdue;
        _totalReceivables = total;
        _overdueCount = overdue.length;
        _loading = false;
      });
    }
  }

  bool _isOverdue(CustomerDebt d) {
    return d.dueDate != null &&
        d.dueDate!.isBefore(DateTime.now()) &&
        d.status != 'Lunas';
  }

  // ── Add Debt ────────────────────────────────────────────────────────

  void _showAddSheet() {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    Customer? selectedCustomer;
    DateTime? dueDate;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return Container(
              decoration: BoxDecoration(
                color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: NusaConfig.dividerColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: NusaConfig.accentGold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.handshake_outlined,
                            color: NusaConfig.accentGold, size: 20),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Catat Piutang Baru',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? NusaConfig.darkTextPrimary
                              : NusaConfig.textPrimary,
                        ),
                      ),
                    ]),
                    SizedBox(height: 18),

                    // Customer picker
                    GestureDetector(
                      onTap: () async {
                        final picked = await _pickCustomer(ctx);
                        if (picked != null) setSt(() => selectedCustomer = picked);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? NusaConfig.darkInputFill
                              : NusaConfig.inputFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? NusaConfig.darkInputBorder
                                : NusaConfig.inputBorder,
                          ),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Text(
                              selectedCustomer?.name ?? 'Pilih Pelanggan',
                              style: TextStyle(
                                fontSize: 15,
                                color: selectedCustomer != null
                                    ? (isDark
                                        ? NusaConfig.darkTextPrimary
                                        : NusaConfig.textPrimary)
                                    : (isDark
                                        ? NusaConfig.darkTextTertiary
                                        : NusaConfig.textTertiary),
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              size: 20,
                              color: isDark
                                  ? NusaConfig.darkTextSecondary
                                  : NusaConfig.textSecondary),
                        ]),
                      ),
                    ),
                    SizedBox(height: 14),
                    NusaInput('Jumlah Piutang',
                        controller: amountCtrl,
                        type: TextInputType.number,
                        monospace: true,
                        hint: 'Cth: 500000'),
                    SizedBox(height: 14),

                    // Due date picker
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          useRootNavigator: true,
                          initialDate: DateTime.now().add(Duration(days: 7)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(Duration(days: 365 * 2)),
                          builder: (ctx, child) => Theme(
                            data: Theme.of(ctx).copyWith(
                              colorScheme: Theme.of(ctx).colorScheme.copyWith(
                                    primary: NusaConfig.activePrimary,
                                  ),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          setSt(() => dueDate = picked);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? NusaConfig.darkInputFill
                              : NusaConfig.inputFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? NusaConfig.darkInputBorder
                                : NusaConfig.inputBorder,
                          ),
                        ),
                        child: Row(children: [
                          Icon(Icons.calendar_today,
                              size: 18,
                              color: isDark
                                  ? NusaConfig.darkTextSecondary
                                  : NusaConfig.textSecondary),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              dueDate != null
                                  ? '${dueDate!.day}/${dueDate!.month}/${dueDate!.year}'
                                  : 'Jatuh Tempo (opsional)',
                              style: TextStyle(
                                fontSize: 15,
                                color: dueDate != null
                                    ? (isDark
                                        ? NusaConfig.darkTextPrimary
                                        : NusaConfig.textPrimary)
                                    : (isDark
                                        ? NusaConfig.darkTextTertiary
                                        : NusaConfig.textTertiary),
                              ),
                            ),
                          ),
                          if (dueDate != null)
                            GestureDetector(
                              onTap: () => setSt(() => dueDate = null),
                              child: Icon(Icons.close,
                                  size: 18,
                                  color: isDark
                                      ? NusaConfig.darkTextTertiary
                                      : NusaConfig.textTertiary),
                            ),
                        ]),
                      ),
                    ),
                    SizedBox(height: 14),
                    NusaInput('Keterangan (opsional)',
                        controller: descCtrl, hint: 'Cth: Belanja 5 kg beras'),
                    SizedBox(height: 20),
                    NusaButton(
                      'Simpan',
                      onPressed: saving
                          ? null
                          : () async {
                              final amountText = amountCtrl.text.trim();
                              if (amountText.isEmpty ||
                                  int.tryParse(amountText) == null ||
                                  int.parse(amountText) <= 0) {
                                TopToast.error(
                                    ctx, 'Jumlah piutang harus diisi');
                                return;
                              }
                              if (selectedCustomer == null) {
                                TopToast.error(ctx, 'Pilih pelanggan dulu');
                                return;
                              }
                              setSt(() => saving = true);
                              final repo =
                                  DebtRepository(ref.read(databaseProvider));
                              await repo.addDebt(
                                customerId: selectedCustomer!.id,
                                customerName: selectedCustomer!.name,
                                amount: int.parse(amountText),
                                dueDate: dueDate,
                                description: descCtrl.text.trim().isEmpty
                                    ? null
                                    : descCtrl.text.trim(),
                              );
                              if (mounted) {
                                Navigator.pop(ctx);
                                TopToast.success(ctx, 'Piutang tercatat');
                                _load();
                              }
                            },
                    ),
                    SizedBox(height: 4),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Customer?> _pickCustomer(BuildContext ctx) async {
    final customers =
        await CustomerRepository(ref.read(databaseProvider)).getCustomers();
    if (!ctx.mounted) return null;

    return showModalBottomSheet<Customer>(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (ctx2) {
        final isDark = Theme.of(ctx2).brightness == Brightness.dark;
        return Container(
          constraints: BoxConstraints(maxHeight: 400),
          decoration: BoxDecoration(
            color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(children: [
                  Text('Pilih Pelanggan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? NusaConfig.darkTextPrimary
                            : NusaConfig.textPrimary,
                      )),
                ]),
              ),
              Divider(),
              Flexible(
                child: customers.isEmpty
                    ? EmptyState(
                        icon: Icons.people_outline,
                        message: 'Belum ada pelanggan',
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.symmetric(vertical: 4),
                        itemCount: customers.length,
                        separatorBuilder: (_, __) =>
                            SizedBox(height: 2),
                        itemBuilder: (_, i) {
                          final c = customers[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: NusaConfig.activePrimary
                                  .withValues(alpha: 0.12),
                              child: Text(
                                c.name.isNotEmpty
                                    ? c.name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: NusaConfig.activePrimary,
                                ),
                              ),
                            ),
                            title: Text(c.name,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: c.phone != null && c.phone!.isNotEmpty
                                ? Text(c.phone!,
                                    style: TextStyle(fontSize: 12))
                                : null,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            onTap: () => Navigator.pop(ctx2, c),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Opsi Cicilan (Owner only) ───────────────────────────────────────

  /// Sheet CRUD paket cicilan — tambah/ubah/hapus pilihan bulan (Owner only).
  void _openInstallmentOptions() {
    final repo = InstallmentOptionRepository(ref.read(databaseProvider));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return FutureBuilder<List<InstallmentOption>>(
              future: repo.getAll(),
              builder: (ctx, snap) {
                final options = snap.data ?? [];
                return Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? NusaConfig.darkSurface
                        : NusaConfig.surfaceColor,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            margin: EdgeInsets.symmetric(vertical: 8),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: NusaConfig.dividerColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Row(children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: NusaConfig.accentGold
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.calendar_month_outlined,
                                color: NusaConfig.accentGold, size: 20),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Opsi Cicilan',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? NusaConfig.darkTextPrimary
                                    : NusaConfig.textPrimary,
                              ),
                            ),
                          ),
                          Text('Owner',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: NusaConfig.activePrimary,
                              )),
                        ]),
                        SizedBox(height: 6),
                        Text(
                          'Paket cicilan yang bisa dipilih kasir saat checkout.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? NusaConfig.darkTextTertiary
                                : NusaConfig.textTertiary,
                          ),
                        ),
                        SizedBox(height: 14),
                        if (options.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text('Belum ada paket cicilan',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? NusaConfig.darkTextTertiary
                                      : NusaConfig.textTertiary,
                                )),
                          )
                        else
                          ...options.map((o) {
                            return Container(
                              margin: EdgeInsets.only(bottom: 8),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? NusaConfig.darkSurface2
                                    : NusaConfig.inputFill,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        o.label ??
                                            '${o.months}× bulanan',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? NusaConfig.darkTextPrimary
                                              : NusaConfig.textPrimary,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text('${o.months} bulan',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? NusaConfig
                                                    .darkTextTertiary
                                                : NusaConfig
                                                    .textTertiary,
                                          )),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.edit_outlined,
                                      size: 18,
                                      color: NusaConfig.activePrimary),
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    await _editInstallmentOption(repo, o);
                                    setSt(() {});
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      size: 18,
                                      color: NusaConfig.error),
                                  onPressed: () async {
                                    final ok = await showDialog<bool>(
                                      context: ctx,
                                      builder: (dctx) => AlertDialog(
                                        backgroundColor: isDark
                                            ? NusaConfig.darkSurface
                                            : NusaConfig.surfaceColor,
                                        title: Text('Hapus paket cicilan?',
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight:
                                                    FontWeight.w700)),
                                        content: Text(
                                          '${o.label ?? '${o.months}× bulanan'} akan dihapus. '
                                          'Paket yang masih dipakai cicilan aktif tidak bisa dihapus.',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dctx, false),
                                            child: Text('Batal'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dctx, true),
                                            child: Text('Hapus',
                                                style: TextStyle(
                                                    color:
                                                        NusaConfig.error)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok == true) {
                                      final deleted =
                                          await repo.deleteIfUnused(o.id);
                                      if (!deleted) {
                                        TopToast.error(
                                            ctx,
                                            'Paket masih dipakai cicilan '
                                            'aktif');
                                      } else {
                                        TopToast.success(ctx,
                                            'Paket cicilan dihapus');
                                      }
                                      setSt(() {});
                                    }
                                  },
                                ),
                              ]),
                            );
                          }),
                        SizedBox(height: 8),
                        NusaButton('+ Tambah Paket', onPressed: () async {
                          Navigator.pop(ctx);
                          await _editInstallmentOption(repo, null);
                          setSt(() {});
                        }),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Dialog tambah/ubah paket cicilan (months + label).
  Future<void> _editInstallmentOption(
      InstallmentOptionRepository repo, InstallmentOption? existing) async {
    final monthsCtrl =
        TextEditingController(text: existing?.months.toString() ?? '');
    final labelCtrl = TextEditingController(text: existing?.label ?? '');

    return showDialog<void>(
      context: context,
      builder: (dctx) {
        final isDark = Theme.of(dctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor:
              isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
          title: Text(
            existing == null ? 'Tambah Paket Cicilan' : 'Ubah Paket Cicilan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NusaInput('Jumlah Bulan',
                    controller: monthsCtrl,
                    type: TextInputType.number,
                    monospace: true,
                    hint: 'Cth: 3'),
                SizedBox(height: 12),
                NusaInput('Label (opsional)',
                    controller: labelCtrl,
                    hint: 'Cth: 3× bulanan'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: Text('Batal'),
            ),
            TextButton(
              onPressed: () async {
                final months = int.tryParse(monthsCtrl.text.trim());
                if (months == null || months <= 0) {
                  TopToast.error(dctx, 'Jumlah bulan harus diisi');
                  return;
                }
                final label = labelCtrl.text.trim().isEmpty
                    ? null
                    : labelCtrl.text.trim();
                if (existing == null) {
                  final existingOpt = await repo.byMonths(months);
                  if (existingOpt != null) {
                    TopToast.error(dctx, 'Paket $months bulan sudah ada');
                    return;
                  }
                  await repo.add(months, label: label);
                } else {
                  await repo.update(existing.id, months, label: label);
                }
                if (dctx.mounted) Navigator.pop(dctx);
                TopToast.success(dctx,
                    existing == null ? 'Paket cicilan ditambahkan' : 'Paket cicilan diubah');
                _load();
              },
              child: Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  // ── Payment Bottom Sheet ────────────────────────────────────────────

  void _showPaymentSheet(CustomerDebt debt) async {
    final repo = DebtRepository(ref.read(databaseProvider));
    final payments = await repo.getPayments(debt.id);

    if (!mounted) return;

    // Debt ber-cicilan → default jumlah bayar = 1 cicilan (per bulan),
    // bukan sisa penuh. Kasir tetap bisa ubah jumlah.
    final isInstallment = debt.installmentMonths != null &&
        debt.installmentMonths! > 0 &&
        debt.remainingAmount > 0;
    final perMonth = isInstallment
        ? (debt.remainingAmount / debt.installmentMonths!).ceil()
        : 0;
    final defaultAmount = isInstallment ? perMonth : debt.remainingAmount;

    final amountCtrl = TextEditingController(text: '$defaultAmount');
    String method = 'Tunai';
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (ctx, scrollCtrl) => Container(
                decoration: BoxDecoration(
                  color:
                      isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: ListView(
                  controller: scrollCtrl,
                  padding: EdgeInsets.fromLTRB(20, 10, 20, 40),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: NusaConfig.dividerColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Debt info header
                    Row(children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: NusaConfig.accentGold
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.handshake_outlined,
                            color: NusaConfig.accentGold, size: 22),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(debt.customerName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? NusaConfig.darkTextPrimary
                                      : NusaConfig.textPrimary,
                                )),
                            SizedBox(height: 2),
                            Text(
                              'Total: ${formatRupiah(debt.amount)}  |  Sisa: ${formatRupiah(debt.remainingAmount)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? NusaConfig.darkTextSecondary
                                    : NusaConfig.textSecondary,
                              ),
                            ),
                            if (isInstallment) ...[
                              SizedBox(height: 4),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: NusaConfig.activePrimary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Cicilan ${debt.installmentMonths}× · '
                                  '${formatRupiah(perMonth)}/bulan',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: NusaConfig.activePrimary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: debt.status == 'Lunas'
                              ? NusaConfig.successSoft
                              : NusaConfig.warningSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          debt.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: debt.status == 'Lunas'
                                ? NusaConfig.successText
                                : NusaConfig.warningText,
                          ),
                        ),
                      ),
                    ]),

                    if (debt.description != null &&
                        debt.description!.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Text(debt.description!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? NusaConfig.darkTextTertiary
                                : NusaConfig.textTertiary,
                          )),
                    ],

                    // Progress bar
                    SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: debt.amount > 0
                            ? (debt.amount - debt.remainingAmount) /
                                debt.amount
                            : 0,
                        minHeight: 8,
                        backgroundColor: isDark
                            ? NusaConfig.darkDivider
                            : NusaConfig.dividerColor,
                        valueColor: AlwaysStoppedAnimation(
                          debt.status == 'Lunas'
                              ? NusaConfig.success
                              : NusaConfig.activePrimary,
                        ),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Dibayar: ${formatRupiah(debt.amount - debt.remainingAmount)} / ${formatRupiah(debt.amount)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? NusaConfig.darkTextTertiary
                            : NusaConfig.textTertiary,
                      ),
                    ),

                    // Payment form (only if not fully paid)
                    if (debt.status != 'Lunas') ...[
                      SizedBox(height: 20),
                      Text('Bayar Cicilan',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? NusaConfig.darkTextPrimary
                                : NusaConfig.textPrimary,
                          )),
                      SizedBox(height: 12),
                      NusaInput('Jumlah Bayar',
                          controller: amountCtrl,
                          type: TextInputType.number,
                          monospace: true,
                          hint: isInstallment
                              ? 'Cicilan ${debt.installmentMonths}× — ${formatRupiah(perMonth)}/bulan'
                              : formatRupiah(debt.remainingAmount)),
                      SizedBox(height: 12),

                      // Method dropdown
                      Text(
                        'Metode',
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
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? NusaConfig.darkInputFill
                              : NusaConfig.inputFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? NusaConfig.darkInputBorder
                                : NusaConfig.inputBorder,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: method,
                            isExpanded: true,
                            dropdownColor: isDark
                                ? NusaConfig.darkSurface
                                : NusaConfig.surfaceColor,
                            items: ['Tunai', 'Transfer', 'QRIS']
                                .map((m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(m,
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: isDark
                                                ? NusaConfig.darkTextPrimary
                                                : NusaConfig.textPrimary,
                                          )),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setSt(() => method = v);
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      NusaInput('Catatan (opsional)',
                          controller: notesCtrl,
                          hint: 'Cth: Bayar separuh dulu'),
                      SizedBox(height: 16),
                      NusaButton('Bayar', onPressed: () async {
                        final amountText = amountCtrl.text.trim();
                        final amt = int.tryParse(amountText);
                        if (amt == null || amt <= 0) {
                          TopToast.error(ctx, 'Jumlah bayar harus diisi');
                          return;
                        }
                        if (amt > debt.remainingAmount) {
                          TopToast.error(
                              ctx, 'Jumlah melebihi sisa piutang');
                          return;
                        }
                        await DebtRepository(ref.read(databaseProvider))
                            .addPayment(
                          debtId: debt.id,
                          amount: amt,
                          method: method,
                          notes: notesCtrl.text.trim().isEmpty
                              ? null
                              : notesCtrl.text.trim(),
                        );
                        if (mounted) {
                          Navigator.pop(ctx);
                          TopToast.success(ctx, 'Pembayaran berhasil');
                          _load();
                        }
                      }),
                    ],

                    // Payment history
                    SizedBox(height: 20),
                    Text('Riwayat Pembayaran',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? NusaConfig.darkTextPrimary
                              : NusaConfig.textPrimary,
                        )),
                    SizedBox(height: 8),
                    if (payments.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('Belum ada pembayaran',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? NusaConfig.darkTextTertiary
                                  : NusaConfig.textTertiary,
                            )),
                      )
                    else
                      ...payments.map((p) {
                        return Container(
                          margin: EdgeInsets.only(bottom: 8),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? NusaConfig.darkSurface2
                                : NusaConfig.inputFill,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: NusaConfig.accentGreen
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.payment,
                                  color: NusaConfig.accentGreen, size: 18),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(formatRupiah(p.amount),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? NusaConfig.darkTextPrimary
                                            : NusaConfig.textPrimary,
                                      )),
                                  SizedBox(height: 2),
                                  Text(
                                    '${p.method}  |  ${p.paidAt.day}/${p.paidAt.month}/${p.paidAt.year}${p.notes != null && p.notes!.isNotEmpty ? '  |  ${p.notes}' : ''}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? NusaConfig.darkTextTertiary
                                          : NusaConfig.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]),
                        );
                      }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = ref.read(employeeSessionProvider);
    final isOwner = session?.role == 'Owner';

    return ScreenScaffold(
      'Piutang Pelanggan',
      Column(
        children: [
          // Summary bar
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(14),
            margin: EdgeInsets.fromLTRB(16, 12, 16, 0),
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
              borderRadius: BorderRadius.circular(NusaConfig.radiusLG),
              border: Border.all(
                  color: isDark
                      ? NusaConfig.darkBorder
                      : NusaConfig.dividerColor),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Piutang',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? NusaConfig.darkTextTertiary
                            : NusaConfig.textTertiary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      formatRupiah(_totalReceivables),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: NusaConfig.accentGold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: isDark
                    ? NusaConfig.darkDivider
                    : NusaConfig.dividerColor,
              ),
              SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jatuh Tempo',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? NusaConfig.darkTextTertiary
                          : NusaConfig.textTertiary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Row(children: [
                    Text(
                      '$_overdueCount',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _overdueCount > 0
                            ? NusaConfig.activePrimary
                            : NusaConfig.success,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text('piutang',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? NusaConfig.darkTextSecondary
                              : NusaConfig.textSecondary,
                        )),
                  ]),
                ],
              ),
            ]),
          ),

          // Tabs
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color:
                    isDark ? NusaConfig.darkSurface : NusaConfig.backgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isDark
                        ? NusaConfig.darkBorder
                        : NusaConfig.dividerColor),
              ),
              child: TabBar(
                controller: _tabCtrl,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: NusaConfig.activePrimary,
                  borderRadius: BorderRadius.circular(8),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: isDark
                    ? NusaConfig.darkTextSecondary
                    : NusaConfig.textSecondary,
                labelStyle:
                    TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                unselectedLabelStyle:
                    TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(text: 'Aktif (${_activeDebts.length})'),
                  Tab(text: 'Lunas (${_lunasDebts.length})'),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Jatuh Tempo'),
                        if (_overdueCount > 0) ...[
                          SizedBox(width: 4),
                          Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: NusaConfig.accentGold,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$_overdueCount',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tab content
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildList(_activeDebts, isDark),
                      _buildList(_lunasDebts, isDark),
                      _buildList(_overdueDebts, isDark,
                          showDueBadge: true),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: NusaConfig.activePrimary,
        foregroundColor: Colors.white,
        icon: Icon(Icons.add),
        label: Text('Catat Piutang'),
        onPressed: _showAddSheet,
      ),
      actions: [
        if (isOwner)
          Padding(
            padding: EdgeInsets.only(right: 4),
            child: GestureDetector(
              onTap: _openInstallmentOptions,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? NusaConfig.darkSurface
                      : NusaConfig.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? NusaConfig.darkBorder
                        : NusaConfig.dividerColor,
                  ),
                ),
                child: Icon(Icons.settings_outlined,
                    size: 20,
                    color: isDark
                        ? NusaConfig.darkTextSecondary
                        : NusaConfig.textSecondary),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildList(List<CustomerDebt> debts, bool isDark,
      {bool showDueBadge = false}) {
    if (debts.isEmpty) {
      return EmptyState(
        icon: Icons.handshake_outlined,
        message: 'Tidak ada piutang',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: debts.length,
        separatorBuilder: (_, __) => SizedBox(height: 10),
        itemBuilder: (_, i) {
          final d = debts[i];
          final paid = d.amount - d.remainingAmount;
          final progress = d.amount > 0 ? paid / d.amount : 0.0;
          final isOverdue = d.dueDate != null &&
              d.dueDate!.isBefore(DateTime.now()) &&
              d.status != 'Lunas';

          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(NusaConfig.radiusLG),
            child: InkWell(
              onTap: () => _showPaymentSheet(d),
              borderRadius: BorderRadius.circular(NusaConfig.radiusLG),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? NusaConfig.darkSurface
                      : NusaConfig.surfaceColor,
                  borderRadius: BorderRadius.circular(NusaConfig.radiusLG),
                  border: Border.all(
                    color: isDark
                        ? NusaConfig.darkBorder
                        : NusaConfig.dividerColor,
                  ),
                ),
                padding: EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: NusaConfig.accentGold
                            .withValues(alpha: 0.12),
                        child: Text(
                          d.customerName.isNotEmpty
                              ? d.customerName[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: NusaConfig.accentGold,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.customerName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? NusaConfig.darkTextPrimary
                                      : NusaConfig.textPrimary,
                                )),
                            SizedBox(height: 2),
                            Text(
                              formatRupiah(d.amount),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: NusaConfig.accentGold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: d.status == 'Lunas'
                                  ? NusaConfig.successSoft
                                  : NusaConfig.warningSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              d.status,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: d.status == 'Lunas'
                                    ? NusaConfig.successText
                                    : NusaConfig.warningText,
                              ),
                            ),
                          ),
                          SizedBox(height: 6),
                          if (d.dueDate != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 10,
                                  color: isOverdue
                                      ? NusaConfig.activePrimary
                                      : (isDark
                                          ? NusaConfig.darkTextTertiary
                                          : NusaConfig.textTertiary),
                                ),
                                SizedBox(width: 3),
                                Text(
                                  '${d.dueDate!.day}/${d.dueDate!.month}/${d.dueDate!.year}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isOverdue
                                        ? NusaConfig.activePrimary
                                        : (isDark
                                            ? NusaConfig.darkTextTertiary
                                            : NusaConfig.textTertiary),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ]),
                    if (d.description != null &&
                        d.description!.isNotEmpty) ...[
                      SizedBox(height: 6),
                      Text(d.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? NusaConfig.darkTextTertiary
                                : NusaConfig.textTertiary,
                          )),
                    ],
                    if (d.installmentMonths != null &&
                        d.installmentMonths! > 0 &&
                        d.remainingAmount > 0) ...[
                      SizedBox(height: 6),
                      Row(children: [
                        Icon(Icons.calendar_month_outlined,
                            size: 11,
                            color: NusaConfig.activePrimary),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Cicilan ${d.installmentMonths}× · '
                            '${formatRupiah((d.remainingAmount / d.installmentMonths!).ceil())}/bulan',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: NusaConfig.activePrimary,
                            ),
                          ),
                        ),
                      ]),
                    ],
                    SizedBox(height: 10),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: isDark
                            ? NusaConfig.darkDivider
                            : NusaConfig.dividerColor,
                        valueColor: AlwaysStoppedAnimation(
                          d.status == 'Lunas'
                              ? NusaConfig.success
                              : NusaConfig.activePrimary,
                        ),
                      ),
                    ),
                    SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sisa: ${formatRupiah(d.remainingAmount)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: d.remainingAmount > 0
                                ? NusaConfig.activePrimary
                                : NusaConfig.success,
                          ),
                        ),
                        Text(
                          'Dibayar: ${formatRupiah(paid)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? NusaConfig.darkTextSecondary
                                : NusaConfig.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
