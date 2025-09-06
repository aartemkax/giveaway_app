// lib/utils/api_exception.dart
import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String code;
  final String? detail;
  ApiException(this.code, {this.detail});

  @override
  String toString() =>
      'ApiException($code${detail != null ? ": $detail" : ""})';

  static ApiException fromDio(DioException e) {
    final r = e.response;
    String code = 'network_error';
    String? detail;

    if (r != null) {
      code = 'server_error';
      try {
        final data = r.data;
        if (data is Map) {
          code = (data['error'] as String?) ?? code;
          detail = (data['detail'] as String?) ?? (data['message'] as String?);
        } else if (data is String) {
          detail = data;
        }
      } catch (_) {}
      // мапінг типових кодів з бекенда
      if (r.statusCode == 401 && code == 'invalid_credentials') {
        return ApiException('invalid_credentials', detail: detail);
      }
      if (r.statusCode == 401 && code == 'login_required') {
        return ApiException('login_required', detail: detail);
      }
      if (r.statusCode == 412 && code == 'instagram_challenge') {
        return ApiException('instagram_challenge', detail: detail);
      }
      if (r.statusCode == 403 && code == 'suspicious_login') {
        return ApiException('suspicious_login', detail: detail);
      }
      return ApiException(code, detail: detail ?? 'HTTP ${r.statusCode}');
    }

    // без response
    return ApiException('network_error', detail: e.message);
  }
}
