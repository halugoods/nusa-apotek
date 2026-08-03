import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/shared/widgets/animated_builder.dart'
    show NusaAnimatedBuilder;

/// EmployeeCardData — pre-fetched data for the flip card back side.
class EmployeeCardData {
  final int penjualan;
  final int laba;
  final int trxCount;
  final int modalAwal;
  final int totalLaci;
  final int selisihLaci;
  final String? shiftHours;
  final int omzet;
  final int transaksiBulan;
  final int hadirDays;
  final int totalDays;
  final int pendingItems;

  EmployeeCardData({
    this.penjualan = 0,
    this.laba = 0,
    this.trxCount = 0,
    this.modalAwal = 0,
    this.totalLaci = 0,
    this.selisihLaci = 0,
    this.shiftHours,
    this.omzet = 0,
    this.transaksiBulan = 0,
    this.hadirDays = 0,
    this.totalDays = 0,
    this.pendingItems = 0,
  });
}

/// Red gradient profile card with 3D flip.
///
/// **Front:** Same layout as before — avatar, name, role, branch, attendance,
/// and 4 sales KPI stats (PENJUALAN, TRANSAKSI, RATA-RATA, TERLARIS).
///
/// **Back:** Role-adaptive data:
///   - Owner → live sales + profit + pending items
///   - Manager → monthly performance + attendance
///   - Kasir → cash drawer reconciliation
///
/// Tap to flip. Non-Owner / non-self viewers cannot see the back.
class ProfileStatsCard extends StatefulWidget {
  // ── Front display fields (unchanged) ────────────────
  final String? photoPath;
  final String initials;
  final String userName;
  final String role;
  final String branch;
  final String attendanceStatus;
  final String salesValue;
  final String transactionCount;
  final String avgValue;
  final String topProduct;

  // ── Flip / back-side fields ────────────────────────
  final String viewerRole;
  final int? viewerEmployeeId;
  final int? employeeId;
  final EmployeeCardData? cardData;
  final Future<bool> Function()? onAuthOwner;
  final VoidCallback? onAbsenMasuk;
  final VoidCallback? onAbsenKeluar;
  final VoidCallback? onKontakWa;

  ProfileStatsCard({
    super.key,
    this.photoPath,
    this.initials = '?',
    this.userName = 'Belum ada sesi kasir',
    this.role = '',
    this.branch = '',
    this.attendanceStatus = 'Buka Kasir untuk memulai',
    this.salesValue = 'Rp 0',
    this.transactionCount = '0',
    this.avgValue = 'Rp 0',
    this.topProduct = '—',
    this.viewerRole = 'Kasir',
    this.viewerEmployeeId,
    this.employeeId,
    this.cardData,
    this.onAuthOwner,
    this.onAbsenMasuk,
    this.onAbsenKeluar,
    this.onKontakWa,
  });

  @override
  State<ProfileStatsCard> createState() => _ProfileStatsCardState();
}

