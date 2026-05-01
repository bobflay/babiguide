import 'dart:math';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../i18n.dart';
import '../theme.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback? onContinue;
  final int minDurationMs;
  const SplashScreen({
    super.key,
    this.onContinue,
    this.minDurationMs = 2200,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _pulse;
  late final AnimationController _dots;
  late final AnimationController _ring;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
    _dots = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    _ring = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();

    if (widget.onContinue != null) {
      Future.delayed(Duration(milliseconds: widget.minDurationMs), () {
        if (mounted) widget.onContinue!();
      });
    }
  }

  @override
  void dispose() {
    _entry.dispose();
    _pulse.dispose();
    _dots.dispose();
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.palette;
    final l = L(state.lang);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background gradient
        DecoratedBox(
          decoration: BoxDecoration(
            color: p.bg,
            gradient: RadialGradient(
              center: const Alignment(0, -0.2),
              radius: 0.9,
              colors: [
                p.orange.withValues(alpha: 0.18),
                p.bg.withValues(alpha: 0),
              ],
              stops: const [0.0, 0.7],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, 1),
              radius: 0.9,
              colors: [
                p.green.withValues(alpha: 0.10),
                p.bg.withValues(alpha: 0),
              ],
              stops: const [0.0, 0.7],
            ),
          ),
        ),
        // Weave
        Opacity(
          opacity: 0.06,
          child: CustomPaint(painter: _WeaveOverlay(color: p.ink)),
        ),
        // Skyline
        Positioned(
          top: MediaQuery.of(context).size.height * 0.24,
          left: 0,
          right: 0,
          child: SizedBox(
            height: 90,
            child: Opacity(
              opacity: 0.10,
              child: CustomPaint(painter: _SkylinePainter(color: p.orangeDeep)),
            ),
          ),
        ),
        // Center mark
        Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_entry, _ring, _pulse]),
            builder: (_, __) {
              final t = Curves.easeOutBack.transform(_entry.value.clamp(0, 1));
              return Opacity(
                opacity: _entry.value,
                child: Transform.scale(
                  scale: 0.92 + 0.08 * t,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 168,
                        height: 168,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            for (int i = 0; i < 3; i++)
                              _PulsingRing(
                                phase: (_pulse.value + i * 0.33) % 1,
                                color: p.orange,
                              ),
                            CustomPaint(
                              size: const Size(168, 168),
                              painter: _ProgressRing(
                                progress: _ring.value,
                                color: p.orange,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8EE),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: p.orangeDeep.withValues(alpha: 0.45),
                                    blurRadius: 40,
                                    offset: const Offset(0, 18),
                                    spreadRadius: -18,
                                  ),
                                ],
                                border: Border.all(
                                  color: p.orange.withValues(alpha: 0.18),
                                ),
                              ),
                              child: ClipOval(
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Image.asset(
                                    'assets/images/babiguide-logo.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'BabiGuide',
                        style: BgFonts.display(
                          size: 32,
                          weight: FontWeight.w800,
                          color: p.orangeDeep,
                          letterSpacing: -0.8,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l.splashTagline,
                        style: BgFonts.display(
                          size: 14,
                          weight: FontWeight.w600,
                          color: p.ink,
                          letterSpacing: -0.1,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.splashSub.toUpperCase(),
                        style: BgFonts.body(
                          size: 11,
                          weight: FontWeight.w600,
                          color: p.inkMuted,
                          letterSpacing: 0.6,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Bridge near bottom
        Positioned(
          bottom: 110,
          left: 0,
          right: 0,
          child: SizedBox(
            height: 60,
            child: Opacity(
              opacity: 0.18,
              child: CustomPaint(painter: _BridgePainter(color: p.orangeDeep)),
            ),
          ),
        ),
        // Loading dots
        Positioned(
          bottom: 56,
          left: 0,
          right: 0,
          child: AnimatedBuilder(
            animation: _dots,
            builder: (_, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final phase = ((_dots.value + i * 0.18) % 1.0);
                    final tt = (sin(phase * 2 * pi) + 1) / 2;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Opacity(
                        opacity: 0.25 + 0.75 * tt,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: p.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                Text(
                  l.loading.toUpperCase(),
                  style: BgFonts.body(
                    size: 10,
                    weight: FontWeight.w600,
                    color: p.inkMuted,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PulsingRing extends StatelessWidget {
  final double phase;
  final Color color;
  const _PulsingRing({required this.phase, required this.color});

  @override
  Widget build(BuildContext context) {
    final scale = 1 + 0.4 * phase;
    final opacity = (0.5 - phase * 0.5).clamp(0.0, 1.0);
    return Transform.scale(
      scale: scale,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: opacity),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _ProgressRing extends CustomPainter {
  final double progress;
  final Color color;
  _ProgressRing({required this.progress, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: 78);
    canvas.drawArc(rect, -pi / 2, 2 * pi * 0.5 * progress, false, p);
  }

  @override
  bool shouldRepaint(covariant _ProgressRing old) => old.progress != progress;
}

class _SkylinePainter extends CustomPainter {
  final Color color;
  _SkylinePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final w = size.width;
    final h = size.height;
    final path = Path();
    final pts = [
      [0.0, 60.0], [0.0, 40.0], [50.0, 40.0], [50.0, 30.0], [100.0, 30.0],
      [125.0, 10.0], [150.0, 10.0], [150.0, 30.0], [220.0, 30.0],
      [220.0, 18.0], [290.0, 18.0], [320.0, -10.0], [350.0, -10.0],
      [375.0, 0.0], [405.0, 0.0], [410.0, 18.0], [445.0, 18.0],
      [445.0, 30.0], [520.0, 30.0], [520.0, -20.0], [560.0, -20.0],
      [600.0, 0.0], [640.0, 0.0], [640.0, 14.0], [720.0, 14.0],
      [720.0, 30.0], [800.0, 30.0], [840.0, 4.0], [880.0, 4.0],
      [880.0, 36.0], [950.0, 36.0], [950.0, 50.0], [w, 50.0], [w, h], [0, h]
    ];
    final scale = w / 1000.0;
    for (var i = 0; i < pts.length; i++) {
      final x = pts[i][0] * scale;
      final y = pts[i][1] / 90 * h + 18;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _SkylinePainter old) => false;
}

class _BridgePainter extends CustomPainter {
  final Color color;
  _BridgePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final cx = size.width / 2;
    final base = size.height * 0.83;
    final top = size.height * 0.13;
    canvas.drawLine(Offset(0, base), Offset(size.width, base), p);
    final cables = [-101, -71, -41, 41, 71, 101];
    for (final c in cables) {
      canvas.drawLine(
        Offset(cx, top),
        Offset(cx + c.toDouble(), base),
        Paint()
          ..color = color
          ..strokeWidth = 1
          ..strokeCap = StrokeCap.round,
      );
    }
    final p2 = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, 0), Offset(cx, base), p2);
  }

  @override
  bool shouldRepaint(covariant _BridgePainter old) => false;
}

class _WeaveOverlay extends CustomPainter {
  final Color color;
  _WeaveOverlay({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(pi / 4);
    canvas.translate(-size.width, -size.height);
    final w = size.width * 2;
    final h = size.height * 2;
    for (double y = 0; y < h; y += 14) {
      canvas.drawLine(Offset(0, y), Offset(w, y), p);
    }
    canvas.restore();
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-pi / 4);
    canvas.translate(-size.width, -size.height);
    for (double y = 0; y < h; y += 14) {
      canvas.drawLine(Offset(0, y), Offset(w, y), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WeaveOverlay old) => false;
}
