import 'package:flutter/material.dart';
import '../app_state.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets/photo_placeholder.dart';

class OnboardingScreen extends StatefulWidget {
  final int initialStep;
  final VoidCallback? onFinish;

  const OnboardingScreen({super.key, this.initialStep = 0, this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late int step = widget.initialStep;

  void _next() {
    if (step == 1) {
      // Step 1 is informational — the actual OS permission popup is deferred
      // until a feature in the app needs the device position.
      widget.onFinish?.call();
      return;
    }
    setState(() => step += 1);
  }

  void _skip() => widget.onFinish?.call();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.palette;
    final l = L(state.lang);
    final s = l.onbSteps[step];

    return Container(
      color: p.bg,
      child: Column(
        children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/babiguide-logo.png',
                    width: 30,
                    height: 30,
                    fit: BoxFit.cover,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _skip,
                  child: Text(
                    l.skip,
                    style: BgFonts.body(
                      size: 13,
                      weight: FontWeight.w600,
                      color: p.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _StepHero(step: step),
          // Copy
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s['eyebrow']!.toUpperCase(),
                    style: BgFonts.body(
                      size: 11,
                      weight: FontWeight.w700,
                      color: p.orangeDeep,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s['title']!,
                    style: BgFonts.display(
                      size: 26,
                      weight: FontWeight.w700,
                      color: p.ink,
                      letterSpacing: -0.6,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s['body']!,
                    style: BgFonts.body(
                      size: 14,
                      color: p.inkMuted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Dots + CTA
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 38),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(2, (i) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == step ? 22 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == step ? p.orange : const Color(0x2E785028),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 18),
                if (step == 1)
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: _OutlineButton(label: l.later, onTap: _skip),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _PrimaryButton(
                          label: l.allow,
                          icon: Icons.location_on_outlined,
                          onTap: _next,
                        ),
                      ),
                    ],
                  )
                else
                  _PrimaryButton(
                    label: l.next,
                    onTap: _next,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepHero extends StatelessWidget {
  final int step;
  const _StepHero({required this.step});

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    if (step == 0) {
      return SizedBox(
        width: double.infinity,
        height: 320,
        child: Stack(
          children: [
            Positioned.fill(
              child: PhotoPlaceholder(seed: 'onb-hero', label: 'ABIDJAN · LAGUNE'),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, p.bg],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              left: 30,
              child: Transform.rotate(
                angle: -0.105,
                child: _FloatingPhoto(seed: 'card-a', label: 'POULET', w: 110, h: 90),
              ),
            ),
            Positioned(
              top: 70,
              right: 24,
              child: Transform.rotate(
                angle: 0.14,
                child: _FloatingPhoto(seed: 'card-b', label: 'ATTIÉKÉ', w: 100, h: 80),
              ),
            ),
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: Transform.rotate(
                  angle: -0.052,
                  child: _FloatingPhoto(seed: 'card-c', label: 'MAQUIS', w: 120, h: 95),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (step == 1) {
      return SizedBox(
        width: double.infinity,
        height: 320,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (int i = 0; i < 4; i++)
              Container(
                width: 80 + i * 60.0,
                height: 80 + i * 60.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: p.orange.withValues(alpha: 0.4 * (0.7 - i * 0.15).clamp(0.0, 1.0)),
                    width: 1,
                  ),
                ),
                child: CustomPaint(painter: _DashedCircle(color: p.orange.withValues(alpha: 0.4))),
              ),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: p.orange,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: p.orange.withValues(alpha: 0.6),
                    blurRadius: 38,
                    offset: const Offset(0, 18),
                    spreadRadius: -10,
                  ),
                ],
              ),
              child: const Icon(Icons.location_on_outlined, color: Colors.white, size: 28),
            ),
            ..._neighborhoods(p),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  List<Widget> _neighborhoods(BgPalette p) {
    const names = [
      ['Cocody', 0.20, 0.25],
      ['Plateau', 0.74, 0.32],
      ['Marcory', 0.24, 0.72],
      ['Riviera', 0.70, 0.68],
    ];
    return names.map((n) {
      return FractionallySizedBox(
        widthFactor: 1,
        heightFactor: 1,
        child: Align(
          alignment: Alignment(
            ((n[1] as double) * 2) - 1,
            ((n[2] as double) * 2) - 1,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: p.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: -6,
                ),
              ],
            ),
            child: Text(
              n[0] as String,
              style: BgFonts.body(
                size: 11,
                weight: FontWeight.w600,
                color: p.ink,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}

class _DashedCircle extends CustomPainter {
  final Color color;
  _DashedCircle({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final r = size.width / 2;
    final cx = size.width / 2;
    final cy = size.height / 2;
    const dashAngle = 6 * 3.14159 / 180;
    const gapAngle = 3 * 3.14159 / 180;
    double a = 0;
    while (a < 6.2832) {
      final p1 = Offset(cx + r * (a == 0 ? 1 : 0), cy);
      // Use arc approximation
      final path = Path()
        ..addArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), a, dashAngle);
      canvas.drawPath(path, paint);
      a += dashAngle + gapAngle;
      // Suppress unused warning
      p1.dx;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCircle old) => false;
}

class _FloatingPhoto extends StatelessWidget {
  final String seed;
  final String label;
  final double w;
  final double h;

  const _FloatingPhoto({required this.seed, required this.label, required this.w, required this.h});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 28,
            offset: const Offset(0, 12),
            spreadRadius: -10,
          ),
        ],
      ),
      child: PhotoPlaceholder(
        seed: seed,
        label: label,
        width: w,
        height: h,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  const _PrimaryButton({required this.label, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: p.orange,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: p.orange.withValues(alpha: 0.6),
              blurRadius: 22,
              offset: const Offset(0, 10),
              spreadRadius: -10,
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 15),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: BgFonts.body(
                  size: 14,
                  weight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _OutlineButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: p.cardBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            label,
            style: BgFonts.body(
              size: 14,
              weight: FontWeight.w600,
              color: p.ink,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
