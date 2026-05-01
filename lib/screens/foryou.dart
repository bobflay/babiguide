import 'package:flutter/material.dart';
import '../app_state.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets/photo_placeholder.dart';

class _Reviewer {
  final String name;
  final String handle;
  final String avatar;
  final String followers;
  final bool following;
  const _Reviewer({
    required this.name,
    required this.handle,
    required this.avatar,
    required this.followers,
    required this.following,
  });
}

class _Place {
  final String name;
  final String neighborhood;
  final double rating;
  final String seed;
  final String label;
  const _Place({
    required this.name,
    required this.neighborhood,
    required this.rating,
    required this.seed,
    required this.label,
  });
}

class _Video {
  final String id;
  final String seed;
  final String label;
  final String duration;
  final _Reviewer reviewer;
  final _Place place;
  final String caption;
  final List<String> tags;
  final int rating;
  final int likes;
  final int comments;
  final int shares;
  final int saves;
  final bool liked;
  const _Video({
    required this.id,
    required this.seed,
    required this.label,
    required this.duration,
    required this.reviewer,
    required this.place,
    required this.caption,
    required this.tags,
    required this.rating,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.saves,
    required this.liked,
  });
}

const List<_Video> _videos = [
  _Video(
    id: 'v1',
    seed: 'fyp1',
    label: 'POULET BRAISÉ · CLOSE-UP',
    duration: '0:42',
    reviewer: _Reviewer(
      name: 'Mariam K.',
      handle: '@mariamk',
      avatar: 'M',
      followers: '12,4K',
      following: false,
    ),
    place: _Place(
      name: 'Chez Norima',
      neighborhood: 'Cocody · Angré',
      rating: 4.8,
      seed: 'p1',
      label: 'POULET',
    ),
    caption:
        "Le poulet braisé ici 🔥 Mariné 24h, ça se sent. Toilettes nickel en plus — détail qui change tout.",
    tags: ['#cocody', '#mauquis', '#pouletbraise'],
    rating: 5,
    likes: 12400,
    comments: 284,
    shares: 142,
    saves: 890,
    liked: false,
  ),
  _Video(
    id: 'v2',
    seed: 'fyp2',
    label: 'TERRASSE · AMBIANCE NUIT',
    duration: '0:24',
    reviewer: _Reviewer(
      name: 'Yao D.',
      handle: '@yaod',
      avatar: 'Y',
      followers: '3,8K',
      following: true,
    ),
    place: _Place(
      name: 'Le Maquis 17',
      neighborhood: 'Marcory · Zone 4',
      rating: 4.6,
      seed: 'p2',
      label: 'TERRASSE',
    ),
    caption:
        "Ambiance grave cool le vendredi soir. Service un peu lent mais ça vaut le coup.",
    tags: ['#zone4', '#vendredisoir'],
    rating: 4,
    likes: 8200,
    comments: 156,
    shares: 67,
    saves: 412,
    liked: true,
  ),
];

String _fmt(int n) {
  if (n >= 1000) {
    final v = n / 1000.0;
    final s = v.toStringAsFixed(1);
    return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}K';
  }
  return n.toString();
}

class ForYouScreen extends StatefulWidget {
  final bool initialCommentsOpen;
  final VoidCallback? onOpenMap;
  const ForYouScreen({
    super.key,
    this.initialCommentsOpen = false,
    this.onOpenMap,
  });

  @override
  State<ForYouScreen> createState() => _ForYouScreenState();
}

class _ForYouScreenState extends State<ForYouScreen> {
  late final PageController _pc = PageController();
  int _idx = 0;
  bool _comments = false;

