import 'package:flutter/material.dart';
import 'package:nusa_kasir/core/config/nusa_config.dart';

/// Animated barcode scanner overlay with looping scan line + corner brackets.
///
/// Shows a moving scan line that bounces top-to-bottom continuously,
/// plus four corner brackets for a professional scanner look.
///
/// Usage:
/// ```dart
/// AnimatedScannerOverlay(
///   child: MobileScanner(controller: controller, onDetect: ...),
/// )
/// ```
class AnimatedScannerOverlay extends StatefulWidget {
  final Widget child;
  final double size;
  final Color? scanColor;
  final double bracketLength;
  final double bracketWidth;

  const AnimatedScannerOverlay({
    super.key,
    required this.child,
    this.size = 200,
    this.scanColor,
    this.bracketLength = 24,
    this.bracketWidth = 2.5,
  });

  @override
  State<AnimatedScannerOverlay> createState() => _AnimatedScannerOverlayState();
}

class _AnimatedScannerOverlayState extends State<AnimatedScannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scanAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _scanAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.scanColor ?? NusaConfig.activePrimary;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(children: [
        // Camera feed
        Positioned.fill(child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: widget.child,
        )),

        // Moving scan line
        AnimatedBuilder(
          animation: _scanAnim,
          builder: (_, child) {
            return Positioned(
              left: 8,
              right: 8,
              top: 8 + _scanAnim.value * (widget.size - 16 - 2),
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      color.withOpacity(0.9),
                      color.withOpacity(0.9),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // Corner brackets
        // Top-left
        Positioned(
          top: 4, left: 4,
          child: CustomPaint(
            size: Size(widget.bracketLength, widget.bracketLength),
            painter: _CornerBracketPainter(
              color: color.withOpacity(0.6),
              orientation: _CornerOrientation.topLeft,
              length: widget.bracketLength,
              width: widget.bracketWidth,
            ),
          ),
        ),
        // Top-right
        Positioned(
          top: 4, right: 4,
          child: CustomPaint(
            size: Size(widget.bracketLength, widget.bracketLength),
            painter: _CornerBracketPainter(
              color: color.withOpacity(0.6),
              orientation: _CornerOrientation.topRight,
              length: widget.bracketLength,
              width: widget.bracketWidth,
            ),
          ),
        ),
        // Bottom-left
        Positioned(
          bottom: 4, left: 4,
          child: CustomPaint(
            size: Size(widget.bracketLength, widget.bracketLength),
            painter: _CornerBracketPainter(
              color: color.withOpacity(0.6),
              orientation: _CornerOrientation.bottomLeft,
              length: widget.bracketLength,
              width: widget.bracketWidth,
            ),
          ),
        ),
        // Bottom-right
        Positioned(
          bottom: 4, right: 4,
          child: CustomPaint(
            size: Size(widget.bracketLength, widget.bracketLength),
            painter: _CornerBracketPainter(
              color: color.withOpacity(0.6),
              orientation: _CornerOrientation.bottomRight,
              length: widget.bracketLength,
              width: widget.bracketWidth,
            ),
          ),
        ),
      ]),
    );
  }
}

enum _CornerOrientation { topLeft, topRight, bottomLeft, bottomRight }

class _CornerBracketPainter extends CustomPainter {
  final Color color;
  final _CornerOrientation orientation;
  final double length;
  final double width;

  _CornerBracketPainter({
    required this.color,
    required this.orientation,
    required this.length,
    required this.width,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    double x1, y1, x2, y2;
    double vx1, vy1, vx2, vy2;

    switch (orientation) {
      case _CornerOrientation.topLeft:
        x1 = width / 2; y1 = length;
        x2 = width / 2; y2 = width / 2;
        vx1 = width / 2; vy1 = width / 2;
        vx2 = length; vy2 = width / 2;
      case _CornerOrientation.topRight:
        x1 = size.width - width / 2; y1 = length;
        x2 = size.width - width / 2; y2 = width / 2;
        vx1 = size.width - width / 2; vy1 = width / 2;
        vx2 = size.width - length; vy2 = width / 2;
      case _CornerOrientation.bottomLeft:
        x1 = width / 2; y1 = size.height - length;
        x2 = width / 2; y2 = size.height - width / 2;
        vx1 = width / 2; vy1 = size.height - width / 2;
        vx2 = length; vy2 = size.height - width / 2;
      case _CornerOrientation.bottomRight:
        x1 = size.width - width / 2; y1 = size.height - length;
        x2 = size.width - width / 2; y2 = size.height - width / 2;
        vx1 = size.width - width / 2; vy1 = size.height - width / 2;
        vx2 = size.width - length; vy2 = size.height - width / 2;
    }

    // Vertical line
    canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    // Horizontal line
    canvas.drawLine(Offset(vx1, vy1), Offset(vx2, vy2), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter oldDelegate) =>
      color != oldDelegate.color;
}