class _ProfileStatsCardState extends State<ProfileStatsCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  bool _isFlipped = false;

  bool get _isSelf =>
      widget.viewerEmployeeId != null &&
      widget.employeeId != null &&
      widget.viewerEmployeeId == widget.employeeId;

  bool get _canFlip =>
      _isSelf || widget.viewerRole == 'Owner';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _anim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _toggleFlip() async {
    if (_isFlipped) {
      // Flip back to front — always allowed
      _ctrl.reverse();
      setState(() => _isFlipped = false);
      return;
    }

    // Flip to back — check access
    if (!_canFlip) return; // silently blocked

    // Owner in non-Owner session must authenticate
    if (widget.viewerRole == 'Owner' &&
        widget.onAuthOwner != null &&
        !_isSelf) {
      final ok = await widget.onAuthOwner!();
      if (!ok) return;
    }

    _ctrl.forward();
    setState(() => _isFlipped = true);
  }

  // ────────────────────────────────────────────────────
  // FRONT SIDE (unchanged from original)
  // ────────────────────────────────────────────────────

  Widget _buildFront() {
    final hasPhoto = widget.photoPath != null &&
        widget.photoPath!.isNotEmpty &&
        File(widget.photoPath!).existsSync();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: NusaConfig.activePrimary,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Flip hint (top-right corner)
          if (_canFlip)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.flip_to_back,
                    size: 14, color: Colors.white.withValues(alpha: 0.8)),
              ),
            ),

          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                _buildTopRow(hasPhoto),
                Container(
                  margin: EdgeInsets.symmetric(vertical: 16),
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                _buildStatsGrid(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopRow(bool hasPhoto) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
            ),
            image: hasPhoto
                ? DecorationImage(
                    image: FileImage(File(widget.photoPath!)),
                    fit: BoxFit.cover)
                : null,
          ),
          alignment: Alignment.center,
          child: hasPhoto
              ? null
              : Text(
                  widget.initials,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),
        SizedBox(width: 12),

        // Name + role + attendance
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.userName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
              Text(
                '${widget.role}${widget.branch.isNotEmpty ? ' • ${widget.branch}' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.4,
                ),
              ),
              SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  SizedBox(width: 4),
                  Text(
                    widget.attendanceStatus,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      _Stat(
        icon: Icons.monetization_on_outlined,
        iconBg: NusaConfig.accentGold.withValues(alpha: 0.95),
        iconColor: Colors.white,
        value: widget.salesValue,
        label: 'PENJUALAN',
      ),
      _Stat(
        icon: Icons.shopping_cart_outlined,
        iconBg: Colors.white.withValues(alpha: 0.22),
        iconColor: Colors.white,
        value: widget.transactionCount,
        label: 'TRANSAKSI',
      ),
      _Stat(
        icon: Icons.trending_up,
        iconBg: Colors.white.withValues(alpha: 0.22),
        iconColor: Colors.white,
        value: widget.avgValue,
        label: 'RATA-RATA',
      ),
      _Stat(
        icon: Icons.star_outline,
        iconBg: Colors.white.withValues(alpha: 0.22),
        iconColor: Colors.white,
        value: widget.topProduct,
        label: 'TERLARIS',
      ),
    ];

    return Row(
      children: stats.map((s) => Expanded(child: _statItem(s))).toList(),
    );
  }

  Widget _statItem(_Stat s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: s.iconBg,
          ),
          alignment: Alignment.center,
          child: Icon(s.icon, size: 16, color: s.iconColor),
        ),
        SizedBox(height: 6),
        Text(
          s.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.2,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        Text(
          s.label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────
  // BACK CONTENT (role-adaptive, inside same red gradient card)
  // ────────────────────────────────────────────────────

  Widget _buildBackContent() {
    final data = widget.cardData;

    switch (widget.viewerRole) {
      case 'Kasir':
        return _buildKasirBack(data);
      case 'Manager':
        return _buildManagerBack(data);
      default:
        return _buildOwnerBack(data);
    }
  }

  // ── Kasir: Cash Drawer ────────────────────────────

  Widget _buildKasirBack(EmployeeCardData? data) {
    final isRed = (data?.selisihLaci ?? 0) < 0;

    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _backHeader(Icons.point_of_sale, 'Shift Saya'),
          SizedBox(height: 14),
          _statRowW('Modal Awal', formatRupiah(data?.modalAwal ?? 0)),
          _statRowW('Penjualan', formatRupiah(data?.penjualan ?? 0)),
          Container(
            margin: EdgeInsets.symmetric(vertical: 10),
            height: 1,
            color: Colors.white.withValues(alpha: 0.18),
          ),
          _statRowW('Total di Laci', formatRupiah(data?.totalLaci ?? 0),
              bold: true),
          _statRowW(
            'Selisih',
            formatRupiah(data?.selisihLaci.abs() ?? 0),
            valueColor: isRed
                ? NusaConfig.accentGold
                : Color(0xFF4ADE80),
            suffix: isRed ? ' (kurang)' : '',
          ),
          if (data?.shiftHours != null) ...[
            SizedBox(height: 8),
            Text('Shift: ${data!.shiftHours}',
                style: TextStyle(
                    fontSize: 12, color: Colors.white.withValues(alpha: 0.75))),
          ],
          SizedBox(height: 16),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: _backButton('Absen Masuk', Icons.login,
                    Colors.white.withValues(alpha: 0.9), widget.onAbsenMasuk),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _backButton('Absen Keluar', Icons.logout,
                    Colors.white.withValues(alpha: 0.9), widget.onAbsenKeluar),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Manager: Performance ──────────────────────────

  Widget _buildManagerBack(EmployeeCardData? data) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _backHeader(Icons.trending_up, 'Performa Bulan Ini'),
          SizedBox(height: 14),
          _statRowW('Omzet', formatRupiah(data?.omzet ?? 0)),
          _statRowW('Transaksi', '${data?.transaksiBulan ?? 0}'),
          _statRowW(
              'Hadir', '${data?.hadirDays ?? 0}/${data?.totalDays ?? 0} hari'),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: _backButton('Hubungi WA', Icons.chat,
                Colors.white.withValues(alpha: 0.9), widget.onKontakWa),
          ),
        ],
      ),
    );
  }

  // ── Owner: Command Center ─────────────────────────

  Widget _buildOwnerBack(EmployeeCardData? data) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _backHeader(Icons.insights, 'Live Hari Ini'),
          SizedBox(height: 14),
          // Mini stats row
          Row(
            children: [
              _ownerMiniStatW(
                  'Penjualan', formatRupiah(data?.penjualan ?? 0)),
              _ownerMiniStatW('Laba', formatRupiah(data?.laba ?? 0)),
              _ownerMiniStatW('Trx', '${data?.trxCount ?? 0}'),
            ],
          ),
          SizedBox(height: 12),
          // Pending alert
          if ((data?.pendingItems ?? 0) > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_active,
                      size: 16, color: NusaConfig.accentGold),
                  SizedBox(width: 6),
                  Text('${data!.pendingItems} item perlu tindakan',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ],
              ),
            ),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _backButton('Hubungi WA', Icons.chat,
                Colors.white.withValues(alpha: 0.9), widget.onKontakWa),
          ),
        ],
      ),
    );
  }

  // ── Shared back-side helpers (white-on-red theme) ──

  Widget _backHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ),
        // Flip-back hint
        GestureDetector(
          onTap: _toggleFlip,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.flip_to_front,
                size: 16, color: Colors.white.withValues(alpha: 0.85)),
          ),
        ),
      ],
    );
  }

  Widget _statRowW(String label, String value,
      {bool bold = false, String suffix = '', Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
          Text(
            '$value$suffix',
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ownerMiniStatW(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3)),
          SizedBox(height: 2),
          Text(label,
              style:
                  TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _backButton(
      String label, IconData icon, Color color, VoidCallback? onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────
  // BACK WRAPPER (same red gradient card as front)
  // ────────────────────────────────────────────────────

  Widget _buildBack() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: NusaConfig.activePrimary,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          _buildBackContent(),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────
  // 3D FLIP BUILD
  // ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: _toggleFlip,
        child: NusaAnimatedBuilder(
          animation: _anim,
          builder: (context, child) {
            final isFrontVisible = _anim.value <= 0.5;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(_anim.value * 3.14159),
              child: isFrontVisible
                  ? _buildFront()
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(3.14159),
                      child: _buildBack(),
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _Stat {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final String label;
  _Stat({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    required this.label,
  });
}
