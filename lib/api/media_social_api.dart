import 'package:dio/dio.dart';
import 'api_error.dart';
import 'client.dart';

class MediaCommentAuthor {
  final String id;
  final String name;
  final String? avatarUrl;

  const MediaCommentAuthor({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory MediaCommentAuthor.fromJson(Map<String, dynamic> json) {
    return MediaCommentAuthor(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      avatarUrl: resolveMediaUrl(json['avatar_url']?.toString()),
    );
  }
}

class MediaComment {
  /// The prefixed id ("mc_88") returned on reads.
  final String id;

  /// Bare numeric id used on the delete write path. On the spec,
  /// `mc_88` strips to `88`. We compute it once here so screens don't
  /// have to think about it.
  final String? deleteId;

  final String text;
  final MediaCommentAuthor author;
  final String? createdAt;
  final String? when;

  const MediaComment({
    required this.id,
    required this.text,
    required this.author,
    this.deleteId,
    this.createdAt,
    this.when,
  });

  factory MediaComment.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final stripped = id.startsWith('mc_') ? id.substring(3) : id;
    final authorMap = json['author'];
    return MediaComment(
      id: id,
      deleteId: stripped.isEmpty ? null : stripped,
      text: json['text']?.toString() ?? '',
      author: authorMap is Map
          ? MediaCommentAuthor.fromJson(Map<String, dynamic>.from(authorMap))
          : const MediaCommentAuthor(id: '', name: ''),
      createdAt: json['created_at']?.toString(),
      when: json['when']?.toString(),
    );
  }
}

class MediaCommentsPage {
  final List<MediaComment> items;
  final int total;
  final String? nextCursor;
  const MediaCommentsPage({
    required this.items,
    required this.total,
    this.nextCursor,
  });
}

class MediaLikeResult {
  final int likesCount;
  final bool userLiked;
  const MediaLikeResult({required this.likesCount, required this.userLiked});

  factory MediaLikeResult.fromJson(Map<String, dynamic> json) {
    return MediaLikeResult(
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      userLiked: json['user_liked'] == true,
    );
  }
}

class MediaCommentPostResult {
  final MediaComment comment;
  final int commentsCount;
  const MediaCommentPostResult({
    required this.comment,
    required this.commentsCount,
  });
}

class MediaSocialApi {
  final ApiClient _client;
  MediaSocialApi(this._client);

  Future<MediaLikeResult> like(String mediaId) async {
    try {
      final res = await _client.dio.post('/media/$mediaId/like');
      return MediaLikeResult.fromJson(_asMap(res.data));
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  Future<MediaLikeResult> unlike(String mediaId) async {
    try {
      final res = await _client.dio.delete('/media/$mediaId/like');
      return MediaLikeResult.fromJson(_asMap(res.data));
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  Future<MediaCommentsPage> getComments(
    String mediaId, {
    int? page,
    int? limit,
  }) async {
    try {
      final res = await _client.dio.get(
        '/media/$mediaId/comments',
        queryParameters: {
          'page': ?page,
          'limit': ?limit,
        },
      );
      final body = _asMap(res.data);
      final items = (body['items'] as List?)
              ?.whereType<Map>()
              .map((e) => MediaComment.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false) ??
          const <MediaComment>[];
      return MediaCommentsPage(
        items: items,
        total: (body['total'] as num?)?.toInt() ?? items.length,
        nextCursor: body['next_cursor']?.toString(),
      );
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  Future<MediaCommentPostResult> postComment(
    String mediaId, {
    required String text,
  }) async {
    try {
      final res = await _client.dio.post(
        '/media/$mediaId/comments',
        data: {'text': text},
      );
      final body = _asMap(res.data);
      final commentMap = body['comment'];
      if (commentMap is! Map) {
        throw ApiError(message: 'Malformed comment response');
      }
      return MediaCommentPostResult(
        comment:
            MediaComment.fromJson(Map<String, dynamic>.from(commentMap)),
        commentsCount: (body['comments_count'] as num?)?.toInt() ?? 0,
      );
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  /// [commentId] must be the bare numeric id (e.g. "88"). Use
  /// [MediaComment.deleteId] which strips the `mc_` prefix automatically.
  Future<int> deleteComment(String mediaId, String commentId) async {
    try {
      final res =
          await _client.dio.delete('/media/$mediaId/comments/$commentId');
      final body = _asMap(res.data);
      return (body['comments_count'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }
}
