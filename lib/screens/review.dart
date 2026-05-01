import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api/api_error.dart';
import '../api/media_api.dart';
import '../app_state.dart';
import '../constants.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets/photo_placeholder.dart';

class ReviewScreen extends StatefulWidget {
  final String? slug;
  final String? placeName;
  final String? placeNeighborhood;
  final String? coverPhotoUrl;
  final VoidCallback? onCancel;
  final VoidCallback? onPublish;

  const ReviewScreen({
    super.key,
    this.slug,
    this.placeName,
    this.placeNeighborhood,
    this.coverPhotoUrl,
    this.onCancel,
    this.onPublish,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _overall = 5;
  final Map<String, int> _cats = {
    for (final k in reviewSubKeys) k: 4,
  };
  final Set<int> _tagIndexes = {0, 2};
  final TextEditingController _text = TextEditingController();
  bool _busy = false;
  String? _error;
  Map<String, List<String>> _fieldErrors = const {};

  static const int _maxPhotos = 4;
  final ImagePicker _picker = ImagePicker();
  final List<MediaUploadResult> _uploaded = [];
  int _uploading = 0;

  @override
  void initState() {
    super.initState();
    _cats['food'] = 5;
    _cats['staff'] = 5;
    _cats['toilet'] = 4;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final state = AppScope.of(context);
    final l = L(state.lang);
    final slug = widget.slug;
    if (slug == null || slug.isEmpty) {
      setState(() => _error = l.pick(
            'Restaurant introuvable.',
            'Place not found.',
          ));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _fieldErrors = const {};
    });
    final tags = _tagIndexes
        .map((i) => reviewTagsFr[i])
        .toList(growable: false);
    try {
      await state.reviewsApi.postReview(
        slug,
        rating: _overall,
        text: _text.text.trim(),
        sub: _cats,
        tags: tags,
        mediaIds: _uploaded.map((m) => m.id).toList(growable: false),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.pick('Avis publié, merci !', 'Review posted, thanks!')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onPublish?.call();
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _fieldErrors = e.fieldErrors;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onAddPhotoTap() async {
    if (_uploaded.length + _uploading >= _maxPhotos) {
      final l = L(AppScope.of(context).lang);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l.photoLimitReached),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final source = await _showSourceSheet();
    if (source == null) return;
    await _pickAndUpload(source);
  }

  Future<ImageSource?> _showSourceSheet() {
    final l = L(AppScope.of(context).lang);
    final p = AppScope.of(context).palette;
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: p.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: p.ink),
              title: Text(l.pickFromGallery,
                  style: BgFonts.body(
                      size: 14, weight: FontWeight.w600, color: p.ink)),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: Icon(Icons.photo_camera_outlined, color: p.ink),
              title: Text(l.pickFromCamera,
                  style: BgFonts.body(
                      size: 14, weight: FontWeight.w600, color: p.ink)),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              title: Center(
                child: Text(l.cancel,
                    style: BgFonts.body(
                        size: 14,
                        weight: FontWeight.w600,
                        color: p.inkMuted)),
              ),
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    final state = AppScope.of(context);
    final l = L(state.lang);
    final slug = widget.slug;
    if (slug == null || slug.isEmpty) return;
    XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2048,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l.photoUploadFailed),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (picked == null) return;
    setState(() => _uploading += 1);
    try {
      final result = await state.mediaApi.upload(
        file: File(picked.path),
        kind: 'photo',
        placeId: slug,
      );
      if (!mounted) return;
      setState(() => _uploaded.add(result));
    } on ApiError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l.photoUploadFailed),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _uploading -= 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.palette;
    final l = L(state.lang);

    return Container(
      color: p.bg,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          Container(
            color: p.bg,
            padding: const EdgeInsets.fromLTRB(16, 54, 16, 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onCancel,
                  child: Text(
                    l.cancel,
                    style: BgFonts.body(
                      size: 14,
                      weight: FontWeight.w600,
                      color: p.inkMuted,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      l.reviewTitle,
                      style: BgFonts.display(
                        size: 17,
                        weight: FontWeight.w700,
                        color: p.ink,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _busy ? null : _submit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _busy
                          ? p.orange.withValues(alpha: 0.6)
                          : p.orange,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: _busy
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
                              height: 1.0,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0x14C8551A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x33C8551A)),
                ),
                child: Text(
                  _error!,
                  style: BgFonts.body(
                    size: 13,
                    color: p.orangeDeep,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.cardBorder),
              ),
              child: Row(
                children: [
                  PhotoPlaceholder(
                    seed: widget.slug ?? 'rev-place',
                    showLabel: false,
                    width: 50,
                    height: 50,
                    borderRadius: BorderRadius.circular(10),
                    photoUrl: widget.coverPhotoUrl,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.placeName ??
                              l.pick('Restaurant', 'Place'),
                          style: BgFonts.display(
                            size: 15,
                            weight: FontWeight.w700,
                            color: p.ink,
                          ),
                        ),
                        if ((widget.placeNeighborhood ?? '').isNotEmpty)
                          Text(
                            widget.placeNeighborhood!,
                            style:
                                BgFonts.body(size: 12, color: p.inkMuted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              children: [
                Text(
                  l.overall.toUpperCase(),
                  style: BgFonts.body(
                    size: 12,
                    weight: FontWeight.w700,
                    color: p.inkMuted,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 12),
                _StarPick(
                  value: _overall,
                  size: 32,
                  onChange: (v) => setState(() => _overall = v),
                ),
                const SizedBox(height: 8),
                Text(
                  l.overallLabel(_overall),
                  style: BgFonts.display(
                    size: 15,
                    weight: FontWeight.w700,
                    color: p.orangeDeep,
                  ),
                ),
                if (_fieldErrors['rating']?.first != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _fieldErrors['rating']!.first,
                      style: BgFonts.body(
                          size: 11,
                          color: p.orangeDeep,
                          weight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.breakdown.toUpperCase(),
                  style: BgFonts.body(
                    size: 12,
                    weight: FontWeight.w700,
                    color: p.inkMuted,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.cardBorder),
                  ),
                  child: Column(
                    children: List.generate(reviewSubKeys.length, (i) {
                      final key = reviewSubKeys[i];
                      final label = l.reviewCats[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: i < reviewSubKeys.length - 1
                                  ? p.cardBorder
                                  : Colors.transparent,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: BgFonts.body(
                                  size: 13,
                                  weight: FontWeight.w600,
                                  color: p.ink,
                                ),
                              ),
                            ),
                            _StarPick(
                              value: _cats[key] ?? 4,
                              size: 16,
                              onChange: (v) =>
                                  setState(() => _cats[key] = v),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.reviewMedia.toUpperCase(),
                  style: BgFonts.body(
                    size: 12,
                    weight: FontWeight.w700,
                    color: p.inkMuted,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 4,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final m in _uploaded)
                      _UploadedTile(
                        media: m,
                        onRemove: () =>
                            setState(() => _uploaded.remove(m)),
                      ),
                    for (int i = 0; i < _uploading; i++)
                      Container(
                        decoration: BoxDecoration(
                          color: p.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: p.cardBorder),
                        ),
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(p.orangeDeep),
                          ),
                        ),
                      ),
                    if (_uploaded.length + _uploading < _maxPhotos)
                      GestureDetector(
                        onTap: _onAddPhotoTap,
                        child: Container(
                          decoration: BoxDecoration(
                            color: p.card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: p.cardBorder,
                              width: 2,
                            ),
                          ),
                          child: Icon(Icons.camera_alt_outlined,
                              size: 20, color: p.orangeDeep),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.reviewText.toUpperCase(),
                  style: BgFonts.body(
                    size: 12,
                    weight: FontWeight.w700,
                    color: p.inkMuted,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _fieldErrors['text']?.isNotEmpty == true
                          ? p.orangeDeep
                          : p.cardBorder,
                    ),
                  ),
                  constraints: const BoxConstraints(minHeight: 100),
                  child: TextField(
                    controller: _text,
                    maxLines: 6,
                    minLines: 4,
                    maxLength: 2000,
                    style: BgFonts.body(
                        size: 13, color: p.ink, height: 1.5),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: l.reviewPlaceholder,
                      hintStyle: BgFonts.body(
                          size: 13,
                          color: p.inkMuted,
                          height: 1.5),
                      counterText: '',
                    ),
                  ),
                ),
                if (_fieldErrors['text']?.first != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _fieldErrors['text']!.first,
                      style: BgFonts.body(
                          size: 11,
                          color: p.orangeDeep,
                          weight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.reviewTags.toUpperCase(),
                  style: BgFonts.body(
                    size: 12,
                    weight: FontWeight.w700,
                    color: p.inkMuted,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(l.reviewTagList.length, (i) {
                    final on = _tagIndexes.contains(i);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (on) {
                            _tagIndexes.remove(i);
                          } else {
                            _tagIndexes.add(i);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: on ? p.orange : p.card,
                          borderRadius: BorderRadius.circular(999),
                          border: on
                              ? null
                              : Border.all(color: p.cardBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (on) ...[
                              const Icon(Icons.check,
                                  size: 11, color: Colors.white),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              l.reviewTagList[i],
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
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadedTile extends StatelessWidget {
  final MediaUploadResult media;
  final VoidCallback onRemove;
  const _UploadedTile({required this.media, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    final thumb = media.thumbUrl ?? media.url;
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            color: p.card,
            child: thumb.isEmpty
                ? Icon(Icons.image_outlined, color: p.inkMuted)
                : Image.network(
                    thumb,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Icon(Icons.broken_image_outlined, color: p.inkMuted),
                  ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _StarPick extends StatelessWidget {
  final int value;
  final double size;
  final ValueChanged<int> onChange;
  const _StarPick({required this.value, this.size = 28, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < value;
        return GestureDetector(
          onTap: () => onChange(i + 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: filled ? p.orange : const Color(0x2E785028),
            ),
          ),
        );
      }),
    );
  }
}
