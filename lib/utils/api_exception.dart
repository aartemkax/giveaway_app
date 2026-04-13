// lib/utils/api_exception.dart
import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String code;
  final String? detail;

  // ← додано
  final int? status;
  final int? retryAfterSec;
  final int? active;
  final int? limit;

  ApiException(
    this.code, {
    this.detail,
    this.status,
    this.retryAfterSec,
    this.active,
    this.limit,
  });

  @override
  String toString() {
    final extras = <String, Object?>{
      if (status != null) 'status': status,
      if (retryAfterSec != null) 'retry': retryAfterSec,
      if (active != null) 'active': active,
      if (limit != null) 'limit': limit,
      if (detail != null) 'detail': detail,
    };
    return 'ApiException($code${extras.isEmpty ? '' : ' $extras'})';
  }

  static ApiException fromDio(DioException e) {
    final r = e.response;
    String code = 'network_error';
    String? detail;
    int? status;

    if (r != null) {
      status = r.statusCode;
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

      if (status == 401 && code == 'invalid_credentials') {
        return ApiException('invalid_credentials',
            detail: detail, status: status);
      }
      if (status == 401 && code == 'login_required') {
        return ApiException('login_required', detail: detail, status: status);
      }
      if (status == 412 && code == 'instagram_challenge') {
        return ApiException('instagram_challenge',
            detail: detail, status: status);
      }
      if (status == 412 && code == 'sessionid_challenge') {
        return ApiException('sessionid_challenge',
            detail: detail, status: status);
      }
      if (status == 429 && code == 'rate_limited') {
        return ApiException('rate_limited', detail: detail, status: status);
      }
      if (status == 403 && code == 'suspicious_login') {
        return ApiException('suspicious_login', detail: detail, status: status);
      }
      return ApiException(code,
          detail: detail ?? 'HTTP $status', status: status);
    }

    return ApiException('network_error', detail: e.message);
  }
}
