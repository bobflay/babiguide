import 'package:flutter/material.dart';
import '../api/api_error.dart';
import '../api/places_api.dart';
import '../app_state.dart';
import '../data.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets/photo_placeholder.dart';

const List<String> _categoryKeys = [
  'all',
  'food',
  'place',
  'toilets',
  'staff',
  'videos',
];

class MediaScreen extends StatefulWidget {
  final String? slug;
  final String? placeName;
  final VoidCallback? onBack;
  final bool initialLightbox;
  final int initialIndex;

  const MediaScreen({
    super.key,
    this.slug,
    this.placeName,
    this.onBack,
    this.initialLightbox = false,
    this.initialIndex = 0,
  });

  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  int _tab = 0;
  int? _open;
  final Map<String, MediaPage> _cache = {};
  Future<MediaPage>? _future;
  Map<String, int> _counts = const {};

  @override
  void initState() {
    super.initState();
    if (widget.initialLightbox) _open = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  void _load() {
    final slug = widget.slug;
    if (slug == null || slug.isEmpty) {
      setState(() {
        _future = Future.error(
          ApiError(message: 'Missing place identifier'),
        );
      });
      return;
    }
    final cat = _categoryKeys[_tab];
    final cached = _cache[cat];
    if (cached != null) {
      setState(() {
        _future = Future.value(cached);
        _counts = cached.countsByCategory.isNotEmpty
            ? cached.countsByCategory
            : _counts;
      });
      return;
    }
    final api = AppScope.of(context).placesApi;
    final fut = api.getMedia(slug, category: cat).then((page) {
      _cache[cat] = page;
      if (mounted) {
        setState(() {
          if (page.countsByCategory.isNotEmpty) {
            _counts = page.countsByCategory;
          }
        });
      }
      return page;
    });
    setState(() {
      _future = fut;
    });
  }

  void _selectTab(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.palette;
    final l = L(state.lang);
    final tabs = l.mediaTabs;

    return Stack(
      children: [
        Container(
          color: p.bg,
          child: FutureBuilder<MediaPage>(
            future: _future,
            builder: (context, snap) {
              final filtered = snap.data?.items ?? const <GalleryItem>[];
              final loading = snap.connectionState == ConnectionState.waiting;
              final error = snap.error;
              return ListView(
                padding: const EdgeInsets.only(bottom: 30),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 54, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: widget.onBack,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: p.card,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.chevron_left,
                                    size: 18, color: p.ink),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (widget.placeName ?? '').toUpperCase(),
                                    style: BgFonts.body(
                                      size: 11,
                                      weight: FontWeight.w600,
                                      color: p.inkMuted,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        l.mediaTitle,
                                        style: BgFonts.display(
                                          size: 19,
                                          weight: FontWeight.w700,
                                          color: p.ink,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '· ${_countFor(_categoryKeys[_tab], filtered.length)}',
                                        style: BgFonts.display(
                                          size: 19,
                                          weight: FontWeight.w600,
                                          color: p.inkMuted,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: p.orange,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add,
                                  size: 18, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 32,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: tabs.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 6),
                            itemBuilder: (_, i) {
                              final on = i == _tab;
                              return GestureDetector(
                                onTap: () => _selectTab(i),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: on ? p.ink : p.card,
                                    borderRadius: BorderRadius.circular(999),
                                    border: on
                                        ? null
                                        : Border.all(color: p.cardBorder),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        tabs[i],
                                        style: BgFonts.body(
                                          size: 12,
                                          weight: FontWeight.w600,
                                          color: on ? p.bg : p.ink,
                                          height: 1,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: on
                                              ? Colors.white
                                                  .withValues(alpha: 0.18)
                                              : const Color(0x1A785028),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        constraints:
                                            const BoxConstraints(minWidth: 16),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '${_counts[_categoryKeys[i]] ?? 0}',
                                          style: BgFonts.body(
                                            size: 10,
                                            weight: FontWeight.w700,
                                            color: on ? p.bg : p.inkMuted,
                                            height: 1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (loading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(p.orange),
                          ),
                        ),
                      ),
                    )
                  else if (error != null)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          error is ApiError
                              ? error.message
                              : l.pick('Erreur de chargement',
                                  'Failed to load media'),
                          textAlign: TextAlign.center,
                          style: BgFonts.body(size: 13, color: p.inkMuted),
                        ),
                      ),
                    )
                  else if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          l.pick('Aucun média', 'No media yet'),
                          style: BgFonts.body(size: 14, color: p.inkMuted),
                        ),
                      ),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: SizedBox(
                        height: 220 + 6,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 220 + 6,
                                child: filtered.isNotEmpty
                                    ? _MediaTile(
                                        item: filtered[0],
                                        onTap: () =>
                                            setState(() => _open = 0),
                                      )
                                    : const SizedBox(),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 1,
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: 110,
                                    child: filtered.length > 1
                                        ? _MediaTile(
                                            item: filtered[1],
                                            onTap: () =>
                                                setState(() => _open = 1),
                                          )
                                        : const SizedBox(),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 110,
                                    child: filtered.length > 2
                                        ? _MediaTile(
                                            item: filtered[2],
                                            onTap: () =>
                                                setState(() => _open = 2),
                                          )
                                        : const SizedBox(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (filtered.length > 3)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                        child: GridView.count(
                          crossAxisCount: 3,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            for (var i = 3; i < filtered.length; i++)
                              _MediaTile(
                                item: filtered[i],
                                onTap: () => setState(() => _open = i),
                              ),
                          ],
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
        if (_open != null) _LightboxOverlay(
          open: _open!,
          items: _cache[_categoryKeys[_tab]]?.items ?? const [],
          onClose: () => setState(() => _open = null),
        ),
      ],
    );
  }

  int _countFor(String cat, int fallback) {
    return _counts[cat] ?? fallback;
  }
}

class _LightboxOverlay extends StatefulWidget {
  final int open;
  final List<GalleryItem> items;
  final VoidCallback onClose;

  const _LightboxOverlay({
    required this.open,
    required this.items,
    required this.onClose,
  });

  @override
  State<_LightboxOverlay> createState() => _LightboxOverlayState();
}

class _LightboxOverlayState extends State<_LightboxOverlay> {
  late int _idx;
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _idx = widget.open;
    _controller = PageController(initialPage: widget.open);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _jumpTo(int i) {
    if (i < 0 || i >= widget.items.length || i == _idx) return;
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty || _idx >= items.length) {
      return const SizedBox.shrink();
    }
    return _Lightbox(
      items: items,
      idx: _idx,
      controller: _controller,
      thumbStrip: items.take(10).toList(),
      onClose: widget.onClose,
      onPageChanged: (i) => setState(() => _idx = i),
      onThumbTap: _jumpTo,
    );
  }
}

class _MediaTile extends StatelessWidget {
  final GalleryItem item;
  final VoidCallback onTap;
  const _MediaTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Positioned.fill(
              child: PhotoPlaceholder(
                seed: item.seed,
                label: item.label,
                photoUrl: item.thumbUrl ?? item.url,
              ),
            ),
            if (item.kind == 'video') ...[
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.5),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow,
                      size: 11, color: Colors.white),
                ),
              ),
              if (item.duration != null)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Text(
                    item.duration!,
                    style: BgFonts.mono(size: 10, color: Colors.white),
                  ),
                ),
            ],
            if (item.verified)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: p.orange.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified, size: 10, color: Colors.white),
                      const SizedBox(width: 3),
                      Text(
                        'OFFICIEL',
                        style: BgFonts.body(
                          size: 9,
                          weight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Lightbox extends StatelessWidget {
  final List<GalleryItem> items;
  final int idx;
  final PageController controller;
  final List<GalleryItem> thumbStrip;
  final VoidCallback onClose;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onThumbTap;

  const _Lightbox({
    required this.items,
    required this.idx,
    required this.controller,
    required this.thumbStrip,
    required this.onClose,
    required this.onPageChanged,
    required this.onThumbTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    final state = AppScope.of(context);
    final l = L(state.lang);
    final item = items[idx];
    final total = items.length;
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF0E0805),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: onClose,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 18, color: Colors.white),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '${idx + 1} ${l.of} $total',
                            style: BgFonts.display(
                              size: 14,
                              weight: FontWeight.w700,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.cat,
                            style: BgFonts.body(
                              size: 11,
                              color: Colors.white.withValues(alpha: 0.6),
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share,
                          size: 16, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: PageView.builder(
                    controller: controller,
                    onPageChanged: onPageChanged,
                    itemCount: total,
                    itemBuilder: (_, i) {
                      final pi = items[i];
                      return Center(
                        child: AspectRatio(
                          aspectRatio: 4 / 5,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: PhotoPlaceholder(
                                  seed: pi.seed,
                                  label: pi.label,
                                  borderRadius: BorderRadius.circular(14),
                                  photoUrl: pi.url ?? pi.thumbUrl,
                                ),
                              ),
                              if (pi.kind == 'video')
                                Center(
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: Colors.black
                                          .withValues(alpha: 0.55),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.7),
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(Icons.play_arrow,
                                        size: 26, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: p.orange,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            (item.author.isNotEmpty ? item.author : 'A')
                                .characters
                                .first,
                            style: BgFonts.display(
                              size: 13,
                              weight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${l.mediaBy} ${item.author}',
                                    style: BgFonts.body(
                                      size: 13,
                                      weight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  if (item.verified)
                                    const Icon(Icons.verified,
                                        size: 13, color: Colors.white),
                                ],
                              ),
                              Text(
                                '${item.when ?? (l.isFr ? "récemment" : "recently")} · ${item.label}',
                                style: BgFonts.body(
                                  size: 11,
                                  color:
                                      Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 52,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: thumbStrip.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 6),
                        itemBuilder: (_, i) {
                          final mi = thumbStrip[i];
                          final selected = i == idx;
                          return GestureDetector(
                            onTap: () => onThumbTap(i),
                            child: Container(
                              width: 52,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: selected
                                      ? p.orange
                                      : Colors.transparent,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Opacity(
                                  opacity: selected ? 1 : 0.6,
                                  child: PhotoPlaceholder(
                                    seed: mi.seed,
                                    showLabel: false,
                                    photoUrl: mi.thumbUrl ?? mi.url,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
