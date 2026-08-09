/// F&B: Table management — polished card list with grid toggle.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/dining_table_repository.dart';
import 'package:nusa_kasir/data/repositories/tab_repository.dart';
import 'package:nusa_kasir/features/pos/cart.dart';
import 'package:nusa_kasir/shared/widgets/nusa_form_field.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

class MejaScreen extends ConsumerStatefulWidget {
  const MejaScreen({super.key});

  @override
  ConsumerState<MejaScreen> createState() => _MejaScreenState();
}

class _MejaScreenState extends ConsumerState<MejaScreen> {
  List<DiningTable> _tables = [];
  bool _loading = true;
  bool _listView = true; // true = list, false = grid
  int _gridCols = 4;
  Map<int, List<OpenTab>> _tableTabs = {}; // open tabs per table id
  bool _payFirst = false; // FnB: bayar dulu di kasir, baru dapat meja

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) _load(); // reload tables when navigating back from POS
    _didInit = true;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = ref.read(databaseProvider);
    final tableRepo = DiningTableRepository(db);
    final data = await tableRepo.getAll();
    // Auto-create default tables if empty
    if (data.isEmpty) {
      for (var i = 0; i < 12; i++) {
        await tableRepo.add(name: 'Meja ${i + 1}');
      }
      final fresh = await tableRepo.getAll();
      if (!mounted) return;
      setState(() {
        _tables = fresh;
        _loading = false;
      });
    } else {
      if (!mounted) return;
      setState(() {
        _tables = data;
        _loading = false;
      });
    }
    // Load open tabs for all tables
    _loadTabs();
    // Load FnB payment flow preference
    _loadPayFirst();
  }

  Future<void> _loadPayFirst() async {
    final v = await SecureStore.getFnbPaymentFirst();
    if (mounted) setState(() => _payFirst = v);
  }

  Future<void> _togglePayFirst() async {
    final next = !_payFirst;
    await SecureStore.setFnbPaymentFirst(next);
    if (mounted) setState(() => _payFirst = next);
  }

  Future<void> _loadTabs() async {
    final db = ref.read(databaseProvider);
    final tabRepo = TabRepository(db);
    final allTabs = await tabRepo.getOpen();
    final map = <int, List<OpenTab>>{};
    for (final tab in allTabs) {
      if (tab.tableId != null) {
        map.putIfAbsent(tab.tableId!, () => []).add(tab);
      }
    }
    if (mounted) setState(() => _tableTabs = map);
  }

  // ── Helpers ──

  Color _statusColor(String s) {
    switch (s) {
      case 'Kosong':
        return NusaConfig.success;
      case 'Dipesan':
        return NusaConfig.warning;
      case 'Tutup':
        return NusaConfig.textTertiary;
      default:
        return NusaConfig.activePrimary;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'Kosong':
        return Icons.check_circle;
      case 'Dipesan':
        return Icons.pending_actions;
      case 'Tutup':
        return Icons.cancel;
      default:
        return Icons.table_bar;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'Kosong':
        return 'Kosong';
      case 'Dipesan':
        return 'Dipesan';
      case 'Tutup':
        return 'Tutup';
      default:
        return s;
    }
  }

  List<OpenTab> _tabsForTable(int tableId) =>
      _tableTabs[tableId] ?? [];

  int _itemCountFromTabs(int tableId) {
    int count = 0;
    for (final tab in _tabsForTable(tableId)) {
      try {
        final items =
            (json.decode(tab.itemsJson) as List).cast<Map<String, dynamic>>();
        count += items.fold<int>(
            0, (sum, item) => sum + ((item['qty'] as int?) ?? 1));
      } catch (_) {}
    }
    return count;
  }

  int _totalFromTabs(int tableId) {
    int total = 0;
    for (final tab in _tabsForTable(tableId)) {
      total += tab.total;
    }
    return total;
  }

  // ── Stats ──

  int get _totalCount => _tables.length;
  int get _bookedCount =>
      _tables.where((t) => t.status == 'Dipesan').length;
  int get _emptyCount =>
      _tables.where((t) => t.status == 'Kosong').length;

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScreenScaffold(
      'Meja & Pesanan',
      _loading
          ? const Center(child: CircularProgressIndicator())
          : _tables.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.table_bar,
                        size: 64,
                        color: isDark
                            ? NusaConfig.darkTextTertiary
                            : NusaConfig.textTertiary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada meja',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark
                              ? NusaConfig.darkTextSecondary
                              : NusaConfig.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildHeader(isDark),
                    const SizedBox(height: 4),
                    _buildViewToggle(isDark),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _listView
                          ? _buildListView(isDark)
                          : _buildGridView(isDark),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTable,
        backgroundColor: NusaConfig.activePrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Meja'),
      ),
    );
  }

  // ── Header: stat cards ──

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              'Total Meja',
              _totalCount,
              NusaConfig.activePrimary,
              Icons.table_restaurant,
              isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statCard(
              'Terisi',
              _bookedCount,
              NusaConfig.warning,
              Icons.pending_actions,
              isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statCard(
              'Tersedia',
              _emptyCount,
              NusaConfig.success,
              Icons.check_circle_outline,
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
      String label, int count, Color color, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
        borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
        border: Border.all(
          color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : NusaConfig.textTertiary)
                .withOpacity(isDark ? 0.25 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? NusaConfig.darkTextPrimary
                        : NusaConfig.textPrimary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? NusaConfig.darkTextTertiary
                        : NusaConfig.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── View toggle ──

  Widget _buildViewToggle(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            '${_tables.length} meja',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color:
                  isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary,
            ),
          ),
          const Spacer(),
          if (!_listView)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DropdownButton<int>(
                value: _gridCols,
                underline: const SizedBox(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? NusaConfig.darkTextSecondary
                      : NusaConfig.textSecondary,
                ),
                items: List.generate(
                  6,
                  (i) => DropdownMenuItem(
                    value: i + 2,
                    child: Text('${i + 2}'),
                  ),
                ),
                onChanged: (v) => setState(() => _gridCols = v!),
                iconSize: 18,
              ),
            ),
          Container(
            height: 34,
            decoration: BoxDecoration(
              color: isDark ? NusaConfig.darkSurface2 : NusaConfig.inputFill,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? NusaConfig.darkBorder : NusaConfig.inputBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _toggleBtn(Icons.view_list, _listView, () {
                  if (!_listView) setState(() => _listView = true);
                }, isDark),
                _toggleBtn(Icons.grid_view, !_listView, () {
                  if (_listView) setState(() => _listView = false);
                }, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleBtn(
      IconData icon, bool active, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: active
              ? (isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 18,
          color: active
              ? NusaConfig.activePrimary
              : (isDark
                  ? NusaConfig.darkTextTertiary
                  : NusaConfig.textTertiary),
        ),
      ),
    );
  }

  // ── List view ──

  Widget _buildListView(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: _tables.length,
      itemBuilder: (_, i) => _buildTableCard(_tables[i], isDark),
    );
  }

  Widget _buildTableCard(DiningTable table, bool isDark) {
    final status = table.status;
    final sc = _statusColor(status);
    final tabs = _tabsForTable(table.id);
    final hasTabs = tabs.isNotEmpty;
    final itemCount = _itemCountFromTabs(table.id);
    final tabTotal = _totalFromTabs(table.id);

    final card = GestureDetector(
      onTap: () => _onTableTap(table),
      onLongPress: () => _editTable(table),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor,
          borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
          border: Border.all(
            color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : NusaConfig.textTertiary)
                  .withOpacity(isDark ? 0.2 : 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left side: icon + name + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: icon + name
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: sc,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          table.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? NusaConfig.darkTextPrimary
                                : NusaConfig.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Status + capacity
                  Padding(
                    padding: const EdgeInsets.only(left: 18),
                    child: Row(
                      children: [
                        Text(
                          _statusLabel(status),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: sc,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: isDark
                                ? NusaConfig.darkTextTertiary
                                : NusaConfig.textTertiary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${table.capacity} Kursi',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? NusaConfig.darkTextTertiary
                                : NusaConfig.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Tab info row (Dipesan + has tabs)
                  if (status == 'Dipesan' && hasTabs) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 18),
                      child: Row(
                        children: [
                          Icon(Icons.receipt_long,
                              size: 14,
                              color: isDark
                                  ? NusaConfig.darkTextTertiary
                                  : NusaConfig.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            formatRupiah(tabTotal),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? NusaConfig.darkTextPrimary
                                  : NusaConfig.textPrimary,
                            ),
                          ),
                          if (tabs.length > 1) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? NusaConfig.darkTextTertiary
                                    : NusaConfig.textTertiary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${tabs.length} tab',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? NusaConfig.darkTextTertiary
                                    : NusaConfig.textTertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Right side: action button
            if (status == 'Kosong' || status == 'Dipesan')
              _tableActionButton(table, status, isDark),
          ],
        ),
      ),
    );

    return card;
  }

  Widget _tableActionButton(
      DiningTable table, String status, bool isDark) {
    if (status == 'Kosong') {
      return ElevatedButton.icon(
        onPressed: () => _bukaPesanan(table),
        style: ElevatedButton.styleFrom(
          backgroundColor: NusaConfig.success,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        icon: const Icon(Icons.add_circle_outline, size: 16),
        label: const Text('Buka Pesanan'),
      );
    }
    // Dipesan
    return ElevatedButton.icon(
      onPressed: () => _lanjutkanPesanan(table),
      style: ElevatedButton.styleFrom(
        backgroundColor: NusaConfig.warning,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      icon: const Icon(Icons.play_arrow_rounded, size: 16),
      label: const Text('Lanjutkan'),
    );
  }

  // ── Grid view ──

  Widget _buildGridView(bool isDark) {
    final cols =
        _tables.length < _gridCols ? _tables.length : _gridCols;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: _tables.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (_, i) {
        final t = _tables[i];
        final sc = _statusColor(t.status);
        final tabs = _tabsForTable(t.id);
        final hasTabs = tabs.isNotEmpty;
        final tabTotal = _totalFromTabs(t.id);

        return GestureDetector(
          onTap: () => _onTableTap(t),
          onLongPress: () => _editTable(t),
          child: Container(
            decoration: BoxDecoration(
              color: (isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor)
                  .withOpacity(isDark ? 1.0 : 0.92),
              borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
              border: Border.all(
                color: sc.withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: sc.withOpacity(isDark ? 0.18 : 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      t.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark
                            ? NusaConfig.darkTextPrimary
                            : NusaConfig.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (t.capacity > 0)
                    Flexible(
                      child: Text(
                        '${t.capacity} Kursi',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? NusaConfig.darkTextTertiary
                              : NusaConfig.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (t.status == 'Dipesan' && hasTabs)
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          formatRupiah(tabTotal),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? NusaConfig.darkTextSecondary
                                : NusaConfig.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Interactions ──

  void _onTableTap(DiningTable table) {
    if (table.status == 'Kosong') {
      _showKosongSheet(table);
    } else if (table.status == 'Dipesan') {
      _showDipesanSheet(table);
    }
    // Tutup: no action on tap
  }

  void _showKosongSheet(DiningTable table) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  table.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? NusaConfig.darkTextPrimary
                        : NusaConfig.textPrimary,
                  ),
                ),
                Text(
                  'Kapasitas ${table.capacity} - Kosong',
                  style: TextStyle(
                    fontSize: 13,
                    color: NusaConfig.success,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _bukaPesanan(table);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NusaConfig.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Buka Pesanan'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await DiningTableRepository(ref.read(databaseProvider))
                          .updateStatus(table.id, 'Tutup');
                      TopToast.success(context, '${table.name} ditutup');
                      _load();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? NusaConfig.darkTextSecondary
                          : NusaConfig.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: isDark
                            ? NusaConfig.darkBorder
                            : NusaConfig.borderColor,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Tutup Meja'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDipesanSheet(DiningTable table) {
    final tabs = _tabsForTable(table.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.3,
          maxChildSize: 0.75,
          expand: false,
          builder: (ctx2, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    table.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? NusaConfig.darkTextPrimary
                          : NusaConfig.textPrimary,
                    ),
                  ),
                  Text(
                    '${tabs.length} pesanan terbuka',
                    style: TextStyle(
                      fontSize: 13,
                      color: NusaConfig.warning,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (tabs.isNotEmpty)
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: tabs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, j) {
                          final tab = tabs[j];
                          int itemCount = 0;
                          try {
                            final items = (json.decode(tab.itemsJson) as List)
                                .cast<Map<String, dynamic>>();
                            itemCount = items.fold<int>(
                                0,
                                (sum, item) =>
                                    sum + ((item['qty'] as int?) ?? 1));
                          } catch (_) {}
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? NusaConfig.darkSurface2
                                  : NusaConfig.inputFill,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? NusaConfig.darkBorder
                                    : NusaConfig.inputBorder,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: NusaConfig.warning.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long,
                                    size: 18,
                                    color: NusaConfig.warning,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '#${tab.id} - ${tab.orderType}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? NusaConfig.darkTextPrimary
                                              : NusaConfig.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${formatRupiah(tab.total)}  -  $itemCount item',
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
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _lanjutkanTab(tab);
                                    },
                                  style: TextButton.styleFrom(
                                    foregroundColor: NusaConfig.warning,
                                  ),
                                  child: const Text('Lanjutkan'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  if (tabs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Tidak ada pesanan terbuka',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? NusaConfig.darkTextTertiary
                              : NusaConfig.textTertiary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _bukaPesanan(table);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NusaConfig.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Tambah Pesanan'),
                    ),
                  ),
                  // "Selesai Makan" — manual table release
                  if (_payFirst) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: ctx,
                            builder: (c) => AlertDialog(
                              title: const Text('Selesai Makan?'),
                              content: Text('Tandai ${table.name} sebagai kosong?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
                                TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Selesai', style: TextStyle(color: NusaConfig.success))),
                              ],
                            ),
                          );
                          if (ok == true) {
                            Navigator.pop(ctx);
                            final db = ref.read(databaseProvider);
                            await DiningTableRepository(db).updateStatus(table.id, 'Kosong');
                            for (final t in (_tableTabs[table.id] ?? [])) {
                              await TabRepository(db).complete(t.id);
                            }
                            TopToast.success(context, '${table.name} sudah kosong');
                            _load();
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: NusaConfig.success,
                          side: BorderSide(color: NusaConfig.success.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Selesai Makan'),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Actions ──

  Future<void> _bukaPesanan(DiningTable table) async {
    // Defer table status change to POS — let POS manage the lifecycle.
    // Pass table info as route params so POS knows which table was opened.
    final tableName = Uri.encodeComponent(table.name);
    if (mounted) context.go('/kasir?tableId=${table.id}&tableName=$tableName');
  }

  Future<void> _lanjutkanPesanan(DiningTable table) async {
    final tabs = _tabsForTable(table.id);
    if (tabs.isEmpty) {
      if (mounted) TopToast.info(context, 'Tidak ada pesanan aktif untuk ${table.name}');
      return;
    }
    // Pass tabId as route param — POS will load the tab from DB
    final tab = tabs.first;
    if (mounted) context.go('/kasir?tabId=${tab.id}');
  }

  Future<void> _lanjutkanTab(OpenTab tab) async {
    if (mounted) context.go('/kasir?tabId=${tab.id}');
  }

  // ── Add table bottom sheet ──

  void _addTable() {
    final nameC = TextEditingController();
    final capC = TextEditingController(text: '4');
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tambah Meja',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              NusaFormField(
                label: 'Nama Meja',
                controller: nameC,
                hintText: 'Contoh: Meja 13, VIP 1',
              ),
              const SizedBox(height: 12),
              NusaFormField(
                label: 'Kapasitas',
                controller: capC,
                hintText: 'Jumlah kursi',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NusaConfig.activePrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    if (nameC.text.trim().isEmpty) return;
                    await DiningTableRepository(ref.read(databaseProvider))
                        .add(
                      name: nameC.text.trim(),
                      capacity: int.tryParse(capC.text) ?? 4,
                    );
                    TopToast.success(context, 'Meja ditambahkan');
                    Navigator.pop(ctx);
                    _load();
                  },
                  child: const Text('Tambah'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ── Edit table bottom sheet ──

  void _editTable(DiningTable t) {
    final nameC = TextEditingController(text: t.name);
    final capC =
        TextEditingController(text: t.capacity > 0 ? '${t.capacity}' : '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Edit Meja',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              NusaFormField(
                label: 'Nama Meja',
                controller: nameC,
                hintText: 'Nama meja',
              ),
              const SizedBox(height: 12),
              NusaFormField(
                label: 'Kapasitas',
                controller: capC,
                hintText: 'Jumlah kursi',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: ctx,
                    builder: (c) => AlertDialog(
                      title: const Text('Hapus Meja?'),
                      content: Text('Hapus ${t.name}?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Batal'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text(
                            'Hapus',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await DiningTableRepository(ref.read(databaseProvider))
                        .delete(t.id);
                    Navigator.pop(ctx);
                    TopToast.success(context, 'Meja dihapus');
                    _load();
                  }
                },
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 18),
                label: const Text(
                  'Hapus Meja',
                  style: TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NusaConfig.activePrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    if (nameC.text.trim().isEmpty) return;
                    await DiningTableRepository(ref.read(databaseProvider))
                        .update(
                      t.id,
                      name: nameC.text.trim(),
                      capacity: int.tryParse(capC.text),
                    );
                    TopToast.success(context, 'Meja diperbarui');
                    Navigator.pop(ctx);
                    _load();
                  },
                  child: const Text('Simpan'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
