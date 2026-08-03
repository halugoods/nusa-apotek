import 'package:flutter/material.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/utils/format_rupiah.dart';
import 'package:nusa_kasir/data/database/app_database.dart';
import 'package:nusa_kasir/data/repositories/cashier_session_repository.dart';
import 'package:nusa_kasir/shared/widgets/top_toast.dart';

/// Bottom sheet modal for "Buka Kasir" — asks for starting cash balance.
///
/// Flow:
///   1. PIN is collected BEFORE this sheet (in dashboard) to authenticate cashier
///   2. This sheet collects the starting cash balance (saldo awal)
///   3. On confirm → creates a CashierSession row, returns (sessionId, saldo)
///
/// Call `show(context, storeName, employeeId, employeeName, employeeRole, onConfirm)`.
class BukaKasirSheet extends StatefulWidget {
  final String storeName;
  final int employeeId;
  final String employeeName;
  final String employeeRole;
  final void Function(int sessionId, int saldo) onConfirm;

  BukaKasirSheet({
    super.key,
    required this.storeName,
    required this.employeeId,
    required this.employeeName,
    required this.employeeRole,
    required this.onConfirm,
  });

  /// Convenience method to show the sheet.
  static void show({
    required BuildContext context,
    required String storeName,
    required int employeeId,
    required String employeeName,
    required String employeeRole,
    required void Function(int sessionId, int saldo) onConfirm,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => BukaKasirSheet(
        storeName: storeName,
        employeeId: employeeId,
        employeeName: employeeName,
        employeeRole: employeeRole,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<BukaKasirSheet> createState() => _BukaKasirSheetState();
}

class _BukaKasirSheetState extends State<BukaKasirSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _loading = false;

  String get _raw => _controller.text.replaceAll(RegExp(r'[^\d]'), '');

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    Future.delayed(Duration(milliseconds: 300), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setChip(int value) {
    _controller.text = value.toString();
  }

  Future<void> _confirm() async {
    final nilai = int.tryParse(_raw);
    if (nilai == null || nilai <= 0) {
      TopToast.error(context, 'Saldo awal wajib diisi');
      return;
    }

    setState(() => _loading = true);
    try {
      // Create cashier session
      final db = AppDatabase();
      final repo = CashierSessionRepository(db);
      final sessionId = await repo.open(
        employeeId: widget.employeeId,
        startingCash: nilai,
      );
      if (mounted) {
        widget.onConfirm(sessionId, nilai);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        TopToast.error(context, 'Gagal buka kasir: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: isDark ? NusaConfig.darkDivider : NusaConfig.dividerColor,
                ),
              ),
            ),
            SizedBox(height: 16),

            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Kasir',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Kasir: ${widget.employeeName} • ${widget.employeeRole}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(shape: BoxShape.circle),
                  child: Icon(Icons.close,
                      size: 20, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Store info
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: NusaConfig.activeSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NusaConfig.activeSoft),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 16, color: NusaConfig.activePrimary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.storeName,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Label
            Text(
              'Saldo Awal Kas',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
              ),
            ),
            SizedBox(height: 8),

            // Input with Rp prefix
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? NusaConfig.darkDivider : NusaConfig.dividerColor),
                color: isDark ? NusaConfig.darkInputFill : Colors.white,
              ),
              child: Row(
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Text(
                      'Rp',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      enabled: !_loading,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(color: isDark ? NusaConfig.darkTextTertiary : NusaConfig.textTertiary),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Masukkan jumlah uang tunai yang ada di laci kasir saat ini.',
              style: TextStyle(fontSize: 12, color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary),
            ),
            SizedBox(height: 16),

            // Quick chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [50000, 100000, 200000, 500000].map((v) {
                return GestureDetector(
                  onTap: _loading ? null : () => _setChip(v),
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? NusaConfig.darkDivider : NusaConfig.dividerColor),
                    ),
                    child: Text(
                      'Rp ${formatRupiah(v)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 24),

            // CTA
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _confirm,
                icon: _loading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(Icons.arrow_forward, size: 18),
                label: Text(_loading ? 'Membuka...' : 'Mulai Sesi Kasir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NusaConfig.activePrimary,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shadowColor: NusaConfig.activePrimary.withValues(alpha: 0.28),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
