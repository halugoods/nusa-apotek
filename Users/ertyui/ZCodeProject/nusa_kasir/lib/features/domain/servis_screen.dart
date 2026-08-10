/// Bengkel & Servis: Service ticket management.
/// - Bengkel variant: vehicle workshop context (plate, brand, category, technician,
///   sparepart+jasa cost split, daily queue #SRV-xxx).
/// - Other variants (e.g. "servis" electronics repair): legacy device context.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/core/utils/receipt_printer.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/attendance_repository.dart';
import 'package:nusa_kasir/data/repositories/cashier_session_repository.dart';
import 'package:nusa_kasir/data/repositories/service_ticket_repository.dart';
import 'package:nusa_kasir/data/repositories/settings_repository.dart';
import 'package:nusa_kasir/features/pos/cart.dart';
import 'package:nusa_kasir/shared/widgets/customer_picker_button.dart';
import 'package:nusa_kasir/shared/widgets/nusa_form_field.dart';
import 'package:nusa_kasir/shared/widgets/nusa_input.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/stage_slider.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';
import 'package:url_launcher/url_launcher.dart';

/// Servis categories (bengkel variant).
const List<String> kServisCategories = [
  'Servis Rutin', 'Ganti Oli', 'Ban & Kaki', 'Kelistrikan',
  'AC', 'Body', 'Mesin', 'Lainnya',
];

const Map<String, Color> kServisCatColors = {
  'Servis Rutin': Color(0xFF3B82F6),
  'Ganti Oli': Color(0xFFF59E0B),
  'Ban & Kaki': Color(0xFF8B5CF6),
  'Kelistrikan': Color(0xFF10B981),
  'AC': Color(0xFF06B6D4),
  'Body': Color(0xFFF97316),
  'Mesin': Color(0xFFEF4444),
  'Lainnya': Color(0xFF6B7280),
};

class ServisScreen extends ConsumerStatefulWidget {
  const ServisScreen({super.key});

  @override
  ConsumerState<ServisScreen> createState() => _ServisScreenState();
}

class _ServisScreenState extends ConsumerState<ServisScreen> with SingleTickerProviderStateMixin {
  bool get _isBengkel => NusaConfig.isBengkelVariant;

  late TabController _tabController;
  final List<String> _tabs = ['Semua', 'Diagnosa', 'Estimasi', 'Perbaikan', 'Selesai', 'Diambil'];
  List<ServiceTicket> _all = [];
  List<ServiceTicket> _filtered = [];
  bool _loading = true;
  final _search = TextEditingController();
  Map<String, int> _counts = {};
  int _selectedIdx = 0;

