import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../api/api_error.dart';
import '../api/feed_api.dart';
import '../app_state.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/photo_placeholder.dart';

const int _kPageLimit = 10;
const int _kPrefetchThreshold = 3;

/// Per-feed-item like/comment counts, mutated optimistically when the user
/// taps the heart or posts a comment. Seeded from the API on first sight,
/// then we trust the local copy until the next refresh.
class _SocialState {
  int likes;
  int comments;
  bool liked;
  _SocialState({
    required this.likes,
    required this.comments,
    required this.liked,
  });
}

/// One slot in the feed's controller cache. The parent (`_ForYouScreenState`)
/// keeps a sliding window of [idx-1, idx, idx+1] so the next video is fully
/// initialized (and has decoded frames buffered) by the time the user swipes.
class _CachedVideo {
  _CachedVideo({required this.index, required this.url});
  final int index;
  final String url;
  VideoPlayerController? controller;
  VoidCallback? listener;
  bool initializing = false;
  bool ready = false;
  bool failed = false;
}

class ForYouScreen extends StatefulWidget {
  /// When true, the comments sheet for the first feed item is opened as
  /// soon as the initial page loads. Used by the `foryouComments` route.
  final bool initialCommentsOpen;
  final VoidCallback? onOpenMap;
  final ValueChanged<String>? onOpenPlace;
  final VoidCallback? onRequireAuth;

  const ForYouScreen({
    super.key,
    this.initialCommentsOpen = false,
    this.onOpenMap,
    this.onOpenPlace,
    this.onRequireAuth,
  });

  @override
  State<ForYouScreen> createState() => _ForYouScreenState();
}

