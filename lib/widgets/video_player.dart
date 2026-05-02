import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class BgVideoPlayer extends StatefulWidget {
  final String url;
  final String? posterUrl;
  final BorderRadius? borderRadius;
  final bool autoPlay;
  final BoxFit fit;

  const BgVideoPlayer({
    super.key,
    required this.url,
    this.posterUrl,
    this.borderRadius,
    this.autoPlay = false,
    this.fit = BoxFit.contain,
  });

  @override
  State<BgVideoPlayer> createState() => _BgVideoPlayerState();
}

class _BgVideoPlayerState extends State<BgVideoPlayer> {
  Player? _player;
  VideoController? _controller;
  bool _started = false;
  bool _initializing = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (widget.autoPlay) _start();
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_initializing || _started) return;
    setState(() {
      _initializing = true;
      _error = null;
    });
    try {
      final player = Player();
      final controller = VideoController(player);
      await player.open(Media(widget.url));
      if (!mounted) {
        await player.dispose();
        return;
      }
      setState(() {
        _player = player;
        _controller = controller;
        _started = true;
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _initializing = false;
      });
    }
  }

  Widget _wrap(Widget child) {
    if (widget.borderRadius == null) return child;
    return ClipRRect(borderRadius: widget.borderRadius!, child: child);
  }

  @override
  Widget build(BuildContext context) {
    if (_started && _controller != null) {
      return _wrap(
        Container(
          color: Colors.black,
          child: Video(
            controller: _controller!,
            controls: AdaptiveVideoControls,
            fit: widget.fit,
          ),
        ),
      );
    }
    return _wrap(
      Stack(
        fit: StackFit.expand,
        children: [
          if (widget.posterUrl != null)
            Image.network(
              widget.posterUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Container(color: Colors.black),
            )
          else
            Container(color: Colors.black),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
              ),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: _initializing ? null : _start,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7),
                    width: 2,
                  ),
                ),
                child: _initializing
                    ? const Padding(
                        padding: EdgeInsets.all(18),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.play_arrow,
                        size: 32, color: Colors.white),
              ),
            ),
          ),
          if (_error != null)
            const Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Text(
                'Could not load video',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
