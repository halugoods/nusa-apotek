import 'package:flutter/material.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/utils/icon_loader.dart';

/// NUSA-branded app header: logo + user info + notification bell.
///
/// Matches the reference design:
///   - "NUSA" wordmark in brand red (24px extrabold)
///   - Vertical divider, then user name (13px semibold) + role • branch (11px)
///   - Bell icon (44x44 tap target) with red notification dot
class DashboardHeader extends StatelessWidget {
  final String userName;
  final String role;
  final String branch;
  final bool hasNotification;
  final VoidCallback? onBellTap;
  final VoidCallback? onLogout;

  DashboardHeader({
    super.key,
    this.userName = '',
    this.role = '',
    this.branch = '',
    this.hasNotification = false,
    this.onBellTap,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Left: Logo + NUSA wordmark (horizontal)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(splashLogoPath(), height: 40, fit: BoxFit.contain),
                SizedBox(width: 10),
                Text(
                  'NUSA',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: NusaConfig.activePrimary,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),

          // Right: Bell button with notification dot
          GestureDetector(
            onTap: onBellTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.notifications_outlined,
                    size: 22,
                    color: isDark ? NusaConfig.darkTextPrimary : NusaConfig.textPrimary,
                  ),
                  if (hasNotification)
                    Positioned(
                      top: 9,
                      right: 10,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: NusaConfig.activePrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (onLogout != null) ...[
            SizedBox(width: 4),
            // Logout / Ganti Pengguna — switch role tanpa buka ulang app
            GestureDetector(
              onTap: onLogout,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  Icons.logout_rounded,
                  size: 22,
                  color: isDark ? NusaConfig.darkTextSecondary : NusaConfig.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