class _ForYouScreenState extends State<ForYouScreen> {
  late final PageController _pc = PageController();
  final List<FeedVideo> _items = [];
  final Set<String> _seenInCurrentCycle = {};
  final Map<int, _CachedVideo> _cache = {};
  Timer? _activeFailureTimer;
  int _idx = 0;
  String? _nextCursor;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  Object? _initialError;
  Object? _paginationError;
  bool _muted = false;
  // Per-media social state. Keyed by FeedVideo.id so counts survive the
  // intentional cycle-back at the end of the feed without diverging.
  final Map<String, _SocialState> _social = {};
  // Tracks which media ids have an in-flight like/unlike call so taps don't
  // race the network.
  final Set<String> _likePending = {};
  bool _commentsAutoOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitial();
    });
  }

  @override
  void dispose() {
    _activeFailureTimer?.cancel();
    for (final e in _cache.values) {
      _disposeEntry(e);
    }
    _cache.clear();
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
        for (final e in _cache.values) {
          _disposeEntry(e);
        }
        _cache.clear();
        _items.clear();
        _seenInCurrentCycle.clear();
        for (final v in page.items) {
          if (_seenInCurrentCycle.add(v.id)) _items.add(v);
        }
        _seedSocialFor(page.items);
        _nextCursor = page.nextCursor;
        _idx = 0;
        _loadingInitial = false;
      });
      _ensureCacheForIndex(_idx);
      _maybeAutoOpenComments();
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
        _seedSocialFor(page.items);
        _nextCursor = page.nextCursor;
        _loadingMore = false;
      });
      _ensureCacheForIndex(_idx);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _paginationError = e;
        _loadingMore = false;
      });
    }
  }

  void _onPageChanged(int i) {
    // Pause + rewind the previously active controller so the user sees a fresh
    // start when they swipe back. This must run before _idx is updated so the
    // lookup hits the outgoing slot.
    final outgoing = _cache[_idx]?.controller;
    if (outgoing != null) {
      outgoing.pause();
      outgoing.seekTo(Duration.zero);
    }
    setState(() => _idx = i);
    _ensureCacheForIndex(i);
    // If the incoming controller is already initialized (preloaded), start it
    // right away. Otherwise _initEntry will start it on completion.
    final incoming = _cache[i];
    if (incoming != null && incoming.ready && incoming.controller != null) {
      incoming.controller!.play();
    }
    _checkActiveFailureSkip();
    if (_items.isNotEmpty &&
        i >= _items.length - _kPrefetchThreshold &&
        !_loadingMore) {
      _loadMore();
    }
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    final v = _muted ? 0.0 : 1.0;
    for (final e in _cache.values) {
      e.controller?.setVolume(v);
    }
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
    if (v.author.isPlace) {
      _openPlace(v);
      return;
    }
    final state = AppScope.of(context);
    final p = state.palette;
    final l = L(state.lang);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _UserProfileSheet(author: v.author, p: p, l: l),
    );
  }

  // ---------------- Social state (likes / comments) ----------------

  void _seedSocialFor(Iterable<FeedVideo> videos) {
    for (final v in videos) {
      // Don't clobber an in-flight optimistic update if the same id comes
      // back from the server (cycle-back).
      _social.putIfAbsent(
        v.id,
        () => _SocialState(
          likes: v.likesCount,
          comments: v.commentsCount,
          liked: v.userLiked,
        ),
      );
    }
  }

  _SocialState _socialFor(FeedVideo v) {
    return _social.putIfAbsent(
      v.id,
      () => _SocialState(
        likes: v.likesCount,
        comments: v.commentsCount,
        liked: v.userLiked,
      ),
    );
  }

  Future<void> _toggleLike(FeedVideo v) async {
    final state = AppScope.of(context);
    if (!state.isSignedIn) {
      widget.onRequireAuth?.call();
      return;
    }
    if (v.id.isEmpty) return;
    if (_likePending.contains(v.id)) return;
    final s = _socialFor(v);
    final wasLiked = s.liked;
    setState(() {
      _likePending.add(v.id);
      s.liked = !wasLiked;
      s.likes = (s.likes + (wasLiked ? -1 : 1)).clamp(0, 1 << 31);
    });
    try {
      final res = wasLiked
          ? await state.mediaSocialApi.unlike(v.id)
          : await state.mediaSocialApi.like(v.id);
      if (!mounted) return;
      setState(() {
        s.liked = res.userLiked;
        s.likes = res.likesCount;
        _likePending.remove(v.id);
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        s.liked = wasLiked;
        s.likes = (s.likes + (wasLiked ? 1 : -1)).clamp(0, 1 << 31);
        _likePending.remove(v.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        s.liked = wasLiked;
        s.likes = (s.likes + (wasLiked ? 1 : -1)).clamp(0, 1 << 31);
        _likePending.remove(v.id);
      });
    }
  }

  void _openComments(FeedVideo v) {
    if (v.id.isEmpty) return;
    final s = _socialFor(v);
    showCommentsSheet(
      context,
      mediaId: v.id,
      initialCount: s.comments,
      onCountChanged: (n) {
        if (!mounted) return;
        setState(() => s.comments = n);
      },
      onRequireAuth: widget.onRequireAuth,
    );
  }

  void _maybeAutoOpenComments() {
    if (!widget.initialCommentsOpen || _commentsAutoOpened) return;
    if (_items.isEmpty) return;
    _commentsAutoOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _items.isEmpty) return;
      _openComments(_items[0]);
    });
  }

  // ---------------- Controller cache (preloads idx-1, idx, idx+1) ----------------

  void _ensureCacheForIndex(int idx) {
    if (_items.isEmpty) return;
    final keep = <int>{};
    for (var i = idx - 1; i <= idx + 1; i++) {
      if (i < 0 || i >= _items.length) continue;
      keep.add(i);
      if (!_cache.containsKey(i)) {
        final entry = _CachedVideo(index: i, url: _items[i].url);
        _cache[i] = entry;
        _initEntry(entry);
      }
    }
    final toRemove = _cache.keys.where((k) => !keep.contains(k)).toList();
    for (final k in toRemove) {
      _disposeEntry(_cache[k]!);
      _cache.remove(k);
    }
  }

  Future<void> _initEntry(_CachedVideo entry) async {
    if (entry.url.isEmpty) {
      entry.failed = true;
      if (entry.index == _idx) _checkActiveFailureSkip();
      return;
    }
    entry.initializing = true;
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(entry.url));
      await c.initialize();
      // Window may have shifted while we awaited the network round-trip — if
      // this entry is no longer the live one for its slot, dispose silently.
      if (!mounted || _cache[entry.index] != entry) {
        await c.dispose();
        return;
      }
      void listener() => _onControllerUpdate(entry.index);
      c.addListener(listener);
      await c.setVolume(_muted ? 0 : 1);
      entry.controller = c;
      entry.listener = listener;
      entry.ready = true;
      entry.initializing = false;
      if (entry.index == _idx) {
        await c.play();
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Feed] init failed idx=${entry.index}: $e');
      }
      entry.failed = true;
      entry.initializing = false;
      if (mounted) {
        setState(() {});
        if (entry.index == _idx) _checkActiveFailureSkip();
      }
    }
  }

  void _onControllerUpdate(int index) {
    final entry = _cache[index];
    final c = entry?.controller;
    if (entry == null || c == null || !mounted) return;
    final value = c.value;
    if (value.hasError) {
      if (kDebugMode) {
        debugPrint(
            '[Feed] playback error idx=$index: ${value.errorDescription}');
      }
      if (!entry.failed) {
        entry.failed = true;
        if (index == _idx) _checkActiveFailureSkip();
      }
      return;
    }
    final dur = value.duration;
    if (dur > Duration.zero &&
        !value.isPlaying &&
        value.position >= dur - const Duration(milliseconds: 250)) {
      if (index == _idx && _idx < _items.length - 1) {
        _pc.animateToPage(
          _idx + 1,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _checkActiveFailureSkip() {
    _activeFailureTimer?.cancel();
    if (_idx >= _items.length) return;
    final entry = _cache[_idx];
    if (entry?.failed != true) return;
    if (_idx >= _items.length - 1) return;
    _activeFailureTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _idx >= _items.length - 1) return;
      _pc.animateToPage(
        _idx + 1,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    });
  }

  void _disposeEntry(_CachedVideo e) {
    final l = e.listener;
    final c = e.controller;
    if (l != null && c != null) c.removeListener(l);
    c?.dispose();
    e.controller = null;
    e.listener = null;
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
            itemBuilder: (_, i) {
              final entry = _cache[i];
              final readyController =
                  (entry != null && entry.ready) ? entry.controller : null;
              final v = _items[i];
              final s = _socialFor(v);
              return _FeedVideoCard(
                key: ValueKey('feed_${i}_${v.id}'),
                video: v,
                controller: readyController,
                muted: _muted,
                palette: p,
                l: l,
                likes: s.likes,
                comments: s.comments,
                liked: s.liked,
                onTap: _toggleMute,
                onAuthorTap: () => _onAuthorTap(v),
                onPlaceTap: () => _openPlace(v),
                onShareTap: () => _share(v),
                onLikeTap: () => _toggleLike(v),
                onCommentsTap: () => _openComments(v),
                onDoubleTapLike: () {
                  if (!s.liked) _toggleLike(v);
                },
              );
            },
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
            const Positioned.fill(
              child: IgnorePointer(
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
                  _topTab(l.fypFor, true),
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

class _FeedVideoCard extends StatelessWidget {
  final FeedVideo video;
  final VideoPlayerController? controller;
  final bool muted;
  final BgPalette palette;
  final L l;
  final int likes;
  final int comments;
  final bool liked;
  final VoidCallback? onTap;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onPlaceTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onLikeTap;
  final VoidCallback? onCommentsTap;
  final VoidCallback? onDoubleTapLike;

  const _FeedVideoCard({
    super.key,
    required this.video,
    required this.controller,
    required this.muted,
    required this.palette,
    required this.l,
    required this.likes,
    required this.comments,
    required this.liked,
    this.onTap,
    this.onAuthorTap,
    this.onPlaceTap,
    this.onShareTap,
    this.onLikeTap,
    this.onCommentsTap,
    this.onDoubleTapLike,
  });

  @override
  Widget build(BuildContext context) {
    final v = video;
    final c = controller;
    final ready = c != null && c.value.isInitialized;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Poster (always rendered as backdrop until video has frames)
        Positioned.fill(child: _Poster(video: v)),
        if (ready)
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: c.value.size.width,
                height: c.value.size.height,
                child: VideoPlayer(c),
              ),
            ),
          ),
        // Tap-to-mute / double-tap to like
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            onDoubleTap: onDoubleTapLike,
            child: const SizedBox.expand(),
          ),
        ),
        // Bottom gradient (improves overlay legibility)
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 380,
          child: IgnorePointer(
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
                  muted ? Icons.volume_off : Icons.volume_up,
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
                palette: palette,
                onTap: onAuthorTap,
              ),
              const SizedBox(height: 18),
              _ActionButton(
                icon: Icon(
                  liked ? Icons.favorite : Icons.favorite_border,
                  color: liked ? palette.orange : Colors.white,
                  size: 24,
                ),
                label: likes > 0 ? _formatCount(likes) : null,
                onTap: onLikeTap,
              ),
              const SizedBox(height: 14),
              _ActionButton(
                icon: const Icon(Icons.mode_comment_outlined,
                    color: Colors.white, size: 22),
                label: comments > 0 ? _formatCount(comments) : null,
                onTap: onCommentsTap,
              ),
              const SizedBox(height: 14),
              _ActionButton(
                icon: const Icon(Icons.ios_share,
                    color: Colors.white, size: 22),
                onTap: onShareTap,
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
            l: l,
            palette: palette,
            onAuthorTap: onAuthorTap,
            onPlaceTap: onPlaceTap,
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
                borderRadius: BorderRadius.circular(6),
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
  final String? label;
  final VoidCallback? onTap;
  const _ActionButton({required this.icon, this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
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
          if (label != null) ...[
            const SizedBox(height: 4),
            Text(
              label!,
              style: BgFonts.body(
                size: 11,
                weight: FontWeight.w700,
                color: Colors.white,
                height: 1,
              ).copyWith(
                shadows: const [
                  Shadow(
                    color: Color(0x99000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatCount(int n) {
  if (n < 1000) return '$n';
  if (n < 10000) {
    final rounded = (n / 100).round() / 10;
    return '${rounded.toStringAsFixed(rounded.truncateToDouble() == rounded ? 0 : 1)}k';
  }
  if (n < 1000000) return '${(n / 1000).round()}k';
  final m = (n / 100000).round() / 10;
  return '${m.toStringAsFixed(m.truncateToDouble() == m ? 0 : 1)}M';
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

class _UserProfileSheet extends StatelessWidget {
  final FeedAuthor author;
  final BgPalette p;
  final L l;
  const _UserProfileSheet({
    required this.author,
    required this.p,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    final initial =
        author.name.isNotEmpty ? author.name.characters.first : '?';
    final hasAvatar = author.avatarUrl != null && author.avatarUrl!.isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: p.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: p.orangeSoft,
                shape: BoxShape.circle,
                image: hasAvatar
                    ? DecorationImage(
                        image: NetworkImage(author.avatarUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: hasAvatar
                  ? null
                  : Text(
                      initial.toString().toUpperCase(),
                      style: BgFonts.display(
                        size: 28,
                        weight: FontWeight.w700,
                        color: p.orangeDeep,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    author.name.isEmpty
                        ? l.pick('Utilisateur', 'User')
                        : author.name,
                    style: BgFonts.display(
                      size: 18,
                      weight: FontWeight.w700,
                      color: p.ink,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (author.verified) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.verified, size: 16, color: p.orange),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l.pick(
                'Profils des contributeurs bientôt disponibles.',
                'Contributor profiles are coming soon.',
              ),
              textAlign: TextAlign.center,
              style: BgFonts.body(size: 13, color: p.inkMuted, height: 1.4),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.cardBorder),
                ),
                alignment: Alignment.center,
                child: Text(
                  l.pick('Fermer', 'Close'),
                  style: BgFonts.body(
                    size: 13,
                    weight: FontWeight.w700,
                    color: p.ink,
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
