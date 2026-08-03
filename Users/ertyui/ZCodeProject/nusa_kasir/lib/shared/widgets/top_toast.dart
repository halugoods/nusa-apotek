import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';

/// Toast notification that slides in from the top of the screen.
/// Replaces the bottom SnackBar — more visible and matches modern POS UX.
///
/// Usage:
///   TopToast.show(context, 'Pesan sukses', type: ToastType.success);
///   TopToast.error(context, 'Error message');
enum ToastType { success, error, info }

class TopToast {
  /// Uses a WeakReference so we don't hold dead BuildContexts.
  static final Map<int, List<OverlayEntry>> _entries = {};
  static int _contextHash(BuildContext c) => c.hashCode;

  /// Show a toast at the top of the screen. Auto-dismisses after [duration].
  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
    IconData? icon,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _TopToastWidget(
        message: message,
        type: type,
        icon: icon,
        onDismiss: () {
          try { entry.remove(); } catch (_) {}
          final hash = _contextHash(context);
          _entries[hash]?.remove(entry);
          if (_entries[hash]?.isEmpty ?? false) _entries.remove(hash);
        },
        duration: duration,
      ),
    );

    overlay.insert(entry);
    final hash = _contextHash(context);
    _entries.putIfAbsent(hash, () => []).add(entry);

    // Fallback cleanup — remove entry after duration in case onDismiss wasn't called
    Future.delayed(duration + Duration(seconds: 2), () {
      try {
        entry.remove();
        _entries[hash]?.remove(entry);
        if (_entries[hash]?.isEmpty ?? false) _entries.remove(hash);
      } catch (_) {}
    });
  }

  static void error(BuildContext context, String message) =>
      show(context, message, type: ToastType.error, icon: Icons.error_outline);

  static void success(BuildContext context, String message) =>
      show(context, message, type: ToastType.success, icon: Icons.check_circle_outline);

  static void info(BuildContext context, String message) =>
      show(context, message, type: ToastType.info, icon: Icons.info_outline);
}

class _TopToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final IconData? icon;
  final VoidCallback onDismiss;
  final Duration duration;

  _TopToastWidget({
    required this.message,
    required this.type,
    this.icon,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<_TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends State<_TopToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 350),
      reverseDuration: Duration(milliseconds: 250),
    );
    _slideAnim = Tween<Offset>(
      begin: Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Interval(0, 0.6)),
    );

    _controller.forward();

    // Auto-dismiss
    Future.delayed(widget.duration, _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  Color get _bgColor {
    switch (widget.type) {
      case ToastType.success:
        return NusaConfig.accentGreen;
      case ToastType.error:
        return NusaConfig.activePrimary;
      case ToastType.info:
        return Color(0xFF3B82F6);
    }
  }

  IconData get _icon =>
      widget.icon ??
      switch (widget.type) {
        ToastType.success => Icons.check_circle_outline,
        ToastType.error => Icons.error_outline,
        ToastType.info => Icons.info_outline,
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top + 8;

    return Positioned(
      top: topPadding,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: GestureDetector(
            onTap: _dismiss,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _bgColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _bgColor.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(_icon, color: Colors.white, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    GestureDetector(
                      onTap: _dismiss,
                      child: Icon(Icons.close,
                          color: Colors.white70, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
