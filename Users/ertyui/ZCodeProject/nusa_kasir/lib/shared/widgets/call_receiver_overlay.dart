import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nusa_kasir/core/auth/employee_session.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';
import 'package:nusa_kasir/core/services/call_service.dart';
import 'package:nusa_kasir/core/services/sound_service.dart';

/// Penerima "Panggil Karyawan" (v2.2.54) — dipasang GLOBAL di
/// MaterialApp.builder sehingga aktif di layar mana pun.
///
/// Owner menekan PANGGIL untuk karyawan X → broadcast Realtime `ring` →
/// device yang login SEBAGAI karyawan X menampilkan banner + ringtone
/// berulang sampai dibubarkan (atau auto-dismiss 30 detik). Event untuk
/// karyawan lain diabaikan (satu channel per toko).
class CallReceiverOverlay extends StatefulWidget {
  final Widget? child;
  const CallReceiverOverlay({super.key, this.child});

  @override
  State<CallReceiverOverlay> createState() => _CallReceiverOverlayState();
}

class _CallReceiverOverlayState extends State<CallReceiverOverlay> {
  StreamSubscription<CallEvent>? _sub;
  CallEvent? _active;
  Timer? _autoDismiss;

  @override
  void initState() {
    super.initState();
    // Join channel panggilan sepanjang app hidup (idempoten; no-op kalau
    // fitur dimatikan / belum login Google).
    CallService.I.start();
    _sub = CallService.I.stream.listen(_onEvent);
  }

  Future<void> _onEvent(CallEvent e) async {
    // Hanya respons kalau event ini ditujukan ke karyawan yang login di
    // device ini.
    final session = await EmployeeSession.restore();
    if (session == null || session.employeeId != e.employeeId) return;
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    SoundService.I.startRing();
    setState(() => _active = e);
    _autoDismiss?.cancel();
    _autoDismiss = Timer(const Duration(seconds: 30), _dismiss);
  }

  void _dismiss() {
    _autoDismiss?.cancel();
    _autoDismiss = null;
    SoundService.I.stopRing();
    if (mounted) setState(() => _active = null);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _autoDismiss?.cancel();
    SoundService.I.stopRing();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = _active;
    return Stack(
      children: [
        Positioned.fill(child: widget.child ?? const SizedBox.shrink()),
        if (e != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Material(
              color: Colors.transparent,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                offset: Offset.zero,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: NusaConfig.info,
                    borderRadius: BorderRadius.circular(NusaConfig.radiusLG),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(
                              NusaConfig.radiusMD,
                            ),
                          ),
                          child: const Icon(
                            Icons.notifications_active_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${e.by} memanggil kamu',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Kamu dibutuhkan di kasir — segera hubungi.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _dismiss,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                NusaConfig.radiusSM,
                              ),
                            ),
                            child: Text(
                              'Oke',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: NusaConfig.info,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
