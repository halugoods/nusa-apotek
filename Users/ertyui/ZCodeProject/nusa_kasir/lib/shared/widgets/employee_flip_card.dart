import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart' show formatRupiah;
import 'package:nusa_kasir/shared/widgets/animated_builder.dart'
    show NusaAnimatedBuilder;
// EmployeeCardData is defined in profile_stats_card.dart
import 'package:nusa_kasir/shared/widgets/profile_stats_card.dart'
    show EmployeeCardData;

/// A 2-sided employee flip card with role-adaptive back side.
///
/// **Front** (public): photo, name, role badge, status, employee ID.
/// **Back** (role-based):
///   - **Owner**: live sales & profit today + pending items.
///   - **Kasir**: cash drawer reconciliation + shift hours.
///   - **Manager**: monthly performance summary.
///
/// The card uses a 3D flip animation. Back side is revealed on tap,
/// with Owner requiring PIN/fingerprint/NFC authentication first.
class EmployeeFlipCard extends StatefulWidget {
  final Employee employee;

  /// Role of the currently logged-in user viewing this card.
  final String viewerRole;
  final int? viewerEmployeeId;

  /// Whether the viewer is the same as the card's employee (self-view).
  bool get isSelf => viewerEmployeeId == employee.id;

  /// Live data for back side (pre-fetched by parent).
  final EmployeeCardData? cardData;

  /// Callbacks for back-side actions.
  final VoidCallback? onAbsenMasuk;
  final VoidCallback? onAbsenKeluar;
  final VoidCallback? onHubungiWa;
  final VoidCallback? onKontakWa; // list overlay

  /// Authentication callback — called when Owner taps to flip.
  /// Return true if authenticated.
  final Future<bool> Function()? onAuthOwner;

  EmployeeFlipCard({
    super.key,
    required this.employee,
    required this.viewerRole,
    this.viewerEmployeeId,
    this.cardData,
    this.onAbsenMasuk,
    this.onAbsenKeluar,
    this.onHubungiWa,
    this.onKontakWa,
    this.onAuthOwner,
  });

  @override
  State<EmployeeFlipCard> createState() => _EmployeeFlipCardState();
}

