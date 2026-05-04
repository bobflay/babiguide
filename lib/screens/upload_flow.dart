import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_error.dart';
import '../api/media_api.dart';
import '../app_state.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets/photo_placeholder.dart';
import 'upload_cover_editor.dart';
import 'upload_trim_editor.dart';

/// Three-step upload flow opened from a place's media gallery `+` button.
/// Mirrors screens 15–17 from the Claude design hand-off:
///
///   * Step 0 — Capture: dark camera viewfinder mock; tapping the record
///     button or library thumbnail invokes `image_picker` and advances.
///   * Step 1 — Edit: preview-with-overlays mock (trim/music/filters are
///     decorative — the real upload uses the unedited file).
///   * Step 2 — Publish: caption + place tag + quick ratings + hashtags +
///     audience + toggles. Tapping Publish hits `MediaApi.upload`.
///
/// On success, the flow pops with the resulting [MediaUploadResult]. The
/// caller (typically the media gallery screen) is responsible for cache
/// invalidation + reload.
class UploadFlow extends StatefulWidget {
  final String placeSlug;
  final String? placeName;
  final String? placeNeighborhood;
  final String? placeCuisine;
  final String? placePhotoUrl;
  final String? initialCategory;

  const UploadFlow({
    super.key,
    required this.placeSlug,
    this.placeName,
    this.placeNeighborhood,
    this.placeCuisine,
    this.placePhotoUrl,
    this.initialCategory,
  });

  @override
  State<UploadFlow> createState() => _UploadFlowState();
}

const List<int> _kDurations = [15, 30, 60];

/// Backend `sub` keys for the four ratings shown on the publish page,
/// indexed to match the localized labels (Plats / Service / Toilettes /
/// Ambiance). See `reviewSubKeys` in lib/constants.dart.
const List<String> _kPublishSubKeys = ['food', 'staff', 'toilet', 'ambiance'];

class _UploadFlowState extends State<UploadFlow> {
  int _step = 0;
  final Map<int, int> _stars = {0: 0, 1: 0, 2: 0, 3: 0};
  bool _publishing = false;
  XFile? _picked; // The originally captured/picked file.
  XFile? _edited; // The post-edit file we'll upload (baked photo or
  //                same as _picked for video).
  XFile? _editedThumb; // Optional cover frame for videos.
  String _kind = 'photo';
  final TextEditingController _captionCtl = TextEditingController();

  String get _draftKey => 'babiguide.upload_draft.${widget.placeSlug}';

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void dispose() {
    _captionCtl.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null) return;
      final data = jsonDecode(raw);
      if (data is! Map) return;
      final caption = data['caption']?.toString() ?? '';
      final stars = data['stars'];
      if (!mounted) return;
      setState(() {
        _captionCtl.text = caption;
        if (stars is Map) {
          for (final k in [0, 1, 2, 3]) {
            final v = stars['$k'];
            if (v is num) _stars[k] = v.toInt().clamp(0, 5);
          }
        }
      });
    } catch (_) {
      // Drafts are best-effort — bad/legacy payloads are ignored silently.
    }
  }

  Future<void> _saveDraftToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'caption': _captionCtl.text,
      'stars': {for (final e in _stars.entries) '${e.key}': e.value},
    });
    await prefs.setString(_draftKey, payload);
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  void _onCaptured(XFile file, String kind) {
    if (!mounted) return;
    setState(() {
      _picked = file;
      _edited = file;
      _kind = kind;
      _step = 1;
    });
  }

  void _onEditDone(XFile editedFile, {XFile? thumb}) {
    if (!mounted) return;
    setState(() {
      _edited = editedFile;
      _editedThumb = thumb;
      _step = 2;
    });
  }

  Future<void> _publish() async {
    final picked = _picked;
    if (picked == null || _publishing) return;
    final state = AppScope.of(context);
    final l = L(state.lang);
    if (!state.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l.pick(
            'Connectez-vous pour publier', 'Sign in to publish')),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _publishing = true);
    try {
      final thumb = _editedThumb;
      final caption = _captionCtl.text.trim();
      final media = await state.mediaApi.upload(
        file: File(picked.path),
        kind: _kind,
        placeId: widget.placeSlug,
        category: widget.initialCategory == 'all' ? null : widget.initialCategory,
        label: caption.isEmpty ? null : caption,
        thumb: thumb == null ? null : File(thumb.path),
      );
      // Submit a review whenever the user gave at least one sub-rating.
      // Otherwise treat this as a media-only upload so the user can post
      // a video without grading the place.
      final subs = <String, int>{
        for (final e in _stars.entries)
          if (e.value > 0 && e.key < _kPublishSubKeys.length)
            _kPublishSubKeys[e.key]: e.value,
      };
      if (subs.isNotEmpty) {
        final overall = (subs.values.reduce((a, b) => a + b) / subs.length)
            .round()
            .clamp(1, 5);
        await state.reviewsApi.postReview(
          widget.placeSlug,
          rating: overall,
          text: _captionCtl.text.trim(),
          sub: subs,
          tags: const [],
          mediaIds: [media.id],
        );
      }
      await _clearDraft();
      if (!mounted) return;
      Navigator.of(context).pop<MediaUploadResult>(media);
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _publishing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _publishing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l.photoUploadFailed),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _saveDraftAndExit() async {
    final messenger = ScaffoldMessenger.of(context);
    final l = L(AppScope.of(context).lang);
    await _saveDraftToPrefs();
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(l.pick('Brouillon enregistré', 'Draft saved')),
      behavior: SnackBarBehavior.floating,
    ));
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_publishing,
      child: switch (_step) {
        0 => _CaptureStep(
            placeName: widget.placeName,
            placeNeighborhood: widget.placeNeighborhood,
            placePhotoUrl: widget.placePhotoUrl,
            onCancel: () => Navigator.of(context).maybePop(),
            onCaptured: _onCaptured,
          ),
        1 => _EditStep(
            picked: _picked,
            kind: _kind,
            onBack: () => setState(() => _step = 0),
            onDone: _onEditDone,
          ),
        _ => _PublishStep(
            captionCtl: _captionCtl,
            picked: _edited ?? _picked,
            thumb: _editedThumb,
            kind: _kind,
            placeName: widget.placeName,
            placeNeighborhood: widget.placeNeighborhood,
            placePhotoUrl: widget.placePhotoUrl,
            stars: _stars,
            publishing: _publishing,
            onStarChanged: (cat, n) => setState(() => _stars[cat] = n),
            onBack: () => setState(() => _step = 1),
            onPublish: _publish,
            onSaveDraft: _saveDraftAndExit,
          ),
      },
    );
  }
}

// ─────────────────────────────────────────────
// Step 1 — Capture
// ─────────────────────────────────────────────

class _CaptureStep extends StatefulWidget {
  final String? placeName;
  final String? placeNeighborhood;
  final String? placePhotoUrl;
  final VoidCallback onCancel;
  final void Function(XFile file, String kind) onCaptured;

  const _CaptureStep({
    required this.placeName,
    required this.placeNeighborhood,
    required this.placePhotoUrl,
    required this.onCancel,
    required this.onCaptured,
  });

  @override
  State<_CaptureStep> createState() => _CaptureStepState();
}

