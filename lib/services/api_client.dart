import 'package:dio/dio.dart';
import 'package:dio/io.dart' show IOHttpClientAdapter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/browser.dart' as dio_web;
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' as fdotenv;

class ApiClient {
  static final ApiClient _i = ApiClient._();
  factory ApiClient() => _i;

  late final Dio dio;
  CookieJar? _cookieJar;

  ApiClient._() {
    final defineBase =
        const String.fromEnvironment('API_BASE', defaultValue: '');
    final envBase = fdotenv.dotenv.maybeGet('API_BASE') ?? '';
    final baseUrl = (defineBase.isNotEmpty ? defineBase : envBase).isNotEmpty
        ? (defineBase.isNotEmpty ? defineBase : envBase)
        : 'http://10.0.2.2:8000';

    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ));

    if (kIsWeb) {
      dio.httpClientAdapter = dio_web.BrowserHttpClientAdapter()
        ..withCredentials = true;
    } else {
      dio.httpClientAdapter = IOHttpClientAdapter();
      _cookieJar = CookieJar();
      dio.interceptors.add(CookieManager(_cookieJar!));
    }
  }

  Future<void> clearCookies() async {
    if (kIsWeb) return;
    try {
      await _cookieJar?.deleteAll();
    } catch (_) {}
  }
}
