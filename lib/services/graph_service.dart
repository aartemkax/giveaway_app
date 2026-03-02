// lib/services/graph_service.dart
import 'package:dio/dio.dart';
import 'api_client.dart';

class GraphService {
  final Dio _dio = ApiClient().dio;

  Future<String> loginUrl() async {
    final r = await _dio.get('/api/fb/login_url');
    return (r.data['url'] as String);
  }

  Future<Map<String, dynamic>> whoami() async {
    final r = await _dio.get('/api/fb/_whoami');
    return r.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> igAccounts() async {
    final r = await _dio.get('/api/ig/accounts');
    final list = (r.data['accounts'] as List? ?? []);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> media(String igUserId, String pageId,
      {String? after}) async {
    final r = await _dio.get('/api/ig/media', queryParameters: {
      'ig_user_id': igUserId,
      'page_id': pageId,
      if (after != null) 'after': after,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> resolveMedia({
    required String igUserId,
    required String pageId,
    required String permalink,
  }) async {
    final r = await _dio.get('/api/ig/resolve_media', queryParameters: {
      'ig_user_id': igUserId,
      'page_id': pageId,
      'permalink': permalink,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> comments(String mediaId, String pageId,
      {String? after}) async {
    final r = await _dio.get('/api/ig/comments', queryParameters: {
      'media_id': mediaId,
      'page_id': pageId,
      if (after != null) 'after': after,
    });
    return r.data as Map<String, dynamic>;
  }
}
