// lib/utils/api_exception.dart
import 'dart:convert';
import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String code;
  final String? detail;
  ApiException(this.code, {this.detail});

  @override
  String toString() =>
      'ApiException($code${detail != null ? ": $detail" : ""})';

  static ApiException fromDio(DioException e) {
    // 1) Класифікуємо помилки транспорту ДО перевірки response
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
        // Перейдемо до розбору response нижче.
        break;
    }

    final r = e.response;
    if (r == null) {
      return ApiException('network_error', detail: e.message);
    }

    // 2) Розбір тіла відповіді
    String code = 'server_error';
    String? detail;
    dynamic data = r.data;

    // Якщо бек віддав JSON рядком — спробуємо розпарсити
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {/* лишаємо як є */}
    }

    if (data is Map) {
      code = (data['error'] as String?) ?? code;
      detail = (data['detail'] as String?) ?? (data['message'] as String?);
    } else {
      detail = 'HTTP ${r.statusCode}';
    }

    final s = r.statusCode ?? 0;

    // 3) Нормалізація відомих кейсів (узгоджено з UI)
    if (s == 401 && code == 'invalid_credentials') {
      return ApiException('invalid_credentials', detail: detail);
    }
    if (s == 401 && code == 'login_required') {
      return ApiException('login_required', detail: detail);
    }
    if (s == 412 && code == 'instagram_challenge') {
      return ApiException('instagram_challenge', detail: detail);
    }
    if (s == 403 && code == 'suspicious_login') {
      return ApiException('suspicious_login', detail: detail);
    }
    if (s == 429 || code == 'rate_limited') {
      return ApiException('rate_limited', detail: detail ?? 'HTTP 429');
    }
    if (s == 400 && code == 'invalid_post_url') {
      return ApiException('invalid_post_url', detail: detail);
    }
    if (s == 502 && code == 'proxy_blocked') {
      return ApiException('proxy_blocked', detail: detail);
    }
    if (s >= 500 && s < 600 && code == 'server_error') {
      return ApiException('internal_error', detail: detail ?? 'HTTP $s');
    }

    // 4) За замовчуванням — віддаємо те, що прийшло
    return ApiException(code, detail: detail ?? 'HTTP ${r.statusCode}');
  }
}
