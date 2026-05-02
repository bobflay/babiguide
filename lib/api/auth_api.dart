import 'package:dio/dio.dart';
import 'api_error.dart';
import 'client.dart';
import 'models.dart';

class AuthApi {
  final ApiClient _client;
  AuthApi(this._client);

  Future<AuthResult> signup({
    required String name,
    required String password,
    String? email,
    String? phone,
  }) async {
    if ((email == null || email.isEmpty) && (phone == null || phone.isEmpty)) {
      throw ApiError(message: 'Email or phone is required');
    }
    try {
      final res = await _client.dio.post(
        '/auth/signup',
        data: {
          'name': name,
          'email': ?(email != null && email.isNotEmpty ? email : null),
          'phone': ?(phone != null && phone.isNotEmpty ? phone : null),
          'password': password,
        },
      );
      return AuthResult.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  Future<AuthResult> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    if ((email == null || email.isEmpty) && (phone == null || phone.isEmpty)) {
      throw ApiError(message: 'Email or phone is required');
    }
    try {
      final res = await _client.dio.post(
        '/auth/login',
        data: {
          'email': ?(email != null && email.isNotEmpty ? email : null),
          'phone': ?(phone != null && phone.isNotEmpty ? phone : null),
          'password': password,
        },
      );
      return AuthResult.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  Future<void> logout() async {
    try {
      await _client.dio.post('/auth/logout');
    } on DioException catch (e) {
      // 401 means the token is already invalid; treat as success.
      if (e.response?.statusCode == 401) return;
      throw ApiError.fromDio(e);
    }
  }

  Future<AuthResult> refresh() async {
    try {
      final res = await _client.dio.post('/auth/refresh');
      return AuthResult.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  Future<User> me() async {
    try {
      final res = await _client.dio.get('/me');
      return User.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  Future<void> requestPasswordReset({required String email}) async {
    try {
      await _client.dio.post(
        '/auth/forgot-password',
        data: {'email': email},
      );
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }
}