  // ── Bengkel: technician filter ──
  List<String> _technicians = [];
  String? _technicianFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _search.addListener(_applyFilter);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = ref.read(databaseProvider);
    final repo = ServiceTicketRepository(db);
    final data = await repo.getAll();
    final counts = <String, int>{};
    for (final s in _tabs) {
      if (s == 'Semua') {
        counts[s] = data.length;
      } else {
        counts[s] = await repo.countByStatus(s);
      }
    }
    final technicians = _isBengkel ? await _loadStaff() : <String>[];
    if (!mounted) return;
    setState(() {
      _all = data;
      _counts = counts;
      _technicians = technicians;
      _loading = false;
    });
    _applyFilter();
  }

  /// Technician options come from the Karyawan (employee) system — all
  /// active staff, filtered by the bengkel's default working roles
  /// (Owner, Manager, Kasir, Gudang) + any custom roles the user added.
  Future<List<String>> _loadStaff() async {
    final emps = await AttendanceRepository(ref.read(databaseProvider)).getEmployees();
    const excluded = {'Finance'};
    final names = emps.where((e) => !excluded.contains(e.role)).map((e) => e.name.trim()).where((n) => n.isNotEmpty).toSet();
    final list = names.toList()..sort();
    if (list.isEmpty) return const [];
    return list;
  }

  void _selectStage(int idx) {
    setState(() => _selectedIdx = idx);
    _applyFilter();
  }

  void _applyFilter() {
    final q = _search.text.toLowerCase();
    final idx = _selectedIdx;
    var list = _all;
    if (idx > 0) list = list.where((t) => t.status == _tabs[idx]).toList();
    if (_isBengkel && _technicianFilter != null) {
      list = list.where((t) => t.technician == _technicianFilter).toList();
    }
    if (q.isNotEmpty) {
      list = list.where((t) =>
          t.customerName.toLowerCase().contains(q) ||
          (t.customerPhone ?? '').contains(q) ||
          t.deviceName.toLowerCase().contains(q) ||
          t.issue.toLowerCase().contains(q) ||
          (_isBengkel && (t.plateNumber ?? '').toLowerCase().contains(q))).toList();
    }
    setState(() => _filtered = list);
  }

  Color _chipColor(String status) {
    switch (status) {
      case 'Diagnosa': return NusaConfig.warning;
      case 'Estimasi': return NusaConfig.info;
      case 'Perbaikan': return NusaConfig.accentPurple;
      case 'Selesai': return NusaConfig.success;
      case 'Diambil': return NusaConfig.textTertiary;
      default: return NusaConfig.activePrimary;
    }
  }

  Color _catColor(String? cat) {
    if (cat == null || cat.isEmpty) return NusaConfig.activePrimary;
    return kServisCatColors[cat] ?? NusaConfig.activePrimary;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScreenScaffold(
      _isBengkel ? 'Tiket Servis Bengkel' : 'Tiket Servis',
      Column(children: [
        // ── Stage slider (pola booking/laundry — no empty left space) ──
        StageSlider(
          stages: _tabs.map((s) => StageData(
            label: s,
            color: s == 'Semua' ? NusaConfig.activePrimary : _chipColor(s),
            count: _counts[s] ?? 0,
          )).toList(),
          selectedIndex: _selectedIdx,
          onChanged: _selectStage,
          isDark: isDark,
        ),
        // ── Counts summary chips ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(children: _tabs.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            final c = _counts[s] ?? 0;
            final color = s == 'Semua' ? NusaConfig.activePrimary : _chipColor(s);
            final selected = i == _selectedIdx;
            return Expanded(child: GestureDetector(
              onTap: () => _selectStage(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? color.withOpacity(0.18) : color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: selected ? Border.all(color: color.withOpacity(0.4), width: 1.2) : null,
                  ),
                  child: Column(children: [
                    Text('$c', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                    Text(s, style: TextStyle(fontSize: 9, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
                  ]),
                ),
              ),
            ));
          }).toList()),
        ),
        // Search + customer picker (sejajar — pola booking/laundry)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: _isBengkel ? 'Cari pelanggan, kendaraan, plat...' : 'Cari pelanggan, device, atau masalah...',
                  hintStyle: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CustomerPickerButton(
              onPick: (r) {
                if (!mounted) return;
                final q = r.phone.isNotEmpty ? r.phone : r.name;
                if (q.isNotEmpty) {
                  _search.text = q;
                  _applyFilter();
                }
              },
            ),
          ]),
        ),
        // Bengkel: technician filter
        if (_isBengkel && _technicians.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Icon(Icons.engineering_outlined, size: 16, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.inputBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _technicianFilter,
                      isExpanded: true,
                      icon: Icon(Icons.arrow_drop_down, size: 20, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                      style: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
                      hint: Text('Semua teknisi', style: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Semua teknisi')),
                        ..._technicians.map((t) => DropdownMenuItem<String?>(value: t, child: Text(t))),
                      ],
                      onChanged: (v) { setState(() => _technicianFilter = v); _applyFilter(); },
                    ),
                  ),
                ),
              ),
            ]),
          ),
        // List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_isBengkel ? Icons.directions_car_filled_outlined : Icons.build_circle_outlined, size: 64, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                      const SizedBox(height: 16),
                      Text(_isBengkel ? 'Belum ada tiket servis' : 'Belum ada tiket servis', style: TextStyle(fontSize: 16, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _ticketCard(_filtered[i], isDark),
                    ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: NusaConfig.activePrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tiket Baru'),
      ),
    );
  }

  Widget _ticketCard(ServiceTicket t, bool isDark) {
    final statusColor = _chipColor(t.status);
    final catColor = _isBengkel ? _catColor(t.deviceName) : null;
    final hasVehicle = _isBengkel && (t.plateNumber?.isNotEmpty ?? false);
    final hasBrand = _isBengkel && (t.vehicleBrand?.isNotEmpty ?? false);
    final total = t.sparepartCost + t.serviceCost;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isDark ? NusaConfig.darkSurface2 : NusaConfig.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(t.customerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
            if (t.queueNumber != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: NusaConfig.accentGold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: NusaConfig.accentGold.withOpacity(0.3)),
                ),
                child: Text('#SRV-${t.queueNumber.toString().padLeft(3, '0')}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: NusaConfig.accentGold)),
              ),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
              child: Text(t.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
            ),
          ]),
          // Vehicle row (bengkel): plate + brand + year
          if (hasVehicle || hasBrand) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (hasVehicle)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: NusaConfig.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: NusaConfig.warning.withOpacity(0.35)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.local_taxi_outlined, size: 12, color: NusaConfig.warning),
                    const SizedBox(width: 4),
                    Text(t.plateNumber!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: NusaConfig.warning)),
                  ]),
                ),
              if (hasBrand)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: catColor!.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(t.vehicleBrand!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: catColor)),
                ),
              if (t.vehicleYear != null && t.vehicleYear! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? NusaConfig.darkSurface : NusaConfig.inputFill,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${t.vehicleYear}', style: const TextStyle(fontSize: 11)),
                ),
              if (t.technician != null && t.technician!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: NusaConfig.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.engineering_outlined, size: 12, color: NusaConfig.info),
                    const SizedBox(width: 4),
                    Text('👤 ${t.technician}', style: const TextStyle(fontSize: 11, color: NusaConfig.info)),
                  ]),
                ),
            ]),
          ],
          if (t.customerPhone != null && t.customerPhone!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: GestureDetector(
                onTap: () => _callCustomer(t.customerPhone!),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.phone_outlined, size: 12, color: NusaConfig.activePrimary),
                  const SizedBox(width: 4),
                  Text(t.customerPhone!, style: TextStyle(fontSize: 12, color: NusaConfig.activePrimary)),
                ]),
              ),
            ),
          const SizedBox(height: 6),
          Row(children: [
            Icon(_isBengkel ? Icons.directions_car_filled_outlined : Icons.devices, size: 16, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
            const SizedBox(width: 4),
            Expanded(child: Text(t.deviceName, style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary))),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.report_problem_outlined, size: 16, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
            const SizedBox(width: 4),
            Expanded(child: Text(t.issue, style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis)),
          ]),
          if (t.estimatedCost > 0 || t.finalCost > 0 || (_isBengkel && total > 0)) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (_isBengkel && total > 0)
                Chip(label: Text('Estimasi: ${formatRupiah(total)}', style: const TextStyle(fontSize: 11)), backgroundColor: NusaConfig.warning.withOpacity(0.1), side: BorderSide.none, visualDensity: VisualDensity.compact),
              if (_isBengkel && t.sparepartCost > 0)
                Chip(label: Text('Sparepart: ${formatRupiah(t.sparepartCost)}', style: const TextStyle(fontSize: 11)), backgroundColor: NusaConfig.info.withOpacity(0.1), side: BorderSide.none, visualDensity: VisualDensity.compact),
              if (_isBengkel && t.serviceCost > 0)
                Chip(label: Text('Jasa: ${formatRupiah(t.serviceCost)}', style: const TextStyle(fontSize: 11)), backgroundColor: NusaConfig.accentGreen.withOpacity(0.1), side: BorderSide.none, visualDensity: VisualDensity.compact),
              if (!_isBengkel && t.estimatedCost > 0)
                Chip(label: Text('Estimasi: ${formatRupiah(t.estimatedCost)}', style: const TextStyle(fontSize: 11)), backgroundColor: NusaConfig.warning.withOpacity(0.1), side: BorderSide.none, visualDensity: VisualDensity.compact),
              if (t.finalCost > 0) ...[
                Chip(label: Text('Final: ${formatRupiah(t.finalCost)}', style: const TextStyle(fontSize: 11)), backgroundColor: NusaConfig.success.withOpacity(0.1), side: BorderSide.none, visualDensity: VisualDensity.compact),
              ],
            ]),
          ],
          const SizedBox(height: 8),
          // ── Quick status chips (pola salon) ──
          Row(children: [
            Icon(Icons.rocket_launch_rounded, size: 13, color: NusaConfig.info),
            const SizedBox(width: 6),
            Expanded(
              child: Wrap(spacing: 6, runSpacing: 4, children: _nextStages(t).map((ns) {
                final nsColor = ns['color'] as Color;
                return GestureDetector(
                  onTap: () => _jumpToStatus(t, ns['label']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: nsColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: nsColor.withOpacity(0.3)),
                    ),
                    child: Text(ns['label'], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: nsColor)),
                  ),
                );
              }).toList()),
            ),
          ]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _actionButton(Icons.print_outlined, 'Cetak', () => _printTicketFlow(t), isDark),
            const SizedBox(width: 4),
            _actionButton(Icons.point_of_sale_outlined, 'Kasir', () => _quickPos(t), isDark),
            const SizedBox(width: 4),
            _actionButton(Icons.edit_outlined, 'Edit', () => _openForm(ticket: t), isDark),
            const SizedBox(width: 4),
            _actionButton(Icons.delete_outline, 'Hapus', () => _deleteTicket(t), isDark),
          ]),
        ]),
      ),
    );
  }

  List<Map<String, dynamic>> _nextStages(ServiceTicket t) {
    final result = <Map<String, dynamic>>[];
    var current = t.status;
    for (int i = 0; i < 4; i++) {
      final next = _nextStatus(current);
      if (next == null) break;
      result.add({'label': next, 'color': _chipColor(next)});
      current = next;
    }
    return result;
  }

  Widget _actionButton(IconData icon, String tooltip, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface : NusaConfig.inputFill,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Tooltip(message: tooltip, child: Icon(icon, size: 18, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary)),
      ),
    );
  }

  String? _nextStatus(String s) {
    const flow = {'Diagnosa': 'Estimasi', 'Estimasi': 'Perbaikan', 'Perbaikan': 'Selesai', 'Selesai': 'Diambil'};
    return flow[s];
  }

  Future<void> _jumpToStatus(ServiceTicket t, String to) async {
    await ServiceTicketRepository(ref.read(databaseProvider)).updateStatus(t.id, to);
    TopToast.success(context, 'Status → $to ✓');
    _load();
  }

  Future<void> _deleteTicket(ServiceTicket t) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Hapus Tiket?'),
      content: Text('Hapus tiket servis ${t.customerName} — ${t.deviceName}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (ok == true) {
      await ServiceTicketRepository(ref.read(databaseProvider)).delete(t.id);
      TopToast.success(context, 'Tiket dihapus');
      _load();
    }
  }

  // ── POS checkout trigger (pola booking salon "Buat Pesanan") ──

  /// Buka POS untuk tiket ini: muat jasa + sparepart ke keranjang kasir
  /// (sebagai item "Jasa" / "Sparepart"), lalu pindah ke layar POS.
  /// Pelanggan (nama + telepon) dikirim via query param agar otomatis
  /// tersambung saat checkout.
  Future<void> _quickPos(ServiceTicket t) async {
    final notifier = ref.read(cartProvider.notifier);
    notifier.clear();
    if (t.serviceCost > 0) {
      notifier.addProduct(-(t.id * 10 + 1), 'Jasa Servis - ${t.deviceName}', t.serviceCost,
          note: t.plateNumber != null && t.plateNumber!.isNotEmpty ? 'Plat: ${t.plateNumber}' : null);
    }
    if (t.sparepartCost > 0) {
      notifier.addProduct(-(t.id * 10 + 2), 'Sparepart - ${t.deviceName}', t.sparepartCost);
    }
    final sessionId = await CashierSessionRepository(ref.read(databaseProvider)).getLast();
    if (!mounted) return;
    final qp = <String, String>{};
    if (sessionId != null) qp['sessionId'] = sessionId.id.toString();
    if (t.customerName.isNotEmpty) qp['customer'] = Uri.encodeComponent(t.customerName);
    if (t.customerPhone != null && t.customerPhone!.isNotEmpty) {
      qp['customerPhone'] = Uri.encodeComponent(t.customerPhone!);
    }
    final uri = Uri(path: '/kasir', queryParameters: qp.isNotEmpty ? qp : null);
    context.push(uri.toString());
    TopToast.success(context, 'Buka kasir untuk ${t.customerName}');
  }

  /// Tap-to-call pelanggan (pola suppliers_screen).
  Future<void> _callCustomer(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      TopToast.error(context, 'Tidak bisa membuka dialer');
    }
  }

  /// Cetak tiket servis ke printer thermal Bluetooth (ESC/POS).
  Future<void> _printTicket(ServiceTicket t) async {
    final repo = SettingsRepository(ref.read(databaseProvider));
    final storeName = await repo.getStoreName();
    if (!mounted) return;
    final paperSize = await SecureStore.getPaperSize();
    final logoPath = await SecureStore.getPrinterLogoPath();
    if (logoPath != null) await ReceiptPrinter.loadLogo(logoPath);
    final lines = <ReceiptLine>[
      const ReceiptLine(name: 'JASA SERVIS', qty: 1, price: 0),
    ];
    if (t.plateNumber != null && t.plateNumber!.isNotEmpty) {
      lines.add(ReceiptLine(name: 'Plat: ${t.plateNumber}', qty: 1, price: 0));
    }
    if (t.vehicleBrand != null && t.vehicleBrand!.isNotEmpty) {
      lines.add(ReceiptLine(name: 'Kendaraan: ${t.vehicleBrand}', qty: 1, price: 0));
    }
    lines
      ..add(ReceiptLine(name: 'Kategori: ${t.deviceName}', qty: 1, price: 0))
      ..add(ReceiptLine(name: 'Keluhan: ${t.issue}', qty: 1, price: 0));
    if (t.technician != null && t.technician!.isNotEmpty) {
      lines.add(ReceiptLine(name: 'Teknisi: ${t.technician}', qty: 1, price: 0));
    }
    lines
      ..add(ReceiptLine(name: 'Status: ${t.status}', qty: 1, price: 0))
      ..add(ReceiptLine(name: 'Estimasi: ${formatRupiah(t.sparepartCost + t.serviceCost)}', qty: 1, price: 0));
    if (t.sparepartCost > 0) {
      lines.add(ReceiptLine(name: 'Sparepart: ${formatRupiah(t.sparepartCost)}', qty: 1, price: 0));
    }
    if (t.serviceCost > 0) {
      lines.add(ReceiptLine(name: 'Jasa: ${formatRupiah(t.serviceCost)}', qty: 1, price: 0));
    }
    if (t.finalCost > 0) {
      lines.add(ReceiptLine(name: 'Total: ${formatRupiah(t.finalCost)}', qty: 1, price: 0));
    }
    if (t.notes != null && t.notes!.isNotEmpty) {
      lines.add(ReceiptLine(name: 'Catatan: ${t.notes}', qty: 1, price: 0));
    }
    final total = t.finalCost > 0 ? t.finalCost : t.sparepartCost + t.serviceCost;
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final queueStr = t.queueNumber != null ? 'Tiket #SRV-${t.queueNumber.toString().padLeft(3, '0')}' : '';

    final ok = await ReceiptPrinter.printTicket(
      storeName: storeName,
      lines: lines,
      total: total,
      paperWidth: paperSize,
      dateStr: dateStr,
      ticketNo: queueStr,
      customerName: t.customerName,
      customerPhone: t.customerPhone,
    );
    if (!mounted) return;
    if (ok) {
      TopToast.success(context, 'Tiket servis dicetak');
    } else {
      TopToast.error(context, 'Gagal mencetak. Hubungkan printer di Pengaturan dulu.');
    }
  }

  /// Hubungkan printer (reuse alur PrinterSettingsSheet, tanpa mengubah
  /// printer utama) lalu cetak tiket servis.
  Future<void> _printTicketFlow(ServiceTicket t) async {
    final printer = ReceiptPrinter();
    try {
      if (!await ReceiptPrinter.ensureBluetoothReady()) {
        if (mounted) TopToast.error(context, 'Bluetooth tidak siap. Periksa izin pengaturan.');
        return;
      }
      final devices = await printer.discover();
      if (devices.isEmpty) {
        if (mounted) TopToast.error(context, 'Tidak ada printer ditemukan. Pasangkan printer di Pengaturan.');
        return;
      }
      final repo = SettingsRepository(ref.read(databaseProvider));
      final saved = await repo.getPrinterAddress();
      PrinterDevice target = devices.first;
      if (saved != null && saved.contains('|')) {
        final savedAddr = saved.split('|').last;
        final found = devices.where((d) => d.address == savedAddr);
        if (found.isNotEmpty) target = found.first;
      }
      await printer.connect(target);
      await _printTicket(t);
    } catch (_) {
      if (mounted) TopToast.error(context, 'Gagal mencetak tiket servis');
    } finally {
      await printer.dispose();
    }
  }

  // ── Form ────────────────────────────────────────────────────────────

  Future<void> _openForm({ServiceTicket? ticket}) async {
    final isEdit = ticket != null;
    final nameC = TextEditingController(text: ticket?.customerName ?? '');
    final phoneC = TextEditingController(text: ticket?.customerPhone ?? '');
    final deviceC = TextEditingController(text: ticket?.deviceName ?? '');
    final issueC = TextEditingController(text: ticket?.issue ?? '');
    final estC = TextEditingController(text: ticket != null && ticket.estimatedCost > 0 ? '${ticket.estimatedCost}' : '');
    final finalC = TextEditingController(text: ticket != null && ticket.finalCost > 0 ? '${ticket.finalCost}' : '');
    final notesC = TextEditingController(text: ticket?.notes ?? '');

    // ── Bengkel fields ──
    final plateC = TextEditingController(text: ticket?.plateNumber ?? '');
    final brandC = TextEditingController(text: ticket?.vehicleBrand ?? '');
    final yearC = TextEditingController(text: (ticket?.vehicleYear ?? 0) > 0 ? '${ticket?.vehicleYear}' : '');
    final spareC = TextEditingController(text: (ticket?.sparepartCost ?? 0) > 0 ? '${ticket?.sparepartCost}' : '');
    final svcC = TextEditingController(text: (ticket?.serviceCost ?? 0) > 0 ? '${ticket?.serviceCost}' : '');
    String? category = _isBengkel ? (ticket?.deviceName != null && kServisCategories.contains(ticket!.deviceName) ? ticket.deviceName : null) : null;
    String? technician = ticket?.technician;

    // ── Auto final-cost: sinkron dari sparepart + jasa (bisa di-override manual) ──
    bool finalAuto = ticket == null ||
        !(ticket.finalCost > 0 &&
            ticket.finalCost != (ticket.sparepartCost + ticket.serviceCost));
    void syncFinal() {
      if (!finalAuto) return;
      final auto = (int.tryParse(spareC.text) ?? 0) + (int.tryParse(svcC.text) ?? 0);
      if (auto > 0 && finalC.text != '$auto') finalC.text = '$auto';
      if (auto == 0 && finalC.text.isNotEmpty && int.tryParse(finalC.text) == 0) {
        finalC.text = '';
      }
    }

    spareC.addListener(syncFinal);
    svcC.addListener(syncFinal);
    finalC.addListener(() {
      final auto = (int.tryParse(spareC.text) ?? 0) + (int.tryParse(svcC.text) ?? 0);
      if ((int.tryParse(finalC.text) ?? -1) != auto) finalAuto = false;
    });

    final formKey = GlobalKey<FormState>();

    // Queue number for new bengkel tickets
    String? queueLabel;
    if (!isEdit && _isBengkel) {
      final repo = ServiceTicketRepository(ref.read(databaseProvider));
      final nextQ = await repo.getNextQueue();
      queueLabel = '#SRV-${nextQ.toString().padLeft(3, '0')}';
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Row(children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: (_isBengkel ? NusaConfig.warning : NusaConfig.info).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_isBengkel ? Icons.directions_car_filled_outlined : Icons.build_outlined, color: _isBengkel ? NusaConfig.warning : NusaConfig.info, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(isEdit ? 'Edit Tiket' : 'Tiket Servis Baru', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      if (queueLabel != null)
                        Text(queueLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: NusaConfig.accentGold)),
                    ])),
                  ]),
                  const SizedBox(height: 18),
                  if (_isBengkel) ...[
                    // ── Vehicle identity (bengkel) ──
                    NusaInput('Plat Nomor', controller: plateC, hint: 'Contoh: B 1234 XYZ'),
                    const SizedBox(height: 12),
                    NusaInput('Merk / Model Kendaraan', controller: brandC, hint: 'Contoh: Honda Beat, Toyota Avanza'),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: NusaInput('Tahun', controller: yearC, type: TextInputType.number, hint: 'Contoh: 2020')),
                      const SizedBox(width: 12),
                      Expanded(child: NusaInput('Nama Pelanggan', controller: nameC, hint: 'Nama pemilik')),
                    ]),
                    const SizedBox(height: 12),
                    NusaInput('No. Telepon', controller: phoneC, type: TextInputType.phone, hint: 'Contoh: 0812-3456-7890'),
                    const SizedBox(height: 12),
                    // Kategori servis
                    Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: NusaConfig.warning.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.build_rounded, color: NusaConfig.warning, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.inputBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: category,
                              isExpanded: true,
                              icon: Icon(Icons.arrow_drop_down, size: 20, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                              style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
                              hint: Text('Kategori servis', style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
                              items: [
                                const DropdownMenuItem<String?>(value: null, child: Text('Kategori servis')),
                                ...kServisCategories.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c))),
                              ],
                              onChanged: (v) => setModalState(() => category = v),
                            ),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    // Teknisi
                    Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: NusaConfig.info.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.engineering_outlined, color: NusaConfig.info, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? NusaConfig.darkInputFill : NusaConfig.inputFill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? NusaConfig.darkBorder : NusaConfig.inputBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: technician,
                              isExpanded: true,
                              icon: Icon(Icons.arrow_drop_down, size: 20, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                              style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary),
                              hint: Text('Pilih teknisi (opsional)', style: TextStyle(fontSize: 13, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary)),
                              items: [
                                const DropdownMenuItem<String?>(value: null, child: Text('Pilih teknisi (opsional)')),
                                ..._technicians.map((t) => DropdownMenuItem<String?>(value: t, child: Text(t))),
                              ],
                              onChanged: (v) => setModalState(() => technician = v),
                            ),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    // Teknisi belum ada di Karyawan? arahkan ke menu Karyawan
                    if (_technicians.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(children: [
                          Icon(Icons.info_outline, size: 13, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                          const SizedBox(width: 6),
                          Expanded(child: Text('Belum ada karyawan. Tambah di menu Karyawan dulu agar bisa dipilih jadi teknisi.',
                            style: TextStyle(fontSize: 11, color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary))),
                        ]),
                      ),
                    NusaFormField(label: 'Keluhan / Pekerjaan', controller: issueC, hintText: 'Deskripsikan pekerjaan servis...', maxLines: 3, validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null),
                    const SizedBox(height: 12),
                    // ── Cost split: sparepart + jasa ──
                    Row(children: [
                      Expanded(child: NusaFormField(label: 'Biaya Sparepart', controller: spareC, hintText: 'Rp', keyboardType: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(child: NusaFormField(label: 'Biaya Jasa', controller: svcC, hintText: 'Rp', keyboardType: TextInputType.number)),
                    ]),
                    const SizedBox(height: 12),
                    NusaFormField(label: 'Biaya Final (auto dari sparepart + jasa)', controller: finalC, hintText: 'Rp', keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                  ] else ...[
                    // ── Legacy device form ──
                    NusaFormField(label: 'Nama Pelanggan', controller: nameC, hintText: 'Nama pelanggan', validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null),
                    const SizedBox(height: 12),
                    NusaFormField(label: 'No. Telepon', controller: phoneC, hintText: 'Contoh: 0812-3456-7890', keyboardType: TextInputType.phone),
                    const SizedBox(height: 12),
                    NusaFormField(label: 'Nama Perangkat', controller: deviceC, hintText: 'Contoh: iPhone 13, Samsung A52', validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null),
                    const SizedBox(height: 12),
                    NusaFormField(label: 'Keluhan / Masalah', controller: issueC, hintText: 'Deskripsikan masalah perangkat...', maxLines: 3, validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: NusaFormField(label: 'Estimasi Biaya', controller: estC, hintText: 'Rp', keyboardType: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(child: NusaFormField(label: 'Biaya Final', controller: finalC, hintText: 'Rp', keyboardType: TextInputType.number)),
                    ]),
                    const SizedBox(height: 12),
                  ],
                  NusaFormField(label: 'Catatan', controller: notesC, hintText: 'Catatan tambahan...', maxLines: 2),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NusaConfig.activePrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final db = ref.read(databaseProvider);
                        final repo = ServiceTicketRepository(db);
                        if (_isBengkel) {
                          // ── Bengkel save ──
                          final spare = int.tryParse(spareC.text) ?? 0;
                          final svc = int.tryParse(svcC.text) ?? 0;
                          final totalEst = spare + svc;
                          final plate = plateC.text.trim().toUpperCase();
                          final brand = brandC.text.trim();
                          final year = int.tryParse(yearC.text);
                          final cat = category ?? 'Lainnya';
                          if (isEdit) {
                            await repo.updateCost(
                              ticket.id,
                              customerName: nameC.text.trim(),
                              customerPhone: phoneC.text.trim().isEmpty ? null : phoneC.text.trim(),
                              deviceName: cat,
                              issue: issueC.text.trim(),
                              estimatedCost: totalEst,
                              finalCost: int.tryParse(finalC.text),
                              notes: notesC.text.trim().isEmpty ? null : notesC.text.trim(),
                              plateNumber: plate.isEmpty ? null : plate,
                              vehicleBrand: brand.isEmpty ? null : brand,
                              vehicleYear: (year ?? 0) > 0 ? year : null,
                              technician: technician?.isEmpty ?? true ? null : technician,
                              sparepartCost: spare,
                              serviceCost: svc,
                            );
                            TopToast.success(context, 'Tiket diperbarui ✓');
                          } else {
                            final nextQ = await repo.getNextQueue();
                            await repo.add(
                              customerName: nameC.text.trim(),
                              customerPhone: phoneC.text.trim().isEmpty ? null : phoneC.text.trim(),
                              deviceName: cat,
                              issue: issueC.text.trim(),
                              estimatedCost: totalEst,
                              notes: notesC.text.trim().isEmpty ? null : notesC.text.trim(),
                              plateNumber: plate.isEmpty ? null : plate,
                              vehicleBrand: brand.isEmpty ? null : brand,
                              vehicleYear: (year ?? 0) > 0 ? year : null,
                              technician: technician?.isEmpty ?? true ? null : technician,
                              sparepartCost: spare,
                              serviceCost: svc,
                              queueNumber: nextQ,
                            );
                            TopToast.success(context, 'Tiket servis baru ditambahkan ✓');
                          }
                        } else {
                          // ── Legacy device save ──
                          final estCost = int.tryParse(estC.text) ?? 0;
                          if (isEdit) {
                            await repo.updateCost(ticket.id, finalCost: int.tryParse(finalC.text), notes: notesC.text.isNotEmpty ? notesC.text : null);
                            TopToast.success(context, 'Tiket diperbarui ✓');
                          } else {
                            await repo.add(
                              customerName: nameC.text.trim(),
                              customerPhone: phoneC.text.trim().isEmpty ? null : phoneC.text.trim(),
                              deviceName: deviceC.text.trim(),
                              issue: issueC.text.trim(),
                              estimatedCost: estCost,
                              notes: notesC.text.trim().isEmpty ? null : notesC.text.trim(),
                            );
                            TopToast.success(context, 'Tiket servis baru ditambahkan ✓');
                          }
                        }
                        Navigator.pop(ctx);
                        _load();
                      },
                      child: Text(isEdit ? 'Simpan Perubahan' : 'Tambah Tiket'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ]),
              ),
            ),
          );
        });
      },
    );
  }
}
