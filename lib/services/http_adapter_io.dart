// lib/services/http_adapter_io.dart
import 'package:dio/dio.dart';
import 'package:dio/io.dart' show IOHttpClientAdapter;
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

final _cookieJar = CookieJar();

HttpClientAdapter createHttpAdapter({required bool withCredentials}) {
  // withCredentials не має сенсу для IO
  return IOHttpClientAdapter();
}

void attachCookieJarIfSupported(Dio dio) {
  dio.interceptors.add(CookieManager(_cookieJar));
}

Future<void> clearCookiesImpl() async {
  try {
    await _cookieJar.deleteAll();
  } catch (_) {}
}
