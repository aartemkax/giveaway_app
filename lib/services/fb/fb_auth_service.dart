// lib/services/fb/fb_auth_service.dart
import 'package:dio/dio.dart';
import 'package:giveaway_app/services/api_client.dart';
import 'package:giveaway_app/utils/api_exception.dart';

class FbAuthService {
  final Dio _dio;
  FbAuthService() : _dio = ApiClient().dio;
  FbAuthService.withDio(this._dio);

  /// Отримати URL для початку OAuth
  Future<String> getLoginUrl() async {
    try {
      final r = await _dio.get('/api/fb/login_url');
      if (r.statusCode == 200 && r.data is Map && r.data['url'] is String) {
        return r.data['url'] as String;
      }
      throw ApiException('server_error', detail: 'fb login_url malformed');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Хто ми зараз на бекенді (чи є валідний FB токен у Flask-сесії)
  Future<Map<String, dynamic>> whoAmI() async {
    try {
      final r = await _dio.get('/api/fb/whoami');
      if (r.statusCode == 200 && r.data is Map) {
        return Map<String, dynamic>.from(r.data as Map);
      }
      throw ApiException('login_required');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
