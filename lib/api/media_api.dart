import 'dart:io';
import 'package:dio/dio.dart';
import 'api_error.dart';
import 'client.dart' show ApiClient, resolveMediaUrl;

class MediaUploadResult {
  final String id;
  final String url;
  final String? thumbUrl;
  final String kind;
  final String? duration;
  final String seed;

  const MediaUploadResult({
    required this.id,
    required this.url,
    required this.kind,
    required this.seed,
    this.thumbUrl,
    this.duration,
  });

  factory MediaUploadResult.fromJson(Map<String, dynamic> json) {
    return MediaUploadResult(
      id: json['id'].toString(),
      url: resolveMediaUrl(json['url']?.toString()) ?? '',
      thumbUrl: resolveMediaUrl(json['thumb_url']?.toString()),
      kind: json['kind']?.toString() ?? 'photo',
      duration: json['duration']?.toString(),
      seed: json['seed']?.toString() ?? json['id'].toString(),
    );
  }
}

class MediaApi {
  final ApiClient _client;
  MediaApi(this._client);

  Future<MediaUploadResult> upload({
    required File file,
    required String kind,
    required String placeId,
    String? category,
    String? label,
    File? thumb,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
        'kind': kind,
        'place_id': placeId,
        'category': ?category,
        'label': ?label,
        if (thumb != null)
          'thumb': await MultipartFile.fromFile(thumb.path),
      });
      final res = await _client.dio.post('/media/upload', data: form);
      return MediaUploadResult.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }
}
