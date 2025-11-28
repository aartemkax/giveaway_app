// lib/services/http_adapter_web.dart
import 'package:dio/dio.dart';
import 'package:dio/browser.dart' as dio_web;

// На Web використовуємо браузерні кукі — окремий CookieJar не потрібен.
HttpClientAdapter createHttpAdapter({required bool withCredentials}) {
  final adapter = dio_web.BrowserHttpClientAdapter();
  adapter.withCredentials = withCredentials;
  return adapter;
}

void attachCookieJarIfSupported(Dio dio) {
  // no-op на Web
}

Future<void> clearCookiesImpl() async {
  // Очищення кукі на Web через Dio недоступне — no-op
}
