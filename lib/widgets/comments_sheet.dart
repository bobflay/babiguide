import 'package:flutter/material.dart';

import '../api/api_error.dart';
import '../api/media_social_api.dart';
import '../app_state.dart';
import '../i18n.dart';
import '../theme.dart';

/// Bottom sheet that lists, paginates, posts and deletes comments for a single
/// media item. Caller passes in the media id (prefixed `m123` or bare `123`)
/// and an optional starting count; the sheet returns the latest count via
/// [onCountChanged] so the parent screen can update its overlay badge.
///
/// The sheet itself decides whether to require auth (post + delete are
/// auth-only); when an unauthenticated user taps the input, [onRequireAuth]
/// is invoked so the parent can route to the auth screen.
class CommentsSheet extends StatefulWidget {
  final String mediaId;
  final int initialCount;
  final ValueChanged<int>? onCountChanged;
  final VoidCallback? onRequireAuth;

  const CommentsSheet({
    super.key,
    required this.mediaId,
    this.initialCount = 0,
    this.onCountChanged,
    this.onRequireAuth,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final List<MediaComment> _items = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  String? _nextCursor;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _posting = false;
  Object? _error;
  late int _count;

  @override
  void initState() {
    super.initState();
    _count = widget.initialCount;
    _scroll.addListener(_maybeLoadMore);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final api = AppScope.of(context).mediaSocialApi;
    setState(() {
      _loadingInitial = true;
      _error = null;
    });
    try {
      final page = await api.getComments(widget.mediaId, limit: 20);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _nextCursor = page.nextCursor;
        _count = page.total;
        _loadingInitial = false;
      });
      widget.onCountChanged?.call(_count);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loadingInitial = false;
      });
    }
  }

  void _maybeLoadMore() {
    if (_loadingMore || _nextCursor == null) return;
    if (_scroll.position.pixels <
        _scroll.position.maxScrollExtent - 200) {
      return;
    }
    _loadMore();
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore) return;
    final api = AppScope.of(context).mediaSocialApi;
    setState(() => _loadingMore = true);
    try {
      final page = await api.getComments(
        widget.mediaId,
        page: int.tryParse(cursor) ?? 1,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        for (final c in page.items) {
          if (!_items.any((e) => e.id == c.id)) _items.add(c);
        }
        _nextCursor = page.nextCursor;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _post() async {
    final text = _input.text.trim();
    if (text.isEmpty || _posting) return;
    final state = AppScope.of(context);
    if (!state.isSignedIn) {
      Navigator.of(context).pop();
      widget.onRequireAuth?.call();
      return;
    }
    setState(() => _posting = true);
    try {
      final res =
          await state.mediaSocialApi.postComment(widget.mediaId, text: text);
      if (!mounted) return;
      setState(() {
        _items.insert(0, res.comment);
        _count = res.commentsCount;
        _input.clear();
        _posting = false;
      });
      widget.onCountChanged?.call(_count);
      FocusScope.of(context).unfocus();
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _posting = false);
      final msg = e.firstFieldError('text') ?? e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _posting = false);
    }
  }

  Future<void> _delete(MediaComment c) async {
    final deleteId = c.deleteId;
    if (deleteId == null || deleteId.isEmpty) return;
    final state = AppScope.of(context);
    final l = L(state.lang);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.pick('Supprimer ce commentaire ?',
            'Delete this comment?')),
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
    final originalIndex = _items.indexOf(c);
    setState(() {
      _items.removeWhere((e) => e.id == c.id);
      _count = (_count - 1).clamp(0, 1 << 31);
    });
    widget.onCountChanged?.call(_count);
    try {
      final newCount =
          await state.mediaSocialApi.deleteComment(widget.mediaId, deleteId);
      if (!mounted) return;
      setState(() => _count = newCount);
      widget.onCountChanged?.call(newCount);
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        if (originalIndex >= 0 && originalIndex <= _items.length) {
          _items.insert(originalIndex.clamp(0, _items.length), c);
        }
        _count += 1;
      });
      widget.onCountChanged?.call(_count);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.palette;
    final l = L(state.lang);
    final mq = MediaQuery.of(context);
    final myUserId = state.user?.id;
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: mq.size.height * 0.78,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: p.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Text(
                      l.fypCommentsTitle,
                      style: BgFonts.display(
                        size: 16,
                        weight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _count > 0 ? '· $_count' : '',
                      style: BgFonts.body(
                        size: 13,
                        color: p.inkMuted,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(Icons.close, size: 20, color: p.inkMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Divider(height: 1, color: p.cardBorder),
              Expanded(
                child: _buildList(p, l, myUserId),
              ),
              Divider(height: 1, color: p.cardBorder),
              _Composer(
                controller: _input,
                palette: p,
                hint: l.fypCommentPlaceholder,
                sendLabel: l.fypSend,
                posting: _posting,
                onSend: _post,
                onTap: () {
                  if (!state.isSignedIn) {
                    Navigator.of(context).pop();
                    widget.onRequireAuth?.call();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(BgPalette p, L l, String? myUserId) {
    if (_loadingInitial) {
      return Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(p.orange),
          ),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: p.inkMuted, size: 28),
              const SizedBox(height: 10),
              Text(
                _error is ApiError
                    ? (_error as ApiError).message
                    : l.pick('Erreur de chargement',
                        'Failed to load comments'),
                textAlign: TextAlign.center,
                style: BgFonts.body(size: 13, color: p.inkMuted),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loadInitial,
                child: Text(l.pick('Réessayer', 'Retry')),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l.pick('Soyez le premier à commenter.',
                'Be the first to comment.'),
            style: BgFonts.body(size: 13, color: p.inkMuted),
          ),
        ),
      );
    }
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _items.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (_, i) {
        if (i >= _items.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(p.orange),
                ),
              ),
            ),
          );
        }
        final c = _items[i];
        final isMine = myUserId != null && c.author.id == myUserId;
        return _CommentRow(
          comment: c,
          palette: p,
          l: l,
          canDelete: isMine,
          onDelete: isMine ? () => _delete(c) : null,
        );
      },
    );
  }
}

