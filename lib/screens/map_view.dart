import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../api/api_error.dart';
import '../api/places_api.dart';
import '../app_state.dart';
import '../data.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets/photo_placeholder.dart';

// Bounding box covering greater Abidjan; used to fetch markers and as the
// initial camera target for the FlutterMap viewport.
const double _swLat = 5.30;
const double _swLng = -4.10;
const double _neLat = 5.45;
const double _neLng = -3.85;
const LatLng _abidjanCenter = LatLng(5.36, -4.00);

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
  final MapController _controller = MapController();

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

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.palette;
    final l = L(state.lang);

    return Stack(
      children: [
        Positioned.fill(
          child: FutureBuilder<MapMarkers>(
            future: _future,
            builder: (context, snap) {
              final markers = snap.data?.markers ?? const <MapMarker>[];
              return FlutterMap(
                mapController: _controller,
                options: const MapOptions(
                  initialCenter: _abidjanCenter,
                  initialZoom: 12,
                  minZoom: 10,
                  maxZoom: 18,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'app.babiguide.mobile',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _abidjanCenter,
                        width: 80,
                        height: 80,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  p.green.withValues(alpha: 0.35),
                                  p.green.withValues(alpha: 0),
                                ],
                                stops: const [0.0, 0.7],
                              ),
                            ),
                          ),
                        ),
                      ),
                      for (final m in markers)
                        Marker(
                          point: LatLng(m.lat, m.lng),
                          width: 56,
                          height: 56,
                          alignment: Alignment.topCenter,
                          child: _Pin(
                            label: m.rating.toStringAsFixed(1),
                            big: m.id == _selectedId || m.sponsored,
                            onTap: () {
                              setState(() => _selectedId = m.id);
                              _controller.move(LatLng(m.lat, m.lng), 15);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
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
            final selected = _selectedId == null
                ? null
                : markers.where((m) => m.id == _selectedId).firstOrNull;
            if (selected != null) {
              return Positioned(
                bottom: 90,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            widget.onOpenRestaurant?.call(selected.id),
                        child: _MarkerCard(m: selected, l: l, p: p),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _selectedId = null),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                              spreadRadius: -8,
                            ),
                          ],
                        ),
                        child: Icon(Icons.close,
                            size: 18, color: p.ink),
                      ),
                    ),
                  ],
                ),
              );
            }
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
                        _controller.move(LatLng(m.lat, m.lng), 15);
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

class _Pin extends StatelessWidget {
  final String label;
  final bool big;
  final VoidCallback? onTap;

  const _Pin({
    required this.label,
    this.big = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = big ? 44.0 : 32.0;
    const color = Color(0xFFF37221);
    return GestureDetector(
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
