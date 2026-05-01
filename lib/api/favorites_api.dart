import 'package:dio/dio.dart';
import '../data.dart';
import 'api_error.dart';
import 'client.dart';

class FavoritesApi {
  final ApiClient _client;
  FavoritesApi(this._client);

  Future<List<Place>> list() async {
    try {
      final res = await _client.dio.get('/me/favorites');
      final raw = _unwrapList(res.data);
      return raw
          .whereType<Map>()
          .map((e) => Place.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  /// Pull a list out of any of the envelopes the backend uses for /me/favorites:
  /// bare `[...]`, paged `{items: [...]}`, wrapped `{data: [...]}`, or wrapped-
  /// paged `{data: {items: [...]}}`. See backend gotcha #9.
  static List _unwrapList(dynamic body) {
    if (body is List) return body;
    if (body is Map) {
      if (body['items'] is List) return body['items'] as List;
      final data = body['data'];
      if (data is List) return data;
      if (data is Map && data['items'] is List) return data['items'] as List;
    }
    return const [];
  }

  Future<void> add(String placeId) async {
    try {
      await _client.dio.post('/me/favorites', data: {'place_id': placeId});
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  Future<void> remove(String placeId) async {
    try {
      await _client.dio.delete('/me/favorites/$placeId');
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }
}