  @override
  void initState() {
    super.initState();
    _comments = widget.initialCommentsOpen;
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = L(state.lang);
    final p = state.palette;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pc,
            scrollDirection: Axis.vertical,
            itemCount: _videos.length,
            onPageChanged: (i) => setState(() => _idx = i),
            itemBuilder: (_, i) => _Card(
              v: _videos[i],
              l: l,
              palette: p,
              onComments: () => setState(() => _comments = true),
              onOpenMap: widget.onOpenMap,
            ),
          ),
          // Right edge progress dots indicating which video is active
          Positioned(
            right: 6,
            top: 0,
            bottom: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_videos.length, (i) {
                  final active = i == _idx;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1.5),
                    child: Container(
                      width: 2,
                      height: active ? 18 : 8,
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          if (_comments)
            _CommentsSheet(
              v: _videos[_idx],
              l: l,
              palette: p,
              onClose: () => setState(() => _comments = false),
            ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final _Video v;
  final L l;
  final BgPalette palette;
  final VoidCallback onComments;
  final VoidCallback? onOpenMap;
  const _Card({
    required this.v,
    required this.l,
    required this.palette,
    required this.onComments,
    this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PhotoPlaceholder(seed: v.seed, label: v.label, showLabel: false),
        // Top gradient
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 160,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x8C000000), Colors.transparent],
                ),
              ),
            ),
          ),
        ),
        // Top tabs
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
        // Top-right buttons: map + search
        Positioned(
          top: 56,
          right: 16,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onOpenMap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0x59000000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.map_outlined, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0x59000000),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.search, color: Colors.white, size: 18),
              ),
            ],
          ),
        ),
        // Center play hint
        Center(
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.30),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
        // Right action rail
        Positioned(
          right: 12,
          bottom: 200,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ReviewerAvatar(v: v, palette: palette),
              const SizedBox(height: 16),
              _ActionButton(
                icon: Icon(
                  v.liked ? Icons.favorite : Icons.favorite_border,
                  color: v.liked ? const Color(0xFFFF4D6D) : Colors.white,
                  size: 22,
                ),
                label: _fmt(v.likes),
              ),
              const SizedBox(height: 16),
              _ActionButton(
                icon: const Icon(
                  Icons.mode_comment_outlined,
                  color: Colors.white,
                  size: 22,
                ),
                label: _fmt(v.comments),
                onTap: onComments,
              ),
              const SizedBox(height: 16),
              _ActionButton(
                icon: const Icon(
                  Icons.bookmark_border,
                  color: Colors.white,
                  size: 22,
                ),
                label: _fmt(v.saves),
              ),
              const SizedBox(height: 16),
              _ActionButton(
                icon: const Icon(
                  Icons.ios_share,
                  color: Colors.white,
                  size: 20,
                ),
                label: _fmt(v.shares),
              ),
              const SizedBox(height: 16),
              _PlaceBadge(v: v, palette: palette),
            ],
          ),
        ),
        // Bottom info
        Positioned(
          left: 0,
          right: 80,
          bottom: 110,
          child: _BottomInfo(v: v, l: l, palette: palette),
        ),
        // Progress bar
        Positioned(
          left: 0,
          right: 0,
          bottom: 95,
          child: Container(
            height: 2,
            color: Colors.white.withValues(alpha: 0.18),
            child: const FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.34,
              child: ColoredBox(color: Colors.white),
            ),
          ),
        ),
      ],
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

