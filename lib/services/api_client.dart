// lib/services/api_client.dart

import 'package:dio/dio.dart';
import 'package:giveaway_app/utils/constants.dart';

class ApiClient {
  ApiClient._internal();

  static final ApiClient _instance = ApiClient._internal();

  factory ApiClient() => _instance;

  late final Dio dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 60),
      headers: {'Accept': 'application/json'},
    ),
  )..interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
      ),
    );

  /// Місце для очищення cookie Dio (якщо додаси CookieJar/CookieManager).
  Future<void> clearCookies() async {
    // Наразі нічого не робить, але метод існує й не ламає компіляцію.
  }
}
