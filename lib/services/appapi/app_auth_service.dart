// lib/services/appapi/app_auth_service.dart
import 'package:dio/dio.dart';
import 'package:giveaway_app/services/api_client.dart';
import '../../utils/api_exception.dart';

class AuthService {
  final Dio _dio;

  AuthService() : _dio = ApiClient().dio; // старий шлях — не ламаємо
  AuthService.withDio(this._dio); // новий шлях через провайдер

  Future<void> login(
    String username,
    String password, {
    Map<String, dynamic>? deviceInfo,
  }) async {
    try {
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

  Future<void> loginBySessionId(String sessionId) async {
    try {
      await _dio
          .post('/api/login_by_sessionid', data: {'sessionid': sessionId});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> debugSession() async {
    try {
      final r = await _dio.get('/api/debug_session');
      return Map<String, dynamic>.from(r.data as Map);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
