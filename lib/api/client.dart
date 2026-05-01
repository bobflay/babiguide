import 'package:dio/dio.dart';
import 'token_storage.dart';

/// Some endpoints return relative storage paths (e.g. "places/abc.png")
/// instead of absolute URLs. Prefix those with the Laravel storage host so
/// `Image.network` can fetch them. Absolute URLs and null/empty values pass
/// through unchanged.
String? resolveMediaUrl(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  final trimmed = raw.startsWith('/') ? raw.substring(1) : raw;
  return 'https://babiguide.online/storage/$trimmed';
}

class ApiClient {
  static const String baseUrl = 'https://babiguide.online/api/v1';

  final Dio dio;
  final TokenStorage tokens;

  String? _cachedToken;

  ApiClient._(this.dio, this.tokens);

  factory ApiClient(TokenStorage tokens) {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      responseType: ResponseType.json,
    ));
    final client = ApiClient._(dio, tokens);
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = client._cachedToken ?? await tokens.read();
        client._cachedToken = token;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
    return client;
  }

  void setToken(String? token) {
    _cachedToken = token;
  }

  Future<void> clearToken() async {
    _cachedToken = null;
    await tokens.clear();
  }
}
