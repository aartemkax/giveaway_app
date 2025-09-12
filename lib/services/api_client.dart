import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

// умовні імпорти: web -> http_adapter_web.dart, io -> http_adapter_io.dart
import 'http_adapter_stub.dart'
    if (dart.library.html) 'http_adapter_web.dart'
    if (dart.library.io) 'http_adapter_io.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient _i = ApiClient._();
  factory ApiClient() => _i;

  final CookieJar _jar = CookieJar();
  late final Dio dio = _build();

  Dio _build() {
    final baseUrl = (dotenv.env['API_BASE_URL'] ?? '').trim();
    if (baseUrl.isEmpty) {
      throw StateError('API_BASE_URL is not set in .env');
    }
    final d = Dio(BaseOptions(
      baseUrl: baseUrl,
      validateStatus: (s) => s != null && s < 600,
      headers: {'Accept': 'application/json'},
      // (за потреби) підніми таймаути
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(seconds: 25),
      sendTimeout: const Duration(seconds: 25),
    ));

    // платформи: веб/мобайл
    d.httpClientAdapter = newAdapter();

    // кукі: достатньо In-Memory на перший час (PersistCookieJar додаси пізніше)
    d.interceptors.add(CookieManager(CookieJar()));

    return d;
  }

  Future<void> clearCookies() => _jar.deleteAll();
}
