import 'dart:convert';
import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String code;
  final String? detail;
  final int? status;
  final int? retryAfterSec;
  final int? active;
  final int? limit;

  ApiException(this.code,
      {this.detail, this.status, this.retryAfterSec, this.active, this.limit});

  static Map<String, dynamic>? _ensureMap(dynamic data) {
    if (data is Map) return data.cast<String, dynamic>();
    if (data is String) {
      try {
        final d = jsonDecode(data);
        if (d is Map) return d.cast<String, dynamic>();
      } catch (_) {}
    }
    return null;
  }

  static T? _get<T>(Map<String, dynamic>? m, String k) {
    final v = m == null ? null : m[k];
    return v is T ? v : null;
  }

  static int? _parseRetryAfter(Response? r, Map<String, dynamic>? body) {
    final h = r?.headers.value('retry-after');
    final v = h == null ? null : int.tryParse(h.trim());
    if (v != null && v >= 0) return v;
    final b = _get<int>(body, 'retryAfter');
    return b;
  }

  factory ApiException.fromDio(DioException e) {
    final r = e.response;
    final status = r?.statusCode;
    final body = _ensureMap(r?.data);

    if (status == null) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return ApiException('timeout', detail: e.message);
        case DioExceptionType.cancel:
          return ApiException('canceled', detail: e.message);
        case DioExceptionType.connectionError:
        case DioExceptionType.badCertificate:
          return ApiException('network_error', detail: e.message);
        default:
          return ApiException('network_error', detail: e.message);
      }
    }

    final code = _get<String>(body, 'error') ?? 'server_error';
    final detail =
        _get<String>(body, 'detail') ?? _get<String>(body, 'message');

    if (status == 429) {
      final ra = _parseRetryAfter(r, body) ?? 3600;
      final active = _get<int>(body, 'active');
      final limit = _get<int>(body, 'limit');
      return ApiException(code,
          detail: detail ?? 'HTTP 429',
          status: 429,
          retryAfterSec: ra,
          active: active,
          limit: limit);
    }

    if (status >= 500 && status < 600 && code == 'server_error') {
      return ApiException('internal_error',
          detail: detail ?? 'HTTP $status', status: status);
    }

    return ApiException(code, detail: detail ?? 'HTTP $status', status: status);
  }

  @override
  String toString() =>
      'ApiException($code${detail != null ? ": $detail" : ""})';
}
