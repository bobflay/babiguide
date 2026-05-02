import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

import '../app_state.dart';
import '../i18n.dart';
import '../theme.dart';

/// Inclusive trim window in milliseconds, plus the source duration so the
/// caller can decide whether the user's selection actually changed.
class TrimWindow {
  final int startMs;
  final int endMs;
  final int durationMs;
  const TrimWindow({
    required this.startMs,
    required this.endMs,
    required this.durationMs,
  });

  bool get isFullClip => startMs == 0 && endMs >= durationMs;

  Duration get start => Duration(milliseconds: startMs);
  Duration get duration => Duration(milliseconds: endMs - startMs);
}

/// Full-screen trim editor: live preview, frame-thumbnail timeline, two
/// draggable handles bounding the kept window. Returns a [TrimWindow] on
/// Done, or `null` on Cancel.
class TrimEditor extends StatefulWidget {
  final String videoPath;
  final TrimWindow? initial;
  static const int kThumbCount = 10;
  static const int kMinWindowMs = 1000;

  const TrimEditor({
    super.key,
    required this.videoPath,
    this.initial,
  });

  @override
  State<TrimEditor> createState() => _TrimEditorState();
}

class _TrimEditorState extends State<TrimEditor> {
  VideoPlayerController? _ctl;
  bool _initializing = true;
  String? _initError;
  int _durationMs = 0;
  int _startMs = 0;
  int _endMs = 0;
  final List<File?> _thumbs =
      List<File?>.filled(TrimEditor.kThumbCount, null);
  bool _ctlListenerAttached = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ctl = VideoPlayerController.file(File(widget.videoPath));
      await ctl.initialize();
      await ctl.setLooping(false);
      final dur = ctl.value.duration.inMilliseconds;
      final start = widget.initial?.startMs.clamp(0, dur) ?? 0;
      final end = widget.initial?.endMs.clamp(start + TrimEditor.kMinWindowMs,
              dur) ??
          dur;
      await ctl.seekTo(Duration(milliseconds: start));
      ctl.addListener(_onTick);
      _ctlListenerAttached = true;
      if (!mounted) {
        await ctl.dispose();
        return;
      }
      setState(() {
        _ctl = ctl;
        _durationMs = dur;
        _startMs = start;
        _endMs = end;
        _initializing = false;
      });
      _generateThumbs();
      // Auto-play the trimmed window so the user previews their selection.
      await ctl.play();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initError = e.toString();
        _initializing = false;
      });
    }
  }

  Future<void> _generateThumbs() async {
    if (_durationMs <= 0) return;
    // Scatter thumbnail extraction across the timeline. Each call writes a
    // tmp file under the platform tmp dir.
    for (var i = 0; i < TrimEditor.kThumbCount; i++) {
      final pos = (_durationMs * i ~/ TrimEditor.kThumbCount).toInt();
      try {
        final file = await VideoCompress.getFileThumbnail(
          widget.videoPath,
          quality: 50,
          position: pos,
        );
        if (!mounted) return;
        setState(() {
          _thumbs[i] = file;
        });
      } catch (_) {
        // Skip this thumb; the strip will show a placeholder for it.
      }
    }
  }

  void _onTick() {
    final ctl = _ctl;
    if (ctl == null || !ctl.value.isInitialized) return;
    final pos = ctl.value.position.inMilliseconds;
    // Loop the [start, end] window so the user can preview it.
    if (pos >= _endMs - 16) {
      ctl.seekTo(Duration(milliseconds: _startMs));
      if (!ctl.value.isPlaying) ctl.play();
    } else if (pos < _startMs - 16) {
      ctl.seekTo(Duration(milliseconds: _startMs));
    }
  }

  @override
  void dispose() {
    final ctl = _ctl;
    if (ctl != null && _ctlListenerAttached) {
      ctl.removeListener(_onTick);
    }
    ctl?.dispose();
    super.dispose();
  }

  void _setStart(int ms) {
    final newStart = ms.clamp(0, _endMs - TrimEditor.kMinWindowMs);
    if (newStart == _startMs) return;
    setState(() => _startMs = newStart);
    _ctl?.seekTo(Duration(milliseconds: newStart));
  }

  void _setEnd(int ms) {
    final newEnd = ms.clamp(_startMs + TrimEditor.kMinWindowMs, _durationMs);
    if (newEnd == _endMs) return;
    setState(() => _endMs = newEnd);
  }

  String _fmt(int ms) {
    final s = (ms ~/ 1000);
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  String _fmtDuration() {
    final s = ((_endMs - _startMs) / 1000).toStringAsFixed(
        ((_endMs - _startMs) % 1000) == 0 ? 0 : 1);
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final l = L(AppScope.of(context).lang);
    final ctl = _ctl;
    return Material(
      color: const Color(0xFF0E0805),
      child: SafeArea(
        child: Column(
          children: [
            _Header(
              l: l,
              onCancel: () => Navigator.of(context).pop(),
              onDone: ctl == null
                  ? null
                  : () => Navigator.of(context).pop<TrimWindow>(
                        TrimWindow(
                          startMs: _startMs,
                          endMs: _endMs,
                          durationMs: _durationMs,
                        ),
                      ),
            ),
            Expanded(child: _buildPreview(l)),
            if (ctl != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${_fmt(_startMs)} → ${_fmt(_endMs)} · ${_fmtDuration()}',
                      style: BgFonts.mono(
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: _Timeline(
                  thumbs: _thumbs,
                  durationMs: _durationMs,
                  startMs: _startMs,
                  endMs: _endMs,
                  onStart: _setStart,
                  onEnd: _setEnd,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(L l) {
    if (_initializing) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF37221)),
          ),
        ),
      );
    }
    if (_initError != null || _ctl == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            l.pick("Vidéo illisible.", 'Could not read this video.'),
            textAlign: TextAlign.center,
            style: BgFonts.body(size: 13, color: Colors.white70),
          ),
        ),
      );
    }
    final c = _ctl!;
    return Center(
      child: AspectRatio(
        aspectRatio: c.value.aspectRatio,
        child: VideoPlayer(c),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final L l;
  final VoidCallback onCancel;
  final VoidCallback? onDone;
  const _Header({required this.l, required this.onCancel, this.onDone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: onCancel,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
          Text(
            l.pick('Couper', 'Trim'),
            style: BgFonts.display(
              size: 16,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          GestureDetector(
            onTap: onDone,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF37221).withValues(
                    alpha: onDone == null ? 0.5 : 1.0),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                l.pick('Terminé', 'Done'),
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

class _Timeline extends StatefulWidget {
  final List<File?> thumbs;
  final int durationMs;
  final int startMs;
  final int endMs;
  final ValueChanged<int> onStart;
  final ValueChanged<int> onEnd;

  const _Timeline({
    required this.thumbs,
    required this.durationMs,
    required this.startMs,
    required this.endMs,
    required this.onStart,
    required this.onEnd,
  });

  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> {
  static const double _handleW = 14;
  static const double _stripH = 60;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final w = c.maxWidth;
        // Inner content width subtracts both handles.
        final innerW = (w - _handleW * 2).clamp(1.0, double.infinity);
        final fracStart = widget.durationMs == 0
            ? 0.0
            : widget.startMs / widget.durationMs;
        final fracEnd = widget.durationMs == 0
            ? 1.0
            : widget.endMs / widget.durationMs;
        final leftPx = fracStart * innerW;
        final rightPx = fracEnd * innerW;
        return SizedBox(
          height: _stripH,
          width: w,
          child: Stack(
            children: [
              // Frame strip.
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: List.generate(widget.thumbs.length, (i) {
                      final f = widget.thumbs[i];
                      return Expanded(
                        child: f != null
                            ? Image.file(f, fit: BoxFit.cover)
                            : Container(
                                color: const Color(0xFF2A1A0E),
                              ),
                      );
                    }),
                  ),
                ),
              ),
              // Left dim mask (before window).
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _handleW + leftPx,
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
              ),
              // Right dim mask (after window).
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: _handleW + (innerW - rightPx),
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
              ),
              // Window border.
              Positioned(
                left: leftPx + _handleW / 2,
                width:
                    (rightPx - leftPx + _handleW).clamp(0.0, w),
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.symmetric(
                        horizontal: BorderSide(
                          color: const Color(0xFFF37221),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Start handle.
              Positioned(
                left: leftPx,
                top: 0,
                bottom: 0,
                width: _handleW,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (d) {
                    final newPx =
                        (leftPx + d.delta.dx).clamp(0.0, rightPx - 4);
                    final ms = (newPx / innerW * widget.durationMs).round();
                    widget.onStart(ms);
                  },
                  child: const _Handle(side: _HandleSide.start),
                ),
              ),
              // End handle.
              Positioned(
                left: rightPx + _handleW,
                top: 0,
                bottom: 0,
                width: _handleW,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (d) {
                    final newPx =
                        (rightPx + d.delta.dx).clamp(leftPx + 4, innerW);
                    final ms = (newPx / innerW * widget.durationMs).round();
                    widget.onEnd(ms);
                  },
                  child: const _Handle(side: _HandleSide.end),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _HandleSide { start, end }

class _Handle extends StatelessWidget {
  final _HandleSide side;
  const _Handle({required this.side});

  @override
  Widget build(BuildContext context) {
    final radius = side == _HandleSide.start
        ? const BorderRadius.only(
            topLeft: Radius.circular(8),
            bottomLeft: Radius.circular(8),
          )
        : const BorderRadius.only(
            topRight: Radius.circular(8),
            bottomRight: Radius.circular(8),
          );
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF37221),
        borderRadius: radius,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 2,
        height: 18,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
