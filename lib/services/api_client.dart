// lib/services/api_client.dart
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';

import 'package:giveaway_app/utils/constants.dart';

class ApiClient {
  ApiClient._internal();

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  late final PersistCookieJar _cookieJar;

  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;

    final dir = await getApplicationDocumentsDirectory();
    _cookieJar = PersistCookieJar(
      ignoreExpires: true,
      storage: FileStorage('${dir.path}/cookies'),
    );

    dio = Dio(
      BaseOptions(
        baseUrl: apiBaseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
        headers: const {'Accept': 'application/json'},
      ),
    );

    dio.interceptors.add(CookieManager(_cookieJar));
    dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));

    _inited = true;
  }

  Future<void> clearCookies() => _cookieJar.deleteAll();
}
