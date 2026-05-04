import 'dart:async';
import 'package:flutter/material.dart';
import '../api/api_error.dart';
import '../api/chat_api.dart';
import '../app_state.dart';
import '../i18n.dart';
import '../theme.dart';

const int _kMessageMaxChars = 2000;

class _PendingMessage {
  final String tempId;
  final String content;
  bool failed = false;
  _PendingMessage(this.tempId, this.content);
}

class ChatScreen extends StatefulWidget {
  final String slug;
  final String? placeName;
  final VoidCallback? onBack;

  const ChatScreen({
    super.key,
    required this.slug,
    this.placeName,
    this.onBack,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final List<_PendingMessage> _pending = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();

  bool _loadingHistory = true;
  bool _sending = false;
  Object? _historyError;
  int _tempCounter = 0;

  @override
  void initState() {
    super.initState();
    _input.addListener(_onInputChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
  }

  @override
  void dispose() {
    _input.removeListener(_onInputChanged);
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadHistory() async {
    final api = AppScope.of(context).chatApi;
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      final page = await api.getHistory(widget.slug, limit: 50);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(page.items);
        _loadingHistory = false;
      });
      _scrollToBottom(animated: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _historyError = e;
        _loadingHistory = false;
      });
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (animated) {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  Future<void> _send({String? overrideText, String? retryTempId}) async {
    if (_sending) return;
    final raw = (overrideText ?? _input.text).trim();
    if (raw.isEmpty) return;

    final l = L(AppScope.of(context).lang);
    if (raw.length > _kMessageMaxChars) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.chatTooLong(_kMessageMaxChars)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final tempId = retryTempId ?? 'tmp_${++_tempCounter}';
    setState(() {
      if (retryTempId != null) {
        final existing =
            _pending.firstWhere((p) => p.tempId == retryTempId);
        existing.failed = false;
      } else {
        _pending.add(_PendingMessage(tempId, raw));
        _input.clear();
      }
      _sending = true;
    });
    _scrollToBottom();

    final api = AppScope.of(context).chatApi;
    try {
      final reply = await api.sendMessage(widget.slug, raw);
      if (!mounted) return;
      setState(() {
        _pending.removeWhere((p) => p.tempId == tempId);
        // Persist user-side message in the visible list as well so the order
        // is preserved across an eventual reload.
        _messages.add(ChatMessage(
          id: 'local_user_$tempId',
          role: 'user',
          content: raw,
          createdAt: DateTime.now(),
        ));
        _messages.add(reply);
        _sending = false;
      });
      _scrollToBottom();
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        final p = _pending.firstWhere(
          (p) => p.tempId == tempId,
          orElse: () => _PendingMessage(tempId, raw),
        );
        p.failed = true;
        if (!_pending.contains(p)) _pending.add(p);
        _sending = false;
      });
      _showErrorSnack(e);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        for (final p in _pending) {
          if (p.tempId == tempId) p.failed = true;
        }
        _sending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.chatUnavailable),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showErrorSnack(ApiError e) {
    final l = L(AppScope.of(context).lang);
    String msg;
    if (e.status == 429) {
      msg = l.chatRateLimited;
    } else if (e.status == 502) {
      msg = l.chatUnavailable;
    } else if (e.status == 422) {
      msg = e.firstFieldError('message') ?? e.message;
    } else {
      msg = e.message;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmClear() async {
    final state = AppScope.of(context);
    final l = L(state.lang);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.chatClearConfirm),
        content: Text(l.chatClearConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.pick('Effacer', 'Clear')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await state.chatApi.clearHistory(widget.slug);
      if (!mounted) return;
      setState(() {
        _messages.clear();
        _pending.clear();
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      _showErrorSnack(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.palette;
    final l = L(state.lang);
    final hasContent = _messages.isNotEmpty || _pending.isNotEmpty;

    return Container(
      color: p.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ChatHeader(
              p: p,
              l: l,
              title: widget.placeName ?? l.chatTitle,
              subtitle: l.chatSubtitle,
              onBack: widget.onBack,
              onClear: hasContent && !_loadingHistory ? _confirmClear : null,
            ),
            Expanded(
              child: _loadingHistory
                  ? Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(p.orange),
                        ),
                      ),
                    )
                  : _historyError != null
                      ? _ChatError(
                          error: _historyError,
                          onRetry: _loadHistory,
                          l: l,
                          p: p,
                        )
                      : _buildThread(p, l),
            ),
            _ChatInput(
              p: p,
              l: l,
              controller: _input,
              focusNode: _focus,
              sending: _sending,
              canSend: !_sending && _input.text.trim().isNotEmpty,
              onSend: () => _send(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThread(BgPalette p, L l) {
    if (_messages.isEmpty && _pending.isEmpty) {
      return _ChatEmpty(
        p: p,
        l: l,
        suggestions: l.chatSuggestions,
        onPick: (s) {
          _input.text = s;
          _input.selection = TextSelection.collapsed(offset: s.length);
          _send(overrideText: s);
        },
      );
    }
    final tiles = <Widget>[];
    for (final m in _messages) {
      tiles.add(_MessageBubble(message: m, p: p));
    }
    for (final pending in _pending) {
      tiles.add(_PendingBubble(
        pending: pending,
        p: p,
        l: l,
        onRetry: () => _send(
          overrideText: pending.content,
          retryTempId: pending.tempId,
        ),
      ));
    }
    if (_sending) {
      tiles.add(_TypingBubble(p: p, l: l));
    }
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: tiles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => tiles[i],
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final BgPalette p;
  final L l;
  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final VoidCallback? onClear;

  const _ChatHeader({
    required this.p,
    required this.l,
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
      decoration: BoxDecoration(
        color: p.bg,
        border: Border(bottom: BorderSide(color: p.cardBorder)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(Icons.chevron_left, color: p.ink, size: 24),
            splashRadius: 22,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BgFonts.display(
                    size: 16,
                    weight: FontWeight.w700,
                    color: p.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: p.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      subtitle,
                      style: BgFonts.body(size: 11, color: p.inkMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onClear != null)
            IconButton(
              tooltip: l.chatClear,
              onPressed: onClear,
              icon: Icon(Icons.delete_outline, color: p.inkMuted, size: 20),
              splashRadius: 20,
            ),
        ],
      ),
    );
  }
}

class _ChatEmpty extends StatelessWidget {
  final BgPalette p;
  final L l;
  final List<String> suggestions;
  final ValueChanged<String> onPick;

  const _ChatEmpty({
    required this.p,
    required this.l,
    required this.suggestions,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: p.orangeSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome, color: p.orangeDeep, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            l.chatEmptyTitle,
            textAlign: TextAlign.center,
            style: BgFonts.display(
              size: 20,
              weight: FontWeight.w700,
              color: p.ink,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.chatEmptyBody,
            textAlign: TextAlign.center,
            style: BgFonts.body(size: 13, color: p.inkMuted, height: 1.5),
          ),
          const SizedBox(height: 24),
          for (final s in suggestions) ...[
            _SuggestionChip(label: s, onTap: () => onPick(s), p: p),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final BgPalette p;
  const _SuggestionChip({
    required this.label,
    required this.onTap,
    required this.p,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.cardBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: BgFonts.body(size: 13, color: p.ink, height: 1.3),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_outward, size: 14, color: p.inkMuted),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final BgPalette p;
  const _MessageBubble({required this.message, required this.p});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final fg = isUser ? Colors.white : p.ink;
    final base = BgFonts.body(size: 14, color: fg, height: 1.45);
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isUser ? p.orange : p.card,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            border: isUser ? null : Border.all(color: p.cardBorder),
          ),
          child: isUser
              ? Text(message.content, style: base)
              : _MarkdownText(text: message.content, baseStyle: base),
        ),
      ),
    );
  }
}

/// Lightweight renderer for the small subset of Markdown the chat assistant
/// actually produces: **bold**, paragraph breaks, and `-`/`*`/`•` bullet
/// lists. Anything else falls through as plain text.
class _MarkdownText extends StatelessWidget {
  final String text;
  final TextStyle baseStyle;
  const _MarkdownText({required this.text, required this.baseStyle});

  static final _bulletRe = RegExp(r'^\s*(?:[-*•]|\d+\.)\s+');

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final blocks = <Widget>[];
    var paragraph = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      blocks.add(Text.rich(
        _buildInline(paragraph.join('\n'), baseStyle),
      ));
      paragraph = [];
    }

    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.isEmpty) {
        flushParagraph();
        continue;
      }
      final m = _bulletRe.firstMatch(line);
      if (m != null) {
        flushParagraph();
        final body = line.substring(m.end);
        blocks.add(_BulletLine(text: body, baseStyle: baseStyle));
        continue;
      }
      paragraph.add(line);
    }
    flushParagraph();

    if (blocks.length == 1) return blocks.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          blocks[i],
        ],
      ],
    );
  }
}

class _BulletLine extends StatelessWidget {
  final String text;
  final TextStyle baseStyle;
  const _BulletLine({required this.text, required this.baseStyle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('•', style: baseStyle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(_buildInline(text, baseStyle)),
          ),
        ],
      ),
    );
  }
}

