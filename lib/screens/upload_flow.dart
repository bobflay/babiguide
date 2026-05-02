import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_error.dart';
import '../api/media_api.dart';
import '../app_state.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets/photo_placeholder.dart';

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
  final String? placePhotoUrl;
  final String? initialCategory;

  const UploadFlow({
    super.key,
    required this.placeSlug,
    this.placeName,
    this.placeNeighborhood,
    this.placePhotoUrl,
    this.initialCategory,
  });

  @override
  State<UploadFlow> createState() => _UploadFlowState();
}

const List<int> _kDurations = [15, 30, 60];

class _UploadFlowState extends State<UploadFlow> {
  int _step = 0;
  // 0 = Photo, 1 = Video. Live (idx 2) is rendered but disabled (no support).
  int _modeIdx = 1;
  int _durationIdx = 1;
  bool _recording = false;
  int _filterIdx = 1;
  int _audienceIdx = 0;
  final Map<int, int> _stars = {0: 5, 1: 4, 2: 4, 3: 5};
  final Set<int> _selectedHashtags = {0, 1};
  bool _allowComments = true;
  bool _allowDuet = true;
  bool _publishing = false;
  XFile? _picked;
  String _kind = 'photo';
  final TextEditingController _captionCtl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _captionCtl.dispose();
    super.dispose();
  }

  Future<void> _pickFromCamera() async {
    final l = L(AppScope.of(context).lang);
    try {
      XFile? picked;
      if (_modeIdx == 0) {
        _kind = 'photo';
        picked = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 2048,
        );
      } else if (_modeIdx == 1) {
        _kind = 'video';
        picked = await _picker.pickVideo(
          source: ImageSource.camera,
          maxDuration: Duration(seconds: _kDurations[_durationIdx]),
        );
      } else {
        // Live mode is not supported.
        return;
      }
      if (picked == null || !mounted) return;
      setState(() {
        _picked = picked;
        _step = 1;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l.photoUploadFailed),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _pickFromLibrary() async {
    final l = L(AppScope.of(context).lang);
    try {
      XFile? picked;
      if (_modeIdx == 1) {
        _kind = 'video';
        picked = await _picker.pickVideo(source: ImageSource.gallery);
      } else {
        _kind = 'photo';
        picked = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 2048,
        );
      }
      if (picked == null || !mounted) return;
      setState(() {
        _picked = picked;
        _step = 1;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l.photoUploadFailed),
        behavior: SnackBarBehavior.floating,
      ));
    }
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
      final result = await state.mediaApi.upload(
        file: File(picked.path),
        kind: _kind,
        placeId: widget.placeSlug,
        category: widget.initialCategory == 'all' ? null : widget.initialCategory,
        label: _composedCaption().trim().isEmpty ? null : _composedCaption(),
      );
      if (!mounted) return;
      Navigator.of(context).pop<MediaUploadResult>(result);
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

  String _composedCaption() {
    final base = _captionCtl.text.trim();
    if (_selectedHashtags.isEmpty) return base;
    final tags = _hashtagList(L(AppScope.of(context).lang));
    final selected = _selectedHashtags
        .where((i) => i < tags.length)
        .map((i) => tags[i])
        .join(' ');
    if (base.isEmpty) return selected;
    return '$base $selected';
  }

  List<String> _hashtagList(L l) => l.isFr
      ? const ['#abidjan', '#cocody', '#maquis', '#poulet', '#bonplan']
      : const ['#abidjan', '#cocody', '#maquis', '#chicken', '#mustgo'];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_publishing,
      child: switch (_step) {
        0 => _CaptureStep(
            modeIdx: _modeIdx,
            durationIdx: _durationIdx,
            recording: _recording,
            placeName: widget.placeName,
            placeNeighborhood: widget.placeNeighborhood,
            placePhotoUrl: widget.placePhotoUrl,
            canProceed: _picked != null,
            onModeChanged: (i) => setState(() => _modeIdx = i),
            onDurationChanged: (i) => setState(() => _durationIdx = i),
            onRecordingChanged: (v) => setState(() => _recording = v),
            onCancel: () => Navigator.of(context).maybePop(),
            onLibrary: _pickFromLibrary,
            onCapture: _pickFromCamera,
            onNext: () => setState(() => _step = 1),
          ),
        1 => _EditStep(
            picked: _picked,
            kind: _kind,
            filterIdx: _filterIdx,
            onFilterChanged: (i) => setState(() => _filterIdx = i),
            onBack: () => setState(() => _step = 0),
            onNext: () => setState(() => _step = 2),
          ),
        _ => _PublishStep(
            captionCtl: _captionCtl,
            picked: _picked,
            kind: _kind,
            placeName: widget.placeName,
            placeNeighborhood: widget.placeNeighborhood,
            placePhotoUrl: widget.placePhotoUrl,
            audienceIdx: _audienceIdx,
            stars: _stars,
            selectedHashtags: _selectedHashtags,
            allowComments: _allowComments,
            allowDuet: _allowDuet,
            publishing: _publishing,
            onAudienceChanged: (i) => setState(() => _audienceIdx = i),
            onStarChanged: (cat, n) => setState(() => _stars[cat] = n),
            onHashtagToggled: (i) => setState(() {
              if (_selectedHashtags.contains(i)) {
                _selectedHashtags.remove(i);
              } else {
                _selectedHashtags.add(i);
              }
            }),
            onAllowCommentsChanged: (v) =>
                setState(() => _allowComments = v),
            onAllowDuetChanged: (v) => setState(() => _allowDuet = v),
            onBack: () => setState(() => _step = 1),
            onPublish: _publish,
            onSaveDraft: () {
              Navigator.of(context).maybePop();
            },
          ),
      },
    );
  }
}

