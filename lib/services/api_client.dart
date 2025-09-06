// lib/services/api_client.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';

class ApiClient {
  static final ApiClient _i = ApiClient._();
  ApiClient._();
  factory ApiClient() => _i;

  Dio? _dio;
  PersistCookieJar? _jar;

  Dio get dio {
    if (_dio != null) return _dio!;
    final base = dotenv.env['API_BASE_URL']?.trim();
    if (base == null || base.isEmpty) {
      throw StateError('API_BASE_URL is not set in .env');
    }
    final d = Dio(BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      followRedirects: false,
      validateStatus: (code) => code != null && code >= 200 && code < 600,
      headers: {'Content-Type': 'application/json'},
    ));
    // під’єднаємо cookie-jar пізніше (async)
    _dio = d;
    return _dio!;
  }

  /// Викликни один раз на старті (у main) — підключає PersistCookieJar.
  Future<void> initCookies() async {
    if (_jar != null) return;
    final dir = await getApplicationSupportDirectory();
    _jar = PersistCookieJar(
      storage: FileStorage('${dir.path}${Platform.pathSeparator}cookies'),
    );
    dio.interceptors.removeWhere((i) => i is CookieManager);
    dio.interceptors.add(CookieManager(_jar!));
  }

  Future<void> clearCookies() async {
    await _jar?.deleteAll();
  }
}
