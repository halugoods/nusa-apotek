import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/providers.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/core/utils/secure_storage.dart';
import 'package:nusa_kasir/data/repositories/capster_report_repository.dart';
import 'package:nusa_kasir/features/auth/employee_session_provider.dart';
import 'package:nusa_kasir/shared/widgets/screen_scaffold.dart';
import 'package:nusa_kasir/shared/widgets/empty_state.dart';

/// Laporan kinerja capster/stylist — varian salon (v2.2.57).
///
/// 4 layar dalam satu file karena saling terkait:
///   - [KinerjaCapsterScreen]   — daftar ringkas per kapster (owner)
///   - [DetailCapsterScreen]    — drilldown transaksi per kapster (owner)
///   - [BayarKomisiScreen]      — tandai komisi sudah dibayar (owner)
///   - [PendapatanSayaScreen]   — kapster login lihat omset/komisi sendiri
///
/// Hitungan on-the-fly dari appointments + transactions — tidak ada tabel
/// komisi yang bisa drift.
final _capsterRepoProvider = Provider<CapsterReportRepository>(
  (ref) => CapsterReportRepository(ref.watch(databaseProvider)),
);

DateTimeRange _defaultPeriod() {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 1);
  return DateTimeRange(start: start, end: end);
}

extension _DateTimeRangeExt on DateTimeRange {
  String label() {
    final fmt = DateFormat('d MMM', 'id_ID');
    return '${fmt.format(start)} – ${fmt.format(end)}';
  }
}

// Helper: key SecureStore untuk tandai komisi sudah dibayar per kapster
// pada periode tertentu. Format: `nusa_komisi_paid_<empId>_<startMs>`.
String _paidKey(int employeeId, DateTime start) =>
    'nusa_komisi_paid_e$employeeId'
    '_${start.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay}';

// ───────────────────────────────────────────────────────────────────────────
// KINERJA CAPSTER (root)
// ───────────────────────────────────────────────────────────────────────────

class KinerjaCapsterScreen extends ConsumerStatefulWidget {
  const KinerjaCapsterScreen({super.key});
  @override
  ConsumerState<KinerjaCapsterScreen> createState() =>
      _KinerjaCapsterScreenState();
}