// ─────────────────────────────────────────────
// Step 1 — Capture
// ─────────────────────────────────────────────

class _CaptureStep extends StatelessWidget {
  final int modeIdx;
  final int durationIdx;
  final bool recording;
  final String? placeName;
  final String? placeNeighborhood;
  final String? placePhotoUrl;
  final bool canProceed;
  final ValueChanged<int> onModeChanged;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<bool> onRecordingChanged;
  final VoidCallback onCancel;
  final VoidCallback onLibrary;
  final VoidCallback onCapture;
  final VoidCallback onNext;

  const _CaptureStep({
    required this.modeIdx,
    required this.durationIdx,
    required this.recording,
    required this.placeName,
    required this.placeNeighborhood,
    required this.placePhotoUrl,
    required this.canProceed,
    required this.onModeChanged,
    required this.onDurationChanged,
    required this.onRecordingChanged,
    required this.onCancel,
    required this.onLibrary,
    required this.onCapture,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final l = L(AppScope.of(context).lang);
    final modes = [
      l.pick('Photo', 'Photo'),
      l.pick('Vidéo', 'Video'),
      l.pick('Live', 'Live'),
    ];
    return Material(
      color: const Color(0xFF0E0805),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Warm gradient + radial highlights matching the design.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2A1A0E), Color(0xFF0E0805)],
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.4),
                      radius: 0.9,
                      colors: [
                        const Color(0xFFF37221).withValues(alpha: 0.32),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Rule-of-thirds grid.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _ThirdsGridPainter()),
              ),
            ),
            // Faux subject silhouette.
            Positioned(
              left: 0,
              right: 0,
              top: 200,
              child: Center(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.2, -0.3),
                      radius: 0.75,
                      colors: [
                        const Color(0xFFFFC88C).withValues(alpha: 0.35),
                        const Color(0xFFB45A28).withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Top bar: cancel · duration pills · next.
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
                    onTap: onCancel,
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
                        final on = i == durationIdx;
                        return GestureDetector(
                          onTap: () => onDurationChanged(i),
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
                                    : Colors.white,
                                height: 1,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  GestureDetector(
                    onTap: canProceed ? onNext : null,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: Text(
                        '${l.next} →',
                        style: BgFonts.body(
                          size: 12,
                          weight: FontWeight.w700,
                          color: Colors.white.withValues(
                              alpha: canProceed ? 1.0 : 0.4),
                          height: 1,
                        ),
                      ),
                    ),
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
                  name: placeName ?? '',
                  neighborhood: placeNeighborhood,
                  photoUrl: placePhotoUrl,
                ),
              ),
            ),
            // Right tool rail (decorative).
            Positioned(
              right: 14,
              top: 170,
              child: Column(
                children: [
                  _ToolRailButton(
                    icon: Icons.cameraswitch_outlined,
                    label: l.pick('Retourner', 'Flip'),
                  ),
                  const SizedBox(height: 18),
                  _ToolRailButton(
                    icon: Icons.flash_on_outlined,
                    label: l.pick('Flash', 'Flash'),
                  ),
                  const SizedBox(height: 18),
                  _ToolRailButton(
                    icon: Icons.timer_outlined,
                    label: l.pick('Minuteur', 'Timer'),
                  ),
                  const SizedBox(height: 18),
                  _ToolRailButton(
                    icon: Icons.speed_outlined,
                    label: l.pick('Vitesse', 'Speed'),
                  ),
                  const SizedBox(height: 18),
                  _ToolRailButton(
                    icon: Icons.grid_on_outlined,
                    label: l.pick('Grille', 'Grid'),
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
                      onTap: i == 2 ? null : () => onModeChanged(i),
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
                                      : (modeIdx == i
                                          ? Colors.white
                                          : Colors.white
                                              .withValues(alpha: 0.55)),
                                ),
                              ),
                            ),
                            if (modeIdx == i && i != 2)
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
            // Bottom controls: library · record · effects.
            Positioned(
              bottom: 70,
              left: 32,
              right: 32,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _LibraryThumb(
                    label: l.pick('Galerie', 'Library'),
                    onTap: onLibrary,
                  ),
                  _RecordButton(
                    recording: recording,
                    onTap: onCapture,
                    onPressedChanged: onRecordingChanged,
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
                  '${l.pick('Toucher pour démarrer', 'Tap to start')} · ${_kDurations[durationIdx]}s',
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
  const _ToolRailButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: BgFonts.body(
            size: 10,
            weight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.85),
            height: 1,
          ),
        ),
      ],
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
  final bool recording;
  final VoidCallback onTap;
  final ValueChanged<bool> onPressedChanged;

  const _RecordButton({
    required this.recording,
    required this.onTap,
    required this.onPressedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onTapDown: (_) => onPressedChanged(true),
      onTapUp: (_) => onPressedChanged(false),
      onTapCancel: () => onPressedChanged(false),
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
              width: recording ? 48 : 72,
              height: recording ? 48 : 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF37221),
                borderRadius:
                    BorderRadius.circular(recording ? 8 : 999),
              ),
            ),
            // Decorative progress arc.
            const SizedBox(
              width: 84,
              height: 84,
              child: CustomPaint(painter: _RecordRingPainter(progress: 0.32)),
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

class _EditStep extends StatelessWidget {
  final XFile? picked;
  final String kind;
  final int filterIdx;
  final ValueChanged<int> onFilterChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _EditStep({
    required this.picked,
    required this.kind,
    required this.filterIdx,
    required this.onFilterChanged,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final l = L(AppScope.of(context).lang);
    final filters = l.isFr
        ? const ['Original', 'Chaleur', 'Marché', 'Soir', 'Vif', 'Doux']
        : const ['Original', 'Warm', 'Market', 'Evening', 'Vivid', 'Soft'];
    return Material(
      color: const Color(0xFF0E0805),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Preview backdrop.
            Positioned.fill(child: _PreviewBackdrop(picked: picked, kind: kind)),
            // Top/bottom dim gradients.
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x80000000),
                      Colors.transparent,
                      Colors.transparent,
                      Color(0xB3000000),
                    ],
                    stops: [0.0, 0.18, 0.6, 1.0],
                  ),
                ),
              ),
            ),
            // Top bar.
            Positioned(
              top: 56,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: onBack,
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
                    onTap: onNext,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF37221),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
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
            // Decorative text overlays.
            Positioned(
              top: MediaQuery.of(context).size.height * 0.32,
              left: 0,
              right: 0,
              child: Center(
                child: Transform.rotate(
                  angle: -0.035,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF37221).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l.pick('POULET BRAISÉ 🔥', 'GRILLED CHICKEN 🔥'),
                      style: BgFonts.display(
                        size: 18,
                        weight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.40,
              left: MediaQuery.of(context).size.width * 0.12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '4 800 F',
                  style: BgFonts.display(
                    size: 13,
                    weight: FontWeight.w700,
                    color: const Color(0xFF2A1A0E),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
            // Music chip.
            Positioned(
              top: 110,
              left: 16,
              child: Container(
                padding: const EdgeInsets.fromLTRB(7, 7, 12, 7),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF37221),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.music_note,
                          color: Colors.white, size: 12),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 180,
                      child: Text(
                        'Awilo Longomba — Coupé Bibamba',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BgFonts.body(
                          size: 11,
                          weight: FontWeight.w600,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Trim caption.
            Positioned(
              bottom: 178,
              left: 16,
              child: Text(
                '00:03 → 00:42 · 39s',
                style: BgFonts.mono(
                  size: 10,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
            // Trim timeline.
            Positioned(
              bottom: 130,
              left: 16,
              right: 16,
              child: SizedBox(
                height: 44,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: List.generate(
                          12,
                          (i) => Expanded(
                            child: PhotoPlaceholder(
                              seed: 'up-frame-$i',
                              showLabel: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 44,
                      right: 64,
                      top: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color(0xFFF37221), width: 3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Filter strip.
            Positioned(
              bottom: 200,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final on = i == filterIdx;
                    return GestureDetector(
                      onTap: () => onFilterChanged(i),
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
                                color: on
                                    ? const Color(0xFFF37221)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: const PhotoPlaceholder(
                              seed: 'up-preview',
                              showLabel: false,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            filters[i],
                            style: BgFonts.body(
                              size: 10,
                              weight: FontWeight.w600,
                              color: Colors.white.withValues(
                                  alpha: on ? 1 : 0.7),
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            // Tool tabs.
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: _EditToolTabs(l: l),
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
  const _PreviewBackdrop({required this.picked, required this.kind});

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
    // For video or no-pick fall back to the design's placeholder.
    return const PhotoPlaceholder(
      seed: 'up-preview',
      label: 'POULET BRAISÉ · TERRASSE',
      showLabel: true,
    );
  }
}

class _EditToolTabs extends StatelessWidget {
  final L l;
  const _EditToolTabs({required this.l});

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (Icons.content_cut, l.pick('Couper', 'Trim'), true),
      (Icons.image_outlined, l.pick('Miniature', 'Cover'), false),
      (Icons.text_fields_outlined, l.pick('Texte', 'Text'), false),
      (Icons.auto_awesome_outlined, l.pick('Stickers', 'Stickers'), false),
      (Icons.music_note_outlined, l.pick('Son', 'Sound'), false),
      (Icons.auto_fix_high_outlined, l.pick('Filtres', 'Filters'), false),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: tabs.map((t) {
          final color = t.$3
              ? const Color(0xFFF37221)
              : Colors.white.withValues(alpha: 0.85);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(t.$1, color: color, size: 20),
              const SizedBox(height: 5),
              Text(
                t.$2,
                style: BgFonts.body(
                  size: 10,
                  weight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.2,
                  height: 1,
                ),
              ),
            ],
          );
        }).toList(growable: false),
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
  final String kind;
  final String? placeName;
  final String? placeNeighborhood;
  final String? placePhotoUrl;
  final int audienceIdx;
  final Map<int, int> stars;
  final Set<int> selectedHashtags;
  final bool allowComments;
  final bool allowDuet;
  final bool publishing;
  final ValueChanged<int> onAudienceChanged;
  final void Function(int category, int stars) onStarChanged;
  final ValueChanged<int> onHashtagToggled;
  final ValueChanged<bool> onAllowCommentsChanged;
  final ValueChanged<bool> onAllowDuetChanged;
  final VoidCallback onBack;
  final VoidCallback onPublish;
  final VoidCallback onSaveDraft;

  const _PublishStep({
    required this.captionCtl,
    required this.picked,
    required this.kind,
    required this.placeName,
    required this.placeNeighborhood,
    required this.placePhotoUrl,
    required this.audienceIdx,
    required this.stars,
    required this.selectedHashtags,
    required this.allowComments,
    required this.allowDuet,
    required this.publishing,
    required this.onAudienceChanged,
    required this.onStarChanged,
    required this.onHashtagToggled,
    required this.onAllowCommentsChanged,
    required this.onAllowDuetChanged,
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
    final hashtags = l.isFr
        ? const ['#abidjan', '#cocody', '#maquis', '#poulet', '#bonplan']
        : const ['#abidjan', '#cocody', '#maquis', '#chicken', '#mustgo'];
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
                  _PublishPreview(picked: picked, kind: kind),
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
                            "Le poulet braisé est top, l'attente un peu longue mais ça vaut le coup #cocody #maquis",
                            'The grilled chicken is great, wait was a bit long but worth it #cocody #maquis',
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
                                final filled = s < (stars[i] ?? 4);
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
            // Hashtags.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(
                    text: l.pick('Hashtags suggérés', 'Suggested hashtags'),
                    palette: p,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(hashtags.length, (i) {
                      final on = selectedHashtags.contains(i);
                      return GestureDetector(
                        onTap: () => onHashtagToggled(i),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            color: on ? p.orange : p.card,
                            borderRadius: BorderRadius.circular(999),
                            border: on
                                ? null
                                : Border.all(color: p.cardBorder),
                          ),
                          child: Text(
                            hashtags[i],
                            style: BgFonts.body(
                              size: 12,
                              weight: FontWeight.w600,
                              color: on ? Colors.white : p.ink,
                              height: 1,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            // Audience.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(
                    text: l.pick('Audience', 'Audience'),
                    palette: p,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: p.card,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: p.cardBorder),
                    ),
                    child: Row(
                      children: [
                        _audPill(p, l.pick('Public', 'Public'),
                            Icons.public, 0),
                        _audPill(p, l.pick('Abonnés', 'Followers'),
                            Icons.people_outline, 1),
                        _audPill(p, l.pick('Privé', 'Private'),
                            Icons.lock_outline, 2),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Toggles.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.cardBorder),
                ),
                child: Column(
                  children: [
                    _ToggleRow(
                      label: l.pick('Autoriser les commentaires',
                          'Allow comments'),
                      value: allowComments,
                      onChanged: onAllowCommentsChanged,
                      palette: p,
                      withDivider: true,
                    ),
                    _ToggleRow(
                      label: l.pick('Autoriser les duos', 'Allow duets'),
                      value: allowDuet,
                      onChanged: onAllowDuetChanged,
                      palette: p,
                    ),
                  ],
                ),
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

  Widget _audPill(BgPalette p, String label, IconData icon, int idx) {
    final on = audienceIdx == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => onAudienceChanged(idx),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: on ? p.orange : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 13, color: on ? Colors.white : p.ink),
              const SizedBox(width: 5),
              Text(
                label,
                style: BgFonts.body(
                  size: 12,
                  weight: FontWeight.w600,
                  color: on ? Colors.white : p.ink,
                  height: 1,
                ),
              ),
            ],
          ),
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

class _PublishPreview extends StatelessWidget {
  final XFile? picked;
  final String kind;
  const _PublishPreview({required this.picked, required this.kind});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (picked != null && kind == 'photo')
                Image.file(
                  File(picked!.path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const PhotoPlaceholder(
                    seed: 'up-preview',
                    label: 'POULET',
                    showLabel: true,
                  ),
                )
              else
                const PhotoPlaceholder(
                  seed: 'up-preview',
                  label: 'POULET',
                  showLabel: true,
                ),
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
              if (kind == 'video')
                Center(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.play_arrow,
                        size: 14, color: Colors.white),
                  ),
                ),
            ],
          ),
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

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final BgPalette palette;
  final bool withDivider;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.palette,
    this.withDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: withDivider
            ? Border(bottom: BorderSide(color: palette.cardBorder))
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: BgFonts.body(
              size: 13,
              weight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(!value),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 40,
              height: 24,
              decoration: BoxDecoration(
                color: value
                    ? palette.orange
                    : const Color(0x2E785028),
                borderRadius: BorderRadius.circular(999),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 150),
                alignment:
                    value ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
