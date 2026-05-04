import 'package:dio/dio.dart';
import 'api_error.dart';
import 'client.dart';

class ChatMessage {
  final String id;
  /// Either "user" or "assistant".
  final String role;
  final String content;
  final DateTime? createdAt;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.createdAt,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final t = json['created_at']?.toString();
    return ChatMessage(
      id: json['id'].toString(),
      role: json['role']?.toString() ?? 'assistant',
      content: json['content']?.toString() ?? '',
      createdAt: t == null ? null : DateTime.tryParse(t),
    );
  }
}

class ChatHistoryPage {
  final List<ChatMessage> items;
  final int total;
  final String? nextCursor;
  const ChatHistoryPage({
    required this.items,
    required this.total,
    this.nextCursor,
  });
}

class ChatApi {
  final ApiClient _client;
  ChatApi(this._client);

  Future<ChatMessage> sendMessage(String slug, String message) async {
    try {
      final res = await _client.dio.post(
        '/places/$slug/chat/messages',
        data: {'message': message},
      );
      final body = res.data;
      final raw = body is Map && body['data'] is Map
          ? body['data'] as Map
          : body as Map;
      return ChatMessage.fromJson(Map<String, dynamic>.from(raw));
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  Future<ChatHistoryPage> getHistory(
    String slug, {
    int? limit,
    String? page,
  }) async {
    try {
      final res = await _client.dio.get(
        '/places/$slug/chat/messages',
        queryParameters: {
          'limit': ?limit,
          'page': ?page,
        },
      );
      final data = res.data as Map<String, dynamic>;
      final items = (data['items'] as List?)
              ?.whereType<Map>()
              .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false) ??
          const [];
      return ChatHistoryPage(
        items: items,
        total: (data['total'] as num?)?.toInt() ?? items.length,
        nextCursor: data['next_cursor']?.toString(),
      );
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  Future<void> clearHistory(String slug) async {
    try {
      await _client.dio.delete('/places/$slug/chat');
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }
}