class _EmployeeFlipCardState extends State<EmployeeFlipCard>
    with SingleTickerProviderStateMixin {
  bool _isFlipped = false;
  late final AnimationController _flipCtrl;
  late final Animation<double> _flipAnim;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _flipAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleFlip() async {
    if (!_isFlipped) {
      // Flipping to back side
      // Owner: require authentication (unless already in Owner session)
      if (widget.viewerRole == 'Owner') {
        // Owner in own session can flip freely
        // Owner in other role session needs auth
        if (widget.onAuthOwner != null) {
          final ok = await widget.onAuthOwner!();
          if (!ok) return;
        }
      } else if (!widget.isSelf) {
        // Non-owner viewing someone else's card — cannot flip
        return;
      }
      // Kasir/Manager self: flip freely

      _flipCtrl.forward();
      setState(() => _isFlipped = true);
    } else {
      _flipCtrl.reverse();
      setState(() => _isFlipped = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = widget.cardData;

    return GestureDetector(
      onTap: _toggleFlip,
      child: NusaAnimatedBuilder(
        animation: _flipAnim,
        builder: (context, child) {
          final angle = _flipAnim.value * 3.14159; // 0 to PI
          final isFront = _flipAnim.value <= 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: isFront ? _buildFront(isDark) : Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(3.14159),
              child: _buildBack(isDark, data),
            ),
          );
        },
      ),
    );
  }

  // ─── FRONT SIDE ─────────────────────────────────────────

  Widget _buildFront(bool isDark) {
    final e = widget.employee;
    final hasPhoto = e.photoPath != null &&
        e.photoPath!.isNotEmpty &&
        File(e.photoPath!).existsSync();
    final roleColor = _roleColor(e.role);
    final statusColor = _statusColor(e.status);
    final surfaceColor = isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor;
    final textColor = isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary;
    final subColor = isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Color(0x0A111827),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Photo
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: roleColor.withValues(alpha: 0.12),
                border: Border.all(color: roleColor.withValues(alpha: 0.3), width: 2),
                image: hasPhoto
                    ? DecorationImage(
                        image: FileImage(File(e.photoPath!), scale: 1.0),
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.low,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: !hasPhoto
                  ? Text(
                      e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: roleColor,
                      ),
                    )
                  : null,
            ),
            SizedBox(height: 12),

            // Name
            Text(
              e.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8),

            // Role badge + Status badge
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _badge(e.role, roleColor),
                if (e.status != null && e.status != 'Aktif')
                  _badge(e.status!, statusColor),
              ],
            ),
            SizedBox(height: 10),

            // Employee ID
            Text(
              'ID: ${e.id}',
              style: TextStyle(fontSize: 12, color: subColor),
            ),

            // Tap hint
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.swap_horiz_rounded, size: 14, color: subColor),
                SizedBox(width: 4),
                Text(
                  widget.viewerRole == 'Owner' || widget.isSelf
                      ? 'Ketuk untuk lihat detail'
                      : 'Hanya karyawan sendiri',
                  style: TextStyle(fontSize: 11, color: subColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── BACK SIDE — ROLE-BASED ─────────────────────────────

  Widget _buildBack(bool isDark, EmployeeCardData? data) {
    final role = widget.viewerRole;

    // Kasir self-view: cash drawer
    if (role == 'Kasir' && widget.isSelf) {
      return _buildKasirBack(isDark, data);
    }

    // Manager self-view: performance
    if (role == 'Manager' && widget.isSelf) {
      return _buildManagerBack(isDark, data);
    }

    // Owner: command center (or anyone else falls through to Owner view)
    return _buildOwnerBack(isDark, data);
  }

  // ─── Kasir Back: Cash Drawer ────────────────────────────

  Widget _buildKasirBack(bool isDark, EmployeeCardData? data) {
    final surfaceColor = isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor;
    final subColor = isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary;
    final isRed = (data?.selisihLaci ?? 0) < 0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Color(0x0A111827),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _backHeader('Shift Saya', Icons.point_of_sale_rounded, isDark),
            SizedBox(height: 16),

            _statRow('Modal Awal', formatRupiah(data?.modalAwal ?? 0), isDark),
            _statRow('Penjualan', formatRupiah(data?.penjualan ?? 0), isDark),
            Divider(height: 20),
            _statRow(
              'Total di Laci',
              formatRupiah(data?.totalLaci ?? 0),
              isDark,
              bold: true,
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Text('Selisih', style: TextStyle(fontSize: 13, color: subColor)),
                Spacer(),
                Text(
                  formatRupiah((data?.selisihLaci ?? 0).abs()),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isRed ? NusaConfig.activePrimary : NusaConfig.accentGreen,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            if (data?.shiftHours != null)
              Text(
                'Shift: ${data!.shiftHours}',
                style: TextStyle(fontSize: 12, color: subColor),
              ),

            SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _backButton(
                    'Absen Masuk',
                    Icons.login_rounded,
                    NusaConfig.accentGreen,
                    widget.onAbsenMasuk,
                    isDark,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _backButton(
                    'Absen Keluar',
                    Icons.logout_rounded,
                    NusaConfig.activePrimary,
                    widget.onAbsenKeluar,
                    isDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Manager Back: Performance ──────────────────────────

  Widget _buildManagerBack(bool isDark, EmployeeCardData? data) {
    final surfaceColor = isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Color(0x0A111827),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _backHeader('Performa Bulan Ini', Icons.trending_up_rounded, isDark),
            SizedBox(height: 16),

            _statRow('Omzet', formatRupiah(data?.omzet ?? 0), isDark),
            _statRow('Transaksi', '${data?.trxCount ?? 0}', isDark),
            if (data != null && data.totalDays > 0)
              _statRow('Hadir', '${data.hadirDays}/${data.totalDays} hari', isDark),

            SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: _backButton(
                'Hubungi WA',
                Icons.chat_rounded,
                NusaConfig.accentGreen,
                widget.onHubungiWa,
                isDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Owner Back: Command Center ─────────────────────────

  Widget _buildOwnerBack(bool isDark, EmployeeCardData? data) {
    final surfaceColor = isDark ? NusaConfig.darkSurface : NusaConfig.surfaceColor;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? NusaConfig.darkBorder : NusaConfig.borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Color(0x0A111827),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _backHeader('Live Hari Ini', Icons.insights_rounded, isDark),
            SizedBox(height: 12),

            // Live stats
            Row(
              children: [
                _ownerMiniStat(
                    'Penjualan', formatRupiah(data?.penjualan ?? 0), isDark),
                _ownerMiniStat(
                    'Laba', formatRupiah(data?.laba ?? 0), isDark),
                _ownerMiniStat(
                    'Trx', '${data?.trxCount ?? 0}', isDark),
              ],
            ),

            // Pending
            if (data != null && data.pendingItems > 0) ...[
              SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NusaConfig.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: NusaConfig.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notifications_active_rounded,
                        color: NusaConfig.warning, size: 18),
                    SizedBox(width: 8),
                    Text(
                      '${data.pendingItems} item pending perlu tindakan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: NusaConfig.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: _backButton(
                'Hubungi WA',
                Icons.chat_rounded,
                NusaConfig.accentGreen,
                widget.onKontakWa,
                isDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ownerMiniStat(String label, String value, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shared Helpers ─────────────────────────────────────

  Widget _backHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: NusaConfig.activePrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: NusaConfig.activePrimary, size: 20),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
            ),
          ),
        ),
        Icon(Icons.touch_app_rounded, size: 14,
            color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
      ],
    );
  }

  Widget _statRow(String label, String value, bool isDark, {bool bold = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
            ),
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _backButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback? onTap,
    bool isDark,
  ) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'Owner':  return NusaConfig.activePrimary;
      case 'Manager': return NusaConfig.accentPurple;
      case 'Kasir':  return NusaConfig.accentGreen;
      case 'Gudang': return Color(0xFFF59E0B);
      case 'Finance': return Color(0xFF3B82F6);
      default:       return NusaConfig.textSecondary;
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'Aktif':  return NusaConfig.accentGreen;
      case 'Cuti':   return NusaConfig.warning;
      case 'Nonaktif': return NusaConfig.textSecondary;
      case 'Resign': return NusaConfig.activePrimary;
      default:       return NusaConfig.textSecondary;
    }
  }
	}

// EmployeeCardData is imported from profile_stats_card.dart
