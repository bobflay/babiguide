import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

import '../app_state.dart';
import '../i18n.dart';
import '../theme.dart';

/// Result of the cover editor: the chosen timestamp (ms) and a JPEG file
/// containing the rendered frame at that timestamp.
class CoverFrame {
  final int positionMs;
  final File jpegFile;
  final int durationMs;
  const CoverFrame({
    required this.positionMs,
    required this.jpegFile,
    required this.durationMs,
  });
}

/// Full-screen cover-frame picker. The user scrubs the timeline to a frame,
/// the preview snaps to it, and Done returns a [CoverFrame] with the JPEG
/// the caller will include in the upload as the video's thumbnail.
class CoverEditor extends StatefulWidget {
  final String videoPath;
  final int? initialMs;
  final int? trimStartMs;
  final int? trimEndMs;
  static const int kThumbCount = 10;

  const CoverEditor({
    super.key,
    required this.videoPath,
    this.initialMs,
    this.trimStartMs,
    this.trimEndMs,
  });

  @override
  State<CoverEditor> createState() => _CoverEditorState();
}

class _CoverEditorState extends State<CoverEditor> {
  VideoPlayerController? _ctl;
  bool _initializing = true;
  String? _initError;
  bool _exporting = false;
  int _durationMs = 0;
  int _windowStartMs = 0;
  int _windowEndMs = 0;
  int _positionMs = 0;
  final List<File?> _thumbs =
      List<File?>.filled(CoverEditor.kThumbCount, null);

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
      final ws = (widget.trimStartMs ?? 0).clamp(0, dur);
      final we = (widget.trimEndMs ?? dur).clamp(ws + 100, dur);
      final initial =
          (widget.initialMs ?? ws).clamp(ws, we);
      await ctl.seekTo(Duration(milliseconds: initial));
      await ctl.pause();
      if (!mounted) {
        await ctl.dispose();
        return;
      }
      setState(() {
        _ctl = ctl;
        _durationMs = dur;
        _windowStartMs = ws;
        _windowEndMs = we;
        _positionMs = initial;
        _initializing = false;
      });
      _generateThumbs();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initError = e.toString();
        _initializing = false;
      });
    }
  }

  Future<void> _generateThumbs() async {
    final span = (_windowEndMs - _windowStartMs).clamp(1, _durationMs);
    for (var i = 0; i < CoverEditor.kThumbCount; i++) {
      final pos =
          (_windowStartMs + span * i ~/ CoverEditor.kThumbCount).toInt();
      try {
        final file = await VideoCompress.getFileThumbnail(
          widget.videoPath,
          quality: 50,
          position: pos,
        );
        if (!mounted) return;
        setState(() => _thumbs[i] = file);
      } catch (_) {
        // Skip on failure; placeholder block fills in.
      }
    }
  }

  void _setPosition(int ms) {
    final clamped = ms.clamp(_windowStartMs, _windowEndMs);
    if (clamped == _positionMs) return;
    setState(() => _positionMs = clamped);
    _ctl?.seekTo(Duration(milliseconds: clamped));
  }

  Future<void> _done() async {
    if (_exporting || _ctl == null) return;
    setState(() => _exporting = true);
    try {
      final file = await VideoCompress.getFileThumbnail(
        widget.videoPath,
        quality: 80,
        position: _positionMs,
      );
      if (!mounted) return;
      Navigator.of(context).pop<CoverFrame>(CoverFrame(
        positionMs: _positionMs,
        jpegFile: file,
        durationMs: _durationMs,
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L(AppScope.of(context).lang).pick(
            "Échec de l'extraction de la miniature.",
            'Could not extract the cover frame.')),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  String _fmt(int ms) {
    final s = ms ~/ 1000;
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  void dispose() {
    _ctl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L(AppScope.of(context).lang);
    return Material(
      color: const Color(0xFF0E0805),
      child: SafeArea(
        child: Column(
          children: [
            _Header(
              l: l,
              onCancel: () => Navigator.of(context).pop(),
              onDone: _ctl == null ? null : _done,
              busy: _exporting,
            ),
            Expanded(child: _buildPreview(l)),
            if (_ctl != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${l.pick('Miniature à', 'Cover at')} ${_fmt(_positionMs)}',
                  style: BgFonts.mono(
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: _Timeline(
                  thumbs: _thumbs,
                  windowStartMs: _windowStartMs,
                  windowEndMs: _windowEndMs,
                  positionMs: _positionMs,
                  onChanged: _setPosition,
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
  final bool busy;
  const _Header({
    required this.l,
    required this.onCancel,
    this.onDone,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: busy ? null : onCancel,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.close,
                  color: Colors.white, size: 18),
            ),
          ),
          Text(
            l.pick('Miniature', 'Cover'),
            style: BgFonts.display(
              size: 16,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          GestureDetector(
            onTap: busy ? null : onDone,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF37221).withValues(
                    alpha: (onDone == null || busy) ? 0.5 : 1.0),
                borderRadius: BorderRadius.circular(999),
              ),
              child: busy
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

class _Timeline extends StatelessWidget {
  final List<File?> thumbs;
  final int windowStartMs;
  final int windowEndMs;
  final int positionMs;
  final ValueChanged<int> onChanged;

  const _Timeline({
    required this.thumbs,
    required this.windowStartMs,
    required this.windowEndMs,
    required this.positionMs,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final w = c.maxWidth;
        const handleW = 14.0;
        final innerW = (w - handleW * 2).clamp(1.0, double.infinity);
        final span = (windowEndMs - windowStartMs).clamp(1, 1 << 31);
        final frac = ((positionMs - windowStartMs) / span).clamp(0.0, 1.0);
        final px = frac * innerW;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) {
            final newPx = (px + d.delta.dx).clamp(0.0, innerW);
            final ms = windowStartMs + (newPx / innerW * span).round();
            onChanged(ms);
          },
          onTapDown: (d) {
            final newPx = (d.localPosition.dx - handleW).clamp(0.0, innerW);
            final ms = windowStartMs + (newPx / innerW * span).round();
            onChanged(ms);
          },
          child: SizedBox(
            height: 60,
            width: w,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      children: List.generate(thumbs.length, (i) {
                        final f = thumbs[i];
                        return Expanded(
                          child: f != null
                              ? Image.file(f, fit: BoxFit.cover)
                              : Container(color: const Color(0xFF2A1A0E)),
                        );
                      }),
                    ),
                  ),
                ),
                // Position indicator (single needle).
                Positioned(
                  left: px + handleW - 1,
                  top: -4,
                  bottom: -4,
                  width: 4,
                  child: const _PositionIndicator(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PositionIndicator extends StatelessWidget {
  const _PositionIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF37221),
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}
