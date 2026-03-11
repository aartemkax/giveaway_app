// lib/services/auth_service.dart
import 'package:dio/dio.dart';
import 'package:giveaway_app/services/api_client.dart';
import '../utils/api_exception.dart';

class AuthService {
  Dio get _dio => ApiClient().dio;

  Future<void> login(
    String username,
    String password, {
    Map<String, dynamic>? deviceInfo,
  }) async {
    try {
      await ApiClient().init();

      await _dio.post(
        '/api/login',
        data: {
          'username': username.trim(),
          'password': password.trim(),
          'deviceInfo': deviceInfo ?? {},
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  // Лишити можна, але не як основний flow
  Future<void> loginBySessionId(String sessionId) async {
    try {
      await ApiClient().init();

      await _dio.post(
        '/api/login_by_sessionid',
        data: {'sessionid': sessionId},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<bool> hasValidSession() async {
    try {
      await ApiClient().init();

      final r = await _dio.get('/api/session_status');
      final data = Map<String, dynamic>.from(r.data as Map);
      return data['authenticated'] == true;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> debugSession() async {
    try {
      await ApiClient().init();

      final r = await _dio.get('/api/debug_session');
      return Map<String, dynamic>.from(r.data as Map);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> logout() async {
    try {
      await ApiClient().init();
      await _dio.post('/api/logout');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } finally {
      await ApiClient().clearCookies();
    }
  }
}
