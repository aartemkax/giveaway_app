import 'package:dio/dio.dart';
import 'package:dio/io.dart' show IOHttpClientAdapter;

HttpClientAdapter createHttpAdapter({required bool withCredentials}) {
  return IOHttpClientAdapter();
}

void attachCookieJarIfSupported(Dio dio) {
  // no-op: cookies керуються ApiClient
}

Future<void> clearCookiesImpl() async {
  // no-op
}