/// Tokenizes inline Markdown for the chat: `**bold**` toggles bold,
/// `*italic*` toggles italic, `` `code` `` toggles monospace. Stray markers
/// without a matching close are emitted as plain text.
TextSpan _buildInline(String text, TextStyle base) {
  final spans = <TextSpan>[];
  final buf = StringBuffer();
  bool bold = false;
  bool italic = false;
  bool code = false;

  void flush() {
    if (buf.isEmpty) return;
    var style = base;
    if (bold) style = style.copyWith(fontWeight: FontWeight.w700);
    if (italic) style = style.copyWith(fontStyle: FontStyle.italic);
    if (code) {
      style = style.copyWith(
        fontFamily: 'monospace',
        fontFeatures: const [FontFeature.tabularFigures()],
      );
    }
    spans.add(TextSpan(text: buf.toString(), style: style));
    buf.clear();
  }

  int i = 0;
  while (i < text.length) {
    final two = i + 1 < text.length ? text.substring(i, i + 2) : '';
    if (two == '**') {
      flush();
      bold = !bold;
      i += 2;
      continue;
    }
    final ch = text[i];
    if (ch == '`') {
      flush();
      code = !code;
      i += 1;
      continue;
    }
    if (ch == '*' || ch == '_') {
      // Treat single `*` / `_` as italic only when adjacent to a word char on
      // the inside, to avoid mangling things like "F.CFA *" or measurements.
      final prev = i > 0 ? text[i - 1] : ' ';
      final next = i + 1 < text.length ? text[i + 1] : ' ';
      final opening = !italic && next.trim().isNotEmpty && next != '*';
      final closing = italic && prev.trim().isNotEmpty;
      if (opening || closing) {
        flush();
        italic = !italic;
        i += 1;
        continue;
      }
    }
    buf.write(ch);
    i += 1;
  }
  flush();
  return TextSpan(children: spans);
}