class _CaptureStepState extends State<_CaptureStep>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _cameraIdx = 0;
  FlashMode _flashMode = FlashMode.off;
  bool _gridOn = true;
  // 0 = Photo, 1 = Video. Live (idx 2) is rendered but disabled.
  int _modeIdx = 1;
  int _durationIdx = 1;
  bool _initializing = true;
  String? _error;
  bool _isRecording = false;
  bool _capturingPhoto = false;
  Timer? _recordTimer;
  Duration _recordElapsed = Duration.zero;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Camera plugin doesn't run in widget tests / on web — skip silently
    // there so flutter test still passes.
    if (!kIsWeb) {
      _initCamera();
    } else {
      _initializing = false;
      _error = 'unsupported_platform';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Stop any in-flight recording so the file isn't truncated.
      if (_isRecording) {
        _stopRecording();
      }
      c.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    if (!mounted) return;
    setState(() {
      _initializing = true;
      _error = null;
    });
    try {
      final cams = _cameras ?? await availableCameras();
      _cameras = cams;
      if (cams.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'no_camera';
          _initializing = false;
        });
        return;
      }
      // Prefer back-facing on first init.
      if (_controller == null && _cameraIdx == 0) {
        final backIdx =
            cams.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
        if (backIdx >= 0) _cameraIdx = backIdx;
      }
      final controller = CameraController(
        cams[_cameraIdx.clamp(0, cams.length - 1)],
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      try {
        await controller.setFlashMode(_flashMode);
      } catch (_) {
        // Some devices/lenses don't support all flash modes; ignore.
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
        _error = null;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.code;
        _initializing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'unknown';
        _initializing = false;
      });
    }
  }

  Future<void> _flipCamera() async {
    final cams = _cameras;
    if (cams == null || cams.length < 2 || _isRecording) return;
    final old = _controller;
    setState(() {
      _controller = null;
      _initializing = true;
      _cameraIdx = (_cameraIdx + 1) % cams.length;
    });
    await old?.dispose();
    await _initCamera();
  }

  Future<void> _cycleFlash() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final next = switch (_flashMode) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    try {
      await c.setFlashMode(next);
      if (mounted) setState(() => _flashMode = next);
    } on CameraException {
      // Lens doesn't support this mode; ignore.
    }
  }

  Future<void> _onRecordTap() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (_modeIdx == 0) {
      // Photo mode — take a still.
      if (_capturingPhoto || _isRecording) return;
      setState(() => _capturingPhoto = true);
      try {
        final file = await c.takePicture();
        if (!mounted) return;
        widget.onCaptured(file, 'photo');
      } on CameraException catch (e) {
        _showError(e.description ?? e.code);
      } finally {
        if (mounted) setState(() => _capturingPhoto = false);
      }
    } else if (_modeIdx == 1) {
      // Video mode — toggle recording.
      if (!_isRecording) {
        await _startRecording();
      } else {
        await _stopRecording();
      }
    }
    // _modeIdx == 2 (Live) — disabled, no-op.
  }

  Future<void> _startRecording() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _isRecording) return;
    try {
      await c.startVideoRecording();
      _recordElapsed = Duration.zero;
      _recordTimer =
          Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted) return;
        setState(() {
          _recordElapsed += const Duration(milliseconds: 100);
        });
        if (_recordElapsed.inSeconds >= _kDurations[_durationIdx]) {
          _stopRecording();
        }
      });
      setState(() => _isRecording = true);
    } on CameraException catch (e) {
      _showError(e.description ?? e.code);
    }
  }

  Future<void> _stopRecording() async {
    final c = _controller;
    if (c == null) return;
    _recordTimer?.cancel();
    _recordTimer = null;
    if (!_isRecording) return;
    try {
      final file = await c.stopVideoRecording();
      if (!mounted) return;
      setState(() => _isRecording = false);
      widget.onCaptured(file, 'video');
    } on CameraException catch (e) {
      if (mounted) setState(() => _isRecording = false);
      _showError(e.description ?? e.code);
    }
  }

  Future<void> _onLibraryTap() async {
    if (_isRecording) return;
    final fallbackMsg = L(AppScope.of(context).lang).photoUploadFailed;
    try {
      XFile? picked;
      if (_modeIdx == 1) {
        picked = await _picker.pickVideo(source: ImageSource.gallery);
        if (picked != null && mounted) widget.onCaptured(picked, 'video');
      } else {
        picked = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 2048,
        );
        if (picked != null && mounted) widget.onCaptured(picked, 'photo');
      }
    } catch (_) {
      _showError(fallbackMsg);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  IconData _flashIcon() {
    return switch (_flashMode) {
      FlashMode.off => Icons.flash_off_outlined,
      FlashMode.auto => Icons.flash_auto_outlined,
      _ => Icons.flash_on,
    };
  }

  String _flashLabel(L l) {
    return switch (_flashMode) {
      FlashMode.off => l.pick('Flash off', 'Flash off'),
      FlashMode.auto => l.pick('Auto', 'Auto'),
      _ => l.pick('Flash on', 'Flash on'),
    };
  }

  String _formatElapsed() {
    final secs = _recordElapsed.inMilliseconds / 1000;
    return '${secs.toStringAsFixed(1)}s';
  }

  @override
  Widget build(BuildContext context) {
    final l = L(AppScope.of(context).lang);
    final modes = [
      l.pick('Photo', 'Photo'),
      l.pick('Vidéo', 'Video'),
      l.pick('Live', 'Live'),
    ];
    final cap = _kDurations[_durationIdx];
    final progress = _isRecording
        ? (_recordElapsed.inMilliseconds / (cap * 1000)).clamp(0.0, 1.0)
        : 0.0;
    final canFlip =
        _cameras != null && _cameras!.length > 1 && !_isRecording;
    return Material(
      color: const Color(0xFF0E0805),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Live camera preview, or fallback gradient while initializing
            // / on permission failure.
            Positioned.fill(child: _buildBackdrop(l)),
            // Rule-of-thirds grid (toggleable).
            if (_gridOn)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _ThirdsGridPainter()),
                ),
              ),
            // Top dim gradient for legibility.
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 180,
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
            // Top bar: cancel · duration pills · elapsed/cap.
            Positioned(
              top: 56,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _GlassCircleButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white, size: 18),
                    onTap: widget.onCancel,
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_kDurations.length, (i) {
                        final on = i == _durationIdx;
                        return GestureDetector(
                          onTap: _isRecording
                              ? null
                              : () => setState(() => _durationIdx = i),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 5),
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: on
                                  ? Colors.white.withValues(alpha: 0.95)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${_kDurations[i]}s',
                              style: BgFonts.body(
                                size: 11,
                                weight: FontWeight.w700,
                                color: on
                                    ? const Color(0xFF0E0805)
                                    : Colors.white.withValues(
                                        alpha: _isRecording ? 0.4 : 1.0),
                                height: 1,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  // Recording indicator (replaces the dead "Next →" link).
                  SizedBox(
                    width: 60,
                    child: _isRecording
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatElapsed(),
                                style: BgFonts.body(
                                  size: 12,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1,
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            // Pre-tagged restaurant chip.
            Positioned(
              top: 110,
              left: 0,
              right: 0,
              child: Center(
                child: _PlaceTagChip(
                  name: widget.placeName ?? '',
                  neighborhood: widget.placeNeighborhood,
                  photoUrl: widget.placePhotoUrl,
                ),
              ),
            ),
            // Right tool rail — flip / flash / grid (real). Timer + speed
            // remain as decorative stubs for now.
            Positioned(
              right: 14,
              top: 170,
              child: Column(
                children: [
                  _ToolRailButton(
                    icon: Icons.cameraswitch_outlined,
                    label: l.pick('Retourner', 'Flip'),
                    enabled: canFlip,
                    onTap: canFlip ? _flipCamera : null,
                  ),
                  const SizedBox(height: 18),
                  _ToolRailButton(
                    icon: _flashIcon(),
                    label: _flashLabel(l),
                    enabled: _controller != null && !_isRecording,
                    onTap: _controller == null || _isRecording
                        ? null
                        : _cycleFlash,
                  ),
                  const SizedBox(height: 18),
                  const _ToolRailButton(
                    icon: Icons.timer_outlined,
                    label: 'Timer',
                    enabled: false,
                  ),
                  const SizedBox(height: 18),
                  const _ToolRailButton(
                    icon: Icons.speed_outlined,
                    label: 'Speed',
                    enabled: false,
                  ),
                  const SizedBox(height: 18),
                  _ToolRailButton(
                    icon: _gridOn
                        ? Icons.grid_on_outlined
                        : Icons.grid_off_outlined,
                    label: l.pick('Grille', 'Grid'),
                    enabled: true,
                    onTap: () => setState(() => _gridOn = !_gridOn),
                  ),
                ],
              ),
            ),
            // Mode pills (Photo / Video / Live).
            Positioned(
              bottom: 168,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < modes.length; i++) ...[
                    GestureDetector(
                      onTap: i == 2 || _isRecording
                          ? null
                          : () => setState(() => _modeIdx = i),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 4),
                              child: Text(
                                modes[i].toUpperCase(),
                                style: BgFonts.display(
                                  size: 12,
                                  weight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                  color: i == 2
                                      ? Colors.white.withValues(alpha: 0.35)
                                      : (_modeIdx == i
                                          ? Colors.white
                                          : Colors.white
                                              .withValues(alpha: 0.55)),
                                ),
                              ),
                            ),
                            if (_modeIdx == i && i != 2)
                              const Positioned(
                                bottom: -4,
                                child: _OrangeDot(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Bottom controls: library · record · effects (decorative).
            Positioned(
              bottom: 70,
              left: 32,
              right: 32,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _LibraryThumb(
                    label: l.pick('Galerie', 'Library'),
                    onTap: _onLibraryTap,
                  ),
                  _RecordButton(
                    isRecording: _isRecording,
                    pulsing: _capturingPhoto,
                    progress: progress,
                    onTap: _onRecordTap,
                  ),
                  _GlassSquareButton(
                    icon: const Icon(Icons.auto_awesome_outlined,
                        color: Colors.white, size: 22),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            // Bottom hint.
            Positioned(
              bottom: 38,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  _isRecording
                      ? l.pick('Toucher pour arrêter', 'Tap to stop')
                      : (_modeIdx == 0
                          ? l.pick('Toucher pour photographier',
                              'Tap to take photo')
                          : '${l.pick('Toucher pour démarrer', 'Tap to start')} · ${cap}s'),
                  style: BgFonts.body(
                    size: 10,
                    weight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.7),
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackdrop(L l) {
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      // Cover-fit the preview so it fills the screen even when the camera's
      // aspect ratio doesn't match.
      return ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: c.value.previewSize?.height ?? 1,
            height: c.value.previewSize?.width ?? 1,
            child: CameraPreview(c),
          ),
        ),
      );
    }
    if (_initializing) {
      return Stack(
        fit: StackFit.expand,
        children: [
          const _CaptureGradientFallback(),
          Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFFF37221)),
              ),
            ),
          ),
        ],
      );
    }
    // Permission denied / no camera / unsupported platform.
    return Stack(
      fit: StackFit.expand,
      children: [
        const _CaptureGradientFallback(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.no_photography_outlined,
                    color: Colors.white70, size: 40),
                const SizedBox(height: 12),
                Text(
                  _captureErrorMessage(l),
                  textAlign: TextAlign.center,
                  style: BgFonts.body(
                    size: 13,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: _onLibraryTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l.pick('Choisir depuis la galerie',
                          'Choose from library'),
                      style: BgFonts.body(
                        size: 12,
                        weight: FontWeight.w700,
                        color: const Color(0xFF0E0805),
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _captureErrorMessage(L l) {
    switch (_error) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return l.pick(
          "Accès caméra refusé. Ouvrez les Réglages pour l'autoriser, ou choisissez depuis la galerie.",
          'Camera access denied. Open Settings to allow it, or pick from your library.',
        );
      case 'AudioAccessDenied':
      case 'AudioAccessDeniedWithoutPrompt':
      case 'AudioAccessRestricted':
        return l.pick(
          'Accès micro refusé. Activez-le dans les Réglages pour filmer une vidéo.',
          'Microphone access denied. Enable it in Settings to record video.',
        );
      case 'no_camera':
        return l.pick("Pas de caméra disponible sur cet appareil.",
            'No camera available on this device.');
      case 'unsupported_platform':
        return l.pick("La capture n'est pas disponible sur ce support.",
            'Capture is not supported on this platform.');
      default:
        return l.pick("Caméra indisponible. Utilisez la galerie.",
            'Camera unavailable. Use the library instead.');
    }
  }
}

class _CaptureGradientFallback extends StatelessWidget {
  const _CaptureGradientFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A1A0E), Color(0xFF0E0805)],
        ),
      ),
    );
  }
}

