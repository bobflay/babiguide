import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api_error.dart';
import '../api/places_api.dart';
import '../app_state.dart';
import '../data.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets/photo_placeholder.dart';
import '../widgets/star_row.dart';

class DetailScreen extends StatefulWidget {
  final String? slug;
  final VoidCallback? onBack;
  final VoidCallback? onWriteReview;
  final VoidCallback? onOpenMedia;
  final ValueChanged<int>? onOpenMediaAt;
  final ValueChanged<DetailPlace>? onLoaded;
  final VoidCallback? onRequireAuthForFavorite;
  final VoidCallback? onOpenChat;

  const DetailScreen({
    super.key,
    this.slug,
    this.onBack,
    this.onWriteReview,
    this.onOpenMedia,
    this.onOpenMediaAt,
    this.onLoaded,
    this.onRequireAuthForFavorite,
    this.onOpenChat,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailBundle {
  final DetailPlace place;
  final List<SubRating> subRatings;
  final List<MenuHighlight> menu;
  final PagedList<ReviewItem> reviews;
  final MediaPage media;

  const _DetailBundle({
    required this.place,
    required this.subRatings,
    required this.menu,
    required this.reviews,
    required this.media,
  });
}

class _DetailScreenState extends State<DetailScreen> {
  String _tab = 'overview';
  Future<_DetailBundle>? _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  @override
  void didUpdateWidget(DetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug) _load();
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
    final api = AppScope.of(context).placesApi;
    setState(() {
      _future = _fetch(api, slug);
    });
  }

  Future<_DetailBundle> _fetch(PlacesApi api, String slug) async {
    final results = await Future.wait([
      api.getPlace(slug),
      api.getSubRatings(slug),
      api.getMenu(slug),
      api.getReviews(slug),
      api.getMedia(slug),
    ]);
    final bundle = _DetailBundle(
      place: results[0] as DetailPlace,
      subRatings: results[1] as List<SubRating>,
      menu: results[2] as List<MenuHighlight>,
      reviews: results[3] as PagedList<ReviewItem>,
      media: results[4] as MediaPage,
    );
    if (mounted) widget.onLoaded?.call(bundle.place);
    return bundle;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.palette;
    final l = L(state.lang);

    return Container(
      color: p.bg,
      child: FutureBuilder<_DetailBundle>(
        future: _future,
        builder: (context, snap) {
          if (_future == null ||
              snap.connectionState == ConnectionState.waiting) {
            return _DetailLoading(p: p, onBack: widget.onBack);
          }
          if (snap.hasError) {
            return _DetailError(
              error: snap.error,
              onRetry: _load,
              onBack: widget.onBack,
              l: l,
              p: p,
            );
          }
          final bundle = snap.data!;
          final isFav = state.isFavorite(bundle.place.id) || bundle.place.isFavorited;
          return _DetailBody(
            bundle: bundle,
            tab: _tab,
            onTab: (t) => setState(() => _tab = t),
            onBack: widget.onBack,
            onWriteReview: widget.onWriteReview,
            onOpenMedia: widget.onOpenMedia,
            onOpenMediaAt: widget.onOpenMediaAt,
            onToggleFavorite: () => _toggleFavorite(bundle.place),
            onShare: () => _share(bundle.place),
            onDirections: () => _openDirections(bundle.place),
            onCall: () => _call(bundle.place),
            onOpenChat: widget.onOpenChat,
            onRequireAuthForFavorite: widget.onRequireAuthForFavorite,
            onReviewsChanged: _load,
            isFavorite: isFav,
            l: l,
            p: p,
          );
        },
      ),
    );
  }

  Future<void> _toggleFavorite(DetailPlace place) async {
    final state = AppScope.of(context);
    if (!state.isSignedIn) {
      widget.onRequireAuthForFavorite?.call();
      return;
    }
    try {
      await state.toggleFavorite(place.id);
    } on ApiError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openDirections(DetailPlace place) async {
    final lat = place.lat;
    final lng = place.lng;
    if (lat == null || lng == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      final l = L(AppScope.of(context).lang);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.pick(
              "Impossible d'ouvrir l'itinéraire", 'Could not open directions')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _call(DetailPlace place) async {
    final phone = (place.phone ?? '').trim();
    if (phone.isEmpty) return;
    final sanitized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: sanitized);
    final ok = await launchUrl(uri);
    if (!ok && mounted) {
      final l = L(AppScope.of(context).lang);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.pick(
              "Impossible de lancer l'appel", 'Could not start the call')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _share(DetailPlace place) async {
    final state = AppScope.of(context);
    final l = L(state.lang);
    String url = place.shareUrl ?? '';
    try {
      if (url.isEmpty) {
        url = await state.placesApi.sharePlace(place.id);
      }
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.pick(
              'Lien copié dans le presse-papier', 'Link copied to clipboard')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _DetailLoading extends StatelessWidget {
  final BgPalette p;
  final VoidCallback? onBack;
  const _DetailLoading({required this.p, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(p.orange),
            ),
          ),
        ),
        Positioned(
          top: 56,
          left: 16,
          child: _CircleBtn(icon: Icons.chevron_left, onTap: onBack),
        ),
      ],
    );
  }
}

class _DetailError extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;
  final VoidCallback? onBack;
  final L l;
  final BgPalette p;
  const _DetailError({
    required this.error,
    required this.onRetry,
    required this.onBack,
    required this.l,
    required this.p,
  });

  @override
  Widget build(BuildContext context) {
    final msg = error is ApiError
        ? (error as ApiError).message
        : l.pick(
            "Impossible de charger ce restaurant",
            'Could not load this place',
          );
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off, size: 36, color: p.inkMuted),
                const SizedBox(height: 12),
                Text(
                  msg,
                  textAlign: TextAlign.center,
                  style: BgFonts.body(size: 14, color: p.ink, height: 1.4),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: p.orange,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l.pick('Réessayer', 'Retry'),
                      style: BgFonts.body(
                        size: 13,
                        weight: FontWeight.w700,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 56,
          left: 16,
          child: _CircleBtn(icon: Icons.chevron_left, onTap: onBack),
        ),
      ],
    );
  }
}

class _DetailBody extends StatelessWidget {
  final _DetailBundle bundle;
  final String tab;
  final ValueChanged<String> onTab;
  final VoidCallback? onBack;
  final VoidCallback? onWriteReview;
  final VoidCallback? onOpenMedia;
  final ValueChanged<int>? onOpenMediaAt;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onShare;
  final VoidCallback? onDirections;
  final VoidCallback? onCall;
  final VoidCallback? onOpenChat;
  final VoidCallback? onRequireAuthForFavorite;
  final VoidCallback? onReviewsChanged;
  final bool isFavorite;
  final L l;
  final BgPalette p;

  const _DetailBody({
    required this.bundle,
    required this.tab,
    required this.onTab,
    required this.onBack,
    required this.onWriteReview,
    required this.onOpenMedia,
    required this.onOpenMediaAt,
    required this.onToggleFavorite,
    required this.onShare,
    required this.onDirections,
    required this.onCall,
    required this.onOpenChat,
    required this.onRequireAuthForFavorite,
    required this.onReviewsChanged,
    required this.isFavorite,
    required this.l,
    required this.p,
  });

  @override
  Widget build(BuildContext context) {
    final place = bundle.place;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 140),
          children: [
            _HeroGallery(
              place: place,
              media: bundle.media.items,
              onTap: onOpenMedia,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusRow(place: place, l: l),
                  const SizedBox(height: 6),
                  Text(
                    place.name,
                    style: BgFonts.display(
                      size: 28,
                      weight: FontWeight.w700,
                      color: p.ink,
                      letterSpacing: -0.6,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    [place.cuisine, place.price]
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                    style: BgFonts.body(size: 13, color: p.inkMuted),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 12, color: p.inkMuted),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          place.neighborhood,
                          style: BgFonts.body(size: 12, color: p.inkMuted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _BigRating(place: place, l: l),
                  const SizedBox(height: 14),
                  _ActionRow(
                    place: place,
                    l: l,
                    onWrite: onWriteReview,
                    onDirections: onDirections,
                    onCall: onCall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _TabsBar(tab: tab, onTab: onTab, l: l),
            ..._buildTabContent(),
          ],
        ),
        Positioned(
          top: 56,
          left: 16,
          right: 16,
          child: Row(
            children: [
              _CircleBtn(icon: Icons.chevron_left, onTap: onBack),
              const Spacer(),
              _CircleBtn(
                icon: Icons.auto_awesome,
                onTap: onOpenChat,
              ),
              const SizedBox(width: 8),
              _CircleBtn(icon: Icons.share_outlined, onTap: onShare),
              const SizedBox(width: 8),
              _CircleBtn(
                icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                onTap: onToggleFavorite,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildTabContent() {
    switch (tab) {
      case 'menu':
        return _menuTab();
      case 'photos':
        return _photosTab();
      case 'reviews':
        return _reviewsTab();
      case 'overview':
      default:
        return _overviewTab();
    }
  }

  List<Widget> _overviewTab() {
    final place = bundle.place;
    final gallery = bundle.media.items.take(8).toList(growable: false);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Title(text: l.sectionRatings),
            const SizedBox(height: 6),
            _SubRatingsCard(items: bundle.subRatings, l: l),
          ],
        ),
      ),
      if (gallery.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHead(
                title: l.sectionPhotos,
                action: l.seeAll,
                onTap: () => onTab('photos'),
              ),
              GridView.count(
                crossAxisCount: 4,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 0; i < gallery.length; i++)
                    _GalleryTile(
                      item: gallery[i],
                      onTap: () => onOpenMediaAt?.call(i),
                    ),
                ],
              ),
            ],
          ),
        ),
      if (bundle.menu.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHead(
                title: l.sectionMenu,
                action: l.viewMenu,
                onTap: () => onTab('menu'),
              ),
              for (final m in bundle.menu.take(3)) ...[
                _MenuItem(m: m),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Title(text: l.facts),
            const SizedBox(height: 10),
            _FactsCard(
              place: place,
              l: l,
              onTapAddress: onDirections,
              onTapPhone: onCall,
            ),
          ],
        ),
      ),
      if (bundle.reviews.items.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHead(
                title: l.sectionReviews,
                action: l.seeAll,
                onTap: () => onTab('reviews'),
              ),
              for (final r in bundle.reviews.items.take(3)) ...[
                _ReviewCard(
                  r: r,
                  l: l,
                  onRequireAuth: onRequireAuthForFavorite,
                  onDeleted: onReviewsChanged,
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
    ];
  }

  List<Widget> _menuTab() {
    if (bundle.menu.isEmpty) {
      return [
        _TabEmpty(
          icon: Icons.restaurant_menu,
          text: l.pick(
            'Pas encore de menu publié.',
            'No menu published yet.',
          ),
          p: p,
        ),
      ];
    }
    return [_MenuTab(menu: bundle.menu, l: l, p: p)];
  }

  List<Widget> _photosTab() {
    final items = bundle.media.items;
    if (items.isEmpty) {
      return [
        _TabEmpty(
          icon: Icons.photo_library_outlined,
          text: l.pick(
            'Pas encore de photos.',
            'No photos yet.',
          ),
          p: p,
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHead(
              title: l.sectionPhotos,
              action: l.seeAll,
              onTap: onOpenMedia,
            ),
            GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < items.length; i++)
                  _GalleryTile(
                    item: items[i],
                    onTap: () => onOpenMediaAt?.call(i),
                  ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _reviewsTab() {
    if (bundle.reviews.items.isEmpty) {
      return [
        _TabEmpty(
          icon: Icons.rate_review_outlined,
          text: l.pick(
            "Soyez le premier à laisser un avis.",
            'Be the first to leave a review.',
          ),
          p: p,
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Title(text: l.sectionReviews),
            const SizedBox(height: 12),
            for (final r in bundle.reviews.items) ...[
              _ReviewCard(
                r: r,
                l: l,
                onRequireAuth: onRequireAuthForFavorite,
                onDeleted: onReviewsChanged,
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    ];
  }
}

class _TabEmpty extends StatelessWidget {
  final IconData icon;
  final String text;
  final BgPalette p;
  const _TabEmpty({required this.icon, required this.text, required this.p});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: p.inkMuted),
            const SizedBox(height: 10),
            Text(
              text,
              style: BgFonts.body(size: 13, color: p.inkMuted, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final DetailPlace place;
  final L l;
  const _StatusRow({required this.place, required this.l});

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    final until = place.todayUntil;
    final col = place.openNow ? p.green : p.inkMuted;
    final label = place.openNow
        ? (until == null
            ? l.open
            : '${l.open} · ${l.untilTime} ${until.replaceAll(':00', 'h')}')
        : l.closed;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: col.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: col, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: BgFonts.body(
                  size: 10,
                  weight: FontWeight.w700,
                  color: col,
                  letterSpacing: 0.3,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        if (place.verified) ...[
          const SizedBox(width: 6),
          Icon(Icons.verified, size: 13, color: p.orangeDeep),
          const SizedBox(width: 3),
          Text(
            l.verified,
            style: BgFonts.body(
              size: 11,
              weight: FontWeight.w600,
              color: p.orangeDeep,
            ),
          ),
        ],
      ],
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _CircleBtn({required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF3A1F08)),
      ),
    );
  }
}

class _HeroGallery extends StatelessWidget {
  final DetailPlace place;
  final List<GalleryItem> media;
  final VoidCallback? onTap;
  const _HeroGallery({
    required this.place,
    required this.media,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final photos =
        media.where((m) => m.kind != 'video').toList(growable: false);
    final m1 = photos.isNotEmpty ? photos[0] : null;
    final m2 = photos.length > 1 ? photos[1] : null;
    final m3 = photos.length > 2 ? photos[2] : null;
    final totalMedia = place.photoCount + place.videoCount;
    final extra = totalMedia > 3 ? '+${totalMedia - 3}' : null;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 320,
        child: Stack(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: PhotoPlaceholder(
                    seed: m1?.seed ?? '${place.seed}-hero1',
                    label: m1?.label ?? place.photoLabel ?? '',
                    width: double.infinity,
                    height: 320,
                    photoUrl: m1?.url ?? place.coverPhotoUrl,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      Expanded(
                        child: PhotoPlaceholder(
                          seed: m2?.seed ?? '${place.seed}-hero2',
                          label: m2?.label ?? '',
                          width: double.infinity,
                          height: double.infinity,
                          photoUrl: m2?.url,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: PhotoPlaceholder(
                                seed: m3?.seed ?? '${place.seed}-hero3',
                                label: m3?.label ?? '',
                                photoUrl: m3?.url,
                              ),
                            ),
                            if (extra != null)
                              Positioned.fill(
                                child: Container(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  alignment: Alignment.center,
                                  child: Text(
                                    extra,
                                    style: BgFonts.display(
                                      size: 18,
                                      weight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_outlined,
                        size: 13, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      '${place.photoCount}',
                      style: BgFonts.body(
                        size: 11,
                        weight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.play_arrow, size: 13, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      '${place.videoCount}',
                      style: BgFonts.body(
                        size: 11,
                        weight: FontWeight.w600,
                        color: Colors.white,
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

class _BigRating extends StatelessWidget {
  final DetailPlace place;
  final L l;
  const _BigRating({required this.place, required this.l});
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: p.orangeSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.orange.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  place.rating.toStringAsFixed(1),
                  style: BgFonts.display(
                    size: 30,
                    weight: FontWeight.w700,
                    color: p.orangeDeep,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                StarsRow(filled: place.rating.round(), size: 10),
              ],
            ),
          ),
          Container(width: 1, height: 50, color: p.orange.withValues(alpha: 0.18)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.based, style: BgFonts.body(size: 12, color: p.inkMuted)),
                const SizedBox(height: 1),
                Text(
                  l.reviewsCount(place.reviews),
                  style: BgFonts.display(
                    size: 17,
                    weight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${l.photoCount(place.photoCount)} · ${l.videoCount(place.videoCount)}',
                  style: BgFonts.body(size: 11, color: p.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final DetailPlace place;
  final L l;
  final VoidCallback? onWrite;
  final VoidCallback? onDirections;
  final VoidCallback? onCall;
  const _ActionRow({
    required this.place,
    required this.l,
    this.onWrite,
    this.onDirections,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    Widget btn({
      required String label,
      required IconData icon,
      Color? bg,
      Color? fg,
      bool outline = false,
      bool enabled = true,
      VoidCallback? onTap,
    }) {
      return Expanded(
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: outline ? Colors.transparent : (bg ?? p.ink),
                borderRadius: BorderRadius.circular(12),
                border: outline ? Border.all(color: p.cardBorder) : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 14, color: fg ?? p.bg),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      style: BgFonts.body(
                        size: 13,
                        weight: FontWeight.w600,
                        color: fg ?? p.bg,
                        height: 1.1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        btn(
          label: l.directions,
          icon: Icons.directions,
          bg: p.ink,
          fg: p.bg,
          enabled: place.lat != null && place.lng != null,
          onTap: onDirections,
        ),
        const SizedBox(width: 8),
        btn(
          label: l.call,
          icon: Icons.phone_outlined,
          outline: true,
          fg: p.ink,
          enabled: (place.phone ?? '').isNotEmpty,
          onTap: onCall,
        ),
        const SizedBox(width: 8),
        btn(
          label: l.write,
          icon: Icons.add,
          bg: p.orange,
          fg: Colors.white,
          onTap: onWrite,
        ),
      ],
    );
  }
}

class _TabsBar extends StatelessWidget {
  final String tab;
  final ValueChanged<String> onTab;
  final L l;
  const _TabsBar({required this.tab, required this.onTab, required this.l});
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    final tabs = {
      'overview': l.overview,
      'menu': l.menu,
      'photos': l.photos,
      'reviews': l.reviews,
    };
    return Container(
      color: p.bg,
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.cardBorder)),
        ),
        child: Row(
          children: tabs.entries.map((e) {
            final active = e.key == tab;
            return Padding(
              padding: const EdgeInsets.only(right: 22),
              child: GestureDetector(
                onTap: () => onTab(e.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: active ? p.orange : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    e.value,
                    style: BgFonts.display(
                      size: 13,
                      weight: FontWeight.w700,
                      color: active ? p.ink : p.inkMuted,
                      height: 1,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  const _Title({required this.text});
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    return Text(
      text,
      style: BgFonts.display(
        size: 17,
        weight: FontWeight.w700,
        color: p.ink,
        letterSpacing: -0.3,
      ),
    );
  }
}

class _SectionHead extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback? onTap;
  const _SectionHead({required this.title, required this.action, this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _Title(text: title)),
          GestureDetector(
            onTap: onTap,
            child: Text(
              action,
              style: BgFonts.body(
                size: 12,
                weight: FontWeight.w600,
                color: p.orangeDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubRatingsCard extends StatelessWidget {
  final List<SubRating> items;
  final L l;
  const _SubRatingsCard({required this.items, required this.l});
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.cardBorder),
        ),
        child: Text(
          l.pick('Aucune note détaillée pour le moment.',
              'No detailed ratings yet.'),
          style: BgFonts.body(size: 13, color: p.inkMuted),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.cardBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i += 2)
            Row(
              children: [
                Expanded(child: _SubRow(item: items[i], l: l)),
                const SizedBox(width: 18),
                Expanded(
                  child: i + 1 < items.length
                      ? _SubRow(item: items[i + 1], l: l)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SubRow extends StatelessWidget {
  final SubRating item;
  final L l;
  const _SubRow({required this.item, required this.l});

  IconData _icon(String key) {
    switch (key) {
      case 'fork':
        return Icons.restaurant;
      case 'staff':
        return Icons.groups;
      case 'toilet':
        return Icons.wc;
      case 'ambiance':
        return Icons.local_florist;
      case 'money':
        return Icons.attach_money;
      case 'clock':
        return Icons.access_time;
      case 'wifi':
        return Icons.wifi;
      case 'park':
        return Icons.local_parking;
      default:
        return Icons.star_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    final pct = (item.value / 5).clamp(0.0, 1.0);
    final label = l.rateLabels[item.labelKey] ?? item.labelKey;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: p.orange.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(_icon(item.iconKey), size: 16, color: p.orangeDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: BgFonts.body(
                          size: 13,
                          weight: FontWeight.w600,
                          color: p.ink,
                          height: 1,
                        ),
                      ),
                    ),
                    Text(
                      item.value.toStringAsFixed(1),
                      style: BgFonts.display(
                        size: 13,
                        weight: FontWeight.w700,
                        color: p.ink,
                        height: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0x1A785028),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: pct,
                    child: Container(
                      decoration: BoxDecoration(
                        color: p.orange,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  final GalleryItem item;
  final VoidCallback? onTap;
  const _GalleryTile({required this.item, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 1,
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
                        Colors.black.withValues(alpha: 0.45),
                      ],
                      stops: const [0.55, 1.0],
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
                  child: const Icon(Icons.play_arrow, size: 11, color: Colors.white),
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
          ],
        ),
      ),
    ),
    );
  }
}

class _MenuTab extends StatefulWidget {
  final List<MenuHighlight> menu;
  final L l;
  final BgPalette p;

  const _MenuTab({required this.menu, required this.l, required this.p});

  @override
  State<_MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends State<_MenuTab> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';
  String? _selectedCategory;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _matches(MenuHighlight m, String q) {
    if (q.isEmpty) return true;
    final hay = '${m.name} ${m.desc} ${m.category ?? ''}'.toLowerCase();
    return hay.contains(q);
  }

  String _categoryKey(MenuHighlight m, String fallback) {
    return (m.category != null && m.category!.trim().isNotEmpty)
        ? m.category!.trim()
        : fallback;
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final p = widget.p;
    final q = _query.trim().toLowerCase();
    final fallback = l.pick('Autres', 'Other');

    final categories = <String>[];
    final seen = <String>{};
    for (final m in widget.menu) {
      final key = _categoryKey(m, fallback);
      if (seen.add(key)) categories.add(key);
    }

    final activeCategory = _selectedCategory != null &&
            categories.contains(_selectedCategory)
        ? _selectedCategory
        : null;

    final groups = <String, List<MenuHighlight>>{};
    for (final m in widget.menu) {
      if (!_matches(m, q)) continue;
      final key = _categoryKey(m, fallback);
      if (activeCategory != null && key != activeCategory) continue;
      groups.putIfAbsent(key, () => <MenuHighlight>[]).add(m);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Title(text: l.sectionMenu),
          const SizedBox(height: 12),
          _MenuSearchField(
            p: p,
            controller: _controller,
            hintText: l.pick('Rechercher un plat…', 'Search a dish…'),
            onChanged: (v) => setState(() => _query = v),
            onClear: () {
              _controller.clear();
              setState(() => _query = '');
            },
          ),
          if (categories.length > 1) ...[
            const SizedBox(height: 12),
            _MenuCategoryFilter(
              p: p,
              allLabel: l.pick('Tous', 'All'),
              categories: categories,
              selected: activeCategory,
              onSelect: (c) => setState(() => _selectedCategory = c),
            ),
          ],
          const SizedBox(height: 14),
          if (groups.isEmpty)
            _TabEmpty(
              icon: Icons.search_off,
              text: l.pick(
                'Aucun plat ne correspond.',
                'No dishes match.',
              ),
              p: p,
            )
          else
            for (final entry in groups.entries) ...[
              if (activeCategory == null) ...[
                _MenuCategoryHeader(label: entry.key),
                const SizedBox(height: 8),
              ],
              for (final m in entry.value) ...[
                _MenuItem(m: m),
                const SizedBox(height: 8),
              ],
              if (activeCategory == null) const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _MenuCategoryFilter extends StatelessWidget {
  final BgPalette p;
  final String allLabel;
  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelect;

  const _MenuCategoryFilter({
    required this.p,
    required this.allLabel,
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == 0) {
            final on = selected == null;
            return _MenuFilterPill(
              label: allLabel,
              on: on,
              p: p,
              onTap: () => onSelect(null),
            );
          }
          final cat = categories[i - 1];
          final on = selected == cat;
          return _MenuFilterPill(
            label: cat,
            on: on,
            p: p,
            onTap: () => onSelect(on ? null : cat),
          );
        },
      ),
    );
  }
}

class _MenuFilterPill extends StatelessWidget {
  final String label;
  final bool on;
  final BgPalette p;
  final VoidCallback onTap;
  const _MenuFilterPill({
    required this.label,
    required this.on,
    required this.p,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? p.orange : p.card,
          borderRadius: BorderRadius.circular(999),
          border: on ? null : Border.all(color: p.cardBorder),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: BgFonts.body(
            size: 12,
            weight: FontWeight.w600,
            color: on ? Colors.white : p.ink,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _MenuSearchField extends StatelessWidget {
  final BgPalette p;
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _MenuSearchField({
    required this.p,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.cardBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 16, color: p.ink),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: hintText,
                hintStyle: BgFonts.body(size: 14, color: p.inkMuted),
              ),
              style: BgFonts.body(size: 14, color: p.ink),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close, size: 16, color: p.inkMuted),
            ),
        ],
      ),
    );
  }
}

class _MenuCategoryHeader extends StatelessWidget {
  final String label;
  const _MenuCategoryHeader({required this.label});
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    return Text(
      label.toUpperCase(),
      style: BgFonts.mono(
        size: 11,
        color: p.orangeDeep,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final MenuHighlight m;
  const _MenuItem({required this.m});
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.cardBorder),
      ),
      child: Row(
        children: [
          PhotoPlaceholder(
            seed: m.seed,
            label: m.label,
            width: 84,
            height: 84,
            borderRadius: BorderRadius.circular(10),
            photoUrl: m.photoUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        m.name,
                        style: BgFonts.display(
                          size: 15,
                          weight: FontWeight.w700,
                          color: p.ink,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      m.price,
                      style: BgFonts.display(
                        size: 14,
                        weight: FontWeight.w700,
                        color: p.orangeDeep,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  m.desc,
                  style: BgFonts.body(size: 12, color: p.inkMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FactsCard extends StatelessWidget {
  final DetailPlace place;
  final L l;
  final VoidCallback? onTapAddress;
  final VoidCallback? onTapPhone;
  const _FactsCard({
    required this.place,
    required this.l,
    this.onTapAddress,
    this.onTapPhone,
  });

  String _hoursSummary() {
    if (place.weeklyHours.isEmpty) return '';
    final byDay = <int, DayHours>{};
    for (final d in place.weeklyHours) {
      byDay[d.day] = d;
    }
    // Find a contiguous range with the same hours.
    final ordered = (byDay.keys.toList()..sort());
    if (ordered.isEmpty) return '';
    final first = byDay[ordered.first]!;
    final allSame = byDay.values.every(
      (d) => d.open == first.open && d.close == first.close,
    );
    final dayNamesFr = ['', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final dayNamesEn = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final names = l.isFr ? dayNamesFr : dayNamesEn;
    final range = allSame
        ? '${names[ordered.first]}–${names[ordered.last]}'
        : ordered.map((d) => names[d]).join(', ');
    String fmtTime(String t) => l.isFr ? t.replaceAll(':', 'h') : t;
    return '$range · ${fmtTime(first.open)}–${fmtTime(first.close)}';
  }

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    final hoursText = _hoursSummary();
    final hasAddress = (place.address ?? '').isNotEmpty;
    final hasPhone = (place.phone ?? '').isNotEmpty;
    final items = <_FactRow>[
      if (hasAddress)
        _FactRow(
          icon: Icons.location_on_outlined,
          text: place.address!,
          onTap: place.lat != null && place.lng != null ? onTapAddress : null,
        ),
      if (hoursText.isNotEmpty)
        _FactRow(icon: Icons.access_time, text: hoursText),
      if (hasPhone)
        _FactRow(
          icon: Icons.phone,
          text: place.phone!,
          onTap: onTapPhone,
        ),
    ];
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.cardBorder),
        ),
        child: Text(
          l.pick("Pas d'infos pratiques pour le moment.",
              "No quick facts yet."),
          style: BgFonts.body(size: 13, color: p.inkMuted),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.cardBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            GestureDetector(
              onTap: items[i].onTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: i < items.length - 1
                          ? p.cardBorder
                          : Colors.transparent,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: p.orange.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(items[i].icon,
                          size: 15, color: p.orangeDeep),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        items[i].text,
                        style: BgFonts.body(size: 13, color: p.ink),
                      ),
                    ),
                    if (items[i].onTap != null)
                      Icon(Icons.chevron_right,
                          size: 16, color: p.inkMuted),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FactRow {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  const _FactRow({required this.icon, required this.text, this.onTap});
}

class _ReviewCard extends StatefulWidget {
  final ReviewItem r;
  final L l;
  final VoidCallback? onRequireAuth;
  final VoidCallback? onDeleted;
  const _ReviewCard({
    required this.r,
    required this.l,
    this.onRequireAuth,
    this.onDeleted,
  });

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  late int _helpful = widget.r.helpfulCount;
  late bool _marked = widget.r.userMarkedHelpful;
  bool _busy = false;

  ReviewItem get r => widget.r;
  L get l => widget.l;

  Future<void> _toggleHelpful() async {
    if (_busy) return;
    final state = AppScope.of(context);
    if (!state.isSignedIn) {
      widget.onRequireAuth?.call();
      return;
    }
    if (r.id == null || r.id!.isEmpty) return;
    final wasMarked = _marked;
    setState(() {
      _marked = !wasMarked;
      _helpful += wasMarked ? -1 : 1;
      _busy = true;
    });
    try {
      final res = wasMarked
          ? await state.reviewsApi.unmarkHelpful(r.id!)
          : await state.reviewsApi.markHelpful(r.id!);
      if (!mounted) return;
      setState(() {
        _helpful = res.helpfulCount;
        _marked = res.userMarkedHelpful;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _marked = wasMarked;
        _helpful += wasMarked ? 1 : -1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final state = AppScope.of(context);
    if (r.id == null || r.id!.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.pick("Supprimer cet avis ?", 'Delete this review?')),
        content: Text(l.pick(
          'Cette action est définitive.',
          'This cannot be undone.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.pick('Supprimer', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await state.reviewsApi.deleteReview(r.id!);
      if (!mounted) return;
      widget.onDeleted?.call();
    } on ApiError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.palette;
    final isAuthor = r.authorId != null &&
        state.user?.id != null &&
        r.authorId == state.user!.id;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: p.orangeSoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  r.avatar,
                  style: BgFonts.display(
                    size: 14,
                    weight: FontWeight.w700,
                    color: p.orangeDeep,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.name,
                      style: BgFonts.body(
                        size: 13,
                        weight: FontWeight.w600,
                        color: p.ink,
                      ),
                    ),
                    Text(
                      r.when,
                      style: BgFonts.body(size: 11, color: p.inkMuted),
                    ),
                  ],
                ),
              ),
              StarsRow(filled: r.rating, size: 12),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            r.text,
            style: BgFonts.body(size: 13, color: p.ink, height: 1.55),
          ),
          if (r.media.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                for (final m in r.media) ...[
                  PhotoPlaceholder(
                    seed: m.seed,
                    showLabel: false,
                    width: 64,
                    height: 64,
                    borderRadius: BorderRadius.circular(8),
                    photoUrl: m.thumbUrl ?? m.url,
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ],
          if (r.sub.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: r.sub.entries.map((e) {
                final label = l.rateLabels[e.key] ?? e.key;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: p.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 10, color: p.orangeDeep),
                      const SizedBox(width: 4),
                      Text(
                        '${label.toLowerCase()} · ${e.value}',
                        style: BgFonts.body(
                          size: 10,
                          weight: FontWeight.w600,
                          color: p.orangeDeep,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                onTap: _toggleHelpful,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _marked
                        ? p.orangeSoft
                        : p.cardBorder.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _marked
                            ? Icons.thumb_up
                            : Icons.thumb_up_outlined,
                        size: 12,
                        color: _marked ? p.orangeDeep : p.inkMuted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${l.pick("Utile", "Helpful")} · $_helpful',
                        style: BgFonts.body(
                          size: 11,
                          weight: FontWeight.w600,
                          color: _marked ? p.orangeDeep : p.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (isAuthor)
                GestureDetector(
                  onTap: _delete,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.delete_outline,
                        size: 18, color: p.inkMuted),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
