import 'package:dio/dio.dart';
import 'api_error.dart';
import 'client.dart';
import 'models.dart';

class MeApi {
  final ApiClient _client;
  MeApi(this._client);

  Future<void> postLocation({
    required double lat,
    required double lng,
    double? accuracyM,
  }) async {
    try {
      await _client.dio.post(
        '/me/location',
        data: {
          'lat': lat,
          'lng': lng,
          'accuracy_m': ?accuracyM,
        },
      );
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  Future<User> putSettings({
    String? lang,
    bool? darkMode,
    bool? locationEnabled,
    bool? notificationsEnabled,
  }) async {
    try {
      final res = await _client.dio.put(
        '/me/settings',
        data: {
          'lang': ?lang,
          'dark_mode': ?darkMode,
          'location_enabled': ?locationEnabled,
          'notifications_enabled': ?notificationsEnabled,
        },
      );
      return User.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }
}
