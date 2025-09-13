import 'dart:convert';
import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String code;
  final String? detail;
  final int? status;
  final int? retryAfterSec;

  ApiException(this.code, {this.detail, this.status, this.retryAfterSec});

  @override
  String toString() =>
      'ApiException($code${detail != null ? ": $detail" : ""})';

  static int? _parseRetryAfter(Response? r, Map<String, dynamic>? body) {
    if (r != null) {
      final h = r.headers.value('retry-after');
      if (h != null) {
        final v = int.tryParse(h.trim());
        if (v != null && v >= 0) return v;
      }
    }
    final b = body?['retryAfter'];
    if (b is int && b >= 0) return b;
    return null;
  }

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

  // Розбір транспортних помилок + делегування на розбір HTTP-відповіді
  static ApiException _transport(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException('timeout', detail: e.message);
      case DioExceptionType.cancel:
        return ApiException('canceled', detail: e.message);
      case DioExceptionType.connectionError:
        return ApiException('network_error', detail: e.message);
      case DioExceptionType.badCertificate:
        return ApiException('network_error', detail: 'bad_certificate');
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return _fromResponse(e);
    }
  }

  // Розбір HTTP-відповіді
  static ApiException _fromResponse(DioException e) {
    final r = e.response;
    if (r == null) return ApiException('network_error', detail: e.message);

    final status = r.statusCode ?? 0;
    final body = _ensureMap(r.data);

    String code = (body?['error'] as String?) ?? 'server_error';
    final detail =
        (body?['detail'] as String?) ?? (body?['message'] as String?);

    // 429: відрізняємо ліміт черги від Instagram rate-limit
    if (status == 429) {
      final parsedCode = body?['error'] as String?;
      final retry =
          _parseRetryAfter(r, body) ?? 3600; // фолбек під RQ_DEFAULT_RESULT_TTL
      final actual =
          (parsedCode == 'rate_limited') ? 'rate_limited' : 'too_many_jobs';
      return ApiException(actual,
          detail: detail ?? 'HTTP 429', status: 429, retryAfterSec: retry);
    }

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
    if (status == 403 && code == 'suspicious_login') {
      return ApiException('suspicious_login', detail: detail, status: status);
    }
    if (status == 400 && code == 'invalid_post_url') {
      return ApiException('invalid_post_url', detail: detail, status: status);
    }
    if (status == 502 && code == 'proxy_blocked') {
      return ApiException('proxy_blocked', detail: detail, status: status);
    }
    if (status >= 500 && status < 600 && code == 'server_error') {
      return ApiException('internal_error',
          detail: detail ?? 'HTTP $status', status: status);
    }

    return ApiException(code, detail: detail ?? 'HTTP $status', status: status);
  }

  factory ApiException.fromDio(DioException e) => _transport(e);
}
