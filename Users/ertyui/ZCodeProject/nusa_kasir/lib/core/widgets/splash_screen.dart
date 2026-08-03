import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/nusa_config.dart';
import '../utils/icon_loader.dart';
import 'package:nusa_kasir/shared/widgets/animated_builder.dart'
    show NusaAnimatedBuilder;

/// Splash screen — dynamic variant logo + "NUSA" title + subtitle + bouncing dots.
///
/// The logo PNG is selected from the active theme colour via [splashLogoPath].
/// A "NUSA" title and "by Halu Goods Indonesia" subtitle are rendered below.
/// The 3-dot bouncing animation is layered at the bottom.
/// After ~2.5 seconds, calls [onDone].
class SplashScreen extends StatefulWidget {
  final void Function(BuildContext context) onDone;
  final Duration duration;

  SplashScreen({
    super.key,
    required this.onDone,
    this.duration = const Duration(milliseconds: 2500),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  late final List<AnimationController> _dotCtrls;
  late final List<Animation<double>> _dotAnims;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();

    // Bouncing dots — staggered loop
    _dotCtrls = List.generate(3, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600),
      );
    });
    _dotAnims = List.generate(3, (i) {
      return Tween<double>(begin: 0, end: -12).animate(
        CurvedAnimation(
          parent: _dotCtrls[i],
          curve: Interval(0, 0.5, curve: Curves.easeOut),
        ),
      );
    });

    for (var i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        _startDotLoop(i);
      });
    }

    Future.delayed(widget.duration, () {
      if (mounted) {
        _fadeCtrl.reverse().then((_) {
          widget.onDone(context);
        });
      }
    });
  }

  void _startDotLoop(int i) {
    if (!mounted) return;
    _dotCtrls[i]
        .forward()
        .then((_) => _dotCtrls[i].reverse())
        .then((_) => _startDotLoop(i));
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    for (final c in _dotCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = NusaConfig.activePrimary;
    final logoAsset = splashLogoPath();

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        color: isDark ? NusaConfig.darkBackground : NusaConfig.backgroundColor,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Centered logo + text block
            Center(
              child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Logo (dynamic by theme) ──
                    Image.asset(
                      logoAsset,
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(height: 24),
                    // ── NUSA ──
                    Text(
                      'NUSA',
                      style: GoogleFonts.poppins(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                        color: isDark
                            ? NusaConfig.darkTextPrimary
                            : NusaConfig.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6),
                    // ── by Halu Goods Indonesia ──
                    Text(
                      'by Halu Goods Indonesia',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? NusaConfig.darkTextTertiary
                            : NusaConfig.textTertiary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bouncing dots at bottom
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  return NusaAnimatedBuilder(
                    animation: _dotAnims[i],
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _dotAnims[i].value),
                        child: child,
                      );
                    },
                    child: Container(
                      width: 10,
                      height: 10,
                      margin: EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