class _ThirdsGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(size.width / 3, 0),
        Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(2 * size.width / 3, 0),
        Offset(2 * size.width / 3, size.height), paint);
    canvas.drawLine(Offset(0, size.height / 3),
        Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, 2 * size.height / 3),
        Offset(size.width, 2 * size.height / 3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OrangeDot extends StatelessWidget {
  const _OrangeDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        color: Color(0xFFF37221),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _PlaceTagChip extends StatelessWidget {
  final String name;
  final String? neighborhood;
  final String? photoUrl;

  const _PlaceTagChip({
    required this.name,
    this.neighborhood,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final label = [name, neighborhood ?? '']
        .where((s) => s.isNotEmpty)
        .join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 22,
              height: 22,
              child: PhotoPlaceholder(
                seed: 'up-tag-${name.toLowerCase()}',
                showLabel: false,
                photoUrl: photoUrl,
              ),
            ),
          ),
          const SizedBox(width: 7),
          const Icon(Icons.place_outlined, color: Colors.white, size: 11),
          const SizedBox(width: 4),
          Text(
            label.isEmpty ? '—' : label,
            style: BgFonts.body(
              size: 11,
              weight: FontWeight.w600,
              color: Colors.white,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolRailButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;
  const _ToolRailButton({
    required this.icon,
    required this.label,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tint = enabled ? 1.0 : 0.4;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon,
                color: Colors.white.withValues(alpha: tint), size: 20),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: BgFonts.body(
              size: 10,
              weight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.85 * tint),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryThumb extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LibraryThumb({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.7), width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const PhotoPlaceholder(seed: 'up-lib', showLabel: false),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.only(topLeft: Radius.circular(4)),
                ),
                child: Text(
                  label,
                  style: BgFonts.body(
                    size: 8,
                    weight: FontWeight.w700,
                    color: const Color(0xFF0E0805),
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

class _RecordButton extends StatelessWidget {
  final bool isRecording;
  final bool pulsing;
  final double progress;
  final VoidCallback onTap;

  const _RecordButton({
    required this.isRecording,
    required this.pulsing,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final blob = pulsing ? 56.0 : (isRecording ? 36.0 : 72.0);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 84,
        height: 84,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer ring.
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.95), width: 4),
              ),
            ),
            // Animated inner blob.
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: blob,
              height: blob,
              decoration: BoxDecoration(
                color: const Color(0xFFF37221),
                borderRadius:
                    BorderRadius.circular(isRecording ? 8 : 999),
              ),
            ),
            // Live progress arc when recording.
            if (isRecording)
              SizedBox(
                width: 84,
                height: 84,
                child: CustomPaint(
                  painter: _RecordRingPainter(progress: progress),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecordRingPainter extends CustomPainter {
  final double progress;
  const _RecordRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2 - 2;
    final paint = Paint()
      ..color = const Color(0xFFF37221)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const start = -1.5708; // -90deg
    final sweep = progress * 6.283185;
    canvas.drawArc(
      Rect.fromCircle(center: size.center(Offset.zero), radius: r),
      start,
      sweep,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RecordRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _GlassCircleButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback onTap;
  const _GlassCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: icon,
      ),
    );
  }
}

class _GlassSquareButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback onTap;
  const _GlassSquareButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: icon,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Step 2 — Edit
// ─────────────────────────────────────────────

// Filter palette — index 0 is identity. Each ColorMatrix is 4×5 row-major
// (R, G, B, A, offset).
const _kFilterMatrices = <List<double>>[
  [
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0, //
  ],
  // Warm — boost reds, lift midtones.
  [
    1.05, 0.0, 0.0, 0.0, 12.0, //
    0.0, 1.0, 0.0, 0.0, 8.0, //
    0.0, 0.0, 0.85, 0.0, -8.0, //
    0.0, 0.0, 0.0, 1.0, 0.0, //
  ],
  // Market — sepia-ish.
  [
    0.393, 0.769, 0.189, 0.0, 0.0, //
    0.349, 0.686, 0.168, 0.0, 0.0, //
    0.272, 0.534, 0.131, 0.0, 0.0, //
    0.0, 0.0, 0.0, 1.0, 0.0, //
  ],
  // Evening — cool / blueish.
  [
    0.85, 0.0, 0.10, 0.0, 0.0, //
    0.0, 0.90, 0.0, 0.0, 0.0, //
    0.05, 0.0, 1.05, 0.0, 5.0, //
    0.0, 0.0, 0.0, 1.0, 0.0, //
  ],
  // Vivid — saturated.
  [
    1.30, -0.15, -0.15, 0.0, 0.0, //
    -0.15, 1.30, -0.15, 0.0, 0.0, //
    -0.15, -0.15, 1.30, 0.0, 0.0, //
    0.0, 0.0, 0.0, 1.0, 0.0, //
  ],
  // Soft — desat, slight lift.
  [
    0.65, 0.20, 0.15, 0.0, 12.0, //
    0.20, 0.65, 0.15, 0.0, 12.0, //
    0.15, 0.20, 0.65, 0.0, 12.0, //
    0.0, 0.0, 0.0, 1.0, 0.0, //
  ],
];

ColorFilter _filterFor(int idx) =>
    ColorFilter.matrix(_kFilterMatrices[idx.clamp(0, _kFilterMatrices.length - 1)]);

enum _OverlayKind { text, sticker }

class _EditOverlay {
  _EditOverlay({
    required this.id,
    required this.kind,
    required this.content,
    required this.position,
    this.fontSize = 22,
    this.styleIdx = 0,
  });
  final String id;
  final _OverlayKind kind;
  String content;
  Offset position;
  double fontSize;
  // Text style index: 0 = orange filled, 1 = white pill, 2 = black pill.
  int styleIdx;
}

class _EditStep extends StatefulWidget {
  final XFile? picked;
  final String kind;
  final VoidCallback onBack;
  final void Function(XFile editedFile, {XFile? thumb}) onDone;

  const _EditStep({
    required this.picked,
    required this.kind,
    required this.onBack,
    required this.onDone,
  });

  @override
  State<_EditStep> createState() => _EditStepState();
}

class _EditStepState extends State<_EditStep> {
  // Tool indices: 0=Trim, 1=Cover, 2=Text, 3=Stickers, 4=Filters.
  static const int _toolTrim = 0;
  static const int _toolFilters = 4;
  int _filterIdx = 0;
  int _activeTool = _toolFilters;
  final List<_EditOverlay> _overlays = [];
  String? _selectedOverlayId;
  bool _baking = false;
  final GlobalKey _captureKey = GlobalKey();
  int _overlayCounter = 0;
  VideoPlayerController? _videoCtl;
  bool _videoReady = false;
  // Trim window in milliseconds (null = use full clip).
  TrimWindow? _trim;
  bool _trimming = false;
  // Chosen cover frame for video (null = backend default).
  CoverFrame? _cover;

  @override
  void initState() {
    super.initState();
    if (widget.kind == 'video' &&
        widget.picked != null &&
        widget.picked!.path.isNotEmpty) {
      _initVideoPreview();
    }
  }

  Future<void> _initVideoPreview() async {
    try {
      final ctl = VideoPlayerController.file(File(widget.picked!.path));
      await ctl.initialize();
      await ctl.setLooping(false);
      await ctl.seekTo(Duration.zero);
      await ctl.pause();
      ctl.addListener(_onVideoTick);
      if (!mounted) {
        await ctl.dispose();
        return;
      }
      setState(() {
        _videoCtl = ctl;
        _videoReady = true;
      });
    } catch (_) {
      // Fall back to placeholder backdrop on failure.
    }
  }

  void _onVideoTick() {
    final ctl = _videoCtl;
    final trim = _trim;
    if (ctl == null || trim == null || !ctl.value.isInitialized) return;
    final pos = ctl.value.position.inMilliseconds;
    if (pos >= trim.endMs - 16) {
      ctl.seekTo(Duration(milliseconds: trim.startMs));
      if (!ctl.value.isPlaying) ctl.play();
    } else if (pos < trim.startMs - 16) {
      ctl.seekTo(Duration(milliseconds: trim.startMs));
    }
  }

  Future<void> _openCoverEditor() async {
    if (widget.picked == null || widget.kind != 'video') return;
    final navigator = Navigator.of(context);
    await _videoCtl?.pause();
    final result = await navigator.push<CoverFrame?>(
      MaterialPageRoute<CoverFrame?>(
        fullscreenDialog: true,
        builder: (_) => CoverEditor(
          videoPath: widget.picked!.path,
          initialMs: _cover?.positionMs,
          trimStartMs: _trim?.startMs,
          trimEndMs: _trim?.endMs,
        ),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _cover = result;
        _activeTool = 1; // Cover
      });
    }
    await _videoCtl?.play();
  }

  Future<void> _openTrimEditor() async {
    if (widget.picked == null || widget.kind != 'video') return;
    final navigator = Navigator.of(context);
    // Pause main preview so the trim editor's preview owns playback.
    await _videoCtl?.pause();
    final result = await navigator.push<TrimWindow?>(
      MaterialPageRoute<TrimWindow?>(
        fullscreenDialog: true,
        builder: (_) => TrimEditor(
          videoPath: widget.picked!.path,
          initial: _trim,
        ),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _trim = result.isFullClip ? null : result;
        _activeTool = _toolTrim;
      });
      await _videoCtl?.seekTo(Duration(milliseconds: result.startMs));
    }
    await _videoCtl?.play();
  }

  @override
  void dispose() {
    _videoCtl?.removeListener(_onVideoTick);
    _videoCtl?.dispose();
    super.dispose();
  }

  String _newId() => 'ov_${++_overlayCounter}';

  Future<void> _onAddText() async {
    final added = await showModalBottomSheet<_EditOverlay>(
      context: context,
      backgroundColor: const Color(0xFF1A1208),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _TextOverlayEditor(
        idBuilder: _newId,
        initialPosition: _centerPosition(),
      ),
    );
    if (added == null || !mounted) return;
    setState(() {
      _overlays.add(added);
      _selectedOverlayId = added.id;
      _activeTool = 2;
    });
  }

  Future<void> _onAddSticker() async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A1208),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const _StickerPicker(),
    );
    if (emoji == null || !mounted) return;
    final ov = _EditOverlay(
      id: _newId(),
      kind: _OverlayKind.sticker,
      content: emoji,
      position: _centerPosition(),
      fontSize: 56,
    );
    setState(() {
      _overlays.add(ov);
      _selectedOverlayId = ov.id;
      _activeTool = 3;
    });
  }

  Offset _centerPosition() {
    // Slight randomization so consecutively-added overlays don't stack.
    final mq = MediaQuery.of(context).size;
    final jitter = (_overlayCounter % 4) * 18.0;
    return Offset(
      mq.width / 2 - 60 + jitter,
      mq.height / 2 - 30 + jitter,
    );
  }

  void _onTabTap(int idx) {
    final l = L(AppScope.of(context).lang);
    switch (idx) {
      case _toolTrim:
        if (widget.kind != 'video') {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l.pick(
                "Le découpage est uniquement pour les vidéos.",
                'Trim is only available for videos.')),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ));
          return;
        }
        setState(() => _activeTool = idx);
        _openTrimEditor();
        return;
      case 1: // Cover
        if (widget.kind != 'video') {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l.pick(
                "La miniature est uniquement pour les vidéos.",
                'Cover frame is only available for videos.')),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ));
          return;
        }
        setState(() => _activeTool = idx);
        _openCoverEditor();
        return;
      case 2:
        setState(() => _activeTool = idx);
        _onAddText();
        return;
      case 3:
        setState(() => _activeTool = idx);
        _onAddSticker();
        return;
      case _toolFilters:
        setState(() => _activeTool = idx);
        return;
    }
  }

  void _onSelectOverlay(String? id) {
    setState(() => _selectedOverlayId = id);
  }

  void _onMoveOverlay(_EditOverlay ov, Offset delta) {
    setState(() => ov.position += delta);
  }

  void _onScaleSelected(double factor) {
    final id = _selectedOverlayId;
    if (id == null) return;
    final ov = _overlays.firstWhere((o) => o.id == id, orElse: () => _overlays.first);
    setState(() {
      if (ov.kind == _OverlayKind.text) {
        ov.fontSize = (ov.fontSize * factor).clamp(10.0, 64.0);
      } else {
        ov.fontSize = (ov.fontSize * factor).clamp(20.0, 160.0);
      }
    });
  }

  void _onDeleteSelected() {
    final id = _selectedOverlayId;
    if (id == null) return;
    setState(() {
      _overlays.removeWhere((o) => o.id == id);
      _selectedOverlayId = null;
    });
  }

  Future<void> _onNext() async {
    if (_baking) return;
    setState(() => _baking = true);
    try {
      // Drop selection ring before capture so it isn't burned in.
      final preserved = _selectedOverlayId;
      setState(() => _selectedOverlayId = null);
      await WidgetsBinding.instance.endOfFrame;

      XFile out;
      if (widget.kind == 'photo') {
        out = await _bakePhoto();
      } else if (widget.kind == 'video' && _trim != null) {
        // Filter / overlays still preview-only on video, but trim is real.
        final trimmed = await _trimVideo();
        out = trimmed ?? widget.picked ?? XFile('');
      } else {
        out = widget.picked ?? XFile('');
      }
      if (preserved != null) {
        setState(() => _selectedOverlayId = preserved);
      }
      if (!mounted) return;
      // Attach the cover thumb only for videos. (Photo thumbs are derived
      // server-side from the photo itself.)
      final thumb = widget.kind == 'video' && _cover != null
          ? XFile(_cover!.jpegFile.path)
          : null;
      widget.onDone(out, thumb: thumb);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L(AppScope.of(context).lang)
            .pick("Échec de l'export. Réessayez.", 'Export failed. Try again.')),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _baking = false);
    }
  }

  /// Re-encode the picked video clipped to [_trim] using `video_compress`.
  /// Returns the new file, or null on failure (caller falls back to the
  /// original).
  ///
  /// `VideoCompress.compressVideo` takes integer-second `startTime` and
  /// `duration`, so the timeline handles snap to whole seconds — fine for the
  /// 15/30/60s clips this app deals with.
  String _formatTrim(TrimWindow t) {
    String hms(int ms) {
      final s = ms ~/ 1000;
      final mm = (s ~/ 60).toString().padLeft(2, '0');
      final ss = (s % 60).toString().padLeft(2, '0');
      return '$mm:$ss';
    }

    final secs = ((t.endMs - t.startMs) / 1000).round();
    return '${hms(t.startMs)} → ${hms(t.endMs)} · ${secs}s';
  }

  Future<XFile?> _trimVideo() async {
    final picked = widget.picked;
    final trim = _trim;
    if (picked == null || trim == null) return null;
    if (_trimming) return null;
    _trimming = true;
    try {
      final startSec = (trim.startMs ~/ 1000);
      final lengthSec =
          ((trim.endMs - trim.startMs) / 1000).round().clamp(1, 60 * 5);
      final info = await VideoCompress.compressVideo(
        picked.path,
        quality: VideoQuality.MediumQuality,
        startTime: startSec,
        duration: lengthSec,
      );
      final out = info?.file;
      if (out == null) return null;
      return XFile(out.path);
    } catch (_) {
      return null;
    } finally {
      _trimming = false;
    }
  }

  Future<XFile> _bakePhoto() async {
    final ctx = _captureKey.currentContext;
    if (ctx == null) {
      return widget.picked ?? XFile('');
    }
    final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
    final pixelRatio =
        MediaQuery.of(context).devicePixelRatio.clamp(1.5, 3.0).toDouble();
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      return widget.picked ?? XFile('');
    }
    final bytes = byteData.buffer.asUint8List();
    final tmpDir = Directory.systemTemp;
    final filename =
        'edit_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File('${tmpDir.path}/$filename');
    await file.writeAsBytes(bytes);
    return XFile(file.path);
  }

  @override
  Widget build(BuildContext context) {
    final l = L(AppScope.of(context).lang);
    return Material(
      color: const Color(0xFF0E0805),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Editing canvas — captured by RepaintBoundary on bake.
            Positioned.fill(
              child: RepaintBoundary(
                key: _captureKey,
                child: ColorFiltered(
                  colorFilter: _filterFor(_filterIdx),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: _PreviewBackdrop(
                          picked: widget.picked,
                          kind: widget.kind,
                          videoController:
                              _videoReady ? _videoCtl : null,
                        ),
                      ),
                      for (final ov in _overlays)
                        _OverlayView(
                          overlay: ov,
                          selected: _selectedOverlayId == ov.id,
                          onTap: () => _onSelectOverlay(ov.id),
                          onPan: (d) => _onMoveOverlay(ov, d),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // Tap outside overlays to deselect.
            if (_selectedOverlayId != null)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => _onSelectOverlay(null),
                ),
              ),
            // Top dim gradient (outside RepaintBoundary).
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
                      colors: [Color(0xB3000000), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
            // Bottom dim gradient.
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 280,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xCC000000), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
            // Top bar (outside RepaintBoundary so chrome isn't baked in).
            Positioned(
              top: 56,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _baking ? null : widget.onBack,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '← ${l.pick('Retour', 'Back')}',
                        style: BgFonts.body(
                          size: 12,
                          weight: FontWeight.w600,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    l.pick('02 / Édition', '02 / Edit').toUpperCase(),
                    style: BgFonts.body(
                      size: 11,
                      weight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.85),
                      letterSpacing: 0.5,
                      height: 1,
                    ),
                  ),
                  GestureDetector(
                    onTap: _baking ? null : _onNext,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF37221).withValues(
                            alpha: _baking ? 0.6 : 1.0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: _baking
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                              ),
                            )
                          : Text(
                              '${l.next} →',
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
            ),
            // Selected-overlay floating toolbar (size + delete).
            if (_selectedOverlayId != null)
              Positioned(
                top: 110,
                right: 16,
                child: _SelectedOverlayToolbar(
                  onDelete: _onDeleteSelected,
                  onScaleUp: () => _onScaleSelected(1.15),
                  onScaleDown: () => _onScaleSelected(0.87),
                ),
              ),
            // Video-only banners: trim badge (re-openable) and the
            // "preview only" warning when overlays are present.
            if (widget.kind == 'video')
              Positioned(
                top: 110,
                left: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_trim != null) ...[
                      GestureDetector(
                        onTap: _openTrimEditor,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF37221),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.content_cut,
                                  color: Colors.white, size: 12),
                              const SizedBox(width: 6),
                              Text(
                                _formatTrim(_trim!),
                                style: BgFonts.body(
                                  size: 10,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (_cover != null) ...[
                      GestureDetector(
                        onTap: _openCoverEditor,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: Image.file(
                                  _cover!.jpegFile,
                                  width: 22,
                                  height: 22,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l.pick('Miniature', 'Cover'),
                                style: BgFonts.body(
                                  size: 10,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (_overlays.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.info_outline,
                                color: Colors.white, size: 12),
                            const SizedBox(width: 6),
                            Text(
                              l.pick('Aperçu seulement', 'Preview only'),
                              style: BgFonts.body(
                                size: 10,
                                weight: FontWeight.w700,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            // Filter strip (always visible; this is the most useful tool).
            Positioned(
              bottom: 90,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 96,
                child: _FilterStrip(
                  picked: widget.picked,
                  kind: widget.kind,
                  filterIdx: _filterIdx,
                  onChanged: (i) => setState(() => _filterIdx = i),
                ),
              ),
            ),
            // Tool tabs.
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: _EditToolTabs(
                l: l,
                activeTool: _activeTool,
                trimEnabled: widget.kind == 'video',
                coverEnabled: widget.kind == 'video',
                onTap: _onTabTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewBackdrop extends StatelessWidget {
  final XFile? picked;
  final String kind;
  final VideoPlayerController? videoController;

  const _PreviewBackdrop({
    required this.picked,
    required this.kind,
    this.videoController,
  });

  @override
  Widget build(BuildContext context) {
    if (picked != null && kind == 'photo') {
      return Image.file(
        File(picked!.path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const PhotoPlaceholder(
          seed: 'up-preview',
          label: 'POULET BRAISÉ',
          showLabel: true,
        ),
      );
    }
    if (kind == 'video' && videoController != null) {
      final c = videoController!;
      return ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: c.value.size.width == 0 ? 1 : c.value.size.width,
            height: c.value.size.height == 0 ? 1 : c.value.size.height,
            child: VideoPlayer(c),
          ),
        ),
      );
    }
    return const PhotoPlaceholder(
      seed: 'up-preview',
      label: 'POULET BRAISÉ · TERRASSE',
      showLabel: true,
    );
  }
}

class _OverlayView extends StatelessWidget {
  final _EditOverlay overlay;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<Offset> onPan;

  const _OverlayView({
    required this.overlay,
    required this.selected,
    required this.onTap,
    required this.onPan,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;
    switch (overlay.kind) {
      case _OverlayKind.text:
        content = _TextOverlayChip(overlay: overlay);
        break;
      case _OverlayKind.sticker:
        content = Text(
          overlay.content,
          style: TextStyle(
            fontSize: overlay.fontSize,
            // No font family — rely on system emoji rendering.
            shadows: const [
              Shadow(color: Color(0x80000000), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
        );
        break;
    }
    final framed = selected
        ? Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: content,
          )
        : content;
    return Positioned(
      left: overlay.position.dx,
      top: overlay.position.dy,
      child: GestureDetector(
        onTap: onTap,
        onPanUpdate: (d) => onPan(d.delta),
        behavior: HitTestBehavior.opaque,
        child: framed,
      ),
    );
  }
}

class _TextOverlayChip extends StatelessWidget {
  final _EditOverlay overlay;
  const _TextOverlayChip({required this.overlay});

  @override
  Widget build(BuildContext context) {
    final styles = _kTextStyles[overlay.styleIdx.clamp(0, _kTextStyles.length - 1)];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: styles.bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        overlay.content,
        style: BgFonts.display(
          size: overlay.fontSize,
          weight: FontWeight.w800,
          color: styles.textColor,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

class _TextStyleSpec {
  final Color bgColor;
  final Color textColor;
  const _TextStyleSpec({required this.bgColor, required this.textColor});
}

const _kTextStyles = <_TextStyleSpec>[
  _TextStyleSpec(bgColor: Color(0xEBF37221), textColor: Colors.white),
  _TextStyleSpec(bgColor: Color(0xF2FFFFFF), textColor: Color(0xFF2A1A0E)),
  _TextStyleSpec(bgColor: Color(0xCC000000), textColor: Colors.white),
];

class _SelectedOverlayToolbar extends StatelessWidget {
  final VoidCallback onDelete;
  final VoidCallback onScaleUp;
  final VoidCallback onScaleDown;
  const _SelectedOverlayToolbar({
    required this.onDelete,
    required this.onScaleUp,
    required this.onScaleDown,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconBtn(icon: Icons.remove, onTap: onScaleDown),
          _IconBtn(icon: Icons.add, onTap: onScaleUp),
          _IconBtn(icon: Icons.delete_outline, onTap: onDelete),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: const BoxDecoration(
          color: Color(0x33FFFFFF),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

class _FilterStrip extends StatelessWidget {
  final XFile? picked;
  final String kind;
  final int filterIdx;
  final ValueChanged<int> onChanged;

  const _FilterStrip({
    required this.picked,
    required this.kind,
    required this.filterIdx,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = L(AppScope.of(context).lang);
    final names = l.isFr
        ? const ['Original', 'Chaleur', 'Marché', 'Soir', 'Vif', 'Doux']
        : const ['Original', 'Warm', 'Market', 'Evening', 'Vivid', 'Soft'];
    Widget thumb() {
      if (picked != null && kind == 'photo') {
        return Image.file(
          File(picked!.path),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              const PhotoPlaceholder(seed: 'up-preview', showLabel: false),
        );
      }
      return const PhotoPlaceholder(seed: 'up-preview', showLabel: false);
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: names.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final on = i == filterIdx;
        return GestureDetector(
          onTap: () => onChanged(i),
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: on ? const Color(0xFFF37221) : Colors.transparent,
                    width: 2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: ColorFiltered(
                  colorFilter: _filterFor(i),
                  child: SizedBox.expand(child: thumb()),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                names[i],
                style: BgFonts.body(
                  size: 10,
                  weight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: on ? 1 : 0.7),
                  height: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EditToolTabs extends StatelessWidget {
  final L l;
  final int activeTool;
  final bool trimEnabled;
  final bool coverEnabled;
  final ValueChanged<int> onTap;
  const _EditToolTabs({
    required this.l,
    required this.activeTool,
    required this.trimEnabled,
    required this.coverEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = <(IconData, String, bool)>[
      (Icons.content_cut, l.pick('Couper', 'Trim'), trimEnabled),
      (Icons.image_outlined, l.pick('Miniature', 'Cover'), coverEnabled),
      (Icons.text_fields_outlined, l.pick('Texte', 'Text'), true),
      (Icons.auto_awesome_outlined, l.pick('Stickers', 'Stickers'), true),
      (Icons.auto_fix_high_outlined, l.pick('Filtres', 'Filters'), true),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(tabs.length, (i) {
          final (icon, label, enabled) = tabs[i];
          final on = activeTool == i && enabled;
          final color = enabled
              ? (on
                  ? const Color(0xFFF37221)
                  : Colors.white.withValues(alpha: 0.85))
              : Colors.white.withValues(alpha: 0.35);
          return GestureDetector(
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    style: BgFonts.body(
                      size: 10,
                      weight: FontWeight.w700,
                      color: color,
                      letterSpacing: 0.2,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TextOverlayEditor extends StatefulWidget {
  final String Function() idBuilder;
  final Offset initialPosition;

  const _TextOverlayEditor({
    required this.idBuilder,
    required this.initialPosition,
  });

  @override
  State<_TextOverlayEditor> createState() => _TextOverlayEditorState();
}

class _TextOverlayEditorState extends State<_TextOverlayEditor> {
  final TextEditingController _ctl = TextEditingController();
  int _styleIdx = 0;
  double _fontSize = 22;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctl.text.trim();
    if (text.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(_EditOverlay(
      id: widget.idBuilder(),
      kind: _OverlayKind.text,
      content: text,
      position: widget.initialPosition,
      fontSize: _fontSize,
      styleIdx: _styleIdx,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = L(AppScope.of(context).lang);
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _ctl,
                autofocus: true,
                maxLength: 80,
                style: BgFonts.display(
                  size: 18,
                  weight: FontWeight.w800,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: l.pick('Ajouter du texte', 'Add text'),
                  hintStyle: BgFonts.body(
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  counterStyle: BgFonts.body(
                    size: 10,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    l.pick('Style', 'Style').toUpperCase(),
                    style: BgFonts.body(
                      size: 10,
                      weight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.7),
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(width: 12),
                  for (var i = 0; i < _kTextStyles.length; i++)
                    GestureDetector(
                      onTap: () => setState(() => _styleIdx = i),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _kTextStyles[i].bgColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _styleIdx == i
                                ? Colors.white
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          'Aa',
                          style: BgFonts.display(
                            size: 13,
                            weight: FontWeight.w800,
                            color: _kTextStyles[i].textColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    l.pick('Taille', 'Size').toUpperCase(),
                    style: BgFonts.body(
                      size: 10,
                      weight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.7),
                      letterSpacing: 0.4,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: _fontSize,
                      min: 14,
                      max: 48,
                      onChanged: (v) => setState(() => _fontSize = v),
                      activeColor: const Color(0xFFF37221),
                    ),
                  ),
                  Text(
                    _fontSize.toStringAsFixed(0),
                    style: BgFonts.body(
                      size: 11,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          l.cancel,
                          style: BgFonts.body(
                            size: 13,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: _submit,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF37221),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          l.pick('Ajouter', 'Add'),
                          style: BgFonts.body(
                            size: 13,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const List<String> _kStickers = [
  '🔥', '😋', '😍', '🤤', '👌', '👍', '👏', '🌶️',
  '🍗', '🍖', '🍤', '🐟', '🥘', '🍲', '🍛', '🥗',
  '🍕', '🍔', '🍟', '🌮', '🌯', '🥙', '🧆', '🍱',
  '🍣', '🍜', '🍝', '🍞', '🥖', '🧀', '🍰', '🍩',
  '🍦', '🍪', '🥥', '🍌', '🥭', '🍍', '🍓', '🍇',
  '☕', '🍵', '🥤', '🍺', '🍷', '🥂', '🍾', '🥑',
  '⭐', '✨', '💯', '🎉', '❤️', '🧡', '💛', '💚',
];

class _StickerPicker extends StatelessWidget {
  const _StickerPicker();

  @override
  Widget build(BuildContext context) {
    final l = L(AppScope.of(context).lang);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l.pick('Stickers', 'Stickers').toUpperCase(),
                style: BgFonts.body(
                  size: 11,
                  weight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: GridView.builder(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6),
                itemCount: _kStickers.length,
                itemBuilder: (_, i) {
                  return GestureDetector(
                    onTap: () => Navigator.of(context).pop(_kStickers[i]),
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: Text(
                        _kStickers[i],
                        style: const TextStyle(fontSize: 30),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Step 3 — Publish
// ─────────────────────────────────────────────

class _PublishStep extends StatelessWidget {
  final TextEditingController captionCtl;
  final XFile? picked;
  final XFile? thumb;
  final String kind;
  final String? placeName;
  final String? placeNeighborhood;
  final String? placePhotoUrl;
  final Map<int, int> stars;
  final bool publishing;
  final void Function(int category, int stars) onStarChanged;
  final VoidCallback onBack;
  final VoidCallback onPublish;
  final VoidCallback onSaveDraft;

  const _PublishStep({
    required this.captionCtl,
    required this.picked,
    required this.thumb,
    required this.kind,
    required this.placeName,
    required this.placeNeighborhood,
    required this.placePhotoUrl,
    required this.stars,
    required this.publishing,
    required this.onStarChanged,
    required this.onBack,
    required this.onPublish,
    required this.onSaveDraft,
  });

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.palette;
    final l = L(state.lang);
    final cats = l.isFr
        ? const ['Plats', 'Service', 'Toilettes', 'Ambiance']
        : const ['Food', 'Service', 'Toilets', 'Ambiance'];
    return Material(
      color: p.bg,
      child: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            _PublishHeader(
              palette: p,
              l: l,
              publishing: publishing,
              onBack: publishing ? null : onBack,
              onPublish: publishing ? null : onPublish,
            ),
            // Preview + caption row.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PublishPreview(picked: picked, thumb: thumb, kind: kind),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel(
                          text: l.pick('Légende', 'Caption'),
                          palette: p,
                        ),
                        const SizedBox(height: 6),
                        _CaptionField(
                          controller: captionCtl,
                          palette: p,
                          hint: l.pick(
                            'Décrivez votre expérience…',
                            'Describe your experience…',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Place tag.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _SectionLabel(
                        text: l.pick(
                            'Identifier le restaurant', 'Tag the restaurant'),
                        palette: p,
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: p.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          l.pick('Requis', 'Required').toUpperCase(),
                          style: BgFonts.body(
                            size: 10,
                            weight: FontWeight.w700,
                            color: p.orangeDeep,
                            letterSpacing: 0.4,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: p.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.cardBorder),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: PhotoPlaceholder(
                              seed:
                                  'up-tag-${(placeName ?? '').toLowerCase()}',
                              showLabel: false,
                              photoUrl: placePhotoUrl,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      placeName ??
                                          l.pick('Restaurant', 'Restaurant'),
                                      style: BgFonts.display(
                                        size: 15,
                                        weight: FontWeight.w700,
                                        color: p.ink,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Icon(Icons.verified,
                                      size: 13, color: p.orange),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                placeNeighborhood ?? '',
                                style: BgFonts.body(
                                  size: 12,
                                  color: p.inkMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            size: 16, color: p.inkMuted),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.pick(
                      "Obligatoire — la vidéo apparaîtra sur la fiche",
                      'Required — the video will appear on the place page',
                    ),
                    style: BgFonts.body(
                      size: 11,
                      color: p.inkMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            // Quick ratings.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(
                    text: l.pick('Notes rapides', 'Quick ratings'),
                    palette: p,
                  ),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 3.4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: List.generate(cats.length, (i) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: p.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: p.cardBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              cats[i],
                              style: BgFonts.body(
                                size: 12,
                                weight: FontWeight.w600,
                                color: p.ink,
                                height: 1,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(5, (s) {
                                final filled = s < (stars[i] ?? 0);
                                return GestureDetector(
                                  onTap: () => onStarChanged(i, s + 1),
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 1),
                                    child: Icon(
                                      Icons.star_rounded,
                                      size: 14,
                                      color: filled
                                          ? p.orange
                                          : const Color(0x2E785028),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            // Verify message.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.orangeSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified, size: 14, color: p.orangeDeep),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.pick(
                          "Votre avis sera vérifié sous 24h avant d'apparaître publiquement.",
                          'Your review will be reviewed within 24h before appearing publicly.',
                        ),
                        style: BgFonts.body(
                          size: 11,
                          weight: FontWeight.w600,
                          color: p.orangeDeep,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Save draft.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Center(
                child: GestureDetector(
                  onTap: onSaveDraft,
                  child: Text(
                    l.pick(
                        'Enregistrer brouillon', 'Save draft'),
                    style: BgFonts.body(
                      size: 12,
                      weight: FontWeight.w600,
                      color: p.inkMuted,
                    ).copyWith(decoration: TextDecoration.underline),
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

class _PublishHeader extends StatelessWidget {
  final BgPalette palette;
  final L l;
  final bool publishing;
  final VoidCallback? onBack;
  final VoidCallback? onPublish;

  const _PublishHeader({
    required this.palette,
    required this.l,
    required this.publishing,
    required this.onBack,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 54, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '← ${l.pick('Retour', 'Back')}',
                style: BgFonts.body(
                  size: 14,
                  weight: FontWeight.w600,
                  color: p.inkMuted,
                  height: 1,
                ),
              ),
            ),
          ),
          Text(
            l.pick('Publier votre avis', 'Publish your review'),
            style: BgFonts.display(
              size: 17,
              weight: FontWeight.w700,
              color: p.ink,
            ),
          ),
          GestureDetector(
            onTap: onPublish,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: publishing
                    ? p.orange.withValues(alpha: 0.6)
                    : p.orange,
                borderRadius: BorderRadius.circular(999),
              ),
              child: publishing
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
                      l.publish,
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
    );
  }
}

class _PublishPreview extends StatefulWidget {
  final XFile? picked;
  final XFile? thumb;
  final String kind;
  const _PublishPreview({
    required this.picked,
    required this.thumb,
    required this.kind,
  });

  @override
  State<_PublishPreview> createState() => _PublishPreviewState();
}

class _PublishPreviewState extends State<_PublishPreview> {
  File? _autoThumb;
  bool _autoThumbLoading = false;

  @override
  void initState() {
    super.initState();
    _maybeGenerateThumb();
  }

  @override
  void didUpdateWidget(_PublishPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.picked?.path != widget.picked?.path ||
        oldWidget.thumb?.path != widget.thumb?.path ||
        oldWidget.kind != widget.kind) {
      _autoThumb = null;
      _maybeGenerateThumb();
    }
  }

  /// If this is a video and the editor didn't bake a cover frame, ask
  /// `video_compress` for the first-frame thumbnail so the publish
  /// preview shows the actual recording instead of a placeholder.
  Future<void> _maybeGenerateThumb() async {
    if (widget.kind != 'video') return;
    if (widget.thumb != null) return;
    final picked = widget.picked;
    if (picked == null || picked.path.isEmpty) return;
    if (_autoThumbLoading) return;
    _autoThumbLoading = true;
    try {
      final file = await VideoCompress.getFileThumbnail(
        picked.path,
        quality: 70,
        position: 0,
      );
      if (!mounted) return;
      setState(() => _autoThumb = file);
    } catch (_) {
      // Falls back to the dark placeholder below.
    } finally {
      _autoThumbLoading = false;
    }
  }

  void _openVideoPlayer() {
    final picked = widget.picked;
    if (picked == null || picked.path.isEmpty) return;
    if (widget.kind != 'video') return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _VideoPreviewPage(filePath: picked.path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final picked = widget.picked;
    final thumb = widget.thumb;
    final isVideo = widget.kind == 'video';
    Widget background;
    if (picked != null && !isVideo) {
      background = Image.file(
        File(picked.path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const PhotoPlaceholder(
          seed: 'up-preview',
          showLabel: false,
        ),
      );
    } else if (isVideo && thumb != null) {
      background = Image.file(
        File(thumb.path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF1A1209)),
      );
    } else if (isVideo && _autoThumb != null) {
      background = Image.file(
        _autoThumb!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF1A1209)),
      );
    } else {
      background = const ColoredBox(color: Color(0xFF1A1209));
    }
    return SizedBox(
      width: 92,
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: GestureDetector(
          onTap: isVideo ? _openVideoPlayer : null,
          behavior: HitTestBehavior.opaque,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                background,
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x66000000)],
                      ),
                    ),
                  ),
                ),
                if (isVideo)
                  Center(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.play_arrow,
                          size: 18, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoPreviewPage extends StatefulWidget {
  final String filePath;
  const _VideoPreviewPage({required this.filePath});

  @override
  State<_VideoPreviewPage> createState() => _VideoPreviewPageState();
}

class _VideoPreviewPageState extends State<_VideoPreviewPage> {
  VideoPlayerController? _ctl;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ctl = VideoPlayerController.file(File(widget.filePath));
      await ctl.initialize();
      await ctl.setLooping(true);
      if (!mounted) {
        await ctl.dispose();
        return;
      }
      setState(() {
        _ctl = ctl;
        _ready = true;
      });
      await ctl.play();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _ctl?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final ctl = _ctl;
    if (ctl == null || !ctl.value.isInitialized) return;
    setState(() {
      if (ctl.value.isPlaying) {
        ctl.pause();
      } else {
        ctl.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctl = _ctl;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _togglePlay,
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: _error != null
                      ? Text(
                          _error!,
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        )
                      : (_ready && ctl != null
                          ? AspectRatio(
                              aspectRatio: ctl.value.aspectRatio == 0
                                  ? 9 / 16
                                  : ctl.value.aspectRatio,
                              child: VideoPlayer(ctl),
                            )
                          : const CircularProgressIndicator(
                              color: Colors.white)),
                ),
              ),
            ),
            if (ctl != null && _ready && !ctl.value.isPlaying)
              IgnorePointer(
                child: Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.play_arrow,
                        size: 36, color: Colors.white),
                  ),
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            if (ctl != null && _ready)
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: VideoProgressIndicator(
                  ctl,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Color(0x44FFFFFF),
                    backgroundColor: Color(0x22FFFFFF),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final BgPalette palette;
  const _SectionLabel({required this.text, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: BgFonts.body(
        size: 12,
        weight: FontWeight.w700,
        color: palette.inkMuted,
        letterSpacing: 0.5,
        height: 1,
      ),
    );
  }
}

class _CaptionField extends StatelessWidget {
  final TextEditingController controller;
  final BgPalette palette;
  final String hint;
  const _CaptionField({
    required this.controller,
    required this.palette,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.cardBorder),
      ),
      constraints: const BoxConstraints(minHeight: 100),
      child: TextField(
        controller: controller,
        maxLines: 6,
        minLines: 4,
        maxLength: 280,
        textInputAction: TextInputAction.newline,
        inputFormatters: [LengthLimitingTextInputFormatter(280)],
        style: BgFonts.body(size: 13, color: palette.ink, height: 1.45),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: BgFonts.body(
            size: 13,
            color: palette.inkMuted,
            height: 1.45,
          ),
          counterText: '',
          isCollapsed: true,
          border: InputBorder.none,
        ),
      ),
    );
  }
}