class _CommentRow extends StatelessWidget {
  final MediaComment comment;
  final BgPalette palette;
  final L l;
  final bool canDelete;
  final VoidCallback? onDelete;

  const _CommentRow({
    required this.comment,
    required this.palette,
    required this.l,
    required this.canDelete,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final author = comment.author;
    final initial =
        author.name.isNotEmpty ? author.name.characters.first : '?';
    final avatar = author.avatarUrl;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: palette.orangeSoft,
            shape: BoxShape.circle,
            image: (avatar != null && avatar.isNotEmpty)
                ? DecorationImage(
                    image: NetworkImage(avatar),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          alignment: Alignment.center,
          child: (avatar != null && avatar.isNotEmpty)
              ? null
              : Text(
                  initial.toUpperCase(),
                  style: BgFonts.display(
                    size: 13,
                    weight: FontWeight.w700,
                    color: palette.orangeDeep,
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
                      author.name.isNotEmpty
                          ? author.name
                          : l.pick('Anonyme', 'Anonymous'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BgFonts.body(
                        size: 13,
                        weight: FontWeight.w700,
                        color: palette.ink,
                      ),
                    ),
                  ),
                  if ((comment.when ?? '').isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      '· ${comment.when}',
                      style: BgFonts.body(size: 11, color: palette.inkMuted),
                    ),
                  ],
                  if (canDelete) ...[
                    const Spacer(),
                    GestureDetector(
                      onTap: onDelete,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        child: Icon(Icons.delete_outline,
                            size: 16, color: palette.inkMuted),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                comment.text,
                style: BgFonts.body(
                  size: 13,
                  color: palette.ink,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Composer extends StatefulWidget {
  final TextEditingController controller;
  final BgPalette palette;
  final String hint;
  final String sendLabel;
  final bool posting;
  final VoidCallback onSend;
  final VoidCallback? onTap;

  const _Composer({
    required this.controller,
    required this.palette,
    required this.hint,
    required this.sendLabel,
    required this.posting,
    required this.onSend,
    this.onTap,
  });

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final canSend =
        !widget.posting && widget.controller.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              minLines: 1,
              maxLines: 4,
              maxLength: 1000,
              onTap: widget.onTap,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle:
                    BgFonts.body(size: 13, color: p.inkMuted),
                counterText: '',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: p.bgDeep,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: p.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: p.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: p.orange),
                ),
              ),
              style: BgFonts.body(size: 13, color: p.ink),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) {
                if (canSend) widget.onSend();
              },
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: canSend ? widget.onSend : null,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: canSend
                    ? p.orange
                    : p.orange.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
              ),
              child: widget.posting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      widget.sendLabel,
                      style: BgFonts.body(
                        size: 12,
                        weight: FontWeight.w700,
                        color: Colors.white,
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

/// Convenience helper that opens the comments sheet with the project-standard
/// rounded-top styling. Returns when the sheet is dismissed.
Future<void> showCommentsSheet(
  BuildContext context, {
  required String mediaId,
  int initialCount = 0,
  ValueChanged<int>? onCountChanged,
  VoidCallback? onRequireAuth,
}) {
  final p = AppScope.of(context).palette;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: p.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => CommentsSheet(
      mediaId: mediaId,
      initialCount: initialCount,
      onCountChanged: onCountChanged,
      onRequireAuth: onRequireAuth,
    ),
  );
}
