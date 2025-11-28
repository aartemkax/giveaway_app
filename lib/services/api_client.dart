//lib/services/api_client.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart' as fdotenv;

// Умовна платформа: для мобільних/десктопа — IO, для Web — browser.
import 'http_adapter_io.dart' if (dart.library.html) 'http_adapter_web.dart';

class ApiClient {
  static final ApiClient _i = ApiClient._();
  factory ApiClient() => _i;

  late final Dio dio;

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

    // Створюємо відповідний адаптер і прикріплюємо cookie-jar там, де це можливо.
    dio.httpClientAdapter = createHttpAdapter(withCredentials: kIsWeb);
    attachCookieJarIfSupported(dio);
  }

  Future<void> clearCookies() async {
    await clearCookiesImpl();
  }
}
