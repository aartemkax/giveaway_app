// lib/services/api_client.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/browser.dart' if (dart.library.io) 'package:dio/io.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient _i = ApiClient._();
  factory ApiClient() => _i;

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
    ));
    if (kIsWeb) {
      final adapter = BrowserHttpClientAdapter()..withCredentials = true;
      d.httpClientAdapter = adapter;
      d.interceptors.add(CookieManager(CookieJar())); // тільки пам’ять
    } else {
      d.interceptors.add(CookieManager(CookieJar()));
    }
    return d;
  }
}