class _KinerjaCapsterScreenState
    extends ConsumerState<KinerjaCapsterScreen> {
  late DateTimeRange _range = _defaultPeriod();
  Future<List<CapsterSummary>>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = ref
          .read(_capsterRepoProvider)
          .kinerja(start: _range.start, end: _range.end);
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      initialDateRange: _range,
    );
    if (picked != null && mounted) {
      setState(() => _range = picked);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScreenScaffold(
      'Kinerja Capster',
      FutureBuilder<List<CapsterSummary>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? const [];
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.insights_rounded,
              message: 'Belum ada transaksi dengan kapster pada periode ini.',
            );
          }
          final totalOmset = list.fold<int>(0, (s, e) => s + e.totalOmset);
          final totalKomisi =
              list.fold<int>(0, (s, e) => s + e.totalKomisi);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _summaryCard(isDark, totalOmset, totalKomisi, list.length),
              const SizedBox(height: 12),
              ...list.map((c) => _capsterTile(context, isDark, c)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const BayarKomisiScreen(),
                  ));
                },
                icon: const Icon(Icons.payments_rounded, size: 18),
                label: const Text('Bayar Komisi'),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton.icon(
          onPressed: _pickRange,
          icon: const Icon(Icons.date_range_rounded, size: 18),
          label: Text(_range.label()),
        ),
      ],
    );
  }

  Widget _summaryCard(
      bool isDark, int totalOmset, int totalKomisi, int capsterCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface2 : NusaConfig.surfaceColor,
        borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
        border: Border.all(
          color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Omset',
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? NusaConfig.darkTextTertiary
                            : NusaConfig.textTertiary)),
                const SizedBox(height: 4),
                Text(formatRupiah(totalOmset),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Container(width: 1, height: 36, color: NusaConfig.dividerColor),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Komisi',
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? NusaConfig.darkTextTertiary
                              : NusaConfig.textTertiary)),
                  const SizedBox(height: 4),
                  Text(formatRupiah(totalKomisi),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 36, color: NusaConfig.dividerColor),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              children: [
                Text('$capsterCount',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                Text('capster',
                    style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? NusaConfig.darkTextTertiary
                            : NusaConfig.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _capsterTile(
      BuildContext context, bool isDark, CapsterSummary c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDark ? NusaConfig.darkSurface2 : NusaConfig.surfaceColor,
        borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
        child: InkWell(
          borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DetailCapsterScreen(
              employeeId: c.employeeId,
              name: c.name,
              range: _range,
            ),
          )),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor:
                      NusaConfig.activePrimary.withValues(alpha: 0.12),
                  child: Icon(Icons.person_outline_rounded,
                      color: NusaConfig.activePrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        '${c.trxCount} trx · ${c.appointmentCount} layanan · '
                        'komisi ${c.commissionPercent.toStringAsFixed(0)}%',
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? NusaConfig.darkTextTertiary
                                : NusaConfig.textTertiary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatRupiah(c.totalOmset),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('komisi ${formatRupiah(c.totalKomisi)}',
                        style: TextStyle(
                            fontSize: 11,
                            color: NusaConfig.success,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// DETAIL PER CAPSTER (drilldown)
// ───────────────────────────────────────────────────────────────────────────

class DetailCapsterScreen extends ConsumerStatefulWidget {
  final int employeeId;
  final String name;
  final DateTimeRange range;
  const DetailCapsterScreen({
    super.key,
    required this.employeeId,
    required this.name,
    required this.range,
  });

  @override
  ConsumerState<DetailCapsterScreen> createState() =>
      _DetailCapsterScreenState();
}

class _DetailCapsterScreenState
    extends ConsumerState<DetailCapsterScreen> {
  Future<List<CapsterTransaction>>? _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(_capsterRepoProvider).detail(
          employeeId: widget.employeeId,
          start: widget.range.start,
          end: widget.range.end,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = DateFormat('d MMM, HH:mm', 'id_ID');
    return ScreenScaffold(
      widget.name,
      FutureBuilder<List<CapsterTransaction>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? const [];
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_rounded,
              message: 'Tidak ada layanan yang ditangani kapster ini.',
            );
          }
          final omset = list.fold<int>(0, (s, e) => s + e.omsetShare);
          final komisi = list.fold<int>(0, (s, e) => s + e.komisi);
          return Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color:
                      isDark ? NusaConfig.darkSurface2 : NusaConfig.surfaceColor,
                  borderRadius: BorderRadius.circular(NusaConfig.radiusMD),
                  border: Border.all(
                    color: isDark
                        ? NusaConfig.darkBorder
                        : NusaConfig.dividerColor,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _mini('Omset atribusi', formatRupiah(omset),
                          isDark: isDark),
                    ),
                    Container(
                        width: 1, height: 28, color: NusaConfig.dividerColor),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: _mini('Komisi', formatRupiah(komisi),
                            isDark: isDark, color: NusaConfig.success),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final t = list[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? NusaConfig.darkSurface2
                            : NusaConfig.surfaceColor,
                        borderRadius:
                            BorderRadius.circular(NusaConfig.radiusSM),
                        border: Border.all(
                          color: isDark
                              ? NusaConfig.darkBorder
                              : NusaConfig.dividerColor,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.service,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                  '${fmt.format(t.date)} · ${t.invoice} · '
                                  '${t.customerName}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? NusaConfig.darkTextTertiary
                                          : NusaConfig.textTertiary),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(formatRupiah(t.omsetShare),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                              Text('komisi ${formatRupiah(t.komisi)}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: NusaConfig.success,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _mini(String label, String value,
      {required bool isDark, Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? NusaConfig.darkTextTertiary
                    : NusaConfig.textTertiary)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// BAYAR KOMISI (owner — tandai komisi sudah dibayar)
// ───────────────────────────────────────────────────────────────────────────

class BayarKomisiScreen extends ConsumerStatefulWidget {
  const BayarKomisiScreen({super.key});
  @override
  ConsumerState<BayarKomisiScreen> createState() => _BayarKomisiScreenState();
}

class _BayarKomisiScreenState extends ConsumerState<BayarKomisiScreen> {
  late DateTimeRange _range = _defaultPeriod();
  Future<List<CapsterSummary>>? _future;
  final Set<int> _paidIds = <int>{};
  final Set<int> _selected = <int>{};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    // Lookup paid markers for this period.
    final fut = ref
        .read(_capsterRepoProvider)
        .kinerja(start: _range.start, end: _range.end);
    final list = await fut;
    final paid = <int>{};
    for (final c in list) {
      if (await SecureStore.read(key: _paidKey(c.employeeId, _range.start)) !=
          null) {
        paid.add(c.employeeId);
      }
    }
    if (mounted) {
      setState(() {
        _paidIds
          ..clear()
          ..addAll(paid);
        _future = Future.value(list);
      });
    }
  }

  void _toggleSelect(int id) {
    if (_paidIds.contains(id)) return;
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  Future<void> _markPaid() async {
    if (_selected.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Pembayaran'),
        content: Text(
            'Tandai komisi untuk ${_selected.length} kapster sebagai sudah dibayar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tandai Sudah Dibayar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    for (final id in _selected) {
      await SecureStore.write(
        key: _paidKey(id, _range.start),
        value: DateTime.now().toIso8601String(),
      );
    }
    if (mounted) {
      setState(() => _selected.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Pembayaran komisi dicatat. Data tersimpan di perangkat.')),
      );
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScreenScaffold(
      'Bayar Komisi',
      FutureBuilder<List<CapsterSummary>>(
        future: _future,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = (snap.data ?? const []).where((c) {
            // Hide already-paid capsters from selection list.
            return !_paidIds.contains(c.employeeId);
          }).toList();
          return Column(
            children: [
              if (_selected.isNotEmpty)
                Container(
                  color: NusaConfig.activePrimary.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text('${_selected.length} kapster dipilih',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: NusaConfig.activePrimary))),
                      FilledButton(
                        onPressed: _markPaid,
                        style: FilledButton.styleFrom(
                          backgroundColor: NusaConfig.activePrimary,
                        ),
                        child: const Text('Bayar'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(
                        icon: Icons.payments_outlined,
                        message: 'Belum ada komisi kapster pada periode ini.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final c = list[i];
                          final selected = _selected.contains(c.employeeId);
                          return InkWell(
                            onTap: () => _toggleSelect(c.employeeId),
                            borderRadius:
                                BorderRadius.circular(NusaConfig.radiusMD),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: selected
                                    ? NusaConfig.activePrimary
                                        .withValues(alpha: 0.08)
                                    : (isDark
                                        ? NusaConfig.darkSurface2
                                        : NusaConfig.surfaceColor),
                                borderRadius:
                                    BorderRadius.circular(NusaConfig.radiusMD),
                                border: Border.all(
                                  color: selected
                                      ? NusaConfig.activePrimary
                                      : (isDark
                                          ? NusaConfig.darkBorder
                                          : NusaConfig.dividerColor),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked,
                                    color: selected
                                        ? NusaConfig.activePrimary
                                        : NusaConfig.textTertiary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(c.name,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700)),
                                        Text(
                                            'komisi ${c.commissionPercent.toStringAsFixed(0)}% · ${c.appointmentCount} layanan',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: isDark
                                                    ? NusaConfig.darkTextTertiary
                                                    : NusaConfig
                                                        .textTertiary)),
                                      ],
                                    ),
                                  ),
                                  Text(formatRupiah(c.totalKomisi),
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// PENDAPATAN SAYA (capster self-view)
// ───────────────────────────────────────────────────────────────────────────

class PendapatanSayaScreen extends ConsumerStatefulWidget {
  const PendapatanSayaScreen({super.key});
  @override
  ConsumerState<PendapatanSayaScreen> createState() =>
      _PendapatanSayaScreenState();
}

class _PendapatanSayaScreenState
    extends ConsumerState<PendapatanSayaScreen> {
  late DateTimeRange _range = _defaultPeriod();
  Future<CapsterEarnings>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final session = ref.read(employeeSessionProvider);
    if (session == null) {
      setState(() => _future = null);
      return;
    }
    setState(() {
      _future = ref.read(_capsterRepoProvider).myEarnings(
            employeeId: session.employeeId,
            start: _range.start,
            end: _range.end,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = ref.watch(employeeSessionProvider);
    return ScreenScaffold(
      'Pendapatan Saya',
      session == null
          ? const EmptyState(
              icon: Icons.lock_outline_rounded,
              message: 'Login terlebih dahulu untuk melihat pendapatan.',
            )
          : FutureBuilder<CapsterEarnings>(
              future: _future,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final e = snap.data;
                if (e == null) {
                  return const EmptyState(
                      icon: Icons.info_outline_rounded,
                      message: 'Belum ada transaksi pada periode ini.');
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _bigCard(isDark,
                        label: 'Omset',
                        value: formatRupiah(e.omset),
                        sub: '${e.trxCount} layanan'),
                    const SizedBox(height: 12),
                    _bigCard(isDark,
                        label: 'Komisi',
                        value: formatRupiah(e.komisi),
                        sub: '${_range.label()} · ${session.name}',
                        accent: NusaConfig.success),
                  ],
                );
              },
            ),
    );
  }

  Widget _bigCard(bool isDark,
      {required String label,
      required String value,
      required String sub,
      Color? accent}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? NusaConfig.darkSurface2 : NusaConfig.surfaceColor,
        borderRadius: BorderRadius.circular(NusaConfig.radiusLG),
        border: Border.all(
          color: isDark ? NusaConfig.darkBorder : NusaConfig.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? NusaConfig.darkTextTertiary
                      : NusaConfig.textTertiary)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800, color: accent)),
          const SizedBox(height: 4),
          Text(sub,
              style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? NusaConfig.darkTextTertiary
                      : NusaConfig.textTertiary)),
        ],
      ),
    );
  }
}