import 'package:flutter/material.dart';
import '../api/api_error.dart';
import '../api/places_api.dart';
import '../app_state.dart';
import '../data.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets/photo_placeholder.dart';
import '../widgets/star_row.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<String>? onOpenRestaurant;
  final VoidCallback? onOpenSearch;
  final ValueChanged<Neighborhood>? onOpenNeighborhood;
  final VoidCallback? onSeeAllTrending;
  final VoidCallback? onSeeAllNew;
  final VoidCallback? onSeeAllNeighborhoods;

  const HomeScreen({
    super.key,
    this.onOpenRestaurant,
    this.onOpenSearch,
    this.onOpenNeighborhood,
    this.onSeeAllTrending,
    this.onSeeAllNew,
    this.onSeeAllNeighborhoods,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<HomeFeed>? _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  void _load() {
    final state = AppScope.of(context);
    setState(() {
      _future = state.placesApi.getHome();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.palette;
    final l = L(state.lang);

    return Container(
      color: p.bg,
      child: FutureBuilder<HomeFeed>(
        future: _future,
        builder: (context, snap) {
          if (_future == null ||
              snap.connectionState == ConnectionState.waiting) {
            return _LoadingHome(p: p);
          }
          if (snap.hasError) {
            return _ErrorHome(
              error: snap.error,
              onRetry: _load,
              l: l,
              p: p,
            );
          }
          final feed = snap.data ?? const HomeFeed(
            trending: [],
            newPlaces: [],
            neighborhoods: [],
          );
          return _HomeBody(
            feed: feed,
            l: l,
            p: p,
            userName: state.user?.name,
            onOpenRestaurant: widget.onOpenRestaurant,
            onOpenSearch: widget.onOpenSearch,
            onOpenNeighborhood: widget.onOpenNeighborhood,
            onSeeAllTrending: widget.onSeeAllTrending,
            onSeeAllNew: widget.onSeeAllNew,
            onSeeAllNeighborhoods: widget.onSeeAllNeighborhoods,
          );
        },
      ),
    );
  }
}

class _LoadingHome extends StatelessWidget {
  final BgPalette p;
  const _LoadingHome({required this.p});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(p.orange),
        ),
      ),
    );
  }
}

class _ErrorHome extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;
  final L l;
  final BgPalette p;
  const _ErrorHome({
    required this.error,
    required this.onRetry,
    required this.l,
    required this.p,
  });

  @override
  Widget build(BuildContext context) {
    final msg = error is ApiError
        ? (error as ApiError).message
        : l.pick("Impossible de charger l'accueil",
            'Could not load the home feed');
    return Padding(
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
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
    );
  }
}

class _HomeBody extends StatelessWidget {
  final HomeFeed feed;
  final L l;
  final BgPalette p;
  final String? userName;
  final ValueChanged<String>? onOpenRestaurant;
  final VoidCallback? onOpenSearch;
  final ValueChanged<Neighborhood>? onOpenNeighborhood;
  final VoidCallback? onSeeAllTrending;
  final VoidCallback? onSeeAllNew;
  final VoidCallback? onSeeAllNeighborhoods;

