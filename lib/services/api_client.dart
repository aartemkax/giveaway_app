// lib/services/api_client.dart

import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

import 'package:giveaway_app/utils/constants.dart';

class ApiClient {
  ApiClient._internal() {
    _cookieJar = CookieJar();

    dio = Dio(
      BaseOptions(
        baseUrl: apiBaseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
        headers: {
          'Accept': 'application/json',
        },
      ),
    );

    // Спочатку cookie-менеджер, потім логер (щоб у логах були Cookie/Set-Cookie)
    dio.interceptors.add(CookieManager(_cookieJar));
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
      ),
    );
  }

  static final ApiClient _instance = ApiClient._internal();

  factory ApiClient() => _instance;

  late final Dio dio;
  late final CookieJar _cookieJar;

  /// Очищення всіх HTTP-cookie Dio (для logout)
  Future<void> clearCookies() async {
    await _cookieJar.deleteAll();
  }
}
