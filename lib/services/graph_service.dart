// lib/services/graph_service.dart
import 'package:dio/dio.dart';
import 'api_client.dart';

class GraphService {
  final Dio _dio = ApiClient().dio;

  Future<String> loginUrl() async {
    final r = await _dio.get('/api/fb/login_url');
    return (r.data['url'] as String);
  }

  // Після успішного OAuth бекенд вже збереже токен в сесії (cookie)
  // Тому тут просто опитуємо:
  Future<List<Map<String, dynamic>>> igAccounts() async {
    final r = await _dio.get('/api/ig/accounts');
    return (r.data['accounts'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> media(String igUserId, {String? after}) async {
    final r = await _dio.get('/api/ig/media', queryParameters: {
      'ig_user_id': igUserId,
      if (after != null) 'after': after,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> comments(String mediaId, {String? after}) async {
    final r = await _dio.get('/api/ig/comments', queryParameters: {
      'media_id': mediaId,
      if (after != null) 'after': after,
    });
    return r.data as Map<String, dynamic>;
  }
}