  const _HomeBody({
    required this.feed,
    required this.l,
    required this.p,
    required this.userName,
    required this.onOpenRestaurant,
    required this.onOpenSearch,
    required this.onOpenNeighborhood,
    required this.onSeeAllTrending,
    required this.onSeeAllNew,
    required this.onSeeAllNeighborhoods,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 140),
      children: [
        _Header(
          p: p,
          l: l,
          greeting: l.greetingFor(feed.greetingHint),
          userName: userName,
        ),
        _SearchBar(p: p, l: l, onTap: onOpenSearch),
        const SizedBox(height: 18),
        _SectionHeader(
          title: l.sectionTrending,
          action: l.seeAll,
          onTap: onSeeAllTrending,
        ),
        SizedBox(
          height: 308,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final t in feed.trending) ...[
                GestureDetector(
                  onTap: () => onOpenRestaurant?.call(t.id),
                  child: _HeroCard(place: t, l: l),
                ),
                const SizedBox(width: 12),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SectionHeader(
          title: l.sectionNew,
          action: l.seeAll,
          onTap: onSeeAllNew,
        ),
        for (final n in feed.newPlaces.take(5)) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _NewRow(p: n, l: l, onTap: () => onOpenRestaurant?.call(n.id)),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 16),
        _SectionHeader(
          title: l.sectionNeighborhoods,
          action: l.seeAll,
          onTap: onSeeAllNeighborhoods,
        ),
        SizedBox(
          height: 132,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final n in feed.neighborhoods) ...[
                GestureDetector(
                  onTap: () => onOpenNeighborhood?.call(n),
                  child: _NeighborhoodPill(n: n, l: l),
                ),
                const SizedBox(width: 10),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final BgPalette p;
  final L l;
  final String greeting;
  final String? userName;
  const _Header({
    required this.p,
    required this.l,
    required this.greeting,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final name = (userName == null || userName!.isEmpty)
        ? l.pick('là', 'there')
        : userName!.split(' ').first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.asset(
                  'assets/images/babiguide-logo.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BABIGUIDE · ABIDJAN',
                      style: BgFonts.body(
                        size: 11,
                        weight: FontWeight.w600,
                        color: p.inkMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$greeting, $name',
                      style: BgFonts.display(
                        size: 22,
                        weight: FontWeight.w700,
                        color: p.ink,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l.greetingSub,
            style: BgFonts.body(size: 14, color: p.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final BgPalette p;
  final L l;
  final VoidCallback? onTap;
  const _SearchBar({required this.p, required this.l, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.cardBorder),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 18, color: p.inkMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l.searchHint,
                  style: BgFonts.body(size: 14, color: p.inkMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 1,
                height: 18,
                color: p.cardBorder,
                margin: const EdgeInsets.symmetric(horizontal: 10),
              ),
              Icon(Icons.tune, size: 18, color: p.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback? onTap;
  const _SectionHeader({
    required this.title,
    required this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: BgFonts.display(
                size: 19,
                weight: FontWeight.w700,
                color: p.ink,
                letterSpacing: -0.3,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Text(
                action,
                style: BgFonts.body(
                  size: 12,
                  weight: FontWeight.w600,
                  color: p.orangeDeep,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final Place place;
  final L l;
  const _HeroCard({required this.place, required this.l});

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.cardBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3C1E00).withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Stack(
              children: [
                PhotoPlaceholder(
                  seed: place.seed,
                  label: place.photoLabel,
                  width: double.infinity,
                  height: 180,
                  photoUrl: place.photoUrl,
                ),
                if (place.tag != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        place.tag!.toUpperCase(),
                        style: BgFonts.display(
                          size: 10,
                          weight: FontWeight.w700,
                          color: p.orangeDeep,
                          letterSpacing: 0.4,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.favorite_border,
                        size: 16, color: Color(0xFF3A1F08)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        place.name,
                        style: BgFonts.display(
                          size: 17,
                          weight: FontWeight.w700,
                          color: p.ink,
                          letterSpacing: -0.2,
                          height: 1.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StarRow(value: place.rating),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  place.cuisine,
                  style: BgFonts.body(size: 12, color: p.inkMuted),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 12, color: p.inkMuted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        place.neighborhood,
                        style: BgFonts.body(size: 11, color: p.inkMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _Dot(color: p.inkMuted.withValues(alpha: 0.4)),
                    ),
                    Text(l.distance(place.km),
                        style: BgFonts.body(size: 11, color: p.inkMuted)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _Dot(color: p.inkMuted.withValues(alpha: 0.4)),
                    ),
                    Text(place.price,
                        style: BgFonts.body(size: 11, color: p.inkMuted)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _StatusPill(open: place.open, label: place.open ? l.open : l.closed),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '· ${l.reviewsCount(place.reviews)}',
                        style: BgFonts.body(size: 11, color: p.inkMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
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

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool open;
  final String label;
  const _StatusPill({required this.open, required this.label});
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    final col = open ? p.green : p.inkMuted;
    return Container(
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
              weight: FontWeight.w600,
              color: col,
              letterSpacing: 0.2,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _NeighborhoodPill extends StatelessWidget {
  final Neighborhood n;
  final L l;
  const _NeighborhoodPill({required this.n, required this.l});
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    return Container(
      width: 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhotoPlaceholder(
            seed: n.seed,
            showLabel: false,
            width: double.infinity,
            height: 64,
            borderRadius: BorderRadius.circular(10),
            photoUrl: n.photoUrl,
          ),
          const SizedBox(height: 8),
          Text(
            n.name,
            style: BgFonts.display(
              size: 14,
              weight: FontWeight.w700,
              color: p.ink,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            l.addresses(n.count),
            style: BgFonts.body(size: 11, color: p.inkMuted, height: 1.1),
          ),
        ],
      ),
    );
  }
}

class _NewRow extends StatelessWidget {
  final Place p;
  final L l;
  final VoidCallback? onTap;
  const _NewRow({required this.p, required this.l, this.onTap});
  @override
  Widget build(BuildContext context) {
    final pal = AppScope.of(context).palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: pal.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: pal.cardBorder),
        ),
        child: Row(
          children: [
            PhotoPlaceholder(
              seed: p.seed,
              showLabel: false,
              width: 56,
              height: 56,
              borderRadius: BorderRadius.circular(10),
              photoUrl: p.photoUrl,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: BgFonts.display(
                      size: 15,
                      weight: FontWeight.w700,
                      color: pal.ink,
                      height: 1.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.cuisine,
                    style: BgFonts.body(size: 12, color: pal.inkMuted, height: 1.1),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                StarRow(value: p.rating, size: 12),
                const SizedBox(height: 4),
                Text(
                  l.reviewsCount(p.reviews),
                  style: BgFonts.body(size: 10, color: pal.inkMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