class _PendingBubble extends StatelessWidget {
  final _PendingMessage pending;
  final BgPalette p;
  final L l;
  final VoidCallback onRetry;

  const _PendingBubble({
    required this.pending,
    required this.p,
    required this.l,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Opacity(
              opacity: pending.failed ? 0.7 : 0.85,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: p.orange,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Text(
                  pending.content,
                  style: BgFonts.body(
                    size: 14,
                    color: Colors.white,
                    height: 1.45,
                  ),
                ),
              ),
            ),
            if (pending.failed)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 4),
                child: GestureDetector(
                  onTap: onRetry,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, size: 12, color: p.orangeDeep),
                      const SizedBox(width: 4),
                      Text(
                        l.chatRetry,
                        style: BgFonts.body(
                          size: 11,
                          weight: FontWeight.w600,
                          color: p.orangeDeep,
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

class _TypingBubble extends StatefulWidget {
  final BgPalette p;
  final L l;
  const _TypingBubble({required this.p, required this.l});

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: p.cardBorder),
        ),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  _Dot(phase: (_ctrl.value + i / 3) % 1.0, color: p.inkMuted),
                  if (i < 2) const SizedBox(width: 4),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final double phase;
  final Color color;
  const _Dot({required this.phase, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = (phase * 2) % 2.0;
    final eased = t < 1 ? t : 2 - t;
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.35 + 0.55 * eased),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ChatError extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;
  final L l;
  final BgPalette p;
  const _ChatError({
    required this.error,
    required this.onRetry,
    required this.l,
    required this.p,
  });

  @override
  Widget build(BuildContext context) {
    final msg = error is ApiError
        ? (error as ApiError).message
        : l.pick('Impossible de charger la conversation.',
            'Could not load the conversation.');
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 32, color: p.inkMuted),
            const SizedBox(height: 10),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: BgFonts.body(size: 13, color: p.ink, height: 1.4),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: p.orange,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l.pick('Réessayer', 'Retry'),
                  style: BgFonts.body(
                    size: 12,
                    weight: FontWeight.w700,
                    color: Colors.white,
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

class _ChatInput extends StatelessWidget {
  final BgPalette p;
  final L l;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final bool canSend;
  final VoidCallback onSend;

  const _ChatInput({
    required this.p,
    required this.l,
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.canSend,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomPad),
        decoration: BoxDecoration(
          color: p.bg,
          border: Border(top: BorderSide(color: p.cardBorder)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 44, maxHeight: 140),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: p.cardBorder),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  maxLines: 5,
                  minLines: 1,
                  maxLength: _kMessageMaxChars,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    counterText: '',
                    hintText: l.chatInputHint,
                    hintStyle: BgFonts.body(size: 14, color: p.inkMuted),
                  ),
                  style: BgFonts.body(size: 14, color: p.ink, height: 1.35),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: canSend ? onSend : null,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: canSend ? p.orange : p.cardBorder,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: sending
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        Icons.arrow_upward,
                        size: 18,
                        color: canSend ? Colors.white : p.inkMuted,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