class _ReviewerAvatar extends StatelessWidget {
  final _Video v;
  final BgPalette palette;
  const _ReviewerAvatar({required this.v, required this.palette});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
              shape: BoxShape.circle,
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
            alignment: Alignment.center,
            child: Text(
              v.reviewer.avatar,
              style: BgFonts.display(
                size: 18,
                weight: FontWeight.w700,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
          if (!v.reviewer.following)
            Positioned(
              bottom: -6,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: palette.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.add, color: Colors.white, size: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback? onTap;
  const _ActionButton({required this.icon, required this.label, this.onTap});

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
          const SizedBox(height: 4),
          Text(
            label,
            style: BgFonts.body(
              size: 11,
              weight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ).copyWith(
              shadows: const [
                Shadow(color: Color(0x99000000), blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceBadge extends StatelessWidget {
  final _Video v;
  final BgPalette palette;
  const _PlaceBadge({required this.v, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: PhotoPlaceholder(seed: v.place.seed, showLabel: false),
            ),
          ),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.info_outline, size: 11, color: palette.orange),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomInfo extends StatelessWidget {
  final _Video v;
  final L l;
  final BgPalette palette;
  const _BottomInfo({required this.v, required this.l, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 60, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xA6000000), Colors.transparent],
          stops: [0.3, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                v.reviewer.handle,
                style: BgFonts.display(
                  size: 15,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              _FollowChip(following: v.reviewer.following, l: l, palette: palette),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: v.caption),
                TextSpan(
                  text: ' ${l.fypMore}',
                  style: BgFonts.body(
                    size: 13,
                    color: Colors.white.withValues(alpha: 0.75),
                    height: 1.45,
                  ),
                ),
              ],
            ),
            style: BgFonts.body(
              size: 13,
              color: Colors.white,
              height: 1.45,
            ).copyWith(
              shadows: const [
                Shadow(color: Color(0x80000000), blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            v.tags.join(' '),
            style: BgFonts.body(
              size: 12,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _RestaurantChip(v: v, palette: palette),
        ],
      ),
    );
  }
}

class _FollowChip extends StatelessWidget {
  final bool following;
  final L l;
  final BgPalette palette;
  const _FollowChip({
    required this.following,
    required this.l,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: following ? Colors.white.withValues(alpha: 0.18) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: following
            ? Border.all(color: Colors.white.withValues(alpha: 0.4))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (following) ...[
            const Icon(Icons.check, size: 10, color: Colors.white),
            const SizedBox(width: 3),
          ],
          Text(
            following ? l.fypFollowing : l.fypFollowAction,
            style: BgFonts.body(
              size: 11,
              weight: FontWeight.w700,
              color: following ? Colors.white : palette.orangeDeep,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantChip extends StatelessWidget {
  final _Video v;
  final BgPalette palette;
  const _RestaurantChip({required this.v, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 7, 12, 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: SizedBox(
              width: 28,
              height: 28,
              child: PhotoPlaceholder(seed: v.place.seed, showLabel: false),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  v.place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BgFonts.display(
                    size: 12,
                    weight: FontWeight.w700,
                    color: palette.ink,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.place, size: 9, color: palette.inkMuted),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        v.place.neighborhood,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BgFonts.body(
                          size: 10,
                          color: palette.inkMuted,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.only(left: 6),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: Color(0x2E785028)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, size: 12, color: palette.orange),
                const SizedBox(width: 2),
                Text(
                  v.place.rating.toString(),
                  style: BgFonts.display(
                    size: 12,
                    weight: FontWeight.w700,
                    color: palette.ink,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 14, color: palette.inkMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Comment {
  final String name;
  final String avatar;
  final String when;
  final String text;
  final int likes;
  final bool verified;
  final bool owner;
  const _Comment({
    required this.name,
    required this.avatar,
    required this.when,
    required this.text,
    required this.likes,
    this.verified = false,
    this.owner = false,
  });
}

const List<_Comment> _comments = [
  _Comment(name: 'Sandra A.', avatar: 'S', when: '2h', text: "Trop trop bon ce poulet, j'ai testé samedi 🔥", likes: 24),
  _Comment(name: 'Kouadio J.', avatar: 'K', when: '4h', text: 'Et le prix ? Ça vaut combien le poulet entier ?', likes: 8),
  _Comment(name: 'Aïcha B.', avatar: 'A', when: '6h', text: "J'y vais ce week-end, merci pour la reco 🙏", likes: 12, owner: true),
  _Comment(name: 'Norima', avatar: 'N', when: '1j', text: 'Merci Mariam ! On vous attend bientôt 🧡', likes: 56, verified: true),
];

class _CommentsSheet extends StatelessWidget {
  final _Video v;
  final L l;
  final BgPalette palette;
  final VoidCallback onClose;
  const _CommentsSheet({
    required this.v,
    required this.l,
    required this.palette,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: onClose,
          child: const ColoredBox(color: Color(0x66000000)),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: 0.68,
            child: Container(
              decoration: BoxDecoration(
                color: palette.bg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 40,
                    offset: const Offset(0, -20),
                    spreadRadius: -10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.ink.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_fmt(v.comments)} ${l.fypCommentsTitle}',
                            style: BgFonts.display(
                              size: 15,
                              weight: FontWeight.w700,
                              color: palette.ink,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: onClose,
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: palette.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: palette.cardBorder),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: _comments.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (_, i) =>
                          _CommentRow(c: _comments[i], l: l, palette: palette),
                    ),
                  ),
                  Container(height: 1, color: palette.cardBorder),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 22),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: palette.orangeSoft,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'A',
                            style: BgFonts.display(
                              size: 12,
                              weight: FontWeight.w700,
                              color: palette.orangeDeep,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: palette.card,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: palette.cardBorder),
                            ),
                            child: Text(
                              l.fypCommentPlaceholder,
                              style: BgFonts.body(
                                size: 13,
                                color: palette.inkMuted,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: palette.orange,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            l.fypSend,
                            style: BgFonts.body(
                              size: 12,
                              weight: FontWeight.w700,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CommentRow extends StatelessWidget {
  final _Comment c;
  final L l;
  final BgPalette palette;
  const _CommentRow({required this.c, required this.l, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: c.verified
                ? palette.orange
                : palette.ink.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            c.avatar,
            style: BgFonts.display(
              size: 13,
              weight: FontWeight.w700,
              color: c.verified ? Colors.white : palette.ink,
              height: 1,
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
                  Flexible(
                    child: Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BgFonts.body(
                        size: 12,
                        weight: FontWeight.w600,
                        color: palette.ink,
                      ),
                    ),
                  ),
                  if (c.verified) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.verified, size: 12, color: palette.orange),
                  ],
                  const SizedBox(width: 5),
                  Text(
                    '· ${c.when}',
                    style: BgFonts.body(size: 12, color: palette.inkMuted),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                c.text,
                style: BgFonts.body(
                  size: 13,
                  color: palette.ink,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    l.fypReply,
                    style: BgFonts.body(size: 11, color: palette.inkMuted),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '· ${c.likes} ❤',
                    style: BgFonts.body(size: 11, color: palette.inkMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.favorite_border, size: 14, color: palette.inkMuted),
      ],
    );
  }
}
