import 'package:flutter/material.dart';
import '../api/api_error.dart';
import '../api/places_api.dart';
import '../app_state.dart';
import '../data.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets/photo_placeholder.dart';

// Fixed bbox covering greater Abidjan. The custom-painted map below is
// stylised, not geographic, so we project marker lat/lng linearly onto the
// design's 402×874 canvas using these bounds.
const double _swLat = 5.30;
const double _swLng = -4.10;
const double _neLat = 5.45;
const double _neLng = -3.85;

class MapScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final ValueChanged<String>? onOpenRestaurant;

  const MapScreen({super.key, this.onBack, this.onOpenRestaurant});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Future<MapMarkers>? _future;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  void _load() {
    final api = AppScope.of(context).placesApi;
    setState(() {
      _future = api.getMarkers(
        swLat: _swLat,
        swLng: _swLng,
        neLat: _neLat,
        neLng: _neLng,
      );
    });
  }

  Offset _project(double lat, double lng, Size size) {
    final dx = ((lng - _swLng) / (_neLng - _swLng)).clamp(0.0, 1.0);
    final dy = ((_neLat - lat) / (_neLat - _swLat)).clamp(0.0, 1.0);
    return Offset(dx * size.width, dy * size.height);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.palette;
    final l = L(state.lang);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _MapPainter())),
            FutureBuilder<MapMarkers>(
              future: _future,
              builder: (context, snap) {
                final markers = snap.data?.markers ?? const <MapMarker>[];
                return Stack(
                  children: [
                    for (final m in markers)
                      _PositionedPin(
                        offset: _project(m.lat, m.lng, size),
                        label: m.rating.toStringAsFixed(1),
                        big: m.id == _selectedId || m.sponsored,
                        onTap: () => setState(() => _selectedId = m.id),
                      ),
                  ],
                );
              },
            ),
            // You-are-here glow (Abidjan centre as a placeholder)
            Builder(builder: (context) {
              final youOff = _project(5.36, -4.00, size);
              return Positioned(
                left: youOff.dx - 40,
                top: youOff.dy - 40,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        p.green.withValues(alpha: 0.25),
                        p.green.withValues(alpha: 0),
                      ],
                      stops: const [0.0, 0.7],
                    ),
                  ),
                ),
              );
            }),
            Positioned(
              top: 56,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  if (widget.onBack != null) ...[
                    GestureDetector(
                      onTap: widget.onBack,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.chevron_left,
                            size: 20, color: p.ink),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                            spreadRadius: -8,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search,
                              size: 15, color: const Color(0xFF2A1A0E)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l.searchTheMap,
                              style: BgFonts.body(
                                  size: 13,
                                  color: const Color(0xFF2A1A0E)),
                            ),
                          ),
                          Icon(Icons.tune,
                              size: 15, color: const Color(0xFF2A1A0E)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            FutureBuilder<MapMarkers>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Positioned(
                    bottom: 200,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                if (snap.hasError) {
                  final msg = snap.error is ApiError
                      ? (snap.error as ApiError).message
                      : l.pick('Erreur de carte', 'Map failed to load');
                  return Positioned(
                    bottom: 100,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(msg,
                          style: BgFonts.body(size: 12, color: p.ink)),
                    ),
                  );
                }
                final markers = snap.data?.markers ?? const <MapMarker>[];
                if (markers.isEmpty) return const SizedBox.shrink();
                return Positioned(
                  bottom: 90,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: markers.length.clamp(0, 12),
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (_, i) {
                        final m = markers[i];
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedId = m.id);
                            widget.onOpenRestaurant?.call(m.id);
                          },
                          child: _MarkerCard(m: m, l: l, p: p),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _MarkerCard extends StatelessWidget {
  final MapMarker m;
  final L l;
  final BgPalette p;
  const _MarkerCard({required this.m, required this.l, required this.p});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 28,
            offset: const Offset(0, 12),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Row(
        children: [
          PhotoPlaceholder(
            seed: m.id,
            showLabel: false,
            width: 70,
            height: 70,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (m.sponsored)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: p.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      l.sponsored.toUpperCase(),
                      style: BgFonts.body(
                        size: 9,
                        weight: FontWeight.w700,
                        color: p.orangeDeep,
                        letterSpacing: 0.4,
                        height: 1,
                      ),
                    ),
                  ),
                if (m.sponsored) const SizedBox(height: 3),
                Text(
                  m.name,
                  style: BgFonts.display(
                    size: 14,
                    weight: FontWeight.w700,
                    color: const Color(0xFF2A1A0E),
                    height: 1.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star_rounded, size: 11, color: p.orange),
                    const SizedBox(width: 3),
                    Text(
                      m.rating.toStringAsFixed(1),
                      style: BgFonts.body(
                        size: 11,
                        weight: FontWeight.w700,
                        color: const Color(0xFF2A1A0E),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      m.price,
                      style: BgFonts.body(
                          size: 11, color: const Color(0xFF8C7561)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      m.open ? '· ${l.open}' : '· ${l.closed}',
                      style: BgFonts.body(
                          size: 10, color: const Color(0xFF8C7561)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionedPin extends StatelessWidget {
  final Offset offset;
  final String label;
  final bool big;
  final VoidCallback? onTap;

  const _PositionedPin({
    required this.offset,
    required this.label,
    this.big = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = big ? 44.0 : 32.0;
    const color = Color(0xFFF37221);
    return Positioned(
      left: offset.dx - size / 2,
      top: offset.dy - size,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: BgFonts.display(
                  size: big ? 13 : 11,
                  weight: FontWeight.w700,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
            CustomPaint(
              size: const Size(10, 8),
              painter: _PinTip(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinTip extends CustomPainter {
  final Color color;
  _PinTip({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PinTip old) => false;
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 402;
    final sy = size.height / 874;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEFE3CB),
    );

    final grid = Paint()
      ..color = const Color(0xFF785028).withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 30 * sx) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 30 * sy) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final lagoon = Paint()..color = const Color(0xB3A8C8C8);
    final lagoonPath = Path()
      ..moveTo(0, 540 * sy)
      ..quadraticBezierTo(100 * sx, 480 * sy, 220 * sx, 520 * sy)
      ..quadraticBezierTo(311 * sx, 540 * sy, 402 * sx, 510 * sy)
      ..lineTo(402 * sx, 720 * sy)
      ..quadraticBezierTo(300 * sx, 760 * sy, 180 * sx, 720 * sy)
      ..quadraticBezierTo(90 * sx, 700 * sy, 0, 740 * sy)
      ..close();
    canvas.drawPath(lagoonPath, lagoon);

    final lagoonStroke = Paint()
      ..color = const Color(0xFF7BA1A1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final lagoonTop = Path()
      ..moveTo(0, 540 * sy)
      ..quadraticBezierTo(100 * sx, 480 * sy, 220 * sx, 520 * sy)
      ..quadraticBezierTo(311 * sx, 540 * sy, 402 * sx, 510 * sy);
    canvas.drawPath(lagoonTop, lagoonStroke);

    final roadUnder = Paint()
      ..color = const Color(0xFFD4BD92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    final roads = [
      [0.0, 200.0, 402.0, 280.0],
      [0.0, 360.0, 402.0, 320.0],
      [120.0, 0.0, 160.0, 874.0],
      [260.0, 0.0, 240.0, 874.0],
      [0.0, 700.0, 402.0, 760.0],
    ];
    for (final r in roads) {
      canvas.drawLine(
        Offset(r[0] * sx, r[1] * sy),
        Offset(r[2] * sx, r[3] * sy),
        roadUnder,
      );
    }
    final roadLine = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final r in roads) {
      canvas.drawLine(
        Offset(r[0] * sx, r[1] * sy),
        Offset(r[2] * sx, r[3] * sy),
        roadLine,
      );
    }

    final park = Paint()..color = const Color(0x999DB89E);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(40 * sx, 100 * sy, 120 * sx, 80 * sy),
        const Radius.circular(4),
      ),
      park,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(220 * sx, 380 * sy, 100 * sx, 60 * sy),
        const Radius.circular(4),
      ),
      park,
    );

    final bridge = Paint()
      ..color = const Color(0xFF7E5A2B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(
        Offset(180 * sx, 510 * sy), Offset(220 * sx, 540 * sy), bridge);
    canvas.drawLine(
        Offset(180 * sx, 540 * sy), Offset(220 * sx, 510 * sy), bridge);

    void drawLabel(String t, double x, double y) {
      final tp = TextPainter(
        text: TextSpan(
          text: t,
          style: BgFonts.display(
            size: 14,
            weight: FontWeight.w700,
            color: const Color(0x733C1E00),
            letterSpacing: 2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x, y));
    }

    drawLabel('COCODY', 80 * sx, 80 * sy);
    drawLabel('PLATEAU', 280 * sx, 220 * sy);
    drawLabel('TREICHVILLE', 60 * sx, 640 * sy);
    drawLabel('MARCORY', 250 * sx, 800 * sy);
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => false;
}
