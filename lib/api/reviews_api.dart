import 'package:dio/dio.dart';
import '../data.dart';
import 'api_error.dart';
import 'client.dart';

class HelpfulState {
  final int helpfulCount;
  final bool userMarkedHelpful;
  const HelpfulState({
    required this.helpfulCount,
    required this.userMarkedHelpful,
  });

  factory HelpfulState.fromJson(Map<String, dynamic> json) {
    return HelpfulState(
      helpfulCount: (json['helpful_count'] as num?)?.toInt() ?? 0,
      userMarkedHelpful: json['user_marked_helpful'] == true,
    );
  }
}

/// Strip the "rv_" or "m" prefix the API returns; write paths take bare ints.
String _stripIdPrefix(String id) {
  if (id.startsWith('rv_')) return id.substring(3);
  if (id.startsWith('m_')) return id.substring(2);
  if (id.startsWith('m')) {
    final rest = id.substring(1);
    if (int.tryParse(rest) != null) return rest;
  }
  return id;
}

class ReviewsApi {
  final ApiClient _client;
  ReviewsApi(this._client);

  Future<ReviewItem> postReview(
    String slug, {
    required int rating,
    required String text,
    required Map<String, int> sub,
    required List<String> tags,
    List<String> mediaIds = const [],
  }) async {
    try {
      final res = await _client.dio.post(
        '/places/$slug/reviews',
        data: {
          'rating': rating,
          'text': text,
          'sub': sub,
          'tags': tags,
          'media_ids': mediaIds,
        },
      );
      final data = res.data;
      if (data is Map && data['review'] is Map) {
        return ReviewItem.fromJson(
          Map<String, dynamic>.from(data['review'] as Map),
        );
      }
      if (data is Map<String, dynamic>) return ReviewItem.fromJson(data);
      throw ApiError(message: 'Unexpected review response');
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  Future<void> deleteReview(String reviewId) async {
    try {
      await _client.dio.delete('/reviews/${_stripIdPrefix(reviewId)}');
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  Future<HelpfulState> markHelpful(String reviewId) async {
    try {
      final res = await _client.dio.post(
        '/reviews/${_stripIdPrefix(reviewId)}/helpful',
      );
      return HelpfulState.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  Future<HelpfulState> unmarkHelpful(String reviewId) async {
    try {
      final res = await _client.dio.delete(
        '/reviews/${_stripIdPrefix(reviewId)}/helpful',
      );
      // Some servers may return 204 with no body — guard.
      final data = res.data;
      if (data is Map<String, dynamic>) return HelpfulState.fromJson(data);
      return const HelpfulState(
          helpfulCount: 0, userMarkedHelpful: false);
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }
}
