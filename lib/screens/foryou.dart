import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../api/api_error.dart';
import '../api/feed_api.dart';
import '../app_state.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets/photo_placeholder.dart';

const int _kPageLimit = 10;
const int _kPrefetchThreshold = 3;

class ForYouScreen extends StatefulWidget {
  // Kept for compatibility with the existing main.dart routing; the comments
  // sheet is out of scope for v1 (no backend wiring) and is now a no-op.
  final bool initialCommentsOpen;
  final VoidCallback? onOpenMap;
  final ValueChanged<String>? onOpenPlace;

  const ForYouScreen({
    super.key,
    this.initialCommentsOpen = false,
    this.onOpenMap,
    this.onOpenPlace,
  });

  @override
  State<ForYouScreen> createState() => _ForYouScreenState();
}

class _ForYouScreenState extends State<ForYouScreen> {
  late final PageController _pc = PageController();
  final List<FeedVideo> _items = [];
  final Set<String> _seenInCurrentCycle = {};
  int _idx = 0;
  String? _nextCursor;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  Object? _initialError;
  Object? _paginationError;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitial();
    });
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loadingInitial = true;
      _initialError = null;
      _paginationError = null;
    });
    try {
      final api = AppScope.of(context).feedApi;
      final page = await api.getVideos(page: 1, limit: _kPageLimit);
      if (!mounted) return;
      setState(() {
        _items.clear();
        _seenInCurrentCycle.clear();
        for (final v in page.items) {
          if (_seenInCurrentCycle.add(v.id)) _items.add(v);
        }
        _nextCursor = page.nextCursor;
        _idx = 0;
        _loadingInitial = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initialError = e;
        _loadingInitial = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() {
      _loadingMore = true;
      _paginationError = null;
    });
    // When next_cursor is null, loop back to page 1. Within a cycle we dedupe
    // by id (paranoia against backend repeats); across cycles we intentionally
    // re-append the same videos so the feed never runs out.
    final cursor = _nextCursor;
    final cycling = cursor == null;
    final pageNum = cycling ? 1 : (int.tryParse(cursor) ?? 1);
    try {
      final api = AppScope.of(context).feedApi;
      final page = await api.getVideos(page: pageNum, limit: _kPageLimit);
      if (!mounted) return;
      setState(() {
        if (cycling) {
          _seenInCurrentCycle.clear();
        }
        for (final v in page.items) {
          if (cycling) {
            _seenInCurrentCycle.add(v.id);
            _items.add(v);
          } else if (_seenInCurrentCycle.add(v.id)) {
            _items.add(v);
          }
        }
        _nextCursor = page.nextCursor;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _paginationError = e;
        _loadingMore = false;
      });
    }
  }

  void _onPageChanged(int i) {
    setState(() => _idx = i);
    if (_items.isNotEmpty &&
        i >= _items.length - _kPrefetchThreshold &&
        !_loadingMore) {
      _loadMore();
    }
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
  }

  Future<void> _share(FeedVideo v) async {
    final url = v.place.shareUrl;
    final l = L(AppScope.of(context).lang);
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.pick(
              'Lien indisponible', 'Share link unavailable')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.pick(
            'Lien copié dans le presse-papier', 'Link copied to clipboard')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openPlace(FeedVideo v) {
    final cb = widget.onOpenPlace;
    if (cb == null) return;
    final slug = v.place.slug;
    if (slug.isEmpty) return;
    cb(slug);
  }

  void _onAuthorTap(FeedVideo v) {
    // user → user profile (no screen yet, stub)
    // place → place detail
    if (v.author.isPlace) _openPlace(v);
  }

  void _onPlaybackFailed(int forIndex) {
    if (!mounted) return;
    if (forIndex != _idx) return;
    if (_idx >= _items.length - 1) return;
    _pc.animateToPage(
      _idx + 1,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  void _onCompleted(int forIndex) {
    if (!mounted) return;
    if (forIndex != _idx) return;
    if (_idx >= _items.length - 1) return;
    _pc.animateToPage(
      _idx + 1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = L(state.lang);
    final p = state.palette;

    if (_loadingInitial) {
      return _LoadingScreen(palette: p);
    }
    if (_initialError != null) {
      return _ErrorScreen(
        message: _initialError is ApiError
            ? (_initialError as ApiError).message
            : l.pick(
                "Impossible de charger le fil. Vérifiez votre connexion.",
                'Could not load feed. Check your connection.'),
        retryLabel: l.pick('Réessayer', 'Retry'),
        onRetry: _loadInitial,
      );
    }
    if (_items.isEmpty) {
      return _EmptyScreen(
        title: l.pick('Pas encore de vidéos', 'No videos yet'),
        sub: l.pick('Revenez bientôt — le contenu arrive.',
            'Check back soon — new content is on the way.'),
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pc,
            scrollDirection: Axis.vertical,
            itemCount: _items.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (_, i) => _FeedVideoCard(
              key: ValueKey('feed_${i}_${_items[i].id}'),
              video: _items[i],
              isActive: i == _idx,
              muted: _muted,
              palette: p,
              l: l,
              onTap: _toggleMute,
              onAuthorTap: () => _onAuthorTap(_items[i]),
              onPlaceTap: () => _openPlace(_items[i]),
              onShareTap: () => _share(_items[i]),
              onPlaybackFailed: () => _onPlaybackFailed(i),
              onCompleted: () => _onCompleted(i),
            ),
          ),
          _TopBar(l: l, onOpenMap: widget.onOpenMap),
          if (_paginationError != null && !_loadingMore)
            Positioned(
              left: 0,
              right: 0,
              bottom: 110,
              child: Center(
                child: _RetryPill(
                  label: l.pick('Recharger', 'Retry'),
                  onTap: _loadMore,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// -------------------------- Top bar (sticky overlay) --------------------------

class _TopBar extends StatelessWidget {
  final L l;
  final VoidCallback? onOpenMap;
  const _TopBar({required this.l, this.onOpenMap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 120,
      child: IgnorePointer(
        ignoring: false,
        child: Stack(
          children: [
            const IgnorePointer(
              child: Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x80000000), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 56,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _topTab(l.fypFollow, false),
                  const SizedBox(width: 22),
                  _topTab(l.fypFor, true),
                  const SizedBox(width: 22),
                  _topTab(l.fypNear, false),
                ],
              ),
            ),
            Positioned(
              top: 56,
              right: 16,
              child: GestureDetector(
                onTap: onOpenMap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0x59000000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.map_outlined,
                      color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topTab(String text, bool active) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Opacity(
          opacity: active ? 1 : 0.55,
          child: Text(
            text,
            style: BgFonts.display(
              size: 15,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        if (active)
          Positioned(
            left: 0,
            right: 0,
            bottom: -7,
            child: Center(
              child: Container(
                width: 22,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ----------------------------- Single feed card ------------------------------

class _FeedVideoCard extends StatefulWidget {
  final FeedVideo video;
  final bool isActive;
  final bool muted;
  final BgPalette palette;
  final L l;
  final VoidCallback? onTap;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onPlaceTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onPlaybackFailed;
  final VoidCallback? onCompleted;

  const _FeedVideoCard({
    super.key,
    required this.video,
    required this.isActive,
    required this.muted,
    required this.palette,
    required this.l,
    this.onTap,
    this.onAuthorTap,
    this.onPlaceTap,
    this.onShareTap,
    this.onPlaybackFailed,
    this.onCompleted,
  });

  @override
  State<_FeedVideoCard> createState() => _FeedVideoCardState();
}

class _FeedVideoCardState extends State<_FeedVideoCard> {
  Player? _player;
  VideoController? _controller;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<bool>? _completedSub;
  bool _ready = false;
  bool _failed = false;
  Timer? _failTimer;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(covariant _FeedVideoCard old) {
    super.didUpdateWidget(old);
    if (old.isActive != widget.isActive) {
      _applyPlayState();
    }
    if (old.muted != widget.muted) {
      _player?.setVolume(widget.muted ? 0 : 100);
    }
  }

  @override
  void dispose() {
    _failTimer?.cancel();
    _errorSub?.cancel();
    _completedSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _initPlayer() async {
    final url = widget.video.url;
    if (url.isEmpty) {
      _scheduleFailoverSkip();
      return;
    }
    try {
      final player = Player();
      final controller = VideoController(player);
      await player.setPlaylistMode(PlaylistMode.none);
      await player.setVolume(widget.muted ? 0 : 100);
      _errorSub = player.stream.error.listen((err) {
        if (kDebugMode) {
          debugPrint('[Feed] playback error id=${widget.video.id}: $err');
        }
        _scheduleFailoverSkip();
      });
      _completedSub = player.stream.completed.listen((done) {
        if (!mounted || !done) return;
        if (widget.isActive) widget.onCompleted?.call();
      });
      await player.open(Media(url), play: widget.isActive);
      if (!mounted) {
        await player.dispose();
        return;
      }
      setState(() {
        _player = player;
        _controller = controller;
        _ready = true;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Feed] init failed id=${widget.video.id}: $e');
      }
      if (!mounted) return;
      _scheduleFailoverSkip();
    }
  }

  void _scheduleFailoverSkip() {
    if (_failed) return;
    _failed = true;
    _failTimer?.cancel();
    _failTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      widget.onPlaybackFailed?.call();
    });
  }

  void _applyPlayState() {
    final p = _player;
    if (p == null) return;
    if (widget.isActive) {
      p.play();
    } else {
      p.pause();
      p.seek(Duration.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.video;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Poster (always rendered as backdrop until video has frames)
        Positioned.fill(child: _Poster(video: v)),
        if (_ready && _controller != null)
          Positioned.fill(
            child: Video(
              controller: _controller!,
              controls: NoVideoControls,
              fit: BoxFit.cover,
            ),
          ),
        // Tap-to-mute / double-tap stub
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            // Reserved for future "like" — intentionally a no-op stub.
            onDoubleTap: () {},
            child: const SizedBox.expand(),
          ),
        ),
        // Bottom gradient (improves overlay legibility)
        const IgnorePointer(
          child: Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 380,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xCC000000), Colors.transparent],
                  stops: [0.0, 1.0],
                ),
              ),
            ),
          ),
        ),
        // Mute pill (top-right under map button area, but moved down on left)
        Positioned(
          top: 100,
          left: 16,
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: 1,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  widget.muted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ),
        // Right action rail
        Positioned(
          right: 12,
          bottom: 220,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AuthorAvatar(
                author: v.author,
                palette: widget.palette,
                onTap: widget.onAuthorTap,
              ),
              const SizedBox(height: 18),
              _ActionButton(
                icon: const Icon(Icons.favorite_border,
                    color: Colors.white, size: 24),
                onTap: () {/* stub: future like */},
              ),
              const SizedBox(height: 14),
              _ActionButton(
                icon: const Icon(Icons.ios_share,
                    color: Colors.white, size: 22),
                onTap: widget.onShareTap,
              ),
            ],
          ),
        ),
        // Bottom info: caption + place card
        Positioned(
          left: 0,
          right: 78,
          bottom: 100,
          child: _BottomInfo(
            video: v,
            l: widget.l,
            palette: widget.palette,
            onAuthorTap: widget.onAuthorTap,
            onPlaceTap: widget.onPlaceTap,
          ),
        ),
      ],
    );
  }
}

// ----------------------------- Visual helpers ------------------------------

class _Poster extends StatelessWidget {
  final FeedVideo video;
  const _Poster({required this.video});

  @override
  Widget build(BuildContext context) {
    final url = video.thumbUrl;
    if (url != null && url.isNotEmpty) {
      return Container(
        color: Colors.black,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _SeedBackground(video: video),
        ),
      );
    }
    return _SeedBackground(video: video);
  }
}

class _SeedBackground extends StatelessWidget {
  final FeedVideo video;
  const _SeedBackground({required this.video});

  @override
  Widget build(BuildContext context) {
    final seed = video.seed ?? video.id;
    return PhotoPlaceholder(seed: seed, label: video.label, showLabel: false);
  }
}

class _AuthorAvatar extends StatelessWidget {
  final FeedAuthor author;
  final BgPalette palette;
  final VoidCallback? onTap;
  const _AuthorAvatar({
    required this.author,
    required this.palette,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initial =
        author.name.isNotEmpty ? author.name.characters.first : '?';
    final hasAvatar = author.avatarUrl != null && author.avatarUrl!.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 54,
        height: 60,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: palette.orange,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                    spreadRadius: -4,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: hasAvatar
                  ? Image.network(
                      author.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _AvatarInitial(
                        initial: initial,
                        palette: palette,
                      ),
                    )
                  : _AvatarInitial(initial: initial, palette: palette),
            ),
            if (author.verified)
              Positioned(
                bottom: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: palette.orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.verified,
                      color: Colors.white, size: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  final String initial;
  final BgPalette palette;
  const _AvatarInitial({required this.initial, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: palette.orange,
      alignment: Alignment.center,
      child: Text(
        initial.toUpperCase(),
        style: BgFonts.display(
          size: 18,
          weight: FontWeight.w700,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onTap;
  const _ActionButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        alignment: Alignment.center,
        child: icon,
      ),
    );
  }
}

class _BottomInfo extends StatelessWidget {
  final FeedVideo video;
  final L l;
  final BgPalette palette;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onPlaceTap;

  const _BottomInfo({
    required this.video,
    required this.l,
    required this.palette,
    this.onAuthorTap,
    this.onPlaceTap,
  });

  @override
  Widget build(BuildContext context) {
    final author = video.author;
    final caption = video.label;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onAuthorTap,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    author.name.isNotEmpty
                        ? author.name
                        : l.pick('Anonyme', 'Anonymous'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BgFonts.display(
                      size: 15,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ).copyWith(
                      shadows: const [
                        Shadow(
                          color: Color(0x80000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
                if (author.verified) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified,
                      size: 14, color: Colors.white),
                ],
              ],
            ),
          ),
          if (caption != null && caption.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              caption,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: BgFonts.body(
                size: 13,
                color: Colors.white,
                height: 1.45,
              ).copyWith(
                shadows: const [
                  Shadow(
                    color: Color(0x80000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _PlaceCard(
            place: video.place,
            l: l,
            palette: palette,
            onTap: onPlaceTap,
          ),
        ],
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final FeedPlace place;
  final L l;
  final BgPalette palette;
  final VoidCallback? onTap;

  const _PlaceCard({
    required this.place,
    required this.l,
    required this.palette,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (place.name.isEmpty) return const SizedBox.shrink();
    final secondaryParts = <String>[
      if ((place.cuisine ?? '').isNotEmpty) place.cuisine!,
      if ((place.neighborhood ?? '').isNotEmpty) place.neighborhood!,
    ];
    final secondary = secondaryParts.join(' · ');
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 40,
                height: 40,
                child: PhotoPlaceholder(
                  seed: place.slug.isNotEmpty ? place.slug : place.id,
                  showLabel: false,
                  photoUrl: place.photoUrl,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          place.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BgFonts.display(
                            size: 13,
                            weight: FontWeight.w700,
                            color: palette.ink,
                            height: 1.15,
                          ),
                        ),
                      ),
                      if (place.verified) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.verified,
                            size: 12, color: palette.orange),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded,
                          size: 11, color: palette.orange),
                      const SizedBox(width: 2),
                      Text(
                        place.rating > 0
                            ? place.rating.toStringAsFixed(1)
                            : '—',
                        style: BgFonts.body(
                          size: 11,
                          weight: FontWeight.w700,
                          color: palette.ink,
                          height: 1.2,
                        ),
                      ),
                      if ((place.priceLabel ?? '').isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          place.priceLabel!,
                          style: BgFonts.body(
                            size: 11,
                            weight: FontWeight.w600,
                            color: palette.inkMuted,
                            height: 1.2,
                          ),
                        ),
                      ],
                      if (secondary.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            secondary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BgFonts.body(
                              size: 11,
                              color: palette.inkMuted,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _OpenNowPill(open: place.isOpenNow, l: l, palette: palette),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: palette.inkMuted),
          ],
        ),
      ),
    );
  }
}

class _OpenNowPill extends StatelessWidget {
  final bool open;
  final L l;
  final BgPalette palette;
  const _OpenNowPill({
    required this.open,
    required this.l,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final color = open ? palette.green : palette.inkMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            open ? l.openNow : l.closed,
            style: BgFonts.body(
              size: 10,
              weight: FontWeight.w700,
              color: color,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------- Loading / Empty / Error -------------------------

class _LoadingScreen extends StatelessWidget {
  final BgPalette palette;
  const _LoadingScreen({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(palette.orange),
        ),
      ),
    );
  }
}

class _EmptyScreen extends StatelessWidget {
  final String title;
  final String sub;
  const _EmptyScreen({required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.video_library_outlined,
              color: Colors.white54, size: 48),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: BgFonts.display(
              size: 18,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: BgFonts.body(
              size: 13,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;
  const _ErrorScreen({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, color: Colors.white54, size: 44),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: BgFonts.body(
              size: 14,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                retryLabel,
                style: BgFonts.body(
                  size: 13,
                  weight: FontWeight.w700,
                  color: Colors.black,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RetryPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _RetryPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.refresh, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: BgFonts.body(
                size: 12,
                weight: FontWeight.w600,
                color: Colors.white,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
