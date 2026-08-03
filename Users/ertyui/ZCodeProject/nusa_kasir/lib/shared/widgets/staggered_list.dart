import 'package:flutter/material.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';

/// Wraps a single list item with staggered fade-in + slide-up animation.
/// Add this around each item in a ListView's itemBuilder.
class StaggeredItem extends StatefulWidget {
  final int index;
  final Duration itemDelay;
  final Duration duration;
  final Widget child;

  const StaggeredItem({
    super.key,
    required this.index,
    required this.child,
    this.itemDelay = const Duration(milliseconds: 50),
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<StaggeredItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    // Stretch durations on high-refresh-rate (>90 Hz) devices so
    // animations don't feel unnaturally fast (e.g. Samsung Galaxy A25 at 120 Hz).
    final scale = NusaConfig.animationScale;
    final dur = widget.duration * scale;
    final delay = widget.itemDelay * widget.index * scale;
    _controller = AnimationController(vsync: this, duration: dur);
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _opacity,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}
