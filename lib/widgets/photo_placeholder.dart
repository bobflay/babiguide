import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme.dart';

const _palettes = <List<Color>>[
  [Color(0xFFF37221), Color(0xFFC84B0E), Color(0xFF7A2A00)],
  [Color(0xFFE8A04A), Color(0xFFB26A1B), Color(0xFF5C3413)],
  [Color(0xFF8C6A3F), Color(0xFF5E4527), Color(0xFF2E1F10)],
  [Color(0xFF3F6B4E), Color(0xFF2A4A36), Color(0xFF15281D)],
  [Color(0xFFD6B98A), Color(0xFFA38458), Color(0xFF5A4427)],
  [Color(0xFFC44A2D), Color(0xFF7E2B17), Color(0xFF3A1208)],
];

int _hashIdx(String seed, int mod) {
  var h = 0;
  for (var i = 0; i < seed.length; i++) {
    h = ((h * 31) + seed.codeUnitAt(i)) & 0xFFFFFFFF;
  }
  return h % mod;
}

class PhotoPlaceholder extends StatelessWidget {
  final String seed;
  final String? label;
  final bool showLabel;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? overlay;
  final String? photoUrl;

  const PhotoPlaceholder({
    super.key,
    required this.seed,
    this.label,
    this.showLabel = true,
    this.width,
    this.height,
    this.borderRadius,
    this.overlay,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _palettes[_hashIdx(seed, _palettes.length)];
    final angleDeg = (25 + _hashIdx('${seed}a', 60)).toDouble();
    final rad = angleDeg * 3.14159265 / 180.0;
    final dx = -1 + 2 * (1 - (rad % 3.14159265) / 3.14159265);
    final ang = Alignment(
      -1 * (1 - (angleDeg % 180) / 180) * 2 + 1,
      ((angleDeg % 360) / 360) * 2 - 1,
    );
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    if (kDebugMode && hasPhoto) {
      debugPrint('[PhotoPlaceholder] seed=$seed url=$photoUrl');
    }
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: ang,
            end: -ang,
            colors: [palette[2], palette[1], palette[0]],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _WeavePainter(angle: rad, dx: dx),
            ),
            if (hasPhoto)
              Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) {
                  if (kDebugMode) {
                    debugPrint(
                        '[PhotoPlaceholder] failed to load $photoUrl: $error');
                  }
                  return const SizedBox.shrink();
                },
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox.shrink();
                },
              ),
            if (showLabel && label != null)
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    label!,
                    style: BgFonts.mono(
                      size: 9,
                      color: Colors.white.withValues(alpha: 0.85),
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ?overlay,
          ],
        ),
      ),
    );
  }
}

class _WeavePainter extends CustomPainter {
  final double angle;
  final double dx;
  _WeavePainter({required this.angle, required this.dx});

  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    final p2 = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle);
    canvas.translate(-size.width, -size.height);
    final w = size.width * 2;
    final h = size.height * 2;
    for (double y = 0; y < h; y += 7) {
      canvas.drawLine(Offset(0, y), Offset(w, y), p1);
    }
    canvas.restore();
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-angle);
    canvas.translate(-size.width, -size.height);
    for (double y = 0; y < h; y += 11) {
      canvas.drawLine(Offset(0, y), Offset(w, y), p2);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WeavePainter old) =>
      old.angle != angle || old.dx != dx;
}
