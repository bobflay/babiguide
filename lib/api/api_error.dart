import 'package:dio/dio.dart';

class ApiError implements Exception {
  final int? status;
  final String message;
  final String? code;
  final Map<String, List<String>> fieldErrors;

  ApiError({
    required this.message,
    this.status,
    this.code,
    this.fieldErrors = const {},
  });

  bool get isUnauthorized => status == 401;
  bool get isValidation => status == 422;
  bool get isNetwork => status == null;

  String? firstFieldError(String field) {
    final errs = fieldErrors[field];
    return (errs == null || errs.isEmpty) ? null : errs.first;
  }

  factory ApiError.fromDio(DioException e) {
    final res = e.response;
    if (res == null) {
      return ApiError(
        message: e.message ?? 'Network error',
      );
    }
    final data = res.data;
    if (data is Map) {
      // Spec shape: { error: { code, message, details } }
      final err = data['error'];
      if (err is Map) {
        return ApiError(
          status: res.statusCode,
          code: err['code']?.toString(),
          message: err['message']?.toString() ?? 'Request failed',
        );
      }
      // Laravel validation shape: { message, errors: { field: [...] } }
      final errors = data['errors'];
      final fieldErrors = <String, List<String>>{};
      if (errors is Map) {
        errors.forEach((k, v) {
          if (v is List) {
            fieldErrors[k.toString()] =
                v.map((x) => x.toString()).toList(growable: false);
          }
        });
      }
      return ApiError(
        status: res.statusCode,
        message: data['message']?.toString() ?? 'Request failed',
        fieldErrors: fieldErrors,
      );
    }
    return ApiError(
      status: res.statusCode,
      message: 'Request failed (${res.statusCode})',
    );
  }

  @override
  String toString() => 'ApiError($status, $code): $message';
}
